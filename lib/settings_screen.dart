// ignore_for_file: unused_import
import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'models.dart';
import 'categories_screen.dart';
import 'services/google_drive_service.dart';
import 'login_screen.dart';
import 'main.dart';
import 'package:expenses/splitwise/providers/auth_provider.dart' as split_auth;
import 'package:expenses/splitwise/providers/group_provider.dart' as split_group;
import 'package:expenses/splitwise/providers/expense_provider.dart' as split_expense;
import 'package:expenses/widgets/custom_modal_dialog.dart';
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
  final bool isGuestMode;

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
    this.isGuestMode = false,
  });

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late String _userName;
  String? _localPhotoUrl;
  bool _isDeletingAccount = false;
  bool _isUpdatingAvatar = false;
  final ImagePicker _picker = ImagePicker();
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
                // Sync to Firestore & Auth
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

  /// Open Avatar Options Modal (Upload Custom Photo / Remove Photo)
  void _openAvatarSettingsModal(String displayName, String? currentPhotoUrl) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Profile Avatar Settings',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.pop(ctx),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Theme.of(ctx).colorScheme.primaryContainer,
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.photo_library_rounded, color: Theme.of(ctx).colorScheme.primary),
              ),
              title: const Text('Upload Photo from Gallery', style: TextStyle(fontWeight: FontWeight.w600)),
              subtitle: const Text('Pick any photo (automatically compressed)'),
              onTap: () {
                Navigator.pop(ctx);
                _pickAndSetAvatar(ImageSource.gallery, displayName);
              },
            ),
            if (!kIsWeb)
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Theme.of(ctx).colorScheme.secondaryContainer,
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.camera_alt_rounded, color: Theme.of(ctx).colorScheme.secondary),
              ),
              title: const Text('Take Photo with Camera', style: TextStyle(fontWeight: FontWeight.w600)),
              subtitle: const Text('Snap a quick low-size profile picture'),
              onTap: () {
                Navigator.pop(ctx);
                _pickAndSetAvatar(ImageSource.camera, displayName);
              },
            ),
            if (currentPhotoUrl != null && currentPhotoUrl.isNotEmpty) ...[
              const Divider(height: 24),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Theme.of(ctx).colorScheme.errorContainer,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.delete_outline_rounded, color: Theme.of(ctx).colorScheme.error),
                ),
                title: Text('Remove Profile Photo', style: TextStyle(fontWeight: FontWeight.w600, color: Theme.of(ctx).colorScheme.error)),
                subtitle: const Text('Revert to initial letter icon'),
                onTap: () {
                  Navigator.pop(ctx);
                  _updateAvatar('', displayName);
                },
              ),
            ],
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  /// Pick image via image_picker, automatically resize & compress to prevent memory/render issues
  Future<void> _pickAndSetAvatar(ImageSource source, String displayName) async {
    try {
      final XFile? image = await _picker.pickImage(
        source: source,
        maxWidth: 256, // Low resolution limit (256x256) to eliminate render & memory lag
        maxHeight: 256,
        imageQuality: 60, // Optimized compression quality
      );

      if (image != null) {
        final bytes = await image.readAsBytes();
        final base64Image = 'data:image/png;base64,${base64Encode(bytes)}';
        await _updateAvatar(base64Image, displayName);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to pick image: $e')),
        );
      }
    }
  }

  /// Update avatar: Cache locally + Sync online to Drive and Firestore when available
  Future<void> _updateAvatar(String photoUrl, String displayName) async {
    setState(() {
      _localPhotoUrl = photoUrl;
      _isUpdatingAvatar = true;
    });
    final auth = _getAuth();

    try {
      // 1. Update Firestore & Auth Profile (if online)
      if (auth != null && auth.isAuthenticated) {
        await auth.updateProfile(displayName, photoUrl);
      }

      // 2. Sync to Google Drive app folder (if online)
      final driveSuccess = await widget.driveService.uploadAvatarData(photoUrl);

      if (mounted) {
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              driveSuccess
                  ? 'Profile photo updated and synced to Drive!'
                  : 'Profile photo saved locally. Will sync to Drive when online.',
            ),
            backgroundColor: const Color(0xFF1DD1A1),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Saved locally. Will sync when net is available.')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isUpdatingAvatar = false);
      }
    }
  }

  /// Delete Account: Wipes Drive data, Firestore Splitwise data, and Firebase Auth account
  Future<void> _handleDeleteAccount() async {
    final auth = _getAuth();
    if (auth == null) return;

    final TextEditingController confirmController = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (dialogCtx, setDialogState) {
            final isConfirmed = confirmController.text.trim() == 'DELETE';
            final theme = Theme.of(ctx);

            return CustomModalDialog(
              icon: Icons.warning_amber_rounded,
              iconColor: theme.colorScheme.error,
              iconBackgroundColor: theme.colorScheme.errorContainer,
              title: 'Delete Account',
              subtitle: 'This action is IRREVERSIBLE. It will permanently delete your account & wipe all data.',
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  RichText(
                    text: TextSpan(
                      style: theme.textTheme.bodyMedium,
                      children: const [
                        TextSpan(text: 'To confirm, type '),
                        TextSpan(
                          text: 'DELETE',
                          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.redAccent),
                        ),
                        TextSpan(text: ' below:'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: confirmController,
                    autofocus: true,
                    textCapitalization: TextCapitalization.characters,
                    decoration: InputDecoration(
                      hintText: 'Type DELETE',
                      filled: true,
                      fillColor: theme.colorScheme.surfaceContainerHigh,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    ),
                    onChanged: (_) {
                      setDialogState(() {});
                    },
                  ),
                ],
              ),
              primaryButtonText: 'Delete Everything',
              primaryButtonColor: isConfirmed ? theme.colorScheme.error : theme.colorScheme.error.withValues(alpha: 0.4),
              onPrimaryPressed: isConfirmed ? () => Navigator.of(ctx).pop(true) : null,
            );
          },
        );
      },
    );

    if (confirmed != true || !mounted) return;

    setState(() => _isDeletingAccount = true);

    // 1. Check dues & delete Firestore Splitwise data + Firebase Auth
    final success = await auth.deleteAccount();

    if (!mounted) return;

    if (success) {
      // 2. Wipe ALL Google Drive backup files (expenditure_backup.json, profile_avatar.txt)
      await widget.driveService.deleteAllData();
      
      // 3. Sign out of Google SSO
      await widget.driveService.signOut();

      if (!mounted) return;
      setState(() => _isDeletingAccount = false);

      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (_) => const LoginScreen(isDarkMode: true, onToggleTheme: _dummyToggle),
        ),
        (route) => false,
      );
    } else {
      setState(() => _isDeletingAccount = false);
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(auth.error ?? 'Could not delete account. Settle all group dues first.'),
          backgroundColor: Theme.of(context).colorScheme.error,
          duration: const Duration(seconds: 5),
        ),
      );
    }
  }

  Future<void> _handleConnectGoogleAccount() async {
    final success = await widget.driveService.signIn();
    if (success && mounted) {
      final auth = _getAuth();
      if (auth != null) {
        await auth.signInWithGoogle();
      }
      setState(() {});
      if (!mounted) return;
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Successfully connected Google Account! Syncing to cloud...'),
          backgroundColor: Color(0xFF1DD1A1),
        ),
      );
    } else if (mounted) {
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not sign in with Google.')),
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

    final photoUrl = _localPhotoUrl ?? authProvider?.userModel?.photoUrl ?? authProvider?.user?.photoURL;
    final displayName = authProvider?.userModel?.displayName ?? (widget.isGuestMode && _userName == widget.userName ? 'Guest User' : _userName);
    final email = authProvider?.user?.email ?? widget.driveService.currentUser?.email ?? '';
    final isConnected = email.isNotEmpty;

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
            Material(
              color: theme.colorScheme.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(20),
              clipBehavior: Clip.antiAlias,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Row(
                      children: [
                        // Avatar with edit overlay badge
                        GestureDetector(
                          onTap: _isUpdatingAvatar
                              ? null
                              : () => _openAvatarSettingsModal(displayName, photoUrl),
                          child: Stack(
                            children: [
                              UserAvatar(
                                photoUrl: photoUrl,
                                displayName: displayName.isNotEmpty ? displayName : 'User',
                                radius: 34,
                              ),
                              Positioned(
                                right: 0,
                                bottom: 0,
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: BoxDecoration(
                                    color: theme.colorScheme.primary,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: theme.colorScheme.surfaceContainerHigh,
                                      width: 2,
                                    ),
                                  ),
                                  child: _isUpdatingAvatar
                                      ? const SizedBox(
                                          width: 12,
                                          height: 12,
                                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                        )
                                      : const Icon(
                                          Icons.camera_alt_rounded,
                                          size: 14,
                                          color: Colors.white,
                                        ),
                                ),
                              ),
                            ],
                          ),
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
                              const SizedBox(height: 4),
                              Text(
                                isConnected ? email : 'Local Guest Account',
                                style: TextStyle(
                                  color: theme.colorScheme.onSurfaceVariant,
                                  fontSize: 13,
                                ),
                              ),
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
                    if (!isConnected) ...[
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primaryContainer.withValues(alpha: 0.4),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.cloud_upload_rounded, color: theme.colorScheme.primary),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: const [
                                  Text(
                                    'Connect Google Account',
                                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                  ),
                                  Text(
                                    'Enable Google Drive backups & Splitwise group sharing',
                                    style: TextStyle(fontSize: 11),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            FilledButton.icon(
                              onPressed: _handleConnectGoogleAccount,
                              icon: const Icon(Icons.login_rounded, size: 14),
                              label: const Text('Connect', style: TextStyle(fontSize: 12)),
                              style: FilledButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
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
                  Builder(
                    builder: (ctx) {
                      final isDark = Theme.of(ctx).brightness == Brightness.dark;

                      return ListTile(
                        leading: Icon(
                          isDark ? Icons.nightlight_round : Icons.wb_sunny_rounded,
                          color: theme.colorScheme.primary,
                        ),
                        title: const Text('Dark Mode', style: TextStyle(fontWeight: FontWeight.bold)),
                        trailing: Switch(
                          value: isDark,
                          onChanged: (val) {
                            try {
                              ctx.read<ThemeProvider>().toggleTheme();
                            } catch (_) {}
                          },
                        ),
                      );
                    },
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
                      isConnected
                          ? 'Google Drive · $email'
                          : 'Local Storage · Connect Google Account to backup',
                      style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 12),
                    ),
                    trailing: isConnected
                        ? const Icon(Icons.check_circle_rounded, color: Color(0xFF1DD1A1))
                        : TextButton(
                            onPressed: _handleConnectGoogleAccount,
                            child: const Text('Connect'),
                          ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // ── Account Actions Section (Above Logout) ───────────────
            if (authProvider?.isAuthenticated == true) ...[
              Text(
                'Account Actions',
                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              Material(
                color: theme.colorScheme.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(20),
                clipBehavior: Clip.antiAlias,
                child: ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.errorContainer,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.delete_forever_rounded,
                      color: theme.colorScheme.error,
                      size: 20,
                    ),
                  ),
                  title: Text(
                    'Delete Account',
                    style: TextStyle(
                      color: theme.colorScheme.error,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  subtitle: const Text(
                    'Clears all local, Google Drive, and Splitwise data.',
                    style: TextStyle(fontSize: 12),
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
              ),
              const SizedBox(height: 24),
            ],

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
