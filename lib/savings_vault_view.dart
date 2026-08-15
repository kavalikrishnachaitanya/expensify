import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'models.dart';

class SavingsVaultView extends StatefulWidget {
  final double totalSavings;
  final List<SavingsRecord> savingsHistory;
  final String currencySymbol;
  final Function(double amount, SavingsTransactionType type, String note, {String? monthKey, String? sharedId}) onAddTransaction;
  
  final double netSavings;
  final String currentMonthName;
  final String currentMonthKey;
  final Function(double amount, String sharedId) onAdjustIncome;
  final Function(String) onDeleteTransaction;
  final List<VaultGoal> vaultGoals;
  final Function(VaultGoal) onAddGoal;
  final Function(String) onDeleteGoal;
  final bool isWideScreen;

  const SavingsVaultView({
    super.key,
    required this.totalSavings,
    required this.savingsHistory,
    required this.currencySymbol,
    required this.onAddTransaction,
    required this.netSavings,
    required this.currentMonthName,
    required this.currentMonthKey,
    required this.onAdjustIncome,
    required this.onDeleteTransaction,
    required this.vaultGoals,
    required this.onAddGoal,
    required this.onDeleteGoal,
    this.isWideScreen = false,
  });

  @override
  State<SavingsVaultView> createState() => _SavingsVaultViewState();
}

