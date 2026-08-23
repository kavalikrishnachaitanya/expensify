import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:expenses/splitwise/models/user_model.dart';
import 'package:expenses/splitwise/providers/group_provider.dart';
import 'package:expenses/splitwise/utils/helpers.dart';
import 'package:expenses/splitwise/widgets/user_avatar.dart';

class SettlementCard extends StatelessWidget {
  final Map<String, dynamic> settlement;
  final Map<String, String> memberNames;
  final String currentUserId;
  final VoidCallback onSettle;

  const SettlementCard({
    super.key,
    required this.settlement,
    required this.memberNames,
    required this.currentUserId,
    required this.onSettle,
  });

  @override
  Widget build(BuildContext context) {
    final fromId = settlement['from'] as String;
    final toId = settlement['to'] as String;
    final amount = settlement['amount'] as double;
    
    final colorScheme = Theme.of(context).colorScheme;
    final isUserInvolved = fromId == currentUserId || toId == currentUserId;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: colorScheme.shadow.withValues(alpha: 0.05),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // DEBTOR (Payer)
              _buildPerson(context, fromId, 'Payer'),

              // AMOUNT FLOW
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Column(
                    children: [
                      Text(
                        Helpers.formatCurrency(amount),
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: colorScheme.primary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Stack(
                        alignment: Alignment.center,
                        children: [
                          Container(
                            height: 2,
                            color: colorScheme.surfaceContainerHighest,
                          ),
                          Icon(
                            Icons.arrow_forward_ios_rounded,
                            size: 16,
                            color: colorScheme.primary.withValues(alpha: 0.5),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              // CREDITOR (Receiver)
              _buildPerson(context, toId, 'Receiver'),
            ],
          ),
          
          if (isUserInvolved) ...[
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: onSettle,
                icon: const Icon(Icons.check_circle_outline),
                label: const Text('Mark as Paid'),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPerson(BuildContext context, String userId, String roleLabel) {
    final name = userId == currentUserId ? 'You' : (memberNames[userId] ?? 'Unknown');
    final colorScheme = Theme.of(context).colorScheme;

    return FutureBuilder<UserModel?>(
      future: context.read<GroupProvider>().getUserDetails(userId),
      builder: (context, snapshot) {
        final user = snapshot.data;
        
        return Column(
          children: [
            Container(
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: roleLabel == 'Payer' 
                      ? colorScheme.error.withValues(alpha: 0.3)
                      : colorScheme.primary.withValues(alpha: 0.3),
                  width: 2,
                ),
              ),
              child: UserAvatar(
                displayName: name,
                photoUrl: user?.photoUrl,
                radius: 28,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              name,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              roleLabel,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        );
      }
    );
  }
}
