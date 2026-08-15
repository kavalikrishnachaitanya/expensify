import 'package:flutter/material.dart';
import 'models.dart';
import 'categories_screen.dart';
import 'services/google_drive_service.dart';
import 'login_screen.dart';

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

  @override
  void initState() {
    super.initState();
    _userName = widget.userName;
  }



  void _openEditNameDialog() {
    final controller = TextEditingController(text: _userName);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit Profile Name'),
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
          ElevatedButton(
            onPressed: () {
              final newName = controller.text.trim();
              if (newName.isNotEmpty) {
                setState(() => _userName = newName);
                widget.onUpdateUserName(newName);
              }
              Navigator.of(ctx).pop();
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }





  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Profile Section
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
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 30,
                    backgroundColor: theme.colorScheme.primary,
                    foregroundColor: theme.colorScheme.onPrimary,
                    child: Text(
                      _userName.isNotEmpty ? _userName[0].toUpperCase() : '?',
                      style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _userName,
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        Text('Financial Planner', style: TextStyle(color: theme.colorScheme.onSurfaceVariant)),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.edit_rounded),
                    onPressed: _openEditNameDialog,
                    tooltip: 'Edit Profile',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),



            // App Settings Section
            Text(
              'App Settings',
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Container(
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                children: [
                  ListTile(
                    leading: Icon(widget.isDarkMode ? Icons.wb_sunny_rounded : Icons.nightlight_round, color: theme.colorScheme.primary),
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
                      'Synced to Google Drive (${widget.driveService.currentUser?.email ?? 'Unknown Account'})',
                      style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 12),
                    ),
                    trailing: const Icon(Icons.check_circle_rounded, color: Color(0xFF1DD1A1)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () async {
                  await widget.driveService.signOut();
                  if (!context.mounted) return;
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (_) => const LoginScreen(isDarkMode: true, onToggleTheme: _dummyToggle)),
                    (route) => false,
                  );
                },
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
