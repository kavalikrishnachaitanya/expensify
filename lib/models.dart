import 'package:flutter/material.dart';

enum PaymentMethod {
  cash('Cash', Icons.payments_outlined),
  creditCard('Credit Card', Icons.credit_card),
  debitCard('Debit Card', Icons.account_balance_wallet_outlined),
  upi('UPI / Wallet', Icons.qr_code_scanner),
  netBanking('Net Banking', Icons.account_balance);

  final String label;
  final IconData icon;
  const PaymentMethod(this.label, this.icon);
}

class IncomeRecord {
  final String id;
  final String sourceName;
  final double amount;
  final DateTime date;
  final String? linkedTransactionId;
  
  IncomeRecord({
    required this.id,
    required this.sourceName,
    required this.amount,
    required this.date,
    this.linkedTransactionId,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'sourceName': sourceName,
        'amount': amount,
        'date': date.toIso8601String(),
        'linkedTransactionId': linkedTransactionId,
      };

  factory IncomeRecord.fromJson(Map<String, dynamic> json) => IncomeRecord(
        id: json['id'],
        sourceName: json['sourceName'],
        amount: (json['amount'] as num).toDouble(),
        date: DateTime.parse(json['date']),
        linkedTransactionId: json['linkedTransactionId'],
      );
}

class ExpenseCategory {
  final String id;
  final String name;
  final IconData icon;
  final Color color;

  ExpenseCategory({
    required this.id,
    required this.name,
    required this.icon,
    required this.color,
  });

  ExpenseCategory copyWith({
    String? id,
    String? name,
    IconData? icon,
    Color? color,
  }) {
    return ExpenseCategory(
      id: id ?? this.id,
      name: name ?? this.name,
      icon: icon ?? this.icon,
      color: color ?? this.color,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'icon': icon.codePoint,
        // ignore: deprecated_member_use
        'color': color.value,
      };

  factory ExpenseCategory.fromJson(Map<String, dynamic> json) => ExpenseCategory(
        id: json['id'],
        name: json['name'],
        // ignore: non_const_argument_for_const_parameter
        icon: IconData(json['icon'], fontFamily: 'MaterialIcons'),
        color: Color(json['color']),
      );
}

enum SavingsTransactionType {
  manualDeposit('Manual Deposit', Icons.add_circle_outline),
  manualWithdrawal('Manual Withdrawal', Icons.remove_circle_outline),
  surplusMove('Surplus Moved to Savings', Icons.trending_up),
  deficitCover('Covered Deficit from Savings', Icons.trending_down);

  final String label;
  final IconData icon;
  const SavingsTransactionType(this.label, this.icon);
}

class SavingsRecord {
  final String id;
  final DateTime date;
  final double amount; // Positive for deposit, negative for withdrawal
  final SavingsTransactionType type;
  final String? monthKey; // e.g. "2026_8" for surplus/deficit linking
  final String? note;
  final String? linkedTransactionId; // Links to IncomeRecord id for budget balancing

  SavingsRecord({
    required this.id,
    required this.date,
    required this.amount,
    required this.type,
    this.monthKey,
    this.note,
    this.linkedTransactionId,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'date': date.toIso8601String(),
        'amount': amount,
        'type': type.name,
        'monthKey': monthKey,
        'note': note,
        'linkedTransactionId': linkedTransactionId,
      };

  factory SavingsRecord.fromJson(Map<String, dynamic> json) => SavingsRecord(
        id: json['id'],
        date: DateTime.parse(json['date']),
        amount: (json['amount'] as num).toDouble(),
        type: SavingsTransactionType.values.firstWhere((e) => e.name == json['type']),
        monthKey: json['monthKey'],
        note: json['note'],
        linkedTransactionId: json['linkedTransactionId'],
      );
}

class Expense {
  final String id;
  final String title;
  final double amount;
  final DateTime date;
  final String categoryId;
  final PaymentMethod paymentMethod;
  final String? note;
  final String? linkedTransactionId;

  Expense({
    required this.id,
    required this.title,
    required this.amount,
    required this.date,
    required this.categoryId,
    this.paymentMethod = PaymentMethod.creditCard,
    this.note,
    this.linkedTransactionId,
  });

  Expense copyWith({
    String? id,
    String? title,
    double? amount,
    DateTime? date,
    String? categoryId,
    PaymentMethod? paymentMethod,
    String? note,
    String? linkedTransactionId,
  }) {
    return Expense(
      id: id ?? this.id,
      title: title ?? this.title,
      amount: amount ?? this.amount,
      date: date ?? this.date,
      categoryId: categoryId ?? this.categoryId,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      note: note ?? this.note,
      linkedTransactionId: linkedTransactionId ?? this.linkedTransactionId,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'amount': amount,
        'date': date.toIso8601String(),
        'categoryId': categoryId,
        'paymentMethod': paymentMethod.name,
        'note': note,
        'linkedTransactionId': linkedTransactionId,
      };

  factory Expense.fromJson(Map<String, dynamic> json) => Expense(
        id: json['id'],
        title: json['title'],
        amount: (json['amount'] as num).toDouble(),
        date: DateTime.parse(json['date']),
        categoryId: json['categoryId'],
        paymentMethod: PaymentMethod.values.firstWhere((e) => e.name == json['paymentMethod']),
        note: json['note'],
        linkedTransactionId: json['linkedTransactionId'],
      );
}

class CategorySpending {
  final ExpenseCategory category;
  final double totalAmount;
  final double percentage;
  final int count;

  CategorySpending({
    required this.category,
    required this.totalAmount,
    required this.percentage,
    required this.count,
  });
}

class VaultGoal {
  final String id;
  final String name;
  final double targetAmount;
  final IconData icon;
  final Color color;

  VaultGoal({
    required this.id,
    required this.name,
    required this.targetAmount,
    required this.icon,
    required this.color,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'targetAmount': targetAmount,
        'icon': icon.codePoint,
        'color': color.toARGB32(),
      };

  factory VaultGoal.fromJson(Map<String, dynamic> json) => VaultGoal(
        id: json['id'],
        name: json['name'],
        targetAmount: (json['targetAmount'] as num).toDouble(),
        // ignore: non_const_argument_for_const_parameter
        icon: IconData(json['icon'], fontFamily: 'MaterialIcons'),
        color: Color(json['color']),
      );
}
