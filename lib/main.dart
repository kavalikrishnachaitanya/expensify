import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'models.dart';
import 'sample_data.dart';
import 'charts.dart';
import 'add_expense_sheet.dart';
import 'add_income_sheet.dart';
import 'savings_vault_view.dart';
import 'utils/id_generator.dart';
import 'dart:convert';
import 'settings_screen.dart';
import 'login_screen.dart';
import 'services/google_drive_service.dart';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'firebase_options.dart';
import 'package:provider/provider.dart';
import 'splitwise/providers/auth_provider.dart' as split_auth;
import 'splitwise/providers/group_provider.dart' as split_group;
import 'splitwise/providers/expense_provider.dart' as split_expense;
import 'splitwise/screens/home/home_screen.dart' as split_home;
import 'splitwise/screens/groups/create_group_screen.dart' as split_create_group;
import 'splitwise/screens/expenses/add_expense_screen.dart';
import 'widgets/custom_modal_dialog.dart';
import 'splitwise/services/firestore_service.dart';

bool isFirebaseInitialized = false;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    isFirebaseInitialized = true;
  } catch (e) {
    debugPrint("Firebase initialization error: $e");
    isFirebaseInitialized = false;
  }
  await dotenv.load(fileName: ".env");
  await GoogleDriveService.ensureInitialized();
  if (!kIsWeb) {
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
  }
  runApp(const ExpenditureApp());
}

class ThemeProvider with ChangeNotifier {
  bool _isDarkMode = true;
  bool get isDarkMode => _isDarkMode;

  void toggleTheme() {
    _isDarkMode = !_isDarkMode;
    notifyListeners();
  }
}

class ExpenditureApp extends StatelessWidget {
  const ExpenditureApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        if (isFirebaseInitialized) ...[
          ChangeNotifierProvider(create: (_) => split_auth.AuthProvider()),
          ChangeNotifierProvider(create: (_) => split_group.GroupProvider()),
          ChangeNotifierProvider(create: (_) => split_expense.ExpenseProvider()),
        ],
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, child) {
          return MaterialApp(
            title: 'Expenditure Calculator & Tracker',
            debugShowCheckedModeBanner: false,
            themeMode: themeProvider.isDarkMode ? ThemeMode.dark : ThemeMode.light,
            theme: ThemeData(
              useMaterial3: true,
              brightness: Brightness.light,
              colorScheme: ColorScheme.fromSeed(
                seedColor: const Color(0xFF6C5CE7),
                brightness: Brightness.light,
                surface: Colors.white,
              ),
              scaffoldBackgroundColor: const Color(0xFFF6F7FC),
              fontFamily: 'Roboto',
            ),
            darkTheme: ThemeData(
              useMaterial3: true,
              brightness: Brightness.dark,
              colorScheme: ColorScheme.fromSeed(
                seedColor: const Color(0xFF6C5CE7),
                brightness: Brightness.dark,
                surface: const Color(0xFF12141C),
              ),
              scaffoldBackgroundColor: const Color(0xFF0D0E15),
              fontFamily: 'Roboto',
            ),
            home: LoginScreen(
              isDarkMode: themeProvider.isDarkMode,
              onToggleTheme: themeProvider.toggleTheme,
            ),
          );
        },
      ),
    );
  }
}

class MainScreen extends StatefulWidget {
  final bool isDarkMode;
  final VoidCallback onToggleTheme;
  final GoogleDriveService driveService;
  final bool isGuestMode;

  const MainScreen({
    super.key,
    required this.isDarkMode,
    required this.onToggleTheme,
    required this.driveService,
    this.isGuestMode = false,
  });

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  late List<ExpenseCategory> _categories;
  late List<Expense> _expenses;

  DateTime _selectedDate = DateTime.now();
  
  // Per-month Salary / Income map: Key format 'YYYY_M' -> List of Incomes
  final Map<String, List<IncomeRecord>> _monthlyIncomeMap = {};
  
  final String _currencySymbol = '₹';
  int _selectedTabIndex = 0;
  int _chartType = 0; // 0: Donut/Pie, 1: Bar
  bool _isFabOpen = false;
  bool _showAllCategories = false;

  // Filter & Search
  String _searchQuery = '';
  String? _filterCategoryId;

  // Profile
  String _userName = 'User';

  // Savings
  double _totalSavings = 0.0;
  final List<SavingsRecord> _savingsHistory = [];
  final List<VaultGoal> _vaultGoals = [];

