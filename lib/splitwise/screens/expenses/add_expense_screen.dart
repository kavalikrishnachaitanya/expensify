import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:expenses/splitwise/models/group_model.dart';
import 'package:expenses/splitwise/providers/auth_provider.dart';
import 'package:expenses/splitwise/providers/expense_provider.dart';
import 'package:expenses/splitwise/utils/constants.dart';
import 'package:expenses/splitwise/utils/helpers.dart';

class AddExpenseScreen extends StatefulWidget {
  final GroupModel group;

  const AddExpenseScreen({super.key, required this.group});

  @override
  State<AddExpenseScreen> createState() => _AddExpenseScreenState();
}

class _AddExpenseScreenState extends State<AddExpenseScreen> {
  final _formKey = GlobalKey<FormState>();
  final _descriptionController = TextEditingController();
  final _amountController = TextEditingController();

  String? _paidBy;
  Set<String> _splitAmong = {};

  @override
  void initState() {
    super.initState();
    // Default: current user pays and split among all
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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select who paid')),
        );
        return;
      }

      if (_splitAmong.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select who to split with')),
        );
        return;
      }

      final expenseProvider = context.read<ExpenseProvider>();
      final amount = double.tryParse(_amountController.text.trim()) ?? 0;

      final expenseId = await expenseProvider.addExpense(
        groupId: widget.group.id,
        description: _descriptionController.text.trim(),
        amount: amount,
        paidBy: _paidBy!,
        paidByName: widget.group.memberNames[_paidBy] ?? 'Unknown',
        splitAmongIds: _splitAmong.toList(),
        memberNames: widget.group.memberNames,
        groupMemberIds: widget.group.memberIds,
      );

      if (expenseId != null && mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Expense added successfully!')),
        );
      } else if (expenseProvider.error != null && mounted) {
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
        title: const Text('Add Expense'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Description
              TextFormField(
                controller: _descriptionController,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Description',
                  hintText: 'e.g., Dinner',
                  prefixIcon: Icon(Icons.description_outlined),
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter a description';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Amount
              TextFormField(
                controller: _amountController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: 'Amount',
                  hintText: '0.00',
                  prefixIcon: const Icon(Icons.currency_rupee),
                  prefixText: '${AppConstants.currency} ',
                  border: const OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter an amount';
                  }
                  final amount = double.tryParse(value.trim());
                  if (amount == null || amount <= 0) {
                    return 'Please enter a valid amount';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),

              // Paid By
              Text(
                'Paid by',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: widget.group.memberIds.map((memberId) {
                  final memberName = widget.group.memberNames[memberId] ?? 'Unknown';
                  final isSelected = _paidBy == memberId;
                  final isCurrentUser = memberId == currentUserId;

                  return ChoiceChip(
                    label: Text(isCurrentUser ? 'You' : memberName),
                    selected: isSelected,
                    onSelected: (selected) {
                      if (selected) {
                        setState(() {
                          _paidBy = memberId;
                        });
                      }
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 24),

              // Split Among
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Split equally among',
                    style: Theme.of(context).textTheme.titleMedium,
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
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: widget.group.memberIds.map((memberId) {
                  final memberName = widget.group.memberNames[memberId] ?? 'Unknown';
                  final isSelected = _splitAmong.contains(memberId);
                  final isCurrentUser = memberId == currentUserId;

                  return FilterChip(
                    label: Text(isCurrentUser ? 'You' : memberName),
                    selected: isSelected,
                    onSelected: (selected) {
                      setState(() {
                        if (selected) {
                          _splitAmong.add(memberId);
                        } else {
                          _splitAmong.remove(memberId);
                        }
                      });
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),

              // Split Preview
              if (_splitAmong.isNotEmpty &&
                  _amountController.text.isNotEmpty) ...[
                Builder(
                  builder: (context) {
                    final amount =
                        double.tryParse(_amountController.text.trim()) ?? 0;
                    final splitAmount =
                        Helpers.calculateEqualSplit(amount, _splitAmong.length);

                    return Card(
                      color: colorScheme.surfaceContainerHighest,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Each person pays:',
                              style: Theme.of(context).textTheme.bodyLarge,
                            ),
                            Text(
                              Helpers.formatCurrency(splitAmount),
                              style: Theme.of(context)
                                  .textTheme
                                  .titleLarge
                                  ?.copyWith(
                                    color: colorScheme.primary,
                                    fontWeight: FontWeight.bold,
                                  ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ],
              const SizedBox(height: 32),

              // Add Button
              Consumer<ExpenseProvider>(
                builder: (context, expenseProvider, child) {
                  return FilledButton(
                    onPressed: expenseProvider.isLoading ? null : _addExpense,
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: expenseProvider.isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Add Expense'),
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
