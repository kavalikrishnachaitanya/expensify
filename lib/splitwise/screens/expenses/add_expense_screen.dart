import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:expenses/utils/id_generator.dart';
import 'package:expenses/models.dart';
import 'package:expenses/splitwise/models/group_model.dart';
import 'package:expenses/splitwise/providers/auth_provider.dart';
import 'package:expenses/splitwise/providers/expense_provider.dart';


class AddExpenseScreen extends StatefulWidget {
  final GroupModel group;
  final String? initialDescription;
  final double? initialAmount;
  final Function(Expense)? onAddPersonalExpense;
  final List<Expense>? personalExpenses;
  final List<ExpenseCategory>? categories;
  final bool isImported;
  final Expense? pendingPersonalExpense;

  const AddExpenseScreen({
    super.key,
    required this.group,
    this.initialDescription,
    this.initialAmount,
    this.onAddPersonalExpense,
    this.personalExpenses,
    this.categories,
    this.isImported = false,
    this.pendingPersonalExpense,
  });

  @override
  State<AddExpenseScreen> createState() => _AddExpenseScreenState();
}

class _AddExpenseScreenState extends State<AddExpenseScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _descriptionController;
  late final TextEditingController _amountController;

  String? _paidBy;
  Set<String> _splitAmong = {};
  bool _syncToPersonalTracker = true;
  String _selectedCategoryId = 'cat_food';



  @override
  void initState() {
    super.initState();
    if (widget.pendingPersonalExpense != null) {
      _descriptionController = TextEditingController(text: widget.pendingPersonalExpense!.title);
      _amountController = TextEditingController(text: widget.pendingPersonalExpense!.amount.toStringAsFixed(2));
      _selectedCategoryId = widget.pendingPersonalExpense!.categoryId;
      _syncToPersonalTracker = true;
    } else {
      _descriptionController = TextEditingController(text: widget.initialDescription ?? '');
      _amountController = TextEditingController(
        text: widget.initialAmount != null ? widget.initialAmount!.toStringAsFixed(2) : '',
      );
      _syncToPersonalTracker = !widget.isImported && widget.initialDescription == null;
    }

    final currentUserId = context.read<AuthProvider>().user?.uid;
    _paidBy = currentUserId;
    _splitAmong = widget.group.memberIds.toSet();
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _amountController.dispose();
    super.dispose();
  }




  Future<void> _addExpense() async {
    if (_formKey.currentState?.validate() ?? false) {
      if (_paidBy == null) {
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select who paid')),
        );
        return;
      }

      if (_splitAmong.isEmpty) {
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select who to split with')),
        );
        return;
      }

      final expenseProvider = context.read<ExpenseProvider>();
      final authProvider = context.read<AuthProvider>();
      final amount = double.tryParse(_amountController.text.trim()) ?? 0;
      final descriptionText = _descriptionController.text.trim();

      final payerPhotoUrl = _paidBy == authProvider.user?.uid
          ? (authProvider.userModel?.photoUrl ?? authProvider.user?.photoURL)
          : null;

      final String personalExpenseId = widget.pendingPersonalExpense?.id ??
          IdGenerator.generateExpenseId();

      final expenseId = await expenseProvider.addExpense(
        groupId: widget.group.id,
        description: descriptionText,
        amount: amount,
        paidBy: _paidBy!,
        paidByName: widget.group.memberNames[_paidBy] ?? 'Unknown',
        paidByPhotoUrl: payerPhotoUrl,
        splitAmongIds: _splitAmong.toList(),
        memberNames: widget.group.memberNames,
        groupMemberIds: widget.group.memberIds,
        linkedPersonalExpenseId: personalExpenseId,
      );

      if (expenseId != null && mounted) {
        // Automatically sync & record to personal Expensify transactions list using chosen category
        if (_syncToPersonalTracker && widget.onAddPersonalExpense != null) {
          final personalExpense = widget.pendingPersonalExpense != null
              ? widget.pendingPersonalExpense!.copyWith(linkedTransactionId: expenseId)
              : Expense(
                  id: personalExpenseId,
                  title: '${widget.group.name}: $descriptionText',
                  amount: amount,
                  date: DateTime.now(),
                  categoryId: _selectedCategoryId,
                  paymentMethod: PaymentMethod.creditCard,
                  note: 'Splitwise Group Expense in "${widget.group.name}" with ${_splitAmong.length} members',
                  linkedTransactionId: expenseId,
                );
          widget.onAddPersonalExpense!(personalExpense);
        }

        Navigator.pop(context);
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _syncToPersonalTracker && widget.onAddPersonalExpense != null
                  ? 'Expense added & synced to your personal transactions!'
                  : 'Expense added to Splitwise group!',
            ),
          ),
        );
      } else if (expenseProvider.error != null && mounted) {
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(expenseProvider.error!),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final currentUserId = context.read<AuthProvider>().user?.uid;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.initialDescription != null ? 'Split Transaction' : 'Add Group Expense'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Description
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Description',
                  hintText: 'Dinner, Rent, Groceries...',
                  prefixIcon: Icon(Icons.description_outlined),
                  border: OutlineInputBorder(),
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return 'Please enter a description';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Amount
              TextFormField(
                controller: _amountController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                ],
                decoration: const InputDecoration(
                  labelText: 'Amount (₹)',
                  hintText: '0.00',
                  prefixIcon: Icon(Icons.currency_rupee_rounded),
                  border: OutlineInputBorder(),
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return 'Please enter an amount';
                  }
                  final amt = double.tryParse(val.trim());
                  if (amt == null || amt <= 0) {
                    return 'Please enter a valid positive amount';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),



              // Paid By
              Text(
                'Paid By',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 8),
              Card(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  child: Column(
                    children: widget.group.memberIds.map((memberId) {
                      final memberName = widget.group.memberNames[memberId] ?? 'Unknown';
                      final isMe = memberId == currentUserId;

                      return RadioListTile<String>(
                        title: Text(isMe ? 'You ($memberName)' : memberName),
                        value: memberId,
                        // ignore: deprecated_member_use
                        groupValue: _paidBy,
                        // ignore: deprecated_member_use
                        onChanged: (val) {
                          if (val != null) {
                            setState(() => _paidBy = val);
                          }
                        },
                      );
                    }).toList(),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Split Among
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Split Among (${_splitAmong.length}/${widget.group.memberIds.length})',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  TextButton(
                    onPressed: () {
                      setState(() {
                        if (_splitAmong.length == widget.group.memberIds.length) {
                          _splitAmong.clear();
                        } else {
                          _splitAmong = widget.group.memberIds.toSet();
                        }
                      });
                    },
                    child: Text(
                      _splitAmong.length == widget.group.memberIds.length
                          ? 'Deselect All'
                          : 'Select All',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Card(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  child: Column(
                    children: widget.group.memberIds.map((memberId) {
                      final memberName = widget.group.memberNames[memberId] ?? 'Unknown';
                      final isMe = memberId == currentUserId;
                      final isSelected = _splitAmong.contains(memberId);

                      return CheckboxListTile(
                        title: Text(isMe ? 'You ($memberName)' : memberName),
                        value: isSelected,
                        onChanged: (val) {
                          setState(() {
                            if (val == true) {
                              _splitAmong.add(memberId);
                            } else {
                              _splitAmong.remove(memberId);
                            }
                          });
                        },
                      );
                    }).toList(),
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Submit Button
              Consumer<ExpenseProvider>(
                builder: (context, provider, child) {
                  final bool canSave = _splitAmong.isNotEmpty && _paidBy != null && !provider.isLoading;
                  return SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: canSave ? _addExpense : null,
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: provider.isLoading
                          ? SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: colorScheme.onPrimary,
                              ),
                            )
                          : const Text(
                              'Save Group Expense',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Modal widget for picking personal transactions with Search, Month & Year Filters!
class TransactionPickerModal extends StatefulWidget {
  final List<Expense> allExpenses;
  final Function(Expense) onSelectTransaction;

  const TransactionPickerModal({
    super.key,
    required this.allExpenses,
    required this.onSelectTransaction,
  });

  @override
  State<TransactionPickerModal> createState() => _TransactionPickerModalState();
}

class _TransactionPickerModalState extends State<TransactionPickerModal> {
  final TextEditingController _searchController = TextEditingController();
  int? _selectedMonth; // null = All Months, 1..12
  int? _selectedYear; // null = All Years

  final List<String> _monthNames = const [
    'All Months',
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final query = _searchController.text.trim().toLowerCase();

    // Dynamically extract available years from all transactions + current year
    final years = <int>{DateTime.now().year};
    for (final exp in widget.allExpenses) {
      years.add(exp.date.year);
    }
    final sortedYears = years.toList()..sort((a, b) => b.compareTo(a));

    // Filter matching expenses
    final filtered = widget.allExpenses.where((exp) {
      if (query.isNotEmpty) {
        final titleMatches = exp.title.toLowerCase().contains(query);
        final amountMatches = exp.amount.toString().contains(query);
        if (!titleMatches && !amountMatches) return false;
      }

      if (_selectedMonth != null && exp.date.month != _selectedMonth) {
        return false;
      }

      if (_selectedYear != null && exp.date.year != _selectedYear) {
        return false;
      }

      return true;
    }).toList();

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (ctx, scrollController) {
        return Container(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Drag Handle Bar
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Import Personal Transaction',
                    style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Filter across all months/years & search to import any past transaction into your group split.',
                style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: 16),

              // Search Bar
              TextField(
                controller: _searchController,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  hintText: 'Search by title or amount...',
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: query.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear_rounded),
                          onPressed: () {
                            _searchController.clear();
                            setState(() {});
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: theme.colorScheme.surfaceContainerHigh,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
              ),
              const SizedBox(height: 12),

              // Month & Year Filter Row
              Row(
                children: [
                  // Month Dropdown Filter
                  Expanded(
                    flex: 3,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHigh,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<int?>(
                          value: _selectedMonth,
                          isExpanded: true,
                          hint: const Text('Month: All'),
                          icon: const Icon(Icons.filter_list_rounded, size: 18),
                          items: List.generate(13, (idx) {
                            final monthVal = idx == 0 ? null : idx;
                            return DropdownMenuItem<int?>(
                              value: monthVal,
                              child: Text(
                                _monthNames[idx],
                                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                              ),
                            );
                          }),
                          onChanged: (val) => setState(() => _selectedMonth = val),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),

                  // Year Dropdown Filter
                  Expanded(
                    flex: 2,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHigh,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<int?>(
                          value: _selectedYear,
                          isExpanded: true,
                          hint: const Text('Year: All'),
                          items: [
                            const DropdownMenuItem<int?>(
                              value: null,
                              child: Text('All Years', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                            ),
                            ...sortedYears.map((yr) => DropdownMenuItem<int?>(
                                  value: yr,
                                  child: Text('$yr', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                                )),
                          ],
                          onChanged: (val) => setState(() => _selectedYear = val),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Filter Count Summary & Reset
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Showing ${filtered.length} transactions',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  if (_selectedMonth != null || _selectedYear != null || query.isNotEmpty)
                    InkWell(
                      onTap: () {
                        setState(() {
                          _selectedMonth = null;
                          _selectedYear = null;
                          _searchController.clear();
                        });
                      },
                      child: Text(
                        'Reset Filters',
                        style: TextStyle(
                          fontSize: 12,
                          color: theme.colorScheme.error,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),

              // Transactions List
              Expanded(
                child: filtered.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.search_off_rounded, size: 56, color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5)),
                            const SizedBox(height: 12),
                            Text(
                              'No transactions match your filter.',
                              style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        controller: scrollController,
                        itemCount: filtered.length,
                        itemBuilder: (context, index) {
                          final expense = filtered[index];
                          return Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: theme.colorScheme.primaryContainer,
                                child: Icon(Icons.receipt_long_rounded, color: theme.colorScheme.primary, size: 20),
                              ),
                              title: Text(expense.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                              subtitle: Text(
                                '${expense.date.day}/${expense.date.month}/${expense.date.year}',
                                style: const TextStyle(fontSize: 12),
                              ),
                              trailing: Text(
                                '₹${expense.amount.toStringAsFixed(2)}',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  color: theme.colorScheme.primary,
                                ),
                              ),
                              onTap: () => widget.onSelectTransaction(expense),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}
