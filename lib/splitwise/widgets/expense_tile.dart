import 'package:flutter/material.dart';
import 'package:expenses/splitwise/models/expense_model.dart';
import 'package:expenses/splitwise/utils/helpers.dart';

/// Tile widget for displaying an expense
class ExpenseTile extends StatelessWidget {
  final ExpenseModel expense;
  final String currentUserId;
  final VoidCallback? onDelete;

  const ExpenseTile({
    super.key,
    required this.expense,
    required this.currentUserId,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isPaidByMe = expense.paidBy == currentUserId;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            // Icon
            CircleAvatar(
              radius: 24,
              backgroundColor: colorScheme.secondaryContainer,
              child: Icon(
                Icons.receipt_long,
                color: colorScheme.onSecondaryContainer,
              ),
            ),
            const SizedBox(width: 16),

            // Expense Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    expense.description,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${isPaidByMe ? "You" : expense.paidByName} paid ${Helpers.formatCurrency(expense.amount)}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    Helpers.formatRelativeDate(expense.createdAt),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                  ),
                ],
              ),
            ),

            // Amount and delete
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  Helpers.formatCurrency(expense.amount),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: isPaidByMe
                            ? colorScheme.primary
                            : colorScheme.onSurface,
                      ),
                ),
                if (onDelete != null)
                  IconButton(
                    icon: Icon(
                      Icons.delete_outline,
                      size: 20,
                      color: colorScheme.error,
                    ),
                    onPressed: onDelete,
                    tooltip: 'Delete',
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
