import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:expenses/splitwise/models/expense_model.dart';
import 'package:expenses/splitwise/models/user_model.dart';
import 'package:expenses/splitwise/providers/group_provider.dart';
import 'package:expenses/splitwise/utils/helpers.dart';
import 'package:expenses/splitwise/widgets/user_avatar.dart';

/// Tile widget for displaying an expense with Payer Avatar
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
            // Payer UserAvatar with Tap-to-View Zoom
            FutureBuilder<UserModel?>(
              future: context.read<GroupProvider>().getUserDetails(expense.paidBy),
              builder: (context, snapshot) {
                final payerPhotoUrl = expense.paidByPhotoUrl ?? snapshot.data?.photoUrl;
                return UserAvatar(
                  photoUrl: payerPhotoUrl,
                  displayName: isPaidByMe ? "You" : expense.paidByName,
                  radius: 22,
                );
              },
            ),
            const SizedBox(width: 16),

            // Expense Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    expense.description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${isPaidByMe ? "You" : expense.paidByName} paid ${Helpers.formatCurrency(expense.amount)}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
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
