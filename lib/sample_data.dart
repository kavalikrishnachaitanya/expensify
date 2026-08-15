import 'package:flutter/material.dart';
import 'models.dart';

List<ExpenseCategory> getInitialCategories() {
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

List<Expense> getInitialExpenses() {
  final now = DateTime.now();
  final year = now.year;
  final month = now.month;

  return [
    Expense(
      id: 'exp_1',
      title: 'Weekly Grocery Shopping',
      amount: 142.50,
      date: DateTime(year, month, 2, 14, 30),
      categoryId: 'cat_groceries',
      paymentMethod: PaymentMethod.creditCard,
      note: 'Bought organic fruits & veggies',
    ),
    Expense(
      id: 'exp_2',
      title: 'Electricity & Water Bill',
      amount: 185.00,
      date: DateTime(year, month, 3, 10, 15),
      categoryId: 'cat_bills',
      paymentMethod: PaymentMethod.netBanking,
      note: 'Monthly utility bill',
    ),
    Expense(
      id: 'exp_3',
      title: 'Dinner at Bistro',
      amount: 68.40,
      date: DateTime(year, month, 4, 20, 00),
      categoryId: 'cat_food',
      paymentMethod: PaymentMethod.upi,
      note: 'Dinner with team',
    ),
    Expense(
      id: 'exp_4',
      title: 'Fuel Refill',
      amount: 45.00,
      date: DateTime(year, month, 5, 9, 45),
      categoryId: 'cat_transport',
      paymentMethod: PaymentMethod.creditCard,
    ),
    Expense(
      id: 'exp_5',
      title: 'New Running Shoes',
      amount: 129.99,
      date: DateTime(year, month, 6, 16, 20),
      categoryId: 'cat_shopping',
      paymentMethod: PaymentMethod.creditCard,
      note: 'Nike Air Zoom Sale',
    ),
    Expense(
      id: 'exp_6',
      title: 'Netflix & Spotify Subs',
      amount: 24.99,
      date: DateTime(year, month, 7, 8, 00),
      categoryId: 'cat_entertainment',
      paymentMethod: PaymentMethod.debitCard,
    ),
    Expense(
      id: 'exp_7',
      title: 'Pharmacy & Vitamins',
      amount: 38.20,
      date: DateTime(year, month, 8, 12, 10),
      categoryId: 'cat_health',
      paymentMethod: PaymentMethod.cash,
    ),
    Expense(
      id: 'exp_8',
      title: 'Weekend Getaway Hotel',
      amount: 320.00,
      date: DateTime(year, month, 10, 11, 00),
      categoryId: 'cat_travel',
      paymentMethod: PaymentMethod.creditCard,
      note: 'Booked resort stay',
    ),
    Expense(
      id: 'exp_9',
      title: 'Online Tech Course',
      amount: 49.99,
      date: DateTime(year, month, 12, 15, 30),
      categoryId: 'cat_education',
      paymentMethod: PaymentMethod.upi,
    ),
    Expense(
      id: 'exp_10',
      title: 'Artisan Coffee & Bakery',
      amount: 18.50,
      date: DateTime(year, month, 14, 10, 00),
      categoryId: 'cat_food',
      paymentMethod: PaymentMethod.cash,
    ),
    Expense(
      id: 'exp_11',
      title: 'High-speed Internet Bill',
      amount: 65.00,
      date: DateTime(year, month, 15, 9, 00),
      categoryId: 'cat_bills',
      paymentMethod: PaymentMethod.netBanking,
    ),
    Expense(
      id: 'exp_12',
      title: 'Supermarket Groceries',
      amount: 94.30,
      date: DateTime(year, month, 18, 17, 45),
      categoryId: 'cat_groceries',
      paymentMethod: PaymentMethod.debitCard,
    ),
  ];
}
