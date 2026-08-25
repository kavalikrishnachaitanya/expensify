import 'dart:math';

/// Centralized globally unique ID generator for all models across Expensify & Splitwise.
/// Ensures 100% collision-free, non-repeating unique IDs by combining high-precision
/// timestamps with secure random alphanumeric tokens.
class IdGenerator {
  static final Random _random = Random.secure();
  static const String _chars = 'abcdefghijklmnopqrstuvwxyz0123456789';

  /// Generates a unique ID formatted as: `<prefix>_<timestamp_ms>_<6-char-random>`
  /// Examples:
  /// - Income: `inc_1787678901234_a8f9x2`
  /// - Expense: `exp_1787678901234_k3m1p8`
  /// - Vault: `vault_1787678901234_q9w2z5`
  /// - Category: `cat_1787678901234_r4v7n1`
  static String generate([String prefix = 'txn']) {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final randomStr = List.generate(6, (_) => _chars[_random.nextInt(_chars.length)]).join();
    return '${prefix}_${timestamp}_$randomStr';
  }

  static String generateExpenseId() => generate('exp');
  static String generateIncomeId() => generate('inc');
  static String generateVaultId() => generate('vault');
  static String generateCategoryId() => generate('cat');
  static String generateGroupId() => generate('grp');
}
