import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'models.dart';
import 'add_credit_card_sheet.dart';
import 'utils/id_generator.dart';

class CreditCardsScreen extends StatefulWidget {
  final List<CreditCard> creditCards;
  final List<Expense> expenses;
  final List<CreditCardRepayment> repayments;
  final String currencySymbol;
  final Function(CreditCard) onAddCard;
  final Function(CreditCard) onUpdateCard;
  final Function(String) onDeleteCard;
  final Function(CreditCardRepayment) onAddRepayment;
  final Function(String) onDeleteRepayment;
  final Function(String)? onDeleteExpense;
  final Future<void> Function()? onRefresh;

  const CreditCardsScreen({
    super.key,
    required this.creditCards,
    required this.expenses,
    required this.repayments,
    required this.currencySymbol,
    required this.onAddCard,
    required this.onUpdateCard,
    required this.onDeleteCard,
    required this.onAddRepayment,
    required this.onDeleteRepayment,
    this.onDeleteExpense,
    this.onRefresh,
  });

  @override
  State<CreditCardsScreen> createState() => _CreditCardsScreenState();
}

class _CreditCardsScreenState extends State<CreditCardsScreen> {
  String _formatAmount(double amount) {
    if (!amount.isFinite || amount.isNaN) return '0.00';
    if (amount > 1e11) {
      return amount.toStringAsExponential(2);
    }
    return amount.toStringAsFixed(2);
  }

  String _getDaySuffix(int day) {
    if (day >= 11 && day <= 13) return 'th';
    switch (day % 10) {
      case 1:
        return 'st';
      case 2:
        return 'nd';
      case 3:
        return 'rd';
      default:
        return 'th';
    }
  }

  List<CreditCard> _getCardsForBank(String bankName) {
    final clean = bankName.trim().toLowerCase();
    return widget.creditCards
        .where((c) => c.bankName.trim().toLowerCase() == clean && c.isSharedLimit)
        .toList();
  }

  double _getBankTotalOutstanding(String bankName) {
    final bankCards = _getCardsForBank(bankName);
    return bankCards.fold(0.0, (sum, c) => sum + _getCardOutstanding(c.id));
  }

  double _getAvailableLimit(CreditCard card) {
    final limit = card.creditLimit;
    if (limit <= 0) return 0.0;
    if (!card.isSharedLimit) {
      final remaining = limit - _getCardOutstanding(card.id);
      return remaining < 0 ? 0.0 : remaining;
    }
    final bankOutstanding = _getBankTotalOutstanding(card.bankName);
    final remaining = limit - bankOutstanding;
    return remaining < 0 ? 0.0 : remaining;
  }

  double _getBankUtilization(CreditCard card) {
    final limit = card.creditLimit;
    if (limit <= 0) return 0.0;
    if (!card.isSharedLimit) {
      final ratio = _getCardOutstanding(card.id) / limit;
      return ratio > 1.0 ? 1.0 : ratio;
    }
    final bankOutstanding = _getBankTotalOutstanding(card.bankName);
    final ratio = bankOutstanding / limit;
    return ratio > 1.0 ? 1.0 : ratio;
  }

  double _getCardTotalSpend(String cardId) {
    return widget.expenses.where((e) {
      if (e.paymentMethod != PaymentMethod.creditCard) return false;
      if (e.creditCardId == cardId) return true;
      if ((e.creditCardId == null || e.creditCardId!.isEmpty) && widget.creditCards.length == 1) {
        return widget.creditCards.first.id == cardId;
      }
      return false;
    }).fold(0.0, (sum, e) => sum + e.amount);
  }

  double _getCardTotalRepaid(String cardId) {
    return widget.repayments.where((r) {
      if (r.creditCardId == cardId) return true;
      if (r.creditCardId.isEmpty && widget.creditCards.length == 1) {
        return widget.creditCards.first.id == cardId;
      }
      return false;
    }).fold(0.0, (sum, r) => sum + r.amount);
  }

  double _getCardOutstanding(String cardId) {
    final spend = _getCardTotalSpend(cardId);
    final repaid = _getCardTotalRepaid(cardId);
    final balance = spend - repaid;
    return balance < 0 ? 0.0 : balance;
  }

