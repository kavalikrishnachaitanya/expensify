import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:expenses/models.dart';
import 'package:expenses/splitwise/models/group_model.dart';
import 'package:expenses/splitwise/models/user_model.dart';
import 'package:expenses/splitwise/providers/auth_provider.dart';
import 'package:expenses/splitwise/providers/expense_provider.dart';
import 'package:expenses/splitwise/providers/group_provider.dart';
import 'package:expenses/splitwise/services/firestore_service.dart';
import 'package:expenses/splitwise/utils/constants.dart';
import 'package:expenses/splitwise/widgets/expense_tile.dart';
import 'package:expenses/splitwise/widgets/balance_summary.dart';
import 'package:expenses/splitwise/screens/expenses/add_expense_screen.dart';
import 'package:expenses/splitwise/widgets/user_avatar.dart';
import 'package:expenses/add_expense_sheet.dart';
import 'package:expenses/sample_data.dart';
import 'package:expenses/widgets/custom_modal_dialog.dart';

class GroupDetailScreen extends StatefulWidget {
  final GroupModel group;
  final Function(Expense)? onAddPersonalExpense;
  final Function(String)? onDeletePersonalExpense;
  final Function(String, double)? onAddIncomeRecord;
  final List<Expense>? personalExpenses;
  final List<ExpenseCategory>? categories;

  const GroupDetailScreen({
    super.key,
    required this.group,
    this.onAddPersonalExpense,
    this.onDeletePersonalExpense,
    this.onAddIncomeRecord,
    this.personalExpenses,
    this.categories,
  });

  @override
  State<GroupDetailScreen> createState() => _GroupDetailScreenState();
}

