import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:expenses/splitwise/models/user_model.dart';
import 'package:expenses/splitwise/models/group_model.dart';
import 'package:expenses/splitwise/models/expense_model.dart';
import 'package:expenses/splitwise/utils/constants.dart';

/// Service for Firestore database operations
class FirestoreService {
  FirebaseFirestore get _firestore => FirebaseFirestore.instance;

  // ==================== USER OPERATIONS ====================

  /// Get user by ID
  Future<UserModel?> getUser(String userId) async {
    final doc = await _firestore
        .collection(FirestoreCollections.users)
        .doc(userId)
        .get();

    if (doc.exists) {
      return UserModel.fromMap(doc.data()!, doc.id);
    }
    return null;
  }

  /// Create new user
  Future<void> createUser(UserModel user) async {
    await _firestore
        .collection(FirestoreCollections.users)
        .doc(user.uid)
        .set(user.toMap());
  }

  /// Get user by email
  Future<UserModel?> getUserByEmail(String email) async {
    final query = await _firestore
        .collection(FirestoreCollections.users)
        .where('email', isEqualTo: email)
        .limit(1)
        .get();

    if (query.docs.isNotEmpty) {
      return UserModel.fromMap(query.docs.first.data(), query.docs.first.id);
    }
    return null;
  }

  /// Update user profile
  Future<void> updateUser(String userId, Map<String, dynamic> data) async {
    await _firestore
        .collection(FirestoreCollections.users)
        .doc(userId)
        .update(data);
  }

  // ==================== GROUP OPERATIONS ====================

  /// Create a new group
  Future<String> createGroup(GroupModel group) async {
    final docRef = await _firestore
        .collection(FirestoreCollections.groups)
        .add(group.toMap());
    return docRef.id;
  }

  /// Get groups for a user
  Stream<List<GroupModel>> getUserGroups(String userId) {
    return _firestore
        .collection(FirestoreCollections.groups)
        .where('memberIds', arrayContains: userId)
        .snapshots()
        .map((snapshot) {
          final groups = snapshot.docs
              .map((doc) => GroupModel.fromMap(doc.data(), doc.id))
              .toList();
          groups.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return groups;
        });
  }

  /// Get single group
  Future<GroupModel?> getGroup(String groupId) async {
    final doc = await _firestore
        .collection(FirestoreCollections.groups)
        .doc(groupId)
        .get();

    if (doc.exists) {
      return GroupModel.fromMap(doc.data()!, doc.id);
    }
    return null;
  }

  /// Get single group stream
  Stream<GroupModel?> getGroupStream(String groupId) {
    return _firestore
        .collection(FirestoreCollections.groups)
        .doc(groupId)
        .snapshots()
        .map((doc) {
      if (doc.exists) {
        return GroupModel.fromMap(doc.data()!, doc.id);
      }
      return null;
    });
  }

  /// Update group
  Future<void> updateGroup(String groupId, Map<String, dynamic> data) async {
    await _firestore
        .collection(FirestoreCollections.groups)
        .doc(groupId)
        .update(data);
  }

  /// Add member to group
  Future<void> addMemberToGroup(
    String groupId,
    String userId,
    String displayName,
  ) async {
    await _firestore.collection(FirestoreCollections.groups).doc(groupId).update({
      'memberIds': FieldValue.arrayUnion([userId]),
      'memberNames.$userId': displayName,
    });
  }

  /// Remove member from group
  Future<void> removeMemberFromGroup(String groupId, String userId) async {
    final group = await getGroup(groupId);
    if (group != null) {
      final updatedNames = Map<String, String>.from(group.memberNames);
      updatedNames.remove(userId);

      await _firestore
          .collection(FirestoreCollections.groups)
          .doc(groupId)
          .update({
        'memberIds': FieldValue.arrayRemove([userId]),
        'memberNames': updatedNames,
      });
    }
  }

  /// Delete group
  Future<void> deleteGroup(String groupId) async {
    // Delete all expenses in the group first
    final expenses = await _firestore
        .collection(FirestoreCollections.expenses)
        .where('groupId', isEqualTo: groupId)
        .get();

    for (var doc in expenses.docs) {
      await doc.reference.delete();
    }

    // Delete the group
    await _firestore
        .collection(FirestoreCollections.groups)
        .doc(groupId)
        .delete();
  }

  // ==================== EXPENSE OPERATIONS ====================

  /// Add expense
  Future<String> addExpense(ExpenseModel expense) async {
    final docRef = await _firestore
        .collection(FirestoreCollections.expenses)
        .add(expense.toMap());
    return docRef.id;
  }

