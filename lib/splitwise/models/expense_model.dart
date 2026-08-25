/// Expense model representing a single expense in a group
class ExpenseModel {
  final String id;
  final String groupId;
  final String description;
  final double amount;
  final String paidBy; // userId who paid
  final String paidByName; // display name of payer
  final String? paidByPhotoUrl; // photoUrl of payer
  final Map<String, double> splitAmong; // userId -> amount owed
  final DateTime createdAt;
  final bool isSettlement;
  final String? linkedPersonalExpenseId;

  ExpenseModel({
    required this.id,
    required this.groupId,
    required this.description,
    required this.amount,
    required this.paidBy,
    required this.paidByName,
    this.paidByPhotoUrl,
    required this.splitAmong,
    required this.createdAt,
    this.isSettlement = false,
    this.linkedPersonalExpenseId,
  });

  /// Create from Firestore document
  factory ExpenseModel.fromMap(Map<String, dynamic> map, String id) {
    return ExpenseModel(
      id: id,
      groupId: map['groupId'] ?? '',
      description: map['description'] ?? '',
      amount: (map['amount'] ?? 0).toDouble(),
      paidBy: map['paidBy'] ?? '',
      paidByName: map['paidByName'] ?? '',
      paidByPhotoUrl: map['paidByPhotoUrl'],
      splitAmong: Map<String, double>.from(
        (map['splitAmong'] ?? {}).map(
          (key, value) => MapEntry(key, (value as num).toDouble()),
        ),
      ),
      createdAt: map['createdAt']?.toDate() ?? DateTime.now(),
      isSettlement: map['isSettlement'] ?? (map['description'] == 'Settlement'),
      linkedPersonalExpenseId: map['linkedPersonalExpenseId'],
    );
  }

  /// Convert to Firestore document
  Map<String, dynamic> toMap() {
    return {
      'groupId': groupId,
      'description': description,
      'amount': amount,
      'paidBy': paidBy,
      'paidByName': paidByName,
      'paidByPhotoUrl': paidByPhotoUrl,
      'splitAmong': splitAmong,
      'createdAt': createdAt,
      'isSettlement': isSettlement,
      'linkedPersonalExpenseId': linkedPersonalExpenseId,
    };
  }

  /// Copy with method
  ExpenseModel copyWith({
    String? id,
    String? groupId,
    String? description,
    double? amount,
    String? paidBy,
    String? paidByName,
    String? paidByPhotoUrl,
    Map<String, double>? splitAmong,
    DateTime? createdAt,
    bool? isSettlement,
  }) {
    return ExpenseModel(
      id: id ?? this.id,
      groupId: groupId ?? this.groupId,
      description: description ?? this.description,
      amount: amount ?? this.amount,
      paidBy: paidBy ?? this.paidBy,
      paidByName: paidByName ?? this.paidByName,
      paidByPhotoUrl: paidByPhotoUrl ?? this.paidByPhotoUrl,
      splitAmong: splitAmong ?? this.splitAmong,
      createdAt: createdAt ?? this.createdAt,
      isSettlement: isSettlement ?? this.isSettlement,
    );
  }
}
