import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'models.dart';
import 'utils/id_generator.dart';

class AddCreditCardSheet extends StatefulWidget {
  final CreditCard? cardToEdit;
  final List<CreditCard> existingCards;
  final Function(CreditCard) onSaveCard;

  const AddCreditCardSheet({
    super.key,
    this.cardToEdit,
    this.existingCards = const [],
    required this.onSaveCard,
  });

  @override
  State<AddCreditCardSheet> createState() => _AddCreditCardSheetState();
}

class _AddCreditCardSheetState extends State<AddCreditCardSheet> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _bankController;
  late TextEditingController _nameController;
  late TextEditingController _digitsController;
  late TextEditingController _limitController;
  late TextEditingController _billingDayController;
  late TextEditingController _dueDayController;

  String _selectedNetwork = 'Visa';
  int _selectedColorHex = 0xFF1E272E;
  bool _isSharedLimit = true;

  final List<String> _networks = ['Visa', 'Mastercard', 'RuPay', 'Amex', 'Diners'];
  final List<int> _cardColors = [
    0xFF1E272E, // Matte Black
    0xFF0984E3, // Royal Blue
    0xFF6C5CE7, // Deep Purple
    0xFFD63031, // Ruby Red
    0xFF00B894, // Emerald Green
    0xFFF39C12, // Gold / Bronze
    0xFF2D3436, // Charcoal
  ];

  @override
  void initState() {
    super.initState();
    final card = widget.cardToEdit;
    _bankController = TextEditingController(text: card?.bankName ?? '');
    _nameController = TextEditingController(text: card?.cardName ?? '');
    _digitsController = TextEditingController(text: card?.last4Digits ?? '');
    _limitController = TextEditingController(
      text: card != null && card.creditLimit > 0 ? card.creditLimit.toStringAsFixed(0) : '',
    );
    _billingDayController = TextEditingController(
      text: card?.billingCycleDay?.toString() ?? '',
    );
    _dueDayController = TextEditingController(
      text: card?.paymentDueDay?.toString() ?? '',
    );
    if (card != null) {
      _selectedNetwork = card.cardNetwork;
      _selectedColorHex = card.colorHex;
      _isSharedLimit = card.isSharedLimit;
    }
  }

  @override
  void dispose() {
    _bankController.dispose();
    _nameController.dispose();
    _digitsController.dispose();
    _limitController.dispose();
    _billingDayController.dispose();
    _dueDayController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;

    final limit = double.tryParse(_limitController.text.trim()) ?? 0.0;
    final billingDay = int.tryParse(_billingDayController.text.trim());
    final dueDay = int.tryParse(_dueDayController.text.trim());

    final newCard = CreditCard(
      id: widget.cardToEdit?.id ?? IdGenerator.generateExpenseId(),
      bankName: _bankController.text.trim(),
      cardName: _nameController.text.trim(),
      last4Digits: _digitsController.text.trim(),
      cardNetwork: _selectedNetwork,
      creditLimit: limit,
      billingCycleDay: billingDay,
      paymentDueDay: dueDay,
      colorHex: _selectedColorHex,
      isSharedLimit: _isSharedLimit,
    );

    widget.onSaveCard(newCard);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Form(
          key: _formKey,
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
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(Icons.credit_card_rounded, color: theme.colorScheme.primary, size: 24),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      widget.cardToEdit == null ? 'Add Credit Card' : 'Edit Credit Card',
                      style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Card Preview Widget
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Color(_selectedColorHex),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Color(_selectedColorHex).withAlpha(100),
                        blurRadius: 16,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            _bankController.text.isEmpty ? 'BANK NAME' : _bankController.text.toUpperCase(),
                            style: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.bold, letterSpacing: 1.2),
                          ),
                          Text(
                            _selectedNetwork.toUpperCase(),
                            style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold, fontStyle: FontStyle.italic),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      Text(
                        '••••  ••••  ••••  ${_digitsController.text.isEmpty ? '0000' : _digitsController.text}',
                        style: const TextStyle(color: Colors.white, fontSize: 18, letterSpacing: 2, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            _nameController.text.isEmpty ? 'Card Variant' : _nameController.text,
                            style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500),
                          ),
                          if (_limitController.text.isNotEmpty)
                            Text(
                              'Limit: ₹${_limitController.text}',
                              style: const TextStyle(color: Colors.white70, fontSize: 12),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Bank & Card Name
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _bankController,
                        textCapitalization: TextCapitalization.words,
                        decoration: const InputDecoration(
                          labelText: 'Bank Name *',
                          hintText: 'e.g. HDFC, ICICI, SBI',
                          border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(14))),
                        ),
                        validator: (v) => (v == null || v.trim().isEmpty) ? 'Enter bank name' : null,
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _nameController,
                        textCapitalization: TextCapitalization.words,
                        decoration: const InputDecoration(
                          labelText: 'Card Variant *',
                          hintText: 'e.g. Regalia, Amazon Pay',
                          border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(14))),
                        ),
                        validator: (v) => (v == null || v.trim().isEmpty) ? 'Enter card name' : null,
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Last 4 digits & Network
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _digitsController,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(4),
                        ],
                        decoration: const InputDecoration(
                          labelText: 'Last 4 Digits *',
                          hintText: 'e.g. 4582',
                          border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(14))),
                        ),
                        validator: (v) => (v == null || v.trim().length != 4) ? 'Enter 4 digits' : null,
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: _selectedNetwork,
                        decoration: const InputDecoration(
                          labelText: 'Card Network',
                          border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(14))),
                        ),
                        items: _networks.map((net) => DropdownMenuItem(value: net, child: Text(net))).toList(),
                        onChanged: (val) {
                          if (val != null) setState(() => _selectedNetwork = val);
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Credit Limit & Billing Cycle
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _limitController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(
                          labelText: 'Credit Limit (₹)',
                          hintText: 'e.g. 200000',
                          border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(14))),
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _billingDayController,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(2),
                        ],
                        decoration: const InputDecoration(
                          labelText: 'Statement Date',
                          hintText: 'Day of month (1-31)',
                          border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(14))),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Shared Bank Limit Toggle
                Container(
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest.withAlpha(80),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: theme.colorScheme.outlineVariant.withAlpha(100)),
                  ),
                  child: SwitchListTile(
                    title: const Text('Shared Bank Limit', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    subtitle: const Text('Pool limit with other cards from this bank', style: TextStyle(fontSize: 12)),
                    value: _isSharedLimit,
                    onChanged: (val) => setState(() => _isSharedLimit = val),
                    secondary: Icon(Icons.account_tree_rounded, color: theme.colorScheme.primary),
                  ),
                ),
                const SizedBox(height: 20),

                // Card Theme Color Picker
                Text(
                  'Card Color Theme',
                  style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  height: 44,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: _cardColors.length,
                    separatorBuilder: (ctx, index) => const SizedBox(width: 10),
                    itemBuilder: (context, idx) {
                      final colorHex = _cardColors[idx];
                      final isSelected = _selectedColorHex == colorHex;
                      return GestureDetector(
                        onTap: () => setState(() => _selectedColorHex = colorHex),
                        child: Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: Color(colorHex),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isSelected ? theme.colorScheme.primary : Colors.transparent,
                              width: 3,
                            ),
                          ),
                          child: isSelected
                              ? const Icon(Icons.check_rounded, color: Colors.white, size: 20)
                              : null,
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 28),

                // Save Button
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: FilledButton.icon(
                    onPressed: _submit,
                    icon: const Icon(Icons.save_rounded),
                    label: Text(
                      widget.cardToEdit == null ? 'Add Card' : 'Update Card',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    style: FilledButton.styleFrom(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