  /// Get expenses for a group
  Stream<List<ExpenseModel>> getGroupExpenses(String groupId) {
    return _firestore
        .collection(FirestoreCollections.expenses)
        .where('groupId', isEqualTo: groupId)
        .snapshots()
        .map((snapshot) {
          final expenses = snapshot.docs
              .map((doc) => ExpenseModel.fromMap(doc.data(), doc.id))
              .toList();
          expenses.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return expenses;
        });
  }

  /// Get single expense
  Future<ExpenseModel?> getExpense(String expenseId) async {
    final doc = await _firestore
        .collection(FirestoreCollections.expenses)
        .doc(expenseId)
        .get();

    if (doc.exists) {
      return ExpenseModel.fromMap(doc.data()!, doc.id);
    }
    return null;
  }

  /// Update expense
  Future<void> updateExpense(
    String expenseId,
    Map<String, dynamic> data,
  ) async {
    await _firestore
        .collection(FirestoreCollections.expenses)
        .doc(expenseId)
        .update(data);
  }

  /// Delete expense
  Future<void> deleteExpense(String expenseId) async {
    await _firestore
        .collection(FirestoreCollections.expenses)
        .doc(expenseId)
        .delete();
  }

  // ==================== BALANCE CALCULATIONS ====================

  // ==================== BALANCE CALCULATIONS ====================

  /// Calculate balances from a list of expenses
  /// Returns a map of userId -> net balance (positive = owed money, negative = owes money)
  Map<String, double> calculateBalances(List<ExpenseModel> expenses) {
    final balances = <String, double>{};

    for (var expense in expenses) {
      // The person who paid gets credited
      balances[expense.paidBy] =
          (balances[expense.paidBy] ?? 0) + expense.amount;

      // Each person in the split owes their share
      expense.splitAmong.forEach((userId, amount) {
        balances[userId] = (balances[userId] ?? 0) - amount;
      });
    }

    return balances;
  }

  /// Calculate settlements from balances
  /// Returns a list of settlements needed
  List<Map<String, dynamic>> calculateSettlements(List<ExpenseModel> expenses) {
    final balances = calculateBalances(expenses);
    final settlements = <Map<String, dynamic>>[];

    // Separate debtors (negative balance) and creditors (positive balance)
    final debtors = <String, double>{};
    final creditors = <String, double>{};

    balances.forEach((userId, balance) {
      if (balance < -0.01) {
        debtors[userId] = -balance; // Make positive for easier calculation
      } else if (balance > 0.01) {
        creditors[userId] = balance;
      }
    });

    // Simple settlement algorithm
    final debtorsList = debtors.entries.toList();
    final creditorsList = creditors.entries.toList();

    int i = 0, j = 0;
    while (i < debtorsList.length && j < creditorsList.length) {
      final debtor = debtorsList[i];
      final creditor = creditorsList[j];

      final amount =
          debtor.value < creditor.value ? debtor.value : creditor.value;

      if (amount > 0.01) {
        settlements.add({
          'from': debtor.key,
          'to': creditor.key,
          'amount': amount,
        });
      }

      debtorsList[i] = MapEntry(debtor.key, debtor.value - amount);
      creditorsList[j] = MapEntry(creditor.key, creditor.value - amount);

      if (debtorsList[i].value < 0.01) i++;
      if (creditorsList[j].value < 0.01) j++;
    }

    return settlements;
  }
  // ==================== PROFILE & DELETION OPERATIONS ====================



  /// Check if user can be deleted (no outstanding dues)
  Future<bool> checkIfUserCanBeDeleted(String uid) async {
    try {
      // 1. Get all groups for user
      final groupsSnapshot = await _firestore.collection(FirestoreCollections.groups)
          .where('memberIds', arrayContains: uid)
          .get();

      if (groupsSnapshot.docs.isEmpty) return true;

      // 2. Check balance in each group
      for (final doc in groupsSnapshot.docs) {
        final groupId = doc.id;
        final expensesSnapshot = await _firestore.collection(FirestoreCollections.expenses)
            .where('groupId', isEqualTo: groupId)
            .get();

        final expenses = expensesSnapshot.docs
            .map((doc) => ExpenseModel.fromMap(doc.data(), doc.id))
            .toList();

        final balances = calculateBalances(expenses);

        // If user has ANY non-zero balance (positive or negative), return false
        if ((balances[uid] ?? 0).abs() > 0.01) { // 0.01 tolerance for float
          return false;
        }
      }
      return true;
    } catch (e) {
      // debugPrint('Error checking dues: $e');
      return false; // Fail safe
    }
  }

  /// Delete user data
  Future<void> deleteUserData(String uid) async {
    await _firestore.collection(FirestoreCollections.users).doc(uid).delete();
  }
}
