import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:expenses/splitwise/utils/helpers.dart';
import 'package:expenses/utils/id_generator.dart';
import 'package:expenses/splitwise/providers/expense_provider.dart';
import 'package:expenses/splitwise/providers/group_provider.dart';
import 'package:expenses/splitwise/models/user_model.dart';
import 'package:expenses/splitwise/models/expense_model.dart';
import 'package:expenses/splitwise/widgets/user_avatar.dart';
import 'package:expenses/splitwise/widgets/settlement_card.dart';
import 'package:expenses/widgets/custom_modal_dialog.dart';

import 'package:expenses/models.dart';

/// Widget for displaying balance summary and settlements
class BalanceSummary extends StatelessWidget {
  final Map<String, double> balances;
  final List<Map<String, dynamic>> settlements;
  final Map<String, String> memberNames;
  final String currentUserId;
  final String groupId;
  final List<ExpenseModel> expenses;
  final Function(Expense)? onAddPersonalExpense;
  final Function(String, double)? onAddIncomeRecord;

  const BalanceSummary({
    super.key,
    required this.balances,
    required this.settlements,
    required this.memberNames,
    required this.currentUserId,
    required this.groupId,
    required this.expenses,
    this.onAddPersonalExpense,
    this.onAddIncomeRecord,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    if (balances.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.account_balance_wallet_outlined,
              size: 80,
              color: colorScheme.primary.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 16),
            Text(
              'No balances yet',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'Add expenses to see balances',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Balance Cards
          Text(
            'Balances',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 12),
          ...balances.entries.map((entry) {
            final userId = entry.key;
            final balance = entry.value;
            final memberName = memberNames[userId] ?? 'Unknown';
            final isCurrentUser = userId == currentUserId;
            // Positive balance means you are owed money (Green)
            // Negative balance means you owe money (Red)
            final isPositive = balance > 0;

            return FutureBuilder<UserModel?>(
              future: context.read<GroupProvider>().getUserDetails(userId),
              builder: (context, snapshot) {
                final user = snapshot.data;
                
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: Stack(
                      children: [
                        UserAvatar(
                          displayName: memberName,
                          photoUrl: user?.photoUrl,
                        ),
                        Positioned(
                          right: 0,
                          bottom: 0,
                          child: Container(
                            padding: const EdgeInsets.all(2),
                            decoration: BoxDecoration(
                              color: Theme.of(context).cardColor,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              isPositive
                                  ? Icons.arrow_upward
                                  : Icons.arrow_downward,
                              size: 14,
                              color: isPositive ? Colors.green : Colors.red,
                            ),
                          ),
                        ),
                      ],
                    ),
                    title: Text(isCurrentUser ? 'You' : memberName),
                    trailing: Text(
                      '${isPositive ? '+' : ''}${Helpers.formatCurrency(balance)}',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: isPositive ? Colors.green : Colors.red,
                          ),
                    ),
                  ),
                );
              }
            );
          }),


          // Settlements
          if (settlements.isNotEmpty) ...[
            const SizedBox(height: 32),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.tertiaryContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.handshake_outlined,
                      color: Theme.of(context).colorScheme.onTertiaryContainer,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Settlement Plan',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            ...settlements.map((settlement) {
              return SettlementCard(
                settlement: settlement,
                memberNames: memberNames,
                currentUserId: currentUserId,
                onSettle: () async {
                  final amount = settlement['amount'] as double;
                  final fromId = settlement['from'] as String;
                  final toId = settlement['to'] as String;

                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => CustomModalDialog(
                      icon: Icons.check_circle_rounded,
                      iconColor: const Color(0xFF1DD1A1),
                      iconBackgroundColor: const Color(0xFF1DD1A1).withValues(alpha: 0.15),
                      title: 'Settle Debt',
                      subtitle: 'Mark payment of ${Helpers.formatCurrency(amount)} from ${memberNames[fromId] ?? "Payer"} to ${memberNames[toId] ?? "Receiver"} as paid?',
                      primaryButtonText: 'Confirm Settlement',
                      primaryButtonColor: const Color(0xFF1DD1A1),
                      onPrimaryPressed: () => Navigator.pop(ctx, true),
                    ),
                  );

                  if (confirm == true && context.mounted) {
                    final expenseProvider = context.read<ExpenseProvider>();
                    
                    await expenseProvider.addExpense(
                      groupId: groupId,
                      description: 'Settlement',
                      amount: amount,
                      paidBy: fromId,
                      paidByName: memberNames[fromId] ?? 'Unknown',
                      splitAmongIds: [toId],
                      memberNames: memberNames,
                      groupMemberIds: memberNames.keys.toList(),
                      isSettlement: true,
                    );

                    // Automatically sync settlement to personal ledger!
                    if (fromId == currentUserId && onAddPersonalExpense != null) {
                      // You paid the settlement -> log as Personal Expense
                      final personalExpense = Expense(
                        id: IdGenerator.generateExpenseId(),
                        title: 'Settlement to ${memberNames[toId] ?? "Member"}',
                        amount: amount,
                        date: DateTime.now(),
                        categoryId: 'cat_bills',
                        paymentMethod: PaymentMethod.upi,
                        note: 'Splitwise balance settlement paid',
                      );
                      onAddPersonalExpense!(personalExpense);
                    } else if (toId == currentUserId && onAddIncomeRecord != null) {
                      // You received the settlement -> log as Income Record
                      onAddIncomeRecord!(
                        'Settlement from ${memberNames[fromId] ?? "Member"}',
                        amount,
                      );
                    }
                    
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).clearSnackBars();
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            fromId == currentUserId
                                ? 'Settlement recorded & added to your personal transactions!'
                                : toId == currentUserId
                                    ? 'Settlement recorded & added to your income!'
                                    : 'Settlement recorded successfully!',
                          ),
                        ),
                      );
                    }
                  }
                },
              );
            }),
          ],
          
          // Total Expenses Card
          if (expenses.isNotEmpty) ...[
            const SizedBox(height: 32),
            Card(
              elevation: 2,
              color: colorScheme.primaryContainer,
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Total Expenses',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                color: colorScheme.onPrimaryContainer,
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${expenses.where((e) => !e.isSettlement).length} ${expenses.where((e) => !e.isSettlement).length == 1 ? 'expense' : 'expenses'}',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: colorScheme.onPrimaryContainer.withValues(alpha: 0.7),
                              ),
                        ),
                      ],
                    ),
                    Text(
                      Helpers.formatCurrency(
                        expenses
                            .where((expense) => !expense.isSettlement)
                            .fold<double>(
                          0,
                          (sum, expense) => sum + expense.amount,
                        ),
                      ),
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            color: colorScheme.onPrimaryContainer,
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
