import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:expenses/splitwise/providers/auth_provider.dart';
import 'package:expenses/splitwise/providers/group_provider.dart';
import 'package:expenses/splitwise/screens/groups/create_group_screen.dart';
import 'package:expenses/splitwise/widgets/group_card.dart';
import 'package:expenses/splitwise/screens/groups/group_detail_screen.dart';
import 'package:expenses/splitwise/utils/constants.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    _loadGroups();
  }

  void _loadGroups() {
    final authProvider = context.read<AuthProvider>();
    if (authProvider.user != null) {
      context.read<GroupProvider>().loadUserGroups(authProvider.user!.uid);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Consumer<GroupProvider>(
      builder: (context, groupProvider, child) {
        if (groupProvider.error != null) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.error_outline,
                    size: 60,
                    color: colorScheme.error,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Something went wrong',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  SelectableText(
                    groupProvider.error!,
                    style: TextStyle(color: colorScheme.error),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: () => _loadGroups(),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
          );
        }

        if (groupProvider.groups.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.group_add_outlined,
                  size: 80,
                  color: colorScheme.primary.withValues(alpha: 0.5),
                ),
                const SizedBox(height: 16),
                Text(
                  AppConstants.noGroups,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: () => _navigateToCreateGroup(context),
                  icon: const Icon(Icons.add),
                  label: const Text('Create Group'),
                ),
              ],
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: () async => _loadGroups(),
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: groupProvider.groups.length,
            itemBuilder: (context, index) {
              final group = groupProvider.groups[index];
              return GroupCard(
                group: group,
                onTap: () {
                  groupProvider.selectGroup(group);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => GroupDetailScreen(group: group),
                    ),
                  );
                },
              );
            },
          ),
        );
      },
    );
  }

  void _navigateToCreateGroup(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const CreateGroupScreen(),
      ),
    );
  }
}
