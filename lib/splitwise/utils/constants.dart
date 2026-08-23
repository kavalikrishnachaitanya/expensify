import 'package:flutter/material.dart';

/// App-wide constants
class AppConstants {
  // App Info
  static const String appName = 'Split Expense';
  static const String appVersion = '1.0.0';

  // Currency
  static const String currency = '₹';
  static const String currencyCode = 'INR';

  // Colors - Material 3 inspired
  static const Color primaryColor = Color(0xFF5C6BC0);
  static const Color secondaryColor = Color(0xFF26A69A);
  static const Color errorColor = Color(0xFFEF5350);
  static const Color successColor = Color(0xFF66BB6A);
  static const Color warningColor = Color(0xFFFFA726);

  // Text
  static const String noExpenses = 'No expenses yet';
  static const String noGroups = 'No groups yet. Create one to get started!';
}

/// Firestore collection names
class FirestoreCollections {
  static const String users = 'users';
  static const String groups = 'groups';
  static const String expenses = 'expenses';
}