class _GroupDetailScreenState extends State<GroupDetailScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      setState(() {}); // Rebuild to update FAB visibility
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _loadExpenses();
      }
    });
  }

  void _loadExpenses() {
    context.read<ExpenseProvider>().loadGroupExpenses(widget.group.id);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _showAddMemberDialog() {
    final emailController = TextEditingController();

    showDialog(
      context: context,
      builder: (dialogContext) {
        final theme = Theme.of(dialogContext);
        return CustomModalDialog(
          icon: Icons.person_add_alt_1_rounded,
          iconColor: theme.colorScheme.primary,
          iconBackgroundColor: theme.colorScheme.primaryContainer,
          title: 'Add Member',
          subtitle: 'Invite to ${widget.group.name}',
          content: TextField(
            controller: emailController,
            keyboardType: TextInputType.emailAddress,
            autofocus: true,
            decoration: InputDecoration(
              hintText: 'Enter email address',
              hintStyle: TextStyle(
                fontSize: 13,
                color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
              ),
              prefixIcon: const Icon(Icons.email_outlined, size: 18),
              filled: true,
              fillColor: theme.colorScheme.surfaceContainerHigh,
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: theme.colorScheme.outline.withValues(alpha: 0.2),
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: theme.colorScheme.outline.withValues(alpha: 0.2),
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: theme.colorScheme.primary,
                  width: 1.5,
                ),
              ),
            ),
          ),
          primaryButtonText: 'Add',
          onPrimaryPressed: () async {
            if (emailController.text.trim().isNotEmpty) {
              final groupProvider = context.read<GroupProvider>();
              final messenger = ScaffoldMessenger.of(context);
              final navigator = Navigator.of(dialogContext);
              final errorColor = Theme.of(context).colorScheme.error;

              final errorMsg = await groupProvider.addMemberByEmail(
                widget.group.id,
                emailController.text.trim(),
              );

              navigator.pop();
              messenger.clearSnackBars();
              messenger.showSnackBar(
                SnackBar(
                  content: Text(
                    errorMsg ?? 'Member added successfully!',
                  ),
                  backgroundColor: errorMsg == null ? null : errorColor,
                ),
              );
            }
          },
        );
      },
    );
  }

  void _showMembersDialog(GroupModel group, String? currentUserId, ColorScheme colorScheme) {
    showDialog(
      context: context,
      builder: (dialogCtx) => CustomModalDialog(
        icon: Icons.group_rounded,
        iconColor: colorScheme.primary,
        iconBackgroundColor: colorScheme.primaryContainer,
        title: 'Group Members',
        subtitle: '${group.memberIds.length} members in ${group.name}',
        content: Container(
          constraints: const BoxConstraints(maxHeight: 280),
          child: ListView.separated(
            shrinkWrap: true,
            itemCount: group.memberIds.length,
            separatorBuilder: (context, index) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final memberId = group.memberIds[index];
              final memberName = group.memberNames[memberId] ?? 'Unknown';
              final isCurrentUser = memberId == currentUserId;

              return FutureBuilder<UserModel?>(
                future: context.read<GroupProvider>().getUserDetails(memberId),
                builder: (context, snapshot) {
                  final user = snapshot.data;
                  final email = user?.email ?? 'Loading...';
                  final displayName = user?.displayName ?? memberName;

                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: UserAvatar(
                      photoUrl: user?.photoUrl,
                      displayName: displayName,
                    ),
                    title: Row(
                      children: [
                        Flexible(
                          child: Text(
                            displayName,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (isCurrentUser) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                            decoration: BoxDecoration(
                              color: colorScheme.primaryContainer,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              'You',
                              style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: colorScheme.onPrimaryContainer),
                            ),
                          ),
                        ],
                      ],
                    ),
                    subtitle: Text(email, style: const TextStyle(fontSize: 11)),
                    trailing: (currentUserId == group.createdBy && !isCurrentUser)
                        ? IconButton(
                            icon: Icon(Icons.person_remove_rounded, color: colorScheme.error, size: 20),
                            onPressed: () async {
                              final confirm = await showDialog<bool>(
                                context: context,
                                builder: (ctx) => CustomModalDialog(
                                  icon: Icons.person_remove_rounded,
                                  iconColor: colorScheme.error,
                                  iconBackgroundColor: colorScheme.errorContainer,
                                  title: 'Remove Member',
                                  subtitle: 'Remove $displayName?',
                                  primaryButtonText: 'Remove',
                                  primaryButtonColor: colorScheme.error,
                                  onPrimaryPressed: () => Navigator.pop(ctx, true),
                                ),
                              );

                              if (confirm == true && context.mounted) {
                                final success = await context
                                    .read<GroupProvider>()
                                    .removeMember(group.id, memberId);
                                if (success && context.mounted) {
                                  Navigator.pop(dialogCtx); // Close members dialog
                                  ScaffoldMessenger.of(context).clearSnackBars();
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Member removed successfully')),
                                  );
                                }
                              }
                            },
                          )
                        : null,
                  );
                },
              );
            },
          ),
        ),
        secondaryButtonText: 'Close',
        onSecondaryPressed: () => Navigator.pop(dialogCtx),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final currentUserId = context.read<AuthProvider>().user?.uid;
    final firestoreService = FirestoreService(); // Or inject via provider

    return StreamBuilder<GroupModel?>(
      stream: firestoreService.getGroupStream(widget.group.id),
      initialData: widget.group,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Scaffold(
            appBar: AppBar(title: const Text('Error')),
            body: Center(child: Text('Error: ${snapshot.error}')),
          );
        }

        if (!snapshot.hasData || snapshot.data == null) {
          // Group might have been deleted
          return Scaffold(
            appBar: AppBar(title: const Text('Unavailable')),
            body: const Center(child: Text('Group no longer resides here.')),
          );
        }

        final group = snapshot.data!;

        return Scaffold(
          appBar: AppBar(
            title: Text(group.name),
            actions: [
              IconButton(
                icon: const Icon(Icons.person_add_outlined),
                onPressed: _showAddMemberDialog,
                tooltip: 'Add Member',
              ),
              PopupMenuButton<String>(
                onSelected: (value) async {
                  if (value == 'delete') {
                    final groupProvider = context.read<GroupProvider>();
                    final navigator = Navigator.of(context);

                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => CustomModalDialog(
                        icon: Icons.delete_forever_rounded,
                        iconColor: colorScheme.error,
                        iconBackgroundColor: colorScheme.errorContainer,
                        title: 'Delete Group',
                        subtitle: 'Delete "${group.name}"?',
                        primaryButtonText: 'Delete',
                        primaryButtonColor: colorScheme.error,
                        onPrimaryPressed: () => Navigator.pop(ctx, true),
                      ),
                    );

                    if (confirm == true) {
                      final success = await groupProvider.deleteGroup(group.id);
                      if (success) {
                        navigator.pop(); // Go back to home
                      }
                    }
                  } else if (value == 'leave') {
                    final groupProvider = context.read<GroupProvider>();
                    final navigator = Navigator.of(context);

                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => CustomModalDialog(
                        icon: Icons.exit_to_app_rounded,
                        iconColor: colorScheme.error,
                        iconBackgroundColor: colorScheme.errorContainer,
                        title: 'Leave Group',
                        subtitle: 'Leave "${group.name}"?',
                        primaryButtonText: 'Leave',
                        primaryButtonColor: colorScheme.error,
                        onPrimaryPressed: () => Navigator.pop(ctx, true),
                      ),
                    );

                    if (confirm == true) {
                      final success = await groupProvider.removeMember(group.id, currentUserId!);
                      if (success) {
                        navigator.pop(); // Go back to home
                      }
                    }
                  } else if (value == 'members') {
                    _showMembersDialog(group, currentUserId, colorScheme);
                  }
                },
                itemBuilder: (BuildContext context) {
                  final isOwner = currentUserId == group.createdBy;
                  return [
                    const PopupMenuItem<String>(
                      value: 'members',
                      child: Row(
                        children: [
                          Icon(Icons.people_outline_rounded),
                          SizedBox(width: 8),
                          Text('View Members'),
                        ],
                      ),
                    ),
                    if (isOwner)
                      PopupMenuItem<String>(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(Icons.delete_outline_rounded, color: colorScheme.error),
                            const SizedBox(width: 8),
                            Text(
                              'Delete Group',
                              style: TextStyle(color: colorScheme.error),
                            ),
                          ],
                        ),
                      )
                    else
                      PopupMenuItem<String>(
                        value: 'leave',
                        child: Row(
                          children: [
                            Icon(Icons.exit_to_app_rounded, color: colorScheme.error),
                            const SizedBox(width: 8),
                            Text(
                              'Leave Group',
                              style: TextStyle(color: colorScheme.error),
                            ),
                          ],
                        ),
                      ),
                  ];
                },
              ),
            ],
            bottom: TabBar(
              controller: _tabController,
              tabs: const [
                Tab(text: 'Expenses'),
                Tab(text: 'Balances'),
              ],
            ),
          ),
          body: TabBarView(
            controller: _tabController,
            children: [
              // Expenses Tab
              Consumer<ExpenseProvider>(
                builder: (context, expenseProvider, child) {
                  if (expenseProvider.error != null) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.error_outline, size: 48, color: colorScheme.error),
                            const SizedBox(height: 16),
                            Text(
                              'Unable to load expenses',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              expenseProvider.error!, // This will show "Permission Denied" or "Missing Index"
                              style: TextStyle(color: colorScheme.error),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 16),
                            FilledButton.icon(
                              onPressed: () => _loadExpenses(),
                              icon: const Icon(Icons.refresh),
                              label: const Text('Retry'),
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  if (expenseProvider.expenses.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.receipt_long_outlined,
                            size: 80,
                            color: colorScheme.primary.withValues(alpha: 0.5),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            AppConstants.noExpenses,
                            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                  color: colorScheme.onSurfaceVariant,
                                ),
                          ),
                        ],
                      ),
                    );
                  }

                  return RefreshIndicator(
                    onRefresh: () async {
                      _loadExpenses();
                      // Wait a bit to show the spinner, though the listener updates automatically
                      await Future.delayed(const Duration(seconds: 1));
                    },
                    child: ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: expenseProvider.expenses.length,
                      itemBuilder: (context, index) {
                        final expense = expenseProvider.expenses[index];
                        return ExpenseTile(
                          expense: expense,
                          currentUserId: currentUserId ?? '',
                          onDelete: () async {
                            bool deletePersonalTxn = false;
                            final confirm = await showDialog<bool>(
                              context: context,
                              builder: (ctx) => StatefulBuilder(
                                builder: (context, setDialogState) {
                                  return CustomModalDialog(
                                    icon: Icons.delete_outline_rounded,
                                    iconColor: colorScheme.error,
                                    iconBackgroundColor: colorScheme.errorContainer,
                                    title: 'Delete Expense',
                                    subtitle: 'Are you sure you want to delete "${expense.description}"?',
                                    content: Padding(
                                      padding: const EdgeInsets.only(top: 8.0),
                                      child: CheckboxListTile(
                                        value: deletePersonalTxn,
                                        contentPadding: EdgeInsets.zero,
                                        controlAffinity: ListTileControlAffinity.leading,
                                        activeColor: colorScheme.error,
                                        dense: true,
                                        title: const Text(
                                          'Delete linked personal transaction',
                                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                                        ),
                                        onChanged: (val) {
                                          setDialogState(() {
                                            deletePersonalTxn = val ?? false;
                                          });
                                        },
                                      ),
                                    ),
                                    primaryButtonText: 'Delete',
                                    primaryButtonColor: colorScheme.error,
                                    onPrimaryPressed: () => Navigator.pop(ctx, true),
                                  );
                                },
                              ),
                            );

                            if (confirm == true) {
                              final success = await expenseProvider.deleteExpense(
                                expenseId: expense.id,
                                groupId: group.id,
                                groupMemberIds: group.memberIds,
                                performedBy: currentUserId ?? '',
                                performedByName: group.memberNames[currentUserId] ?? 'Unknown',
                              );

                              if (success && context.mounted) {
                                if (deletePersonalTxn &&
                                    widget.onDeletePersonalExpense != null &&
                                    widget.personalExpenses != null &&
                                    widget.personalExpenses!.isNotEmpty) {
                                  final personal = widget.personalExpenses!;
                                  final descLower = expense.description.trim().toLowerCase();
                                  final amount = expense.amount;

                                  // Stage 0: Direct 2-Way ID Matcher
                                  int matchIndex = personal.indexWhere((e) =>
                                      (expense.linkedPersonalExpenseId != null && e.id == expense.linkedPersonalExpenseId) ||
                                      (e.linkedTransactionId != null && e.linkedTransactionId == expense.id));

                                  // Stage 1: Exact Title & Amount Matcher
                                  if (matchIndex == -1) {
                                    matchIndex = personal.indexWhere((e) =>
                                        e.title.trim().toLowerCase() == descLower &&
                                        (e.amount - amount).abs() < 0.05);
                                  }

                                  if (matchIndex == -1) {
                                    matchIndex = personal.indexWhere((e) {
                                      final t = e.title.trim().toLowerCase();
                                      return (t.contains(descLower) || descLower.contains(t)) &&
                                          (e.amount - amount).abs() < 0.05;
                                    });
                                  }

                                  if (matchIndex == -1) {
                                    matchIndex = personal.indexWhere((e) =>
                                        e.title.trim().toLowerCase() == descLower);
                                  }

                                  if (matchIndex == -1) {
                                    matchIndex = personal.indexWhere((e) {
                                      final t = e.title.trim().toLowerCase();
                                      final n = (e.note ?? '').trim().toLowerCase();
                                      return t.contains(descLower) || descLower.contains(t) || n.contains(descLower);
                                    });
                                  }

                                  if (matchIndex != -1) {
                                    widget.onDeletePersonalExpense!(personal[matchIndex].id);
                                  }
                                }

                                ScaffoldMessenger.of(context).clearSnackBars();
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      deletePersonalTxn
                                          ? 'Group expense & linked personal transaction deleted'
                                          : 'Expense deleted successfully from Splitwise',
                                    ),
                                  ),
                                );
                              }
                            }
                          },
                        );
                      },
                    ),
                  );
                },
              ),

              // Balances Tab
              Consumer<ExpenseProvider>(
                builder: (context, expenseProvider, child) {
                      return BalanceSummary(
                        balances: expenseProvider.balances,
                        settlements: expenseProvider.settlements,
                        memberNames: group.memberNames,
                        currentUserId: currentUserId ?? '',
                        groupId: group.id,
                        expenses: expenseProvider.expenses,
                        onAddPersonalExpense: widget.onAddPersonalExpense,
                        onAddIncomeRecord: widget.onAddIncomeRecord,
                      );
                  },
                ),
              ],
            ),
            floatingActionButton: _tabController.index == 0
                ? FloatingActionButton.extended(
                    onPressed: _showAddExpenseChoiceModal,
                    icon: const Icon(Icons.add),
                    label: const Text('Add Expense'),
                  )
                : null,
          );
        },
      );
    }

  void _showAddExpenseChoiceModal() {
    final theme = Theme.of(context);

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (modalCtx) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Text(
              'Add Group Expense',
              style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              'Choose how you want to add this expense to ${widget.group.name}:',
              style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 13),
            ),
            const SizedBox(height: 20),

            // Option 1: Create New Expense
            Card(
              elevation: 0,
              color: theme.colorScheme.primaryContainer.withValues(alpha: 0.4),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                leading: CircleAvatar(
                  backgroundColor: theme.colorScheme.primary,
                  child: const Icon(Icons.add_rounded, color: Colors.white),
                ),
                title: const Text('Create New Expense', style: TextStyle(fontWeight: FontWeight.bold)),
                subtitle: const Text('Add new & sync to personal log'),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () {
                  Navigator.pop(modalCtx);
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Colors.transparent,
                    builder: (sheetCtx) => AddExpenseSheet(
                      categories: widget.categories ?? getInitialCategories(),
                      currencySymbol: '₹',
                      onAddExpense: (newExpense) {
                        // Pass pending newExpense to AddExpenseScreen
                        // Personal transaction will ONLY be saved when Save Group Expense is confirmed!
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => AddExpenseScreen(
                              group: widget.group,
                              pendingPersonalExpense: newExpense,
                              onAddPersonalExpense: widget.onAddPersonalExpense,
                              personalExpenses: widget.personalExpenses,
                              categories: widget.categories,
                              isImported: false,
                            ),
                          ),
                        );
                      },
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 12),

            // Option 2: Import from Personal Transactions
            Card(
              elevation: 0,
              color: theme.colorScheme.surfaceContainerHigh,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                leading: CircleAvatar(
                  backgroundColor: theme.colorScheme.secondaryContainer,
                  child: Icon(Icons.receipt_long_rounded, color: theme.colorScheme.onSecondaryContainer),
                ),
                title: const Text('Import Transaction', style: TextStyle(fontWeight: FontWeight.bold)),
                subtitle: const Text('Split an existing transaction'),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () {
                  Navigator.pop(modalCtx);
                  if (widget.personalExpenses == null || widget.personalExpenses!.isEmpty) {
                    ScaffoldMessenger.of(context).clearSnackBars();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('No personal transactions available to import.')),
                    );
                    return;
                  }
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: theme.scaffoldBackgroundColor,
                    shape: const RoundedRectangleBorder(
                      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                    ),
                    builder: (importCtx) {
                      return TransactionPickerModal(
                        allExpenses: widget.personalExpenses!,
                        onSelectTransaction: (exp) {
                          Navigator.pop(importCtx);
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => AddExpenseScreen(
                                group: widget.group,
                                initialDescription: exp.title,
                                initialAmount: exp.amount,
                                onAddPersonalExpense: widget.onAddPersonalExpense,
                                personalExpenses: widget.personalExpenses,
                                categories: widget.categories,
                                isImported: true,
                              ),
                            ),
                          );
                        },
                      );
                    },
                  );
                },
              ),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}
