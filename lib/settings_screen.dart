import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'models.dart';
import 'categories_screen.dart';
import 'services/google_drive_service.dart';
import 'login_screen.dart';
import 'splitwise/providers/auth_provider.dart' as split_auth;
import 'splitwise/widgets/user_avatar.dart';

class SettingsScreen extends StatefulWidget {
  final String userName;
  final Function(String) onUpdateUserName;
  final DateTime selectedDate;
  final String currencySymbol;
  final List<ExpenseCategory> categories;
  final List<Expense> expenses;
  final Function(ExpenseCategory) onAddCategory;
  final Function(String) onDeleteCategory;
  final bool isDarkMode;
  final VoidCallback onToggleTheme;
  final GoogleDriveService driveService;

  const SettingsScreen({
    super.key,
    required this.userName,
    required this.onUpdateUserName,
    required this.selectedDate,
    required this.currencySymbol,
    required this.categories,
    required this.expenses,
    required this.onAddCategory,
    required this.onDeleteCategory,
    required this.isDarkMode,
    required this.onToggleTheme,
    required this.driveService,
  });

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late String _userName;
  bool _isDeletingAccount = false;

  @override
  void initState() {
    super.initState();
    _userName = widget.userName;
  }

  split_auth.AuthProvider? _getAuth() {
    try {
      return context.read<split_auth.AuthProvider>();
    } catch (_) {
      return null;
    }
  }

  void _openEditNameDialog(String currentName) {
    final controller = TextEditingController(text: currentName);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit Display Name'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Your Name',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final newName = controller.text.trim();
              if (newName.isNotEmpty) {
                setState(() => _userName = newName);
                widget.onUpdateUserName(newName);
                // Sync to Firestore
                final auth = _getAuth();
                auth?.updateProfile(newName, auth.userModel?.photoUrl);
              }
              Navigator.of(ctx).pop();
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _handleDeleteAccount() async {
    final auth = _getAuth();
    if (auth == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Account'),
        content: const Text(
          'This will permanently delete your account and all Splitwise data.\n\n'
          'You cannot delete your account if you have outstanding balances in any group.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _isDeletingAccount = true);
    final success = await auth.deleteAccount();
    if (!mounted) return;
    setState(() => _isDeletingAccount = false);

    if (success) {
      await widget.driveService.signOut();
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (_) => const LoginScreen(isDarkMode: true, onToggleTheme: _dummyToggle),
        ),
        (route) => false,
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(auth.error ?? 'Could not delete account. Settle all dues first.'),
          backgroundColor: Theme.of(context).colorScheme.error,
          duration: const Duration(seconds: 5),
        ),
      );
    }
  }

  Future<void> _handleLogout() async {
    // Unified logout — Google Sign-In + Drive scope + Firebase Auth all in one call
    await widget.driveService.signOut();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (_) => const LoginScreen(isDarkMode: true, onToggleTheme: _dummyToggle),
      ),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    split_auth.AuthProvider? authProvider;
    try {
      authProvider = context.watch<split_auth.AuthProvider>();
    } catch (_) {}

    final photoUrl = authProvider?.userModel?.photoUrl ?? authProvider?.user?.photoURL;
    final displayName = authProvider?.userModel?.displayName ?? _userName;
    final email = authProvider?.user?.email ?? widget.driveService.currentUser?.email ?? '';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Profile Section ──────────────────────────────────────
            Text(
              'Profile',
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                children: [
                  // Avatar + Name + Email row
                  Row(
                    children: [
                      UserAvatar(
                        photoUrl: photoUrl,
                        displayName: displayName.isNotEmpty ? displayName : 'User',
                        radius: 32,
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              displayName,
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                            if (email.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(
                                email,
                                style: TextStyle(
                                  color: theme.colorScheme.onSurfaceVariant,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.edit_rounded),
                        onPressed: () => _openEditNameDialog(displayName),
                        tooltip: 'Edit Name',
                      ),
                    ],
                  ),

                  // Delete account — only if signed in
                  if (authProvider?.isAuthenticated == true) ...[
                    const SizedBox(height: 12),
                    const Divider(height: 1),
                    const SizedBox(height: 4),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(
                        Icons.delete_forever_rounded,
                        color: theme.colorScheme.error,
                      ),
                      title: Text(
                        'Delete Account',
                        style: TextStyle(
                          color: theme.colorScheme.error,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      subtitle: const Text(
                        'Removes all Splitwise data. Blocked if you have outstanding dues.',
                      ),
                      onTap: _isDeletingAccount ? null : _handleDeleteAccount,
                      trailing: _isDeletingAccount
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Icon(
                              Icons.chevron_right_rounded,
                              color: theme.colorScheme.error,
                            ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 32),

            // ── App Settings Section ─────────────────────────────────
            Text(
              'App Settings',
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Material(
              color: theme.colorScheme.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(20),
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  ListTile(
                    leading: Icon(
                      widget.isDarkMode ? Icons.wb_sunny_rounded : Icons.nightlight_round,
                      color: theme.colorScheme.primary,
                    ),
                    title: const Text('Dark Mode', style: TextStyle(fontWeight: FontWeight.bold)),
                    trailing: Switch(
                      value: widget.isDarkMode,
                      onChanged: (val) => widget.onToggleTheme(),
                    ),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (ctx) => CategoriesScreen(
                            categories: widget.categories,
                            onAddCategory: widget.onAddCategory,
                            onDeleteCategory: widget.onDeleteCategory,
                          ),
                        ),
                      );
                    },
                    leading: Icon(Icons.category_rounded, color: theme.colorScheme.primary),
                    title: const Text('Manage Categories', style: TextStyle(fontWeight: FontWeight.bold)),
                    trailing: const Icon(Icons.chevron_right_rounded),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: Icon(Icons.cloud_sync_rounded, color: theme.colorScheme.primary),
                    title: const Text('Sync Status', style: TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text(
                      'Google Drive · ${email.isNotEmpty ? email : 'Not signed in'}',
                      style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 12),
                    ),
                    trailing: const Icon(Icons.check_circle_rounded, color: Color(0xFF1DD1A1)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // ── Logout Button ────────────────────────────────────────
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _handleLogout,
                icon: const Icon(Icons.logout_rounded),
                label: const Text('Logout'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.colorScheme.errorContainer,
                  foregroundColor: theme.colorScheme.onErrorContainer,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
              ),
            ),
            const SizedBox(height: 60),
          ],
        ),
      ),
    );
  }
}

void _dummyToggle() {}
