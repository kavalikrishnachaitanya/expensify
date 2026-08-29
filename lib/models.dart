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

class CreditCard {
  final String id;
  final String bankName;
  final String cardName;
  final String last4Digits;
  final String cardNetwork; // Visa, Mastercard, RuPay, Amex, etc.
  final double creditLimit;
  final int? billingCycleDay; // e.g. 15th of each month
  final int? paymentDueDay; // e.g. 5th of each month
  final int colorHex;
  final bool isSharedLimit;

  CreditCard({
    required this.id,
    required this.bankName,
    required this.cardName,
    required this.last4Digits,
    this.cardNetwork = 'Visa',
    this.creditLimit = 0.0,
    this.billingCycleDay,
    this.paymentDueDay,
    this.colorHex = 0xFF1E272E,
    this.isSharedLimit = true,
  });

  CreditCard copyWith({
    String? id,
    String? bankName,
    String? cardName,
    String? last4Digits,
    String? cardNetwork,
    double? creditLimit,
    int? billingCycleDay,
    int? paymentDueDay,
    int? colorHex,
    bool? isSharedLimit,
  }) {
    return CreditCard(
      id: id ?? this.id,
      bankName: bankName ?? this.bankName,
      cardName: cardName ?? this.cardName,
      last4Digits: last4Digits ?? this.last4Digits,
      cardNetwork: cardNetwork ?? this.cardNetwork,
      creditLimit: creditLimit ?? this.creditLimit,
      billingCycleDay: billingCycleDay ?? this.billingCycleDay,
      paymentDueDay: paymentDueDay ?? this.paymentDueDay,
      colorHex: colorHex ?? this.colorHex,
      isSharedLimit: isSharedLimit ?? this.isSharedLimit,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'bankName': bankName,
        'cardName': cardName,
        'last4Digits': last4Digits,
        'cardNetwork': cardNetwork,
        'creditLimit': creditLimit,
        'billingCycleDay': billingCycleDay,
        'paymentDueDay': paymentDueDay,
        'colorHex': colorHex,
        'isSharedLimit': isSharedLimit,
      };

  factory CreditCard.fromJson(Map<String, dynamic> json) => CreditCard(
        id: json['id'],
        bankName: json['bankName'] ?? '',
        cardName: json['cardName'] ?? '',
        last4Digits: json['last4Digits'] ?? '',
        cardNetwork: json['cardNetwork'] ?? 'Visa',
        creditLimit: (json['creditLimit'] as num?)?.toDouble() ?? 0.0,
        billingCycleDay: json['billingCycleDay'],
        paymentDueDay: json['paymentDueDay'],
        colorHex: json['colorHex'] ?? 0xFF1E272E,
        isSharedLimit: json['isSharedLimit'] ?? true,
      );
}

class CreditCardRepayment {
  final String id;
  final String creditCardId;
  final double amount;
  final DateTime date;
  final PaymentMethod paymentMethod;
  final String paymentSource; // e.g. "UPI / Wallet", "Salary Account"
  final String? note;

  CreditCardRepayment({
    required this.id,
    required this.creditCardId,
    required this.amount,
    required this.date,
    this.paymentMethod = PaymentMethod.upi,
    String? paymentSource,
    this.note,
  }) : paymentSource = (paymentSource != null && paymentSource.trim().isNotEmpty)
            ? paymentSource.trim()
            : paymentMethod.label;

  Map<String, dynamic> toJson() => {
        'id': id,
        'creditCardId': creditCardId,
        'amount': amount,
        'date': date.toIso8601String(),
        'paymentMethod': paymentMethod.name,
        'paymentSource': paymentSource,
        'note': note,
      };

  factory CreditCardRepayment.fromJson(Map<String, dynamic> json) {
    PaymentMethod method = PaymentMethod.upi;
    if (json['paymentMethod'] != null) {
      method = PaymentMethod.values.firstWhere(
        (m) => m.name == json['paymentMethod'],
        orElse: () => PaymentMethod.upi,
      );
    } else if (json['paymentSource'] != null) {
      final src = json['paymentSource'].toString().toLowerCase();
      if (src.contains('cash')) {
        method = PaymentMethod.cash;
      } else if (src.contains('debit')) {
        method = PaymentMethod.debitCard;
      } else if (src.contains('net') || src.contains('bank')) {
        method = PaymentMethod.netBanking;
      } else {
        method = PaymentMethod.upi;
      }
    }
    return CreditCardRepayment(
      id: json['id'],
      creditCardId: json['creditCardId'],
      amount: (json['amount'] as num).toDouble(),
      date: DateTime.parse(json['date']),
      paymentMethod: method,
      paymentSource: json['paymentSource'] ?? method.label,
      note: json['note'],
    );
  }
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
  final String? creditCardId;

  Expense({
    required this.id,
    required this.title,
    required this.amount,
    required this.date,
    required this.categoryId,
    this.paymentMethod = PaymentMethod.creditCard,
    this.note,
    this.linkedTransactionId,
    this.creditCardId,
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
    String? creditCardId,
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
      creditCardId: creditCardId ?? this.creditCardId,
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
        'creditCardId': creditCardId,
      };

  factory Expense.fromJson(Map<String, dynamic> json) => Expense(
        id: json['id'],
        title: json['title'],
        amount: (json['amount'] as num).toDouble(),
        date: DateTime.parse(json['date']),
        categoryId: json['categoryId'],
        paymentMethod: PaymentMethod.values.firstWhere(
          (e) => e.name == json['paymentMethod'],
          orElse: () => PaymentMethod.creditCard,
        ),
        note: json['note'],
        linkedTransactionId: json['linkedTransactionId'],
        creditCardId: json['creditCardId'],
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

List<ExpenseCategory> getDefaultCategories() {
  return [
    ExpenseCategory(
      id: 'cat_food',
      name: 'Food & Dining',
      icon: Icons.restaurant_rounded,
      color: const Color(0xFFFF6B6B),
    ),
    ExpenseCategory(
      id: 'cat_shopping',
      name: 'Shopping',
      icon: Icons.shopping_bag_rounded,
      color: const Color(0xFFFF9F43),
    ),
    ExpenseCategory(
      id: 'cat_bills',
      name: 'Bills & Utilities',
      icon: Icons.receipt_long_rounded,
      color: const Color(0xFF54A0FF),
    ),
    ExpenseCategory(
      id: 'cat_transport',
      name: 'Transport',
      icon: Icons.directions_car_rounded,
      color: const Color(0xFF5F27CD),
    ),
    ExpenseCategory(
      id: 'cat_entertainment',
      name: 'Entertainment',
      icon: Icons.movie_creation_rounded,
      color: const Color(0xFFFF9FF3),
    ),
    ExpenseCategory(
      id: 'cat_health',
      name: 'Health & Fitness',
      icon: Icons.favorite_rounded,
      color: const Color(0xFF1DD1A1),
    ),
    ExpenseCategory(
      id: 'cat_education',
      name: 'Education',
      icon: Icons.menu_book_rounded,
      color: const Color(0xFF48DBFB),
    ),
    ExpenseCategory(
      id: 'cat_travel',
      name: 'Travel',
      icon: Icons.flight_takeoff_rounded,
      color: const Color(0xFFFECA57),
    ),
    ExpenseCategory(
      id: 'cat_groceries',
      name: 'Groceries',
      icon: Icons.local_grocery_store_rounded,
      color: const Color(0xFF10AC84),
    ),
    ExpenseCategory(
      id: 'cat_misc',
      name: 'Miscellaneous',
      icon: Icons.widgets_rounded,
      color: const Color(0xFF8395A7),
    ),
  ];
}