  double get _totalOutstandingAllCards {
    return widget.creditCards.fold(0.0, (sum, card) => sum + _getCardOutstanding(card.id));
  }

  void _openAddCardModal({CreditCard? cardToEdit}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => AddCreditCardSheet(
        cardToEdit: cardToEdit,
        existingCards: widget.creditCards,
        onSaveCard: (card) {
          if (cardToEdit != null) {
            widget.onUpdateCard(card);
          } else {
            widget.onAddCard(card);
          }
          setState(() {});
        },
      ),
    );
  }

  void _openRecordRepaymentModal(CreditCard card) {
    final amountController = TextEditingController(
      text: _getCardOutstanding(card.id) > 0 ? _formatAmount(_getCardOutstanding(card.id)) : '',
    );
    final noteController = TextEditingController(text: 'Monthly bill payment');
    DateTime paymentDate = DateTime.now();
    PaymentMethod selectedPaymentMethod = PaymentMethod.upi;

    final availableMethods = [
      PaymentMethod.upi,
      PaymentMethod.netBanking,
      PaymentMethod.debitCard,
      PaymentMethod.cash,
    ];

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          final theme = Theme.of(context);
          return AlertDialog(
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1DD1A1).withAlpha(40),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.check_circle_rounded, color: Color(0xFF1DD1A1), size: 22),
                ),
                const SizedBox(width: 12),
                const Text('Record Bill Payment', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Card: ${card.bankName} ${card.cardName} (•••• ${card.last4Digits})',
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: amountController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText: 'Repayment Amount *',
                      prefixText: '${widget.currencySymbol} ',
                      border: const OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(14))),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Paid Via (Payment Method) *',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: theme.colorScheme.onSurfaceVariant),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: availableMethods.map((pm) {
                      final isSelected = selectedPaymentMethod == pm;
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
                            setDialogState(() {
                              selectedPaymentMethod = pm;
                            });
                          }
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: noteController,
                    decoration: const InputDecoration(
                      labelText: 'Note (Optional)',
                      hintText: 'e.g. Monthly bill payment, GPay, etc.',
                      border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(14))),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.info_outline_rounded, size: 16, color: Color(0xFF1DD1A1)),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'This repayment clears your card dues and will NOT be counted as an extra monthly expense.',
                            style: TextStyle(fontSize: 11, height: 1.3),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () {
                  final amt = double.tryParse(amountController.text.trim());
                  if (amt == null || amt <= 0) return;

                  final repayment = CreditCardRepayment(
                    id: IdGenerator.generateVaultId(),
                    creditCardId: card.id,
                    amount: amt,
                    date: paymentDate,
                    paymentMethod: selectedPaymentMethod,
                    paymentSource: selectedPaymentMethod.label,
                    note: noteController.text.trim().isNotEmpty ? noteController.text.trim() : null,
                  );

                  widget.onAddRepayment(repayment);
                  Navigator.of(ctx).pop();
                  setState(() {});
                  ScaffoldMessenger.of(context).clearSnackBars();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Payment of ${widget.currencySymbol}${_formatAmount(amt)} recorded for ${card.cardName}!'),
                      backgroundColor: const Color(0xFF1DD1A1),
                    ),
                  );
                },
                child: const Text('Confirm Payment'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _openCardTransactionsModal(CreditCard card) {
    final cardExpenses = widget.expenses
        .where((e) => e.paymentMethod == PaymentMethod.creditCard && e.creditCardId == card.id)
        .toList();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final theme = Theme.of(context);
        return Container(
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.75,
          ),
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
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${card.bankName} ${card.cardName}',
                          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        Text(
                          '${cardExpenses.length} Swipes · Total: ${widget.currencySymbol}${_formatAmount(_getCardTotalSpend(card.id))}',
                          style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const Divider(height: 20),
              if (cardExpenses.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(32.0),
                  child: Center(child: Text('No swipes recorded for this card')),
                )
              else
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: cardExpenses.length,
                    separatorBuilder: (c, i) => const SizedBox(height: 8),
                    itemBuilder: (c, i) {
                      final exp = cardExpenses[i];
                      return Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceContainerHigh,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFF6B6B).withAlpha(30),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.credit_card_rounded, size: 16, color: Color(0xFFFF6B6B)),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(exp.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                  Text(
                                    '${exp.date.day}/${exp.date.month}/${exp.date.year}',
                                    style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurfaceVariant),
                                  ),
                                ],
                              ),
                            ),
                            Text(
                              '-${widget.currencySymbol}${_formatAmount(exp.amount)}',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFFFF6B6B)),
                            ),
                            if (widget.onDeleteExpense != null) ...[
                              const SizedBox(width: 4),
                              IconButton(
                                icon: Icon(Icons.delete_outline_rounded, size: 16, color: theme.colorScheme.error),
                                tooltip: 'Delete Swipe',
                                onPressed: () {
                                  widget.onDeleteExpense!(exp.id);
                                  Navigator.pop(ctx);
                                  setState(() {});
                                },
                              ),
                            ],
                          ],
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cards = widget.creditCards;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Credit Cards Tracker', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          if ((kIsWeb || MediaQuery.of(context).size.width >= 800) && widget.onRefresh != null)
            IconButton(
              icon: const Icon(Icons.sync_rounded),
              tooltip: 'Sync with Google Drive',
              onPressed: () async {
                await widget.onRefresh!();
                setState(() {});
              },
            ),
          IconButton(
            icon: const Icon(Icons.add_card_rounded),
            tooltip: 'Add Credit Card',
            onPressed: () => _openAddCardModal(),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: widget.onRefresh ?? () async => setState(() {}),
        color: theme.colorScheme.primary,
        child: cards.isEmpty
            ? SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const SizedBox(height: 60),
                        Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primaryContainer.withAlpha(80),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(Icons.credit_card_off_rounded, size: 64, color: theme.colorScheme.primary),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          'No Credit Cards Added',
                          style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Add your credit cards to track swipes, billing cycles, and repayments without double-counting expenses.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
                        ),
                        const SizedBox(height: 24),
                        FilledButton.icon(
                          onPressed: () => _openAddCardModal(),
                          icon: const Icon(Icons.add_rounded),
                          label: const Text('Add Your First Card'),
                          style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14)),
                        ),
                      ],
                    ),
                  ),
                ),
              )
            : SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 800),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Total Outstanding Banner
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF2C3A47), Color(0xFF130F40)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withAlpha(40),
                              blurRadius: 16,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'Total Credit Card Dues',
                                  style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.white24,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    '${cards.length} active cards',
                                    style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '${widget.currencySymbol}${_totalOutstandingAllCards.toStringAsFixed(2)}',
                              style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w800),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Card List
                      Text('Your Cards', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 12),

                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: cards.length,
                        separatorBuilder: (ctx, index) => const SizedBox(height: 16),
                        itemBuilder: (context, idx) {
                          final card = cards[idx];
                          final outstanding = _getCardOutstanding(card.id);
                          final totalSpend = _getCardTotalSpend(card.id);
                          final cardExpenses = widget.expenses.where((e) => e.creditCardId == card.id).toList();

                          final bankCards = _getCardsForBank(card.bankName);
                          final isShared = card.isSharedLimit && bankCards.length > 1;
                          final cardLimit = card.creditLimit;
                          final availableLimit = _getAvailableLimit(card);
                          final utilization = _getBankUtilization(card);
                          final bankTotalOutstanding = _getBankTotalOutstanding(card.bankName);

                          return Container(
                            decoration: BoxDecoration(
                              color: theme.colorScheme.surfaceContainerHigh,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Column(
                              children: [
                                // Visual Card View
                                Container(
                                  padding: const EdgeInsets.all(20),
                                  decoration: BoxDecoration(
                                    color: Color(card.colorHex),
                                    borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Row(
                                            children: [
                                              Text(
                                                card.bankName.toUpperCase(),
                                                style: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.bold, letterSpacing: 1.2),
                                              ),
                                              if (isShared) ...[
                                                const SizedBox(width: 8),
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                  decoration: BoxDecoration(
                                                    color: Colors.white24,
                                                    borderRadius: BorderRadius.circular(6),
                                                  ),
                                                  child: const Text(
                                                    'SHARED LIMIT',
                                                    style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                                                  ),
                                                ),
                                              ],
                                            ],
                                          ),
                                          Text(
                                            card.cardNetwork.toUpperCase(),
                                            style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold, fontStyle: FontStyle.italic),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 18),
                                      Text(
                                        '••••  ••••  ••••  ${card.last4Digits}',
                                        style: const TextStyle(color: Colors.white, fontSize: 18, letterSpacing: 2, fontWeight: FontWeight.w600),
                                      ),
                                      const SizedBox(height: 14),
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            card.cardName,
                                            style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500),
                                          ),
                                          Row(
                                            children: [
                                              if (card.billingCycleDay != null) ...[
                                                Text(
                                                  'Bill: ${card.billingCycleDay}${_getDaySuffix(card.billingCycleDay!)}',
                                                  style: const TextStyle(color: Colors.white70, fontSize: 11),
                                                ),
                                                const SizedBox(width: 8),
                                              ],
                                              if (card.paymentDueDay != null)
                                                Text(
                                                  'Due: ${card.paymentDueDay}${_getDaySuffix(card.paymentDueDay!)}',
                                                  style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                                                ),
                                            ],
                                          ),
                                        ],
                                      ),
                                      if (cardLimit > 0) ...[
                                        const SizedBox(height: 6),
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Text(
                                              'Avail: ${widget.currencySymbol}${_formatAmount(availableLimit)}',
                                              style: const TextStyle(color: Color(0xFF1DD1A1), fontSize: 11, fontWeight: FontWeight.w600),
                                            ),
                                            Text(
                                              'Limit: ${widget.currencySymbol}${_formatAmount(cardLimit)}',
                                              style: const TextStyle(color: Colors.white70, fontSize: 11),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ],
                                  ),
                                ),

                                // Card Metrics & Actions
                                Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      // Status Alert for Bill Due Date
                                      if (outstanding > 0)
                                        Container(
                                          margin: const EdgeInsets.only(bottom: 14),
                                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFFF6B6B).withAlpha(25),
                                            borderRadius: BorderRadius.circular(12),
                                            border: Border.all(color: const Color(0xFFFF6B6B).withAlpha(80)),
                                          ),
                                          child: Row(
                                            children: [
                                              const Icon(Icons.warning_amber_rounded, size: 16, color: Color(0xFFFF6B6B)),
                                              const SizedBox(width: 8),
                                              Expanded(
                                                child: Text(
                                                  card.paymentDueDay != null
                                                      ? 'Pending Bill Dues: Due on ${card.paymentDueDay}${_getDaySuffix(card.paymentDueDay!)} · Clear dues to avoid charges'
                                                      : 'Pending Bill Dues: Clear outstanding balance',
                                                  style: const TextStyle(
                                                    color: Color(0xFFFF6B6B),
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        )
                                      else
                                        Container(
                                          margin: const EdgeInsets.only(bottom: 14),
                                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFF1DD1A1).withAlpha(25),
                                            borderRadius: BorderRadius.circular(12),
                                            border: Border.all(color: const Color(0xFF1DD1A1).withAlpha(80)),
                                          ),
                                          child: Row(
                                            children: [
                                              const Icon(Icons.check_circle_outline_rounded, size: 16, color: Color(0xFF1DD1A1)),
                                              const SizedBox(width: 8),
                                              Text(
                                                card.billingCycleDay != null
                                                    ? 'No Dues · Next statement on ${card.billingCycleDay}${_getDaySuffix(card.billingCycleDay!)}'
                                                    : 'No Dues · All clear',
                                                style: const TextStyle(
                                                  color: Color(0xFF1DD1A1),
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),

                                      // Outstanding & Pay Bill Action
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  'Outstanding Balance',
                                                  style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant),
                                                ),
                                                const SizedBox(height: 2),
                                                FittedBox(
                                                  fit: BoxFit.scaleDown,
                                                  alignment: Alignment.centerLeft,
                                                  child: Text(
                                                    '${widget.currencySymbol}${_formatAmount(outstanding)}',
                                                    style: TextStyle(
                                                      fontSize: 20,
                                                      fontWeight: FontWeight.bold,
                                                      color: outstanding > 0 ? const Color(0xFFFF6B6B) : const Color(0xFF1DD1A1),
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          FilledButton.icon(
                                            onPressed: () => _openRecordRepaymentModal(card),
                                            icon: const Icon(Icons.payment_rounded, size: 16),
                                            label: const Text('Pay Bill'),
                                            style: FilledButton.styleFrom(
                                              backgroundColor: const Color(0xFF1DD1A1),
                                              foregroundColor: Colors.white,
                                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                            ),
                                          ),
                                        ],
                                      ),

                                      // Shared Bank Limit & Remaining Available Balance Details
                                      if (cardLimit > 0) ...[
                                        const SizedBox(height: 14),
                                        Container(
                                          padding: const EdgeInsets.all(12),
                                          decoration: BoxDecoration(
                                            color: theme.colorScheme.surface,
                                            borderRadius: BorderRadius.circular(14),
                                            border: Border.all(color: theme.colorScheme.outlineVariant.withAlpha(80)),
                                          ),
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                children: [
                                                  Text(
                                                    'Remaining Limit',
                                                    style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant, fontWeight: FontWeight.w500),
                                                  ),
                                                  Flexible(
                                                    child: FittedBox(
                                                      fit: BoxFit.scaleDown,
                                                      child: Text(
                                                        '${widget.currencySymbol}${_formatAmount(availableLimit)} / ${widget.currencySymbol}${_formatAmount(cardLimit)}',
                                                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 6),
                                              ClipRRect(
                                                borderRadius: BorderRadius.circular(6),
                                                child: LinearProgressIndicator(
                                                  value: utilization.clamp(0.0, 1.0),
                                                  minHeight: 6,
                                                  backgroundColor: theme.colorScheme.surfaceContainerHighest,
                                                  valueColor: AlwaysStoppedAnimation<Color>(
                                                    utilization > 0.7
                                                        ? const Color(0xFFFF6B6B)
                                                        : utilization > 0.3
                                                            ? const Color(0xFFFF9F43)
                                                            : const Color(0xFF1DD1A1),
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(height: 6),
                                              Wrap(
                                                alignment: WrapAlignment.spaceBetween,
                                                runSpacing: 4,
                                                spacing: 8,
                                                crossAxisAlignment: WrapCrossAlignment.center,
                                                children: [
                                                  Text(
                                                    '${(utilization * 100).clamp(0.0, 100.0).toStringAsFixed(1)}% limit utilized',
                                                    style: TextStyle(
                                                      fontSize: 11,
                                                      fontWeight: FontWeight.w500,
                                                      color: utilization > 0.7
                                                          ? const Color(0xFFFF6B6B)
                                                          : theme.colorScheme.onSurfaceVariant,
                                                    ),
                                                  ),
                                                  if (isShared)
                                                    Container(
                                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                      decoration: BoxDecoration(
                                                        color: theme.colorScheme.primary.withAlpha(25),
                                                        borderRadius: BorderRadius.circular(6),
                                                      ),
                                                      child: Text(
                                                        'Shared across ${bankCards.length} cards (Total: ${widget.currencySymbol}${_formatAmount(bankTotalOutstanding)})',
                                                        style: TextStyle(fontSize: 10, color: theme.colorScheme.primary, fontWeight: FontWeight.w600),
                                                      ),
                                                    ),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                      const SizedBox(height: 12),
                                      Row(
                                        children: [
                                          Expanded(
                                            child: InkWell(
                                              onTap: () => _openCardTransactionsModal(card),
                                              borderRadius: BorderRadius.circular(8),
                                              child: Padding(
                                                padding: const EdgeInsets.symmetric(vertical: 4),
                                                child: Row(
                                                  children: [
                                                    Icon(Icons.receipt_long_rounded, size: 14, color: theme.colorScheme.primary),
                                                    const SizedBox(width: 6),
                                                    Expanded(
                                                      child: Text(
                                                        'Total Swipes: ${widget.currencySymbol}${_formatAmount(totalSpend)} (${cardExpenses.length} txns)',
                                                        style: TextStyle(fontSize: 12, color: theme.colorScheme.primary, fontWeight: FontWeight.w500),
                                                        overflow: TextOverflow.ellipsis,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          ),
                                          IconButton(
                                            icon: const Icon(Icons.list_alt_rounded, size: 18),
                                            tooltip: 'View Swipes',
                                            onPressed: () => _openCardTransactionsModal(card),
                                          ),
                                          IconButton(
                                            icon: const Icon(Icons.edit_outlined, size: 18),
                                            tooltip: 'Edit Card',
                                            onPressed: () => _openAddCardModal(cardToEdit: card),
                                          ),
                                          IconButton(
                                            icon: Icon(Icons.delete_outline_rounded, size: 18, color: theme.colorScheme.error),
                                            tooltip: 'Delete Card',
                                            onPressed: () {
                                              showDialog(
                                                context: context,
                                                builder: (dCtx) => AlertDialog(
                                                  title: const Text('Delete Credit Card?'),
                                                  content: Text('Are you sure you want to remove ${card.cardName}?'),
                                                  actions: [
                                                    TextButton(onPressed: () => Navigator.pop(dCtx), child: const Text('Cancel')),
                                                    FilledButton(
                                                      style: FilledButton.styleFrom(backgroundColor: theme.colorScheme.error),
                                                      onPressed: () {
                                                        widget.onDeleteCard(card.id);
                                                        Navigator.pop(dCtx);
                                                        setState(() {});
                                                      },
                                                      child: const Text('Delete'),
                                                    ),
                                                  ],
                                                ),
                                              );
                                            },
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),

                      // Bill Payments / Repayments History Section
                      if (widget.repayments.isNotEmpty) ...[
                        const SizedBox(height: 28),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: const Color(0xFF00B894).withAlpha(30),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.history_rounded, size: 16, color: Color(0xFF00B894)),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Payment & Repayment History',
                              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                            ),
                            const Spacer(),
                            Text(
                              '${widget.repayments.length} payments',
                              style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: widget.repayments.length,
                          separatorBuilder: (ctx, idx) => const SizedBox(height: 8),
                          itemBuilder: (ctx, idx) {
                            final repayment = widget.repayments[idx];
                            final targetCard = widget.creditCards.firstWhere(
                              (c) => c.id == repayment.creditCardId,
                              orElse: () => CreditCard(id: '', bankName: 'Credit Card', cardName: '', last4Digits: '••••'),
                            );

                            return Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.surfaceContainerHigh,
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF00B894).withAlpha(30),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(Icons.check_circle_outline_rounded, color: Color(0xFF00B894), size: 18),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          '${targetCard.bankName} ${targetCard.cardName}',
                                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          'Paid via ${repayment.paymentSource} · ${repayment.date.day}/${repayment.date.month}/${repayment.date.year}',
                                          style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurfaceVariant),
                                        ),
                                        if (repayment.note != null && repayment.note!.isNotEmpty) ...[
                                          const SizedBox(height: 2),
                                          Text(
                                            repayment.note!,
                                            style: TextStyle(fontSize: 10, fontStyle: FontStyle.italic, color: theme.colorScheme.onSurfaceVariant),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                  Text(
                                    '+${widget.currencySymbol}${repayment.amount.toStringAsFixed(2)}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                      color: Color(0xFF00B894),
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  IconButton(
                                    icon: Icon(Icons.delete_outline_rounded, size: 16, color: theme.colorScheme.error),
                                    tooltip: 'Delete Repayment',
                                    visualDensity: VisualDensity.compact,
                                    onPressed: () {
                                      showDialog(
                                        context: context,
                                        builder: (dCtx) => AlertDialog(
                                          title: const Text('Delete Repayment?'),
                                          content: Text('Are you sure you want to remove this payment of ${widget.currencySymbol}${repayment.amount.toStringAsFixed(2)}?'),
                                          actions: [
                                            TextButton(onPressed: () => Navigator.pop(dCtx), child: const Text('Cancel')),
                                            FilledButton(
                                              style: FilledButton.styleFrom(backgroundColor: theme.colorScheme.error),
                                              onPressed: () {
                                                widget.onDeleteRepayment(repayment.id);
                                                Navigator.pop(dCtx);
                                                setState(() {});
                                              },
                                              child: const Text('Delete'),
                                            ),
                                          ],
                                        ),
                                      );
                                    },
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
      ),
    );
  }
}
