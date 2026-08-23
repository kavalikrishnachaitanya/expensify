import 'package:intl/intl.dart';
import 'constants.dart';

/// Helper functions for the app
class Helpers {
  /// Format amount with currency symbol
  static String formatCurrency(double amount) {
    final formatter = NumberFormat.currency(
      locale: 'en_IN',
      symbol: AppConstants.currency,
      decimalDigits: 2,
    );
    return formatter.format(amount);
  }

  /// Format date to readable string
  static String formatDate(DateTime date) {
    return DateFormat('MMM d, yyyy').format(date);
  }

  /// Format date with time
  static String formatDateTime(DateTime date) {
    return DateFormat('MMM d, yyyy • h:mm a').format(date);
  }

  /// Format relative date (Today, Yesterday, or date)
  static String formatRelativeDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final dateOnly = DateTime(date.year, date.month, date.day);

    if (dateOnly == today) {
      return 'Today';
    } else if (dateOnly == yesterday) {
      return 'Yesterday';
    } else {
      return formatDate(date);
    }
  }

  /// Calculate equal split amount
  static double calculateEqualSplit(double total, int numberOfPeople) {
    if (numberOfPeople <= 0) return 0;
    return total / numberOfPeople;
  }

  /// Get initials from name (for avatars)
  static String getInitials(String name) {
    if (name.isEmpty) return '?';
    final parts = name.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name[0].toUpperCase();
  }

  /// Validate email format
  static bool isValidEmail(String email) {
    return RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email);
  }
}
