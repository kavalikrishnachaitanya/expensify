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
  return [];
}
