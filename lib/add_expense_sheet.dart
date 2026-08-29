import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'utils/id_generator.dart';
import 'models.dart';

class AddExpenseSheet extends StatefulWidget {
  final List<ExpenseCategory> categories;
  final String currencySymbol;
  final Expense? expenseToEdit;
  final List<CreditCard> creditCards;
  final Function(Expense) onAddExpense;

  const AddExpenseSheet({
    super.key,
    required this.categories,
    required this.currencySymbol,
    this.expenseToEdit,
    this.creditCards = const [],
    required this.onAddExpense,
  });

  @override
  State<AddExpenseSheet> createState() => _AddExpenseSheetState();
}

class _AddExpenseSheetState extends State<AddExpenseSheet> {
  final _titleController = TextEditingController();
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();
  String? _errorMessage;

  late String _selectedCategoryId;
  PaymentMethod _selectedPaymentMethod = PaymentMethod.creditCard;
  String? _selectedCreditCardId;
  DateTime _selectedDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    if (widget.expenseToEdit != null) {
      final exp = widget.expenseToEdit!;
      _titleController.text = exp.title;
      _amountController.text = exp.amount.toStringAsFixed(2);
      _noteController.text = exp.note ?? '';
      _selectedCategoryId = exp.categoryId;
      _selectedPaymentMethod = exp.paymentMethod;
      _selectedCreditCardId = exp.creditCardId;
      _selectedDate = exp.date;
    } else {
      _selectedCategoryId = widget.categories.isNotEmpty ? widget.categories.first.id : '';
      if (widget.creditCards.isNotEmpty) {
        _selectedCreditCardId = widget.creditCards.first.id;
      }
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  void _submitData() {
    final titleText = _titleController.text.trim();
    final amount = double.tryParse(_amountController.text.trim());

    if (amount == null || amount <= 0) {
      setState(() {
        _errorMessage = 'Please enter a valid amount (> 0)';
      });
      return;
    }

    if (titleText.isEmpty) {
      setState(() {
        _errorMessage = 'Please enter an expense title';
      });
      return;
    }

    final newExpense = Expense(
      id: widget.expenseToEdit?.id ?? IdGenerator.generateExpenseId(),
      title: titleText,
      amount: amount,
      date: _selectedDate,
      categoryId: _selectedCategoryId,
      paymentMethod: _selectedPaymentMethod,
      note: _noteController.text.trim().isEmpty ? null : _noteController.text.trim(),
      linkedTransactionId: widget.expenseToEdit?.linkedTransactionId,
      creditCardId: _selectedPaymentMethod == PaymentMethod.creditCard ? _selectedCreditCardId : null,
    );

    Navigator.of(context).pop();
    widget.onAddExpense(newExpense);
  }

  Future<void> _pickDate() async {
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );

    if (pickedDate != null) {
      setState(() {
        _selectedDate = DateTime(
          pickedDate.year,
          pickedDate.month,
          pickedDate.day,
          _selectedDate.hour,
          _selectedDate.minute,
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: bottomInset + 20,
      ),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: theme.colorScheme.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              widget.expenseToEdit != null ? 'Edit Expense' : 'Add New Expense',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),

            // Amount Input Card
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: (_errorMessage != null && (double.tryParse(_amountController.text.trim()) == null || double.tryParse(_amountController.text.trim())! <= 0))
                    ? theme.colorScheme.errorContainer.withValues(alpha: 0.3)
                    : theme.colorScheme.primaryContainer.withAlpha(80),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: (_errorMessage != null && (double.tryParse(_amountController.text.trim()) == null || double.tryParse(_amountController.text.trim())! <= 0))
                      ? theme.colorScheme.error
                      : theme.colorScheme.primary.withAlpha(100),
                ),
              ),
              child: Row(
                children: [
                  Text(
                    widget.currencySymbol,
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _amountController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                        LengthLimitingTextInputFormatter(10),
                      ],
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.onSurface,
                      ),
                      decoration: const InputDecoration(
                        hintText: '0.00',
                        border: InputBorder.none,
                      ),
                      onChanged: (_) {
                        if (_errorMessage != null) setState(() => _errorMessage = null);
                      },
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Title Input
            TextField(
              controller: _titleController,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                labelText: 'Expense Title',
                hintText: 'e.g. Dinner, Coffee, Gas bill',
                prefixIcon: const Icon(Icons.edit_note_rounded),
                errorText: _errorMessage != null && _titleController.text.trim().isEmpty ? 'Expense title is required' : null,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onChanged: (_) {
                if (_errorMessage != null) setState(() => _errorMessage = null);
              },
            ),
            const SizedBox(height: 20),

            // Category Selection Grid
            Text(
              'Select Category',
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 100,
              child: GridView.builder(
                scrollDirection: Axis.horizontal,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 1,
                  mainAxisSpacing: 12,
                  childAspectRatio: 1.1,
                ),
                itemCount: widget.categories.length,
                itemBuilder: (context, index) {
                  final cat = widget.categories[index];
                  final isSelected = cat.id == _selectedCategoryId;

                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        _selectedCategoryId = cat.id;
                      });
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? cat.color.withAlpha(40)
                            : theme.colorScheme.surfaceContainerHigh,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isSelected ? cat.color : Colors.transparent,
                          width: 2,
                        ),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: cat.color.withAlpha(200),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(cat.icon, color: Colors.white, size: 20),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            cat.name,
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                              color: isSelected ? cat.color : theme.colorScheme.onSurface,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 20),