  void _addSavingsTransaction(double amount, SavingsTransactionType type, String note, {String? monthKey, String? sharedId}) {
    setState(() {
      _totalSavings += amount;
      _savingsHistory.insert(
        0,
        SavingsRecord(
          id: IdGenerator.generateVaultId(),
          date: DateTime.now(),
          amount: amount,
          type: type,
          note: note,
          monthKey: monthKey,
          linkedTransactionId: sharedId,
        ),
      );
    });
    _syncToDrive();
  }
  @override
  void initState() {
    super.initState();
    _categories = getInitialCategories();
    _expenses = getInitialExpenses();

    _loadFromDrive();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initSplitwiseGroups();
    });
  }

  void _initSplitwiseGroups() {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        context.read<split_group.GroupProvider>().loadUserGroups(user.uid);
      }
    } catch (e) {
      debugPrint('Error pre-loading groups in MainScreen: $e');
    }
  }

  Future<void> _loadFromDrive() async {
    final jsonStr = await widget.driveService.downloadData();
    if (jsonStr != null && jsonStr.isNotEmpty) {
      try {
        final data = jsonDecode(jsonStr);
        setState(() {
          _userName = data['userName'] ?? widget.driveService.userDisplayName ?? 'User';
          _totalSavings = (data['totalSavings'] ?? 0.0).toDouble();
          
          if (data['categories'] != null) {
            _categories.clear();
            _categories.addAll((data['categories'] as List).map((e) => ExpenseCategory.fromJson(e)));
          }
          if (data['expenses'] != null) {
            _expenses.clear();
            _expenses.addAll((data['expenses'] as List).map((e) => Expense.fromJson(e)));
          }
          if (data['savingsHistory'] != null) {
            _savingsHistory.clear();
            _savingsHistory.addAll((data['savingsHistory'] as List).map((e) => SavingsRecord.fromJson(e)));
          }
          if (data['monthlyIncomeMap'] != null) {
            _monthlyIncomeMap.clear();
            final map = data['monthlyIncomeMap'] as Map<String, dynamic>;
            map.forEach((key, value) {
              _monthlyIncomeMap[key] = (value as List).map((e) => IncomeRecord.fromJson(e)).toList();
            });
          }
          if (data['vaultGoals'] != null) {
            _vaultGoals.clear();
            _vaultGoals.addAll((data['vaultGoals'] as List).map((e) => VaultGoal.fromJson(e)));
          }
        });
      } catch (e) {
        debugPrint('Error parsing data: $e');
      }
    } else if (widget.driveService.isDriveConnected && !widget.isGuestMode) {
      // First time, user has no data in drive and no local cache. Sync initial data to drive.
      setState(() {
        _userName = widget.driveService.userDisplayName ?? 'User';
      });
      _syncToDrive();
    }
  }

  Future<void> _syncToDrive() async {
    final data = {
      'userName': _userName,
      'totalSavings': _totalSavings,
      'categories': _categories.map((c) => c.toJson()).toList(),
      'expenses': _expenses.map((e) => e.toJson()).toList(),
      'savingsHistory': _savingsHistory.map((s) => s.toJson()).toList(),
      'monthlyIncomeMap': _monthlyIncomeMap.map((key, value) => MapEntry(key, value.map((i) => i.toJson()).toList())),
      'vaultGoals': _vaultGoals.map((g) => g.toJson()).toList(),
    };
    await widget.driveService.uploadData(jsonEncode(data));
  }

  String get _currentMonthKey => '${_selectedDate.year}_${_selectedDate.month}';

  double get _currentMonthIncome {
    final records = _monthlyIncomeMap[_currentMonthKey] ?? [];
    return records.fold(0.0, (sum, record) => sum + record.amount);
  }

  void _addIncomeRecord(String sourceName, double amount, {DateTime? date, String? specificMonthKey, String? sharedId}) {
    setState(() {
      final recordDate = date ?? DateTime.now();
      final key = specificMonthKey ?? '${recordDate.year}_${recordDate.month}';
      if (!_monthlyIncomeMap.containsKey(key)) {
        _monthlyIncomeMap[key] = [];
      }
      _monthlyIncomeMap[key]!.add(
        IncomeRecord(
          id: sharedId != null ? 'inc_$sharedId' : IdGenerator.generateIncomeId(),
          sourceName: sourceName,
          amount: amount,
          date: recordDate,
          linkedTransactionId: sharedId,
        ),
      );
    });
    _syncToDrive();
  }

  void _editIncomeRecord(String id, String sourceName, double amount, {required DateTime date, String? linkedSharedId}) {
    setState(() {
      for (var list in _monthlyIncomeMap.values) {
        list.removeWhere((inc) => inc.id == id);
      }
      final key = '${date.year}_${date.month}';
      if (!_monthlyIncomeMap.containsKey(key)) {
        _monthlyIncomeMap[key] = [];
      }
      _monthlyIncomeMap[key]!.add(
        IncomeRecord(
          id: id,
          sourceName: sourceName,
          amount: amount,
          date: date,
          linkedTransactionId: linkedSharedId,
        ),
      );
    });
    _syncToDrive();
  }



  void _addExpense(Expense newExpense) {
    setState(() {
      final index = _expenses.indexWhere((e) => e.id == newExpense.id);
      if (index != -1) {
        _expenses[index] = newExpense;
      } else {
        _expenses.insert(0, newExpense);
      }
    });
    _syncToDrive();
  }

  void _deleteExpense(String id, {String? linkedSplitwiseId, String? matchDescription, double? matchAmount}) {
    setState(() {
      final initialCount = _expenses.length;
      _expenses.removeWhere((e) {
        // 1. Direct personal expense ID match
        if (id.isNotEmpty && e.id == id) return true;

        // 2. Splitwise linked ID match
        if (linkedSplitwiseId != null && linkedSplitwiseId.isNotEmpty) {
          if (e.linkedTransactionId == linkedSplitwiseId || e.id == linkedSplitwiseId) return true;
        }
        if (id.isNotEmpty && (e.linkedTransactionId == id || e.id == id)) return true;

        // 3. Fallback: match by description / title / note
        if (matchDescription != null && matchDescription.isNotEmpty) {
          String clean(String s) {
            var str = s.trim().toLowerCase();
            if (str.contains(':')) str = str.split(':').last.trim();
            return str;
          }
          final target = clean(matchDescription);
          final title = clean(e.title);
          final note = (e.note ?? '').trim().toLowerCase();
          final textMatches = target.isNotEmpty &&
              (title == target || title.contains(target) || target.contains(title) || note.contains(target));
          if (textMatches) {
            return true;
          }
        }
        return false;
      });
      debugPrint('Personal _deleteExpense called (id: "$id", linked: "$linkedSplitwiseId", desc: "$matchDescription"). Count: $initialCount -> ${_expenses.length}');
    });
    _syncToDrive();
  }

  void _deleteIncome(String id) {
    setState(() {
      String? linkedSharedId;
      for (var list in _monthlyIncomeMap.values) {
        final recordIndex = list.indexWhere((inc) => inc.id == id);
        if (recordIndex != -1) {
          linkedSharedId = list[recordIndex].linkedTransactionId;
          list.removeAt(recordIndex);
          break;
        }
      }
      
      // If this income record was linked to a vault transaction, revert the vault transaction
      if (linkedSharedId != null) {
        final savIndex = _savingsHistory.indexWhere((sav) => sav.linkedTransactionId == linkedSharedId);
        if (savIndex != -1) {
          _totalSavings -= _savingsHistory[savIndex].amount;
          _savingsHistory.removeAt(savIndex);
        }
      }
    });
    _syncToDrive();
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Income deleted')),
    );
  }

  void _deleteSavingsRecord(String id) {
    setState(() {
      final savIndex = _savingsHistory.indexWhere((sav) => sav.id == id);
      if (savIndex != -1) {
        final linkedSharedId = _savingsHistory[savIndex].linkedTransactionId;
        _totalSavings -= _savingsHistory[savIndex].amount;
        _savingsHistory.removeAt(savIndex);

        // If this savings record was linked to an income record, delete it
        if (linkedSharedId != null) {
          for (var list in _monthlyIncomeMap.values) {
            list.removeWhere((inc) => inc.linkedTransactionId == linkedSharedId);
          }
        }
      }
    });
    _syncToDrive();
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Vault transaction deleted')),
    );
  }

  Future<bool> _confirmDeleteExpense(BuildContext context, dynamic item) async {
    final theme = Theme.of(context);
    final isExpense = item is Expense;
    final isLinkedToSplitwise = isExpense && (item.linkedTransactionId != null && item.linkedTransactionId!.isNotEmpty);

    bool deleteFromSplitwise = isLinkedToSplitwise;
    final itemTitle = isExpense ? item.title : (item as IncomeRecord).sourceName;

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => CustomModalDialog(
          icon: Icons.delete_outline_rounded,
          iconColor: theme.colorScheme.error,
          iconBackgroundColor: theme.colorScheme.errorContainer,
          title: isExpense ? 'Delete Expense' : 'Delete Income',
          subtitle: 'Are you sure you want to delete "$itemTitle"?',
          content: isLinkedToSplitwise
              ? Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: CheckboxListTile(
                    value: deleteFromSplitwise,
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                    activeColor: theme.colorScheme.error,
                    dense: true,
                    title: const Text(
                      'Also delete from linked Splitwise group',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                    ),
                    onChanged: (val) {
                      setDialogState(() {
                        deleteFromSplitwise = val ?? false;
                      });
                    },
                  ),
                )
              : null,
          primaryButtonText: 'Delete',
          primaryButtonColor: theme.colorScheme.error,
          onPrimaryPressed: () => Navigator.pop(ctx, true),
        ),
      ),
    );

    if (result == true) {
      if (isExpense) {
        final expense = item;
        final splitwiseId = expense.linkedTransactionId;
        _deleteExpense(expense.id);

        if (deleteFromSplitwise && splitwiseId != null && splitwiseId.isNotEmpty) {
          try {
            await FirestoreService().deleteExpense(splitwiseId);
            if (context.mounted) {
              ScaffoldMessenger.of(context).clearSnackBars();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Expense deleted from Tracker & Splitwise group')),
              );
            }
          } catch (e) {
            debugPrint('Error deleting linked splitwise expense: $e');
          }
        }
      } else {
        _deleteIncome((item as IncomeRecord).id);
      }
      return true;
    }

    return false;
  }

  void _addVaultGoal(VaultGoal goal) {
    setState(() {
      _vaultGoals.add(goal);
    });
    _syncToDrive();
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Vault goal created')),
    );
  }

  void _deleteVaultGoal(String id) {
    setState(() {
      _vaultGoals.removeWhere((g) => g.id == id);
    });
    _syncToDrive();
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Vault goal deleted')),
    );
  }

  void _addCategory(ExpenseCategory newCategory) {
    setState(() {
      _categories.add(newCategory);
    });
    _syncToDrive();
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Category "${newCategory.name}" added')),
    );
  }

  void _deleteCategory(String id) {
    if (id == 'cat_misc') {
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cannot delete the Miscellaneous category')),
      );
      return;
    }
    setState(() {
      for (int i = 0; i < _expenses.length; i++) {
        if (_expenses[i].categoryId == id) {
          _expenses[i] = _expenses[i].copyWith(categoryId: 'cat_misc');
        }
      }
      _categories.removeWhere((c) => c.id == id);
    });
    _syncToDrive();
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Category deleted. Associated expenses moved to Miscellaneous.')),
    );
  }

  void _openAddExpenseModal({Expense? expenseToEdit}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => AddExpenseSheet(
        categories: _categories,
        currencySymbol: _currencySymbol,
        expenseToEdit: expenseToEdit,
        onAddExpense: _addExpense,
      ),
    );
  }

  void _openAddIncomeModal({IncomeRecord? incomeToEdit}) {
    final monthTitle = '${_getMonthName(_selectedDate.month)} ${_selectedDate.year}';
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => AddIncomeSheet(
        currencySymbol: _currencySymbol,
        monthTitle: monthTitle,
        initialDate: incomeToEdit?.date ?? _selectedDate,
        incomeToEdit: incomeToEdit,
        onAddIncome: (name, val, date) {
          if (incomeToEdit != null) {
            _editIncomeRecord(incomeToEdit.id, name, val, date: date, linkedSharedId: incomeToEdit.linkedTransactionId);
          } else {
            _addIncomeRecord(name, val, date: date);
          }
          final addedMonthTitle = '${_getMonthName(date.month)} ${date.year}';
          ScaffoldMessenger.of(context).clearSnackBars();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(incomeToEdit != null ? 'Income updated' : 'Income added for $addedMonthTitle')),
          );
        },
      ),
    );
  }


  void _openSettingsScreen() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (ctx) => SettingsScreen(
          userName: _userName,
          onUpdateUserName: (name) {
            setState(() {
              _userName = name;
            });
            _syncToDrive();
          },
          selectedDate: _selectedDate,
          currencySymbol: _currencySymbol,
          categories: _categories,
          expenses: _expenses,
          onAddCategory: _addCategory,
          onDeleteCategory: _deleteCategory,
          isDarkMode: Theme.of(context).brightness == Brightness.dark,
          onToggleTheme: widget.onToggleTheme,
          driveService: widget.driveService,
          isGuestMode: widget.isGuestMode,
        ),
      ),
    );
  }

  void _changeMonth(int offset) {
    setState(() {
      _selectedDate = DateTime(_selectedDate.year, _selectedDate.month + offset, 1);
    });
  }

  // Monthly Calculator Helpers
  List<Expense> get _monthlyExpenses {
    return _expenses.where((exp) {
      return exp.date.year == _selectedDate.year && exp.date.month == _selectedDate.month;
    }).toList();
  }

  double get _monthlyTotalSpent {
    return _monthlyExpenses.fold(0.0, (sum, item) => sum + item.amount);
  }

  List<CategorySpending> get _monthlyCategorySpendings {
    final total = _monthlyTotalSpent;
    if (total <= 0) return [];

    final Map<String, double> categoryAmounts = {};
    final Map<String, int> categoryCounts = {};

    for (var exp in _monthlyExpenses) {
      categoryAmounts[exp.categoryId] = (categoryAmounts[exp.categoryId] ?? 0.0) + exp.amount;
      categoryCounts[exp.categoryId] = (categoryCounts[exp.categoryId] ?? 0) + 1;
    }

    final List<CategorySpending> list = [];
    for (var entry in categoryAmounts.entries) {
      final cat = _categories.firstWhere(
        (c) => c.id == entry.key,
        orElse: () => ExpenseCategory(
          id: entry.key,
          name: 'Other',
          icon: Icons.category,
          color: Colors.grey,
        ),
      );

      final percentage = (entry.value / total) * 100;
      list.add(CategorySpending(
        category: cat,
        totalAmount: entry.value,
        percentage: percentage,
        count: categoryCounts[entry.key] ?? 1,
      ));
    }

    list.sort((a, b) => b.totalAmount.compareTo(a.totalAmount));
    return list;
  }

  Map<String, double> get _dailyBarChartData {
    final Map<String, double> dayMap = {};
    final daysCount = DateUtils.getDaysInMonth(_selectedDate.year, _selectedDate.month);

    for (int day = 1; day <= daysCount; day += 3) {
      final label = 'Day $day';
      dayMap[label] = 0.0;
    }

    for (var exp in _monthlyExpenses) {
      final dayBucket = ((exp.date.day - 1) ~/ 3) * 3 + 1;
      final label = 'Day $dayBucket';
      dayMap[label] = (dayMap[label] ?? 0.0) + exp.amount;
    }

    return dayMap;
  }

  String _getMonthName(int month) {
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    return months[month - 1];
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final monthIncome = _currentMonthIncome;
    final monthlyTotal = _monthlyTotalSpent;
    final netSavings = monthIncome - monthlyTotal;

    split_auth.AuthProvider? authProvider;
    try {
      authProvider = context.watch<split_auth.AuthProvider>();
    } catch (_) {}

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWideScreen = constraints.maxWidth >= 800;

        // ── Shared tab content pages ───────────────────────────────────────
        final List<Widget> tabPages = [
          _buildAnalyticsTab(theme, isWideScreen),
          _buildTransactionsTab(theme, isWideScreen: isWideScreen),
          SavingsVaultView(
            totalSavings: _totalSavings,
            savingsHistory: _savingsHistory,
            currencySymbol: _currencySymbol,
            onAddTransaction: (amt, type, note, {monthKey, sharedId}) =>
                _addSavingsTransaction(amt, type, note, monthKey: monthKey, sharedId: sharedId),
            netSavings: netSavings,
            currentMonthName: _getMonthName(_selectedDate.month),
            currentMonthKey: _currentMonthKey,
            onAdjustIncome: (amount, sharedId) {
              _addIncomeRecord('Vault Adjustment', amount, sharedId: sharedId);
            },
            onDeleteTransaction: _deleteSavingsRecord,
            vaultGoals: _vaultGoals,
            onAddGoal: _addVaultGoal,
            onDeleteGoal: _deleteVaultGoal,
            isWideScreen: isWideScreen,
          ),
          _buildSplitTab(),
        ];

        // ── FAB (same logic for both wide & narrow) ────────────────────────
        Widget? fab;
        if (_selectedTabIndex == 3) {
          fab = (authProvider?.isAuthenticated == true && !widget.isGuestMode)
              ? FloatingActionButton.extended(
                  heroTag: 'split_create_group_fab',
                  onPressed: () => split_create_group.showCreateGroupSheet(context),
                  backgroundColor: theme.colorScheme.primary,
                  foregroundColor: theme.colorScheme.onPrimary,
                  icon: const Icon(Icons.group_add_rounded),
                  label: const Text('New Group', style: TextStyle(fontWeight: FontWeight.bold)),
                )
              : null;
        } else {
          fab = Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (_isFabOpen) ...[
                FloatingActionButton.extended(
                  heroTag: 'income_fab',
                  onPressed: () {
                    setState(() => _isFabOpen = false);
                    _openAddIncomeModal();
                  },
                  backgroundColor: const Color(0xFF1DD1A1),
                  foregroundColor: Colors.white,
                  icon: const Icon(Icons.account_balance_wallet_rounded),
                  label: const Text('Add Income', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
                const SizedBox(height: 16),
                FloatingActionButton.extended(
                  heroTag: 'expense_fab',
                  onPressed: () {
                    setState(() => _isFabOpen = false);
                    _openAddExpenseModal();
                  },
                  backgroundColor: const Color(0xFFFF6B6B),
                  foregroundColor: Colors.white,
                  icon: const Icon(Icons.money_off_rounded),
                  label: const Text('Add Expense', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
                const SizedBox(height: 16),
              ],
              FloatingActionButton(
                heroTag: 'main_fab',
                onPressed: () => setState(() => _isFabOpen = !_isFabOpen),
                backgroundColor: theme.colorScheme.primary,
                foregroundColor: theme.colorScheme.onPrimary,
                elevation: 4,
                child: AnimatedRotation(
                  turns: _isFabOpen ? 0.125 : 0,
                  duration: const Duration(milliseconds: 200),
                  child: const Icon(Icons.add_rounded, size: 28),
                ),
              ),
            ],
          );
        }

        // ── AppBar (shared) ────────────────────────────────────────────────
        final appBar = AppBar(
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [theme.colorScheme.primary, theme.colorScheme.tertiary],
                  ),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.account_balance_wallet_rounded, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Expensify',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 19),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.settings_rounded),
              onPressed: _openSettingsScreen,
              tooltip: 'Settings',
            ),
            const SizedBox(width: 4),
          ],
        );

        // ── WIDE / WEB layout: NavigationRail sidebar ──────────────────────
        if (isWideScreen) {
          return Scaffold(
            appBar: appBar,
            floatingActionButton: fab,
            body: Row(
              children: [
                // Sidebar NavigationRail
                NavigationRail(
                  extended: constraints.maxWidth >= 1100,
                  selectedIndex: _selectedTabIndex,
                  onDestinationSelected: (idx) {
                    setState(() {
                      _selectedTabIndex = idx;
                      _isFabOpen = false;
                    });
                  },
                  backgroundColor: theme.colorScheme.surfaceContainerLow,
                  indicatorColor: theme.colorScheme.primaryContainer,
                  destinations: const [
                    NavigationRailDestination(
                      icon: Icon(Icons.pie_chart_outline_rounded),
                      selectedIcon: Icon(Icons.pie_chart_rounded),
                      label: Text('Analytics'),
                    ),
                    NavigationRailDestination(
                      icon: Icon(Icons.receipt_long_outlined),
                      selectedIcon: Icon(Icons.receipt_long_rounded),
                      label: Text('Transactions'),
                    ),
                    NavigationRailDestination(
                      icon: Icon(Icons.savings_outlined),
                      selectedIcon: Icon(Icons.savings_rounded),
                      label: Text('Vault'),
                    ),
                    NavigationRailDestination(
                      icon: Icon(Icons.group_outlined),
                      selectedIcon: Icon(Icons.group_rounded),
                      label: Text('Split'),
                    ),
                  ],
                ),
                // Vertical divider between rail and content
                VerticalDivider(thickness: 1, width: 1, color: theme.colorScheme.outlineVariant),
                // Main content area
                Expanded(
                  child: tabPages[_selectedTabIndex],
                ),
              ],
            ),
          );
        }

        // ── NARROW / MOBILE layout: bottom NavigationBar ───────────────────
        return Scaffold(
          appBar: appBar,
          floatingActionButton: fab,
          body: IndexedStack(
            index: _selectedTabIndex,
            children: tabPages,
          ),
          bottomNavigationBar: NavigationBar(
            selectedIndex: _selectedTabIndex,
            onDestinationSelected: (idx) {
              setState(() {
                _selectedTabIndex = idx;
                _isFabOpen = false;
              });
            },
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.pie_chart_outline_rounded),
                selectedIcon: Icon(Icons.pie_chart_rounded),
                label: 'Analytics',
              ),
              NavigationDestination(
                icon: Icon(Icons.receipt_long_outlined),
                selectedIcon: Icon(Icons.receipt_long_rounded),
                label: 'Transactions',
              ),
              NavigationDestination(
                icon: Icon(Icons.savings_outlined),
                selectedIcon: Icon(Icons.savings_rounded),
                label: 'Vault',
              ),
              NavigationDestination(
                icon: Icon(Icons.group_outlined),
                selectedIcon: Icon(Icons.group_rounded),
                label: 'Split',
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHeroCard(ThemeData theme, double monthlyTotal, double monthIncome, double netSavings, bool isDeficit, double dailyAvg, double progress) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            theme.colorScheme.primary,
            theme.colorScheme.tertiary,
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.primary.withAlpha(80),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.account_balance_wallet_rounded, color: Colors.white, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    'Total ${_getMonthName(_selectedDate.month)} Expenditure',
                    style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${_monthlyExpenses.length} items',
                  style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            '$_currencySymbol${monthlyTotal.toStringAsFixed(2)}',
            style: TextStyle(
              color: Colors.white,
              fontSize: 36,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
              shadows: [
                Shadow(
                  color: Colors.black.withAlpha(80),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const Divider(color: Colors.white24, height: 1),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Monthly Income', style: TextStyle(color: Colors.white70, fontSize: 11)),
                    const SizedBox(height: 2),
                    Text(
                      '$_currencySymbol${monthIncome.toStringAsFixed(2)}',
                      style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
              Container(width: 1, height: 28, color: Colors.white24),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isDeficit ? 'Deficit' : 'Net Savings',
                      style: const TextStyle(color: Colors.white70, fontSize: 11),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$_currencySymbol${netSavings.abs().toStringAsFixed(2)}',
                      style: TextStyle(
                        color: isDeficit ? const Color(0xFFFF6B6B) : Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              Container(width: 1, height: 28, color: Colors.white24),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Daily Avg', style: TextStyle(color: Colors.white70, fontSize: 11)),
                    const SizedBox(height: 2),
                    Text(
                      '$_currencySymbol${dailyAvg.toStringAsFixed(2)}',
                      style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Spent ${(progress * 100).toStringAsFixed(1)}% of Income',
                    style: const TextStyle(color: Colors.white70, fontSize: 11),
                  ),
                  Text(
                    'Salary: $_currencySymbol${monthIncome.toStringAsFixed(0)}',
                    style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 8,
                  backgroundColor: Colors.white24,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    isDeficit
                        ? const Color(0xFFFF6B6B)
                        : progress > 0.8
                            ? const Color(0xFFFF9F43)
                            : const Color(0xFF1DD1A1),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildChartSection(ThemeData theme, List<CategorySpending> categorySpendings, double monthlyTotal, bool isWideScreen) {
    if (isWideScreen) {
      return LayoutBuilder(
        builder: (context, constraints) {
          final childWidth = (constraints.maxWidth - 24) / 2;
          return IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  width: childWidth,
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHigh,
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: PieChartWidget(
                      spendings: categorySpendings,
                      currencySymbol: _currencySymbol,
                      totalAmount: monthlyTotal,
                    ),
                  ),
                ),
                const SizedBox(width: 24),
                SizedBox(
                  width: childWidth,
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHigh,
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: BarChartWidget(
                      dataPoints: _dailyBarChartData,
                      currencySymbol: _currencySymbol,
                      title: 'Monthly Spending',
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      );
    }

    return Column(
      children: [
        Center(
          child: SegmentedButton<int>(
            segments: const [
              ButtonSegment(
                value: 0,
                label: Text('Pie Chart'),
                icon: Icon(Icons.pie_chart_rounded),
              ),
              ButtonSegment(
                value: 1,
                label: Text('Bar Chart'),
                icon: Icon(Icons.bar_chart_rounded),
              ),
            ],
            selected: {_chartType},
            onSelectionChanged: (set) {
              setState(() {
                _chartType = set.first;
              });
            },
          ),
        ),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(24),
          ),
          child: _chartType == 0
              ? PieChartWidget(
                  spendings: categorySpendings,
                  currencySymbol: _currencySymbol,
                  totalAmount: monthlyTotal,
                )
              : BarChartWidget(
                  dataPoints: _dailyBarChartData,
                  currencySymbol: _currencySymbol,
                  title: 'Monthly Spending',
                ),
        ),
      ],
    );
  }

  Widget _buildAnalyticsTab(ThemeData theme, bool isWideScreen) {
    final monthlyTotal = _monthlyTotalSpent;
    final monthIncome = _currentMonthIncome;
    final netSavings = monthIncome - monthlyTotal;
    final isDeficit = netSavings < 0;
    final progress = (monthIncome > 0) ? (monthlyTotal / monthIncome).clamp(0.0, 1.0) : 0.0;

    final now = DateTime.now();
    final isCurrentMonth = _selectedDate.year == now.year && _selectedDate.month == now.month;
    final currentDay = isCurrentMonth ? now.day : DateUtils.getDaysInMonth(_selectedDate.year, _selectedDate.month);
    final dailyAvg = currentDay > 0 ? monthlyTotal / currentDay : 0.0;

    final categorySpendings = _monthlyCategorySpendings;

    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
          // Month Selector Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left_rounded),
                  onPressed: () => _changeMonth(-1),
                ),
                Text(
                  '${_getMonthName(_selectedDate.month)} ${_selectedDate.year}',
                  style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_right_rounded),
                  onPressed: () => _changeMonth(1),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          _buildHeroCard(theme, monthlyTotal, monthIncome, netSavings, isDeficit, dailyAvg, progress),
          const SizedBox(height: 24),
          _buildChartSection(theme, categorySpendings, monthlyTotal, isWideScreen),
          const SizedBox(height: 24),



          // Top Spending Categories Section
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Category Breakdown',
                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              if (categorySpendings.length > 3)
                TextButton(
                  onPressed: () {
                    setState(() {
                      _showAllCategories = !_showAllCategories;
                    });
                  },
                  child: Text(_showAllCategories ? 'Show Less' : 'See All'),
                ),
            ],
          ),
          const SizedBox(height: 8),

          if (categorySpendings.isEmpty)
            Container(
              padding: const EdgeInsets.all(24),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Text('No expenses recorded for this month.'),
            )
          else
            Column(
              children: (_showAllCategories ? categorySpendings : categorySpendings.take(3)).map((cs) {
                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: cs.category.color.withAlpha(40),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(cs.category.icon, color: cs.category.color, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    cs.category.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  '$_currencySymbol${cs.totalAmount.toStringAsFixed(2)}',
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: cs.percentage / 100,
                                minHeight: 5,
                                backgroundColor: theme.colorScheme.surfaceContainerHighest,
                                valueColor: AlwaysStoppedAnimation<Color>(cs.category.color),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),

        ],
    );

    return SingleChildScrollView(
      padding: EdgeInsets.all(isWideScreen ? 24 : 16),
      child: content,
    );
  }

  // ----------------------------------------------------
  // TAB 2: ANALYTICS & VISUALIZATIONS (PIE & BAR CHARTS)
  // ----------------------------------------------------
  void _showTransactionDetails(BuildContext context, dynamic item, ExpenseCategory category) {
    showDialog(
      context: context,
      builder: (ctx) {
        final isIncome = item is IncomeRecord;
        final title = isIncome ? item.sourceName : (item as Expense).title;
        final amount = item.amount;
        final date = item.date as DateTime;
        final note = isIncome ? null : (item as Expense).note;
        final method = isIncome ? 'Default' : (item as Expense).paymentMethod.label;

        return AlertDialog(
          title: Row(
            children: [
              Icon(category.icon, color: category.color),
              const SizedBox(width: 8),
              Expanded(child: Text(category.name)),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                Text('Amount: $_currencySymbol${amount.toStringAsFixed(2)}', style: TextStyle(color: isIncome ? const Color(0xFF1DD1A1) : const Color(0xFFFF6B6B), fontWeight: FontWeight.bold, fontSize: 18)),
                const SizedBox(height: 12),
                Text('Date: ${date.day}/${date.month}/${date.year}'),
                const SizedBox(height: 8),
                Text('Time: ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}'),
                const SizedBox(height: 8),
                Text('Payment Method: $method'),
                if (note != null && note.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  const Text('Note:', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text(note),
                ],
              ],
            ),
          ),
          actions: [
            TextButton.icon(
              onPressed: () async {
                Navigator.of(ctx).pop();
                await _confirmDeleteExpense(context, item);
              },
              icon: Icon(Icons.delete_outline_rounded, size: 16, color: Theme.of(context).colorScheme.error),
              label: Text('Delete', style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ),
            OutlinedButton.icon(
              onPressed: () {
                Navigator.of(ctx).pop();
                if (isIncome) {
                  _openAddIncomeModal(incomeToEdit: item);
                } else {
                  _openAddExpenseModal(expenseToEdit: item);
                }
              },
              icon: const Icon(Icons.edit_rounded, size: 16),
              label: const Text('Edit'),
            ),
            if (!isIncome && isFirebaseInitialized)
              FilledButton.icon(
                onPressed: () {
                  Navigator.of(ctx).pop();
                  _openSplitGroupForExpense(item as Expense);
                },
                icon: const Icon(Icons.call_split_rounded, size: 16),
                label: const Text('Split in Group'),
              ),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Close'),
            ),
          ],
        );
      }
    );
  }

  Future<void> _unlinkExpenseFromSplitwise(Expense expense) async {
    final linkedId = expense.linkedTransactionId;
    if (linkedId != null && linkedId.isNotEmpty && isFirebaseInitialized) {
      try {
        await FirestoreService().deleteExpense(linkedId);
      } catch (e) {
        debugPrint('Error deleting linked splitwise doc: $e');
      }
    }

    setState(() {
      final index = _expenses.indexWhere((e) => e.id == expense.id);
      if (index != -1) {
        _expenses[index] = expense.copyWith(linkedTransactionId: '');
      }
    });
    _syncToDrive();

    if (mounted) {
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Transaction unlinked and deleted from Splitwise group'),
        ),
      );
    }
  }

  /// Open group selection modal to redirect an existing personal transaction into Splitwise
  void _openSplitGroupForExpense(Expense expense) {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final gp = context.read<split_group.GroupProvider>();
      if (gp.groups.isEmpty) {
        gp.loadUserGroups(user.uid);
      }
    }

    final isAlreadyLinked = expense.linkedTransactionId != null && expense.linkedTransactionId!.isNotEmpty;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Consumer<split_group.GroupProvider>(
        builder: (ctx, groupProvider, _) {
          if (isAlreadyLinked) {
            return Container(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Theme.of(ctx).colorScheme.primaryContainer,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(Icons.link_rounded, color: Theme.of(ctx).colorScheme.primary, size: 20),
                          ),
                          const SizedBox(width: 12),
                          const Text(
                            'Already Linked to Group',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Theme.of(ctx).colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Theme.of(ctx).colorScheme.outlineVariant),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          expense.title,
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '$_currencySymbol${expense.amount.toStringAsFixed(2)} • ${expense.date.day}/${expense.date.month}/${expense.date.year}',
                          style: TextStyle(fontSize: 13, color: Theme.of(ctx).colorScheme.onSurfaceVariant),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            const Icon(Icons.info_outline_rounded, size: 16, color: Colors.amber),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'This transaction is already split in a Splitwise group. Unlink it below to remove it from the group. You can then split it into any other group.',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Theme.of(ctx).colorScheme.onSurfaceVariant,
                                  height: 1.3,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: () async {
                        Navigator.pop(ctx);
                        await _unlinkExpenseFromSplitwise(expense);
                      },
                      style: FilledButton.styleFrom(
                        backgroundColor: Theme.of(ctx).colorScheme.error,
                        foregroundColor: Theme.of(ctx).colorScheme.onError,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      icon: const Icon(Icons.link_off_rounded),
                      label: const Text(
                        'Unlink from Split Group',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            );
          }

          return Container(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Select Group to Split Transaction',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Splitting "${expense.title}" ($_currencySymbol${expense.amount.toStringAsFixed(2)})',
                  style: TextStyle(fontSize: 13, color: Theme.of(ctx).colorScheme.onSurfaceVariant),
                ),
                const SizedBox(height: 16),
                if (groupProvider.isLoading)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (groupProvider.groups.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Center(
                      child: Column(
                        children: [
                          Icon(
                            Icons.group_off_rounded,
                            size: 48,
                            color: Theme.of(ctx).colorScheme.outline,
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'No Splitwise groups found',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Create or join a group to start splitting bills with friends.',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 13, color: Theme.of(ctx).colorScheme.onSurfaceVariant),
                          ),
                          const SizedBox(height: 16),
                          FilledButton.icon(
                            onPressed: () {
                              Navigator.pop(ctx);
                              split_create_group.showCreateGroupSheet(context);
                            },
                            icon: const Icon(Icons.add_rounded),
                            label: const Text('Create New Group'),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  Flexible(
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: groupProvider.groups.length,
                      separatorBuilder: (_, _) => const Divider(height: 1),
                      itemBuilder: (ctx, index) {
                        final group = groupProvider.groups[index];
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: CircleAvatar(
                            backgroundColor: Theme.of(ctx).colorScheme.primaryContainer,
                            child: Icon(Icons.group_rounded, color: Theme.of(ctx).colorScheme.primary),
                          ),
                          title: Text(group.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text('${group.memberIds.length} members'),
                          trailing: const Icon(Icons.chevron_right_rounded),
                          onTap: () {
                            Navigator.pop(ctx);
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => AddExpenseScreen(
                                  group: group,
                                  initialDescription: expense.title,
                                  initialAmount: expense.amount,
                                  pendingPersonalExpense: expense,
                                  isImported: true,
                                  onAddPersonalExpense: _addExpense,
                                  personalExpenses: _expenses,
                                  categories: _categories,
                                ),
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ),
                const SizedBox(height: 12),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildTransactionsTab(ThemeData theme, {bool isWideScreen = false}) {
    final allIncomes = _monthlyIncomeMap.values.expand((e) => e).toList();

    var filteredExpenses = _expenses.where((exp) {
      final matchesQuery = exp.title.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          (exp.note?.toLowerCase().contains(_searchQuery.toLowerCase()) ?? false);
      final matchesCat = _filterCategoryId == null || exp.categoryId == _filterCategoryId;
      return matchesQuery && matchesCat;
    }).toList();

    var filteredIncomes = allIncomes.where((inc) {
      final matchesQuery = inc.sourceName.toLowerCase().contains(_searchQuery.toLowerCase());
      final matchesCat = _filterCategoryId == null || _filterCategoryId == 'cat_income';
      return matchesQuery && matchesCat;
    }).toList();

    var combinedList = [...filteredExpenses, ...filteredIncomes];
    combinedList.sort((a, b) => ((b as dynamic).date as DateTime).compareTo((a as dynamic).date as DateTime));

    final incomeCategory = ExpenseCategory(
      id: 'cat_income',
      name: 'Income',
      icon: Icons.account_balance_wallet_rounded,
      color: const Color(0xFF1DD1A1),
    );

    final searchField = TextField(
      onChanged: (val) {
        setState(() {
          _searchQuery = val;
        });
      },
      decoration: InputDecoration(
        hintText: 'Search transactions by name or note...',
        prefixIcon: const Icon(Icons.search_rounded),
        suffixIcon: _searchQuery.isNotEmpty
            ? IconButton(
                icon: const Icon(Icons.clear_rounded),
                onPressed: () {
                  setState(() {
                    _searchQuery = '';
                  });
                },
              )
            : null,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        filled: true,
        fillColor: theme.colorScheme.surfaceContainerHigh,
      ),
    );

    final contentColumn = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Category Filter Pills
          SizedBox(
            height: 36,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                FilterChip(
                  label: const Text('All'),
                  selected: _filterCategoryId == null,
                  onSelected: (selected) {
                    setState(() {
                      _filterCategoryId = null;
                    });
                  },
                ),
                const SizedBox(width: 8),
                FilterChip(
                  avatar: Icon(incomeCategory.icon, size: 14, color: _filterCategoryId == incomeCategory.id ? Colors.white : incomeCategory.color),
                  label: Text(incomeCategory.name),
                  selected: _filterCategoryId == incomeCategory.id,
                  onSelected: (selected) {
                    setState(() {
                      _filterCategoryId = selected ? incomeCategory.id : null;
                    });
                  },
                ),
                ..._categories.map((cat) {
                  final isSelected = _filterCategoryId == cat.id;
                  return Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: FilterChip(
                      avatar: Icon(cat.icon, size: 14, color: isSelected ? Colors.white : cat.color),
                      label: Text(cat.name),
                      selected: isSelected,
                      onSelected: (selected) {
                        setState(() {
                          _filterCategoryId = selected ? cat.id : null;
                        });
                      },
                    ),
                  );
                }),
              ],
            ),
          ),
          const SizedBox(height: 16),
          
          if (combinedList.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(32.0),
                child: Text(
                  'No transactions found',
                  style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
                ),
              ),
            )
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: combinedList.length,
              itemBuilder: (context, index) {
                final item = combinedList[index];
                
                if (item is Expense) {
                  final cat = _categories.firstWhere(
                    (c) => c.id == item.categoryId,
                    orElse: () => ExpenseCategory(
                      id: 'unknown',
                      name: 'General',
                      icon: Icons.receipt_rounded,
                      color: Colors.blueGrey,
                    ),
                  );

                  return Dismissible(
                    key: Key(item.id),
                    direction: DismissDirection.endToStart,
                    background: Container(
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.only(right: 20),
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: Colors.redAccent,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Icon(Icons.delete_rounded, color: Colors.white),
                    ),
                    confirmDismiss: (direction) => _confirmDeleteExpense(context, item),
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Material(
                        color: theme.colorScheme.surfaceContainerHigh,
                        borderRadius: BorderRadius.circular(16),
                        child: InkWell(
                          onTap: () => _showTransactionDetails(context, item, cat),
                          onLongPress: () => _showTransactionDetails(context, item, cat),
                          borderRadius: BorderRadius.circular(16),
                          child: Padding(
                            padding: const EdgeInsets.all(14),
                            child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: cat.color.withAlpha(40),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(cat.icon, color: cat.color, size: 22),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item.title,
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      Text(
                                        '${item.date.day}/${item.date.month}/${item.date.year}',
                                        style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant),
                                      ),
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: theme.colorScheme.surfaceContainerHighest,
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          item.paymentMethod.label,
                                          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w500),
                                        ),
                                      ),
                                    ],
                                  ),
                                  if (item.note != null && item.note!.isNotEmpty) ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      item.note!,
                                      style: TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: theme.colorScheme.onSurfaceVariant),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '-$_currencySymbol${item.amount.toStringAsFixed(2)}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  color: Color(0xFFFF6B6B),
                                ),
                              ),
                              if (isWideScreen || kIsWeb) ...[
                                const SizedBox(width: 8),
                                IconButton(
                                  icon: const Icon(Icons.edit_outlined, size: 18),
                                  tooltip: 'Edit Expense',
                                  visualDensity: VisualDensity.compact,
                                  onPressed: () => _openAddExpenseModal(expenseToEdit: item),
                                ),
                                if (isFirebaseInitialized)
                                  IconButton(
                                    icon: const Icon(Icons.call_split_rounded, size: 18),
                                    tooltip: 'Split in Group',
                                    visualDensity: VisualDensity.compact,
                                    onPressed: () => _openSplitGroupForExpense(item),
                                  ),
                                IconButton(
                                  icon: Icon(Icons.delete_outline_rounded, size: 18, color: theme.colorScheme.error),
                                  tooltip: 'Delete Expense',
                                  visualDensity: VisualDensity.compact,
                                  onPressed: () => _confirmDeleteExpense(context, item),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
                } else if (item is IncomeRecord) {
                  return Dismissible(
                    key: Key(item.id),
                    direction: DismissDirection.endToStart,
                    background: Container(
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.only(right: 20),
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: Colors.redAccent,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Icon(Icons.delete_rounded, color: Colors.white),
                    ),
                    confirmDismiss: (direction) => _confirmDeleteExpense(context, item),
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                    child: Material(
                      color: theme.colorScheme.surfaceContainerHigh,
                      borderRadius: BorderRadius.circular(16),
                      child: InkWell(
                        onTap: () => _showTransactionDetails(context, item, incomeCategory),
                        onLongPress: () => _showTransactionDetails(context, item, incomeCategory),
                        borderRadius: BorderRadius.circular(16),
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: incomeCategory.color.withAlpha(40),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(incomeCategory.icon, color: incomeCategory.color, size: 22),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item.sourceName,
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${item.date.day}/${item.date.month}/${item.date.year}',
                                  style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant),
                                ),
                              ],
                            ),
                          ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '+$_currencySymbol${item.amount.toStringAsFixed(2)}',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: incomeCategory.color,
                              ),
                            ),
                            if (isWideScreen || kIsWeb) ...[
                              const SizedBox(width: 8),
                              IconButton(
                                icon: const Icon(Icons.edit_outlined, size: 18),
                                tooltip: 'Edit Income',
                                visualDensity: VisualDensity.compact,
                                onPressed: () => _openAddIncomeModal(incomeToEdit: item),
                              ),
                              IconButton(
                                icon: Icon(Icons.delete_outline_rounded, size: 18, color: theme.colorScheme.error),
                                tooltip: 'Delete Income',
                                visualDensity: VisualDensity.compact,
                                onPressed: () => _confirmDeleteExpense(context, item),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                  ),
                ),
              ),
            );
          }
                return const SizedBox();
              },
            ),
            const SizedBox(height: 60),
          ],
    );

    if (isWideScreen) {
      return SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: searchField,
            ),
            contentColumn,
          ],
        ),
      );
    }

    return CustomScrollView(
      slivers: [
        SliverAppBar(
          floating: true,
          snap: true,
          backgroundColor: theme.colorScheme.surface,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          automaticallyImplyLeading: false,
          toolbarHeight: 80,
          title: searchField,
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: contentColumn,
          ),
        ),
      ],
    );
  }

  Widget _buildSplitTab() {
    if (!isFirebaseInitialized) {
      final theme = Theme.of(context);
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.cloud_off_rounded, size: 64, color: theme.colorScheme.primary),
              const SizedBox(height: 16),
              Text(
                'Firebase Setup Required',
                style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                'To use the Splitwise feature, please restart the app after setting up your Firebase config.',
                textAlign: TextAlign.center,
                style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
      );
    }
    return Consumer<split_auth.AuthProvider>(
      builder: (context, authProvider, child) {
        final theme = Theme.of(context);
        if (authProvider.isLoading) {
          return Center(
            child: CircularProgressIndicator(color: theme.colorScheme.primary),
          );
        }
        if (!authProvider.isAuthenticated) {
          return Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(28.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primaryContainer,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.groups_rounded,
                      size: 56,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Unlock Splitwise & Group Expenses',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Connect your Google Account to split bills with friends, track balances, and sync data securely.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontSize: 14,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 28),
                  // Feature Card
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHigh,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Column(
                      children: [
                        _buildFeatureRow(
                          context,
                          icon: Icons.group_add_rounded,
                          title: 'Group Expense Splitting',
                          subtitle: 'Split rent, dinners, and trips with friends',
                        ),
                        const Divider(height: 20),
                        _buildFeatureRow(
                          context,
                          icon: Icons.account_balance_rounded,
                          title: 'Smart Settlement Algorithm',
                          subtitle: 'Automatically minimize transactions to settle dues',
                        ),
                        const Divider(height: 20),
                        _buildFeatureRow(
                          context,
                          icon: Icons.cloud_sync_rounded,
                          title: 'Google Drive Sync',
                          subtitle: 'Automatic encrypted backup to your private Drive',
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: () async {
                        final success = await widget.driveService.signIn();
                        if (success) {
                          authProvider.signInWithGoogle();
                        }
                      },
                      icon: const Icon(Icons.login_rounded),
                      label: const Text('Sign in with Google'),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        }
        return split_home.HomeScreen(
          onAddPersonalExpense: _addExpense,
          onDeletePersonalExpense: _deleteExpense,
          onAddIncomeRecord: _addIncomeRecord,
          personalExpenses: _expenses,
          categories: _categories,
        );
      },
    );
  }

  Widget _buildFeatureRow(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: theme.colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: theme.colorScheme.primary, size: 20),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: TextStyle(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
