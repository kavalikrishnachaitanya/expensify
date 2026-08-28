import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:expenses/models.dart';
import 'package:expenses/splitwise/providers/auth_provider.dart';
import 'package:expenses/splitwise/providers/group_provider.dart';
import 'package:expenses/splitwise/screens/groups/create_group_screen.dart';
import 'package:expenses/splitwise/widgets/group_card.dart';
import 'package:expenses/splitwise/screens/groups/group_detail_screen.dart';
import 'package:expenses/splitwise/utils/constants.dart';

class HomeScreen extends StatefulWidget {
  final Function(Expense)? onAddPersonalExpense;
  final void Function(String, {String? linkedSplitwiseId, String? matchDescription, double? matchAmount})? onDeletePersonalExpense;
  final Function(String, double)? onAddIncomeRecord;
  final List<Expense>? personalExpenses;
  final List<ExpenseCategory>? categories;

  const HomeScreen({
    super.key,
    this.onAddPersonalExpense,
    this.onDeletePersonalExpense,
    this.onAddIncomeRecord,
    this.personalExpenses,
    this.categories,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadGroups();
    });
  }

  void _loadGroups() {
    final authProvider = context.read<AuthProvider>();
    final groupProvider = context.read<GroupProvider>();
    groupProvider.clearError();
    if (authProvider.user != null) {
      groupProvider.loadUserGroups(authProvider.user!.uid);
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
                      builder: (context) => GroupDetailScreen(
                        group: group,
                        onAddPersonalExpense: widget.onAddPersonalExpense,
                        onDeletePersonalExpense: widget.onDeletePersonalExpense,
                        onAddIncomeRecord: widget.onAddIncomeRecord,
                        personalExpenses: widget.personalExpenses,
                        categories: widget.categories,
                      ),
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
    showCreateGroupSheet(context);
  }
}