            // Payment Method Chips
            Text(
              'Payment Method',
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: PaymentMethod.values.map((pm) {
                final isSelected = _selectedPaymentMethod == pm;
                return ChoiceChip(
                  showCheckmark: false,
                  avatar: Icon(
                    pm.icon,
                    size: 16,
                    color: isSelected ? theme.colorScheme.onPrimary : theme.colorScheme.onSurface,
                  ),
                  label: Text(pm.label),
                  selected: isSelected,
                  onSelected: (selected) {
                    if (selected) {
                      setState(() {
                        _selectedPaymentMethod = pm;
                      });
                    }
                  },
                );
              }).toList(),
            ),
            if (_selectedPaymentMethod == PaymentMethod.creditCard && widget.creditCards.isNotEmpty) ...[
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: widget.creditCards.any((c) => c.id == _selectedCreditCardId)
                    ? _selectedCreditCardId
                    : widget.creditCards.first.id,
                decoration: InputDecoration(
                  labelText: 'Select Credit Card',
                  prefixIcon: const Icon(Icons.credit_card_rounded),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                ),
                items: widget.creditCards.map((c) {
                  return DropdownMenuItem(
                    value: c.id,
                    child: Text('${c.bankName} ${c.cardName} (•••• ${c.last4Digits})'),
                  );
                }).toList(),
                onChanged: (val) {
                  setState(() => _selectedCreditCardId = val);
                },
              ),
            ],
            const SizedBox(height: 16),

            // Date Picker Row
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: _pickDate,
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        border: Border.all(color: theme.colorScheme.outlineVariant),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.calendar_today_rounded, size: 18, color: theme.colorScheme.primary),
                          const SizedBox(width: 10),
                          Text(
                            'Date: ${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: theme.colorScheme.onSurface,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Note Input
            TextField(
              controller: _noteController,
              decoration: InputDecoration(
                labelText: 'Note (Optional)',
                hintText: 'Add description or receipt memo',
                prefixIcon: const Icon(Icons.notes_rounded),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onChanged: (_) {
                if (_errorMessage != null) setState(() => _errorMessage = null);
              },
            ),
            if (_errorMessage != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: theme.colorScheme.errorContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(Icons.error_outline_rounded, size: 18, color: theme.colorScheme.error),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: TextStyle(fontSize: 13, color: theme.colorScheme.onErrorContainer, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 20),

            // Save Button
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: _submitData,
                icon: const Icon(Icons.check_circle_rounded),
                label: Text(
                  widget.expenseToEdit != null ? 'Save Changes' : 'Add Expense',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.colorScheme.primary,
                  foregroundColor: theme.colorScheme.onPrimary,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 2,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
