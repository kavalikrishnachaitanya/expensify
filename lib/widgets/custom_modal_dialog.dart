import 'package:flutter/material.dart';

class CustomModalDialog extends StatelessWidget {
  final IconData icon;
  final Color? iconColor;
  final Color? iconBackgroundColor;
  final String title;
  final String? subtitle;
  final Widget? content;
  final String? primaryButtonText;
  final VoidCallback? onPrimaryPressed;
  final Color? primaryButtonColor;
  final String? secondaryButtonText;
  final VoidCallback? onSecondaryPressed;
  final bool isPrimaryLoading;

  const CustomModalDialog({
    super.key,
    required this.icon,
    this.iconColor,
    this.iconBackgroundColor,
    required this.title,
    this.subtitle,
    this.content,
    this.primaryButtonText,
    this.onPrimaryPressed,
    this.primaryButtonColor,
    this.secondaryButtonText = 'Cancel',
    this.onSecondaryPressed,
    this.isPrimaryLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final effectiveIconColor = iconColor ?? theme.colorScheme.primary;
    final effectiveIconBg = iconBackgroundColor ?? theme.colorScheme.primaryContainer;
    final effectivePrimaryColor = primaryButtonColor ?? theme.colorScheme.primary;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      clipBehavior: Clip.antiAlias,
      elevation: 10,
      backgroundColor: theme.colorScheme.surface,
      child: Container(
        padding: const EdgeInsets.all(20),
        constraints: const BoxConstraints(maxWidth: 340),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Header Icon Badge + Title Row
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: effectiveIconBg,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    icon,
                    size: 24,
                    color: effectiveIconColor,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 17,
                        ),
                      ),
                      if (subtitle != null && subtitle!.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          subtitle!,
                          style: TextStyle(
                            color: theme.colorScheme.onSurfaceVariant,
                            fontSize: 13,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),

            // Content Child
            if (content != null) ...[
              const SizedBox(height: 14),
              Flexible(child: content!),
            ],

            const SizedBox(height: 18),

            // Action Buttons Row
            Row(
              children: [
                if (secondaryButtonText != null)
                  Expanded(
                    child: OutlinedButton(
                      onPressed: onSecondaryPressed ?? () => Navigator.of(context).pop(false),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        side: BorderSide(
                          color: theme.colorScheme.outline.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Text(
                        secondaryButtonText!,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                    ),
                  ),
                if (secondaryButtonText != null && primaryButtonText != null)
                  const SizedBox(width: 10),
                if (primaryButtonText != null)
                  Expanded(
                    child: FilledButton(
                      onPressed: isPrimaryLoading ? null : onPrimaryPressed,
                      style: FilledButton.styleFrom(
                        backgroundColor: effectivePrimaryColor,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: isPrimaryLoading
                          ? const SizedBox(
                              height: 18,
                              width: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Text(
                              primaryButtonText!,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