class _SavingsVaultViewState extends State<SavingsVaultView> {
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  void _showTransactionDialog(bool isDeposit) {
    _amountController.clear();
    _noteController.clear();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isDeposit ? 'Manual Deposit' : 'Manual Withdrawal'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _amountController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              autofocus: true,
              decoration: InputDecoration(
                prefixText: widget.currencySymbol,
                border: const OutlineInputBorder(),
                labelText: 'Amount',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _noteController,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                labelText: 'Note (Optional)',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final val = double.tryParse(_amountController.text);
              if (val != null && val > 0) {
                if (!isDeposit && val > widget.totalSavings) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Insufficient savings!')),
                  );
                  return;
                }
                widget.onAddTransaction(
                  isDeposit ? val : -val,
                  isDeposit ? SavingsTransactionType.manualDeposit : SavingsTransactionType.manualWithdrawal,
                  _noteController.text.trim(),
                );
                Navigator.of(ctx).pop();
              }
            },
            child: Text(isDeposit ? 'Deposit' : 'Withdraw'),
          ),
        ],
      ),
    );
  }

  void _showBudgetBalanceDialog(bool isSurplus) {
    double maxAmount = isSurplus ? widget.netSavings : widget.totalSavings;
    
    if (maxAmount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Not enough funds available.')));
      return;
    }

    double selectedAmount = maxAmount;
    final TextEditingController amountController = TextEditingController(text: selectedAmount.toStringAsFixed(2));

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text(isSurplus ? 'Move Surplus to Savings' : 'Move Vault Funds to Balance'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Select amount to ${isSurplus ? 'move' : 'transfer'} for ${widget.currentMonthName}:'),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Text(widget.currencySymbol, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: isSurplus ? const Color(0xFF1DD1A1) : const Color(0xFFFF6B6B))),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: amountController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          style: TextStyle(
                            fontSize: 28, 
                            fontWeight: FontWeight.bold,
                            color: isSurplus ? const Color(0xFF1DD1A1) : const Color(0xFFFF6B6B),
                          ),
                          decoration: const InputDecoration(border: InputBorder.none),
                          onChanged: (val) {
                            final parsed = double.tryParse(val);
                            if (parsed != null) {
                              setState(() {
                                selectedAmount = parsed.clamp(0.0, maxAmount);
                              });
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Slider(
                    value: selectedAmount,
                    min: 0,
                    max: maxAmount,
                    divisions: 100,
                    activeColor: isSurplus ? const Color(0xFF1DD1A1) : const Color(0xFFFF6B6B),
                    label: selectedAmount.toStringAsFixed(0),
                    onChanged: (val) {
                      setState(() {
                        selectedAmount = val;
                        amountController.text = val.toStringAsFixed(2);
                      });
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () {
                    if (selectedAmount > 0) {
                      final sharedId = DateTime.now().millisecondsSinceEpoch.toString();
                      if (isSurplus) {
                        widget.onAddTransaction(selectedAmount, SavingsTransactionType.surplusMove, 'Surplus from ${widget.currentMonthName}', monthKey: widget.currentMonthKey, sharedId: sharedId);
                        widget.onAdjustIncome(-selectedAmount, sharedId); // Decrease income to balance
                      } else {
                        widget.onAddTransaction(-selectedAmount, SavingsTransactionType.deficitCover, 'Transfer to balance for ${widget.currentMonthName}', monthKey: widget.currentMonthKey, sharedId: sharedId);
                        widget.onAdjustIncome(selectedAmount, sharedId); // Increase income to balance
                      }
                      Navigator.of(ctx).pop();
                    }
                  },
                  child: const Text('Confirm'),
                ),
              ],
            );
          }
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bool isSurplus = widget.netSavings > 0;

    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Total Savings Hero Card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF1DD1A1), Color(0xFF10AC84)],
              ),
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF10AC84).withAlpha(80),
                  blurRadius: 16,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const Icon(Icons.savings_rounded, color: Colors.white, size: 40),
                const SizedBox(height: 12),
                const Text(
                  'Total Savings Balance',
                  style: TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                Text(
                  '${widget.currencySymbol}${widget.totalSavings.toStringAsFixed(2)}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 40,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    ElevatedButton.icon(
                      onPressed: () => _showTransactionDialog(true),
                      icon: const Icon(Icons.add, color: Color(0xFF10AC84)),
                      label: const Text('Deposit', style: TextStyle(color: Color(0xFF10AC84))),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                    ElevatedButton.icon(
                      onPressed: () => _showTransactionDialog(false),
                      icon: const Icon(Icons.remove, color: Colors.white),
                      label: const Text('Withdraw'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white24,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 24),
          Text(
            'Budget Adjustments (${widget.currentMonthName})',
            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              // Surplus Card
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isSurplus 
                          ? const Color(0xFF1DD1A1).withAlpha(150) 
                          : Colors.transparent,
                      width: 2,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.trending_up,
                            color: isSurplus ? const Color(0xFF1DD1A1) : theme.colorScheme.onSurfaceVariant.withAlpha(100),
                            size: 20,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Surplus',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: isSurplus ? const Color(0xFF1DD1A1) : theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        isSurplus
                            ? '${widget.currencySymbol}${widget.netSavings.toStringAsFixed(2)}'
                            : '${widget.currencySymbol}0.00',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: isSurplus ? theme.colorScheme.onSurface : theme.colorScheme.onSurfaceVariant.withAlpha(100),
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: isSurplus ? () => _showBudgetBalanceDialog(true) : null,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF1DD1A1),
                            foregroundColor: Colors.white,
                            disabledBackgroundColor: theme.colorScheme.surfaceContainerHighest,
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            elevation: isSurplus ? 2 : 0,
                          ),
                          child: const Text('Move to Vault', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Move Back to Balance Card
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: const Color(0xFFFF6B6B).withAlpha(150),
                      width: 2,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.account_balance_wallet_rounded,
                            color: const Color(0xFFFF6B6B),
                            size: 20,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'To Balance',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFFFF6B6B),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${widget.currencySymbol}${widget.totalSavings.toStringAsFixed(2)}',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: widget.totalSavings > 0 ? () => _showBudgetBalanceDialog(false) : null,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFFF6B6B),
                            foregroundColor: Colors.white,
                            disabledBackgroundColor: theme.colorScheme.surfaceContainerHighest,
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            elevation: widget.totalSavings > 0 ? 2 : 0,
                          ),
                          child: const Text('Move to Balance', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),
          
          _buildVaultGoals(theme),
          const SizedBox(height: 32),
          
          Text(
            'Savings History',
            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          
          if (widget.savingsHistory.isEmpty)
            Container(
              padding: const EdgeInsets.all(24),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Text('No savings transactions yet.'),
            )
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: widget.savingsHistory.length,
              itemBuilder: (context, index) {
                final record = widget.savingsHistory[index];
                final isPositive = record.amount > 0;
                
                return Dismissible(
                  key: Key(record.id),
                  direction: DismissDirection.endToStart,
                  background: Container(
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 20),
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: Colors.redAccent,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(Icons.delete_rounded, color: Colors.white),
                  ),
                  onDismissed: (direction) => widget.onDeleteTransaction(record.id),
                  child: Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: isPositive ? const Color(0xFF1DD1A1).withAlpha(40) : const Color(0xFFFF6B6B).withAlpha(40),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          record.type.icon,
                          color: isPositive ? const Color(0xFF1DD1A1) : const Color(0xFFFF6B6B),
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              record.type.label,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              DateFormat.yMMMd().format(record.date) + (record.note != null && record.note!.isNotEmpty ? ' • ${record.note}' : ''),
                              style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        '${isPositive ? '+' : '-'}${widget.currencySymbol}${record.amount.abs().toStringAsFixed(2)}',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: isPositive ? const Color(0xFF1DD1A1) : const Color(0xFFFF6B6B),
                        ),
                      ),
                    ],
                  ),
                  ),
                );
              },
            ),
          const SizedBox(height: 60),
        ],
      );

    if (widget.isWideScreen) {
      return content;
    }
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: content,
    );
  }

  Widget _buildVaultGoals(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Vault Goals',
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            TextButton.icon(
              onPressed: _showAddGoalDialog,
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Add Goal'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (widget.vaultGoals.isEmpty)
          Container(
            padding: const EdgeInsets.all(24),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: theme.colorScheme.surfaceContainerHighest),
            ),
            child: Text(
              'No goals set. Create a goal to track your progress!',
              style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
            ),
          )
        else
          ...widget.vaultGoals.map((goal) {
            final progress = widget.totalSavings / goal.targetAmount;
            final isCompleted = progress >= 1.0;
            return Dismissible(
              key: Key(goal.id),
              direction: DismissDirection.endToStart,
              background: Container(
                alignment: Alignment.centerRight,
                padding: const EdgeInsets.only(right: 20),
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: Colors.redAccent,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(Icons.delete_rounded, color: Colors.white),
              ),
              onDismissed: (_) => widget.onDeleteGoal(goal.id),
              child: Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(16),
                  border: isCompleted 
                      ? Border.all(color: const Color(0xFF1DD1A1), width: 2)
                      : null,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(goal.icon, color: goal.color, size: 24),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            goal.name,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                        ),
                        if (isCompleted)
                          const Icon(Icons.check_circle_rounded, color: Color(0xFF1DD1A1), size: 20)
                        else
                          Text(
                            '${(progress * 100).clamp(0, 100).toStringAsFixed(1)}%',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.primary,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    LinearProgressIndicator(
                      value: progress.clamp(0.0, 1.0),
                      backgroundColor: theme.colorScheme.surfaceContainerHighest,
                      color: isCompleted ? const Color(0xFF1DD1A1) : goal.color,
                      minHeight: 8,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text(
                          'Goal: ${widget.currencySymbol}${goal.targetAmount.toStringAsFixed(0)}',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: theme.colorScheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          }),
      ],
    );
  }

  void _showAddGoalDialog() {
    final nameController = TextEditingController();
    final amountController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Create Vault Goal'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: nameController,
              autofocus: true,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                labelText: 'Goal Name (e.g. Car, Vacation)',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: amountController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                prefixText: widget.currencySymbol,
                border: const OutlineInputBorder(),
                labelText: 'Target Amount',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final name = nameController.text.trim();
              final amount = double.tryParse(amountController.text);
              if (name.isNotEmpty && amount != null && amount > 0) {
                widget.onAddGoal(
                  VaultGoal(
                    id: 'goal_${DateTime.now().millisecondsSinceEpoch}',
                    name: name,
                    targetAmount: amount,
                    icon: Icons.flag_rounded,
                    color: Colors.blueAccent,
                  ),
                );
                Navigator.of(ctx).pop();
              }
            },
            child: const Text('Create Goal'),
          ),
        ],
      ),
    );
  }
}
