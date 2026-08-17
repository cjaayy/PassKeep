import 'dart:math';

/// Password Strength categories
enum PasswordStrength { weak, fair, good, strong, veryStrong }

/// Utility class generating cryptographically strong, customizable passwords.
abstract final class PasswordGenerator {
  static const String uppercaseChars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';
  static const String lowercaseChars = 'abcdefghijklmnopqrstuvwxyz';
  static const String numberChars = '0123456789';
  static const String symbolChars = '!@#\$%^&*()_+-=[]{}|;:,.<>?';

  /// Generates a random password using [Random.secure()] meeting specified constraints.
  static String generate({
    int length = 16,
    bool includeUppercase = true,
    bool includeLowercase = true,
    bool includeNumbers = true,
    bool includeSymbols = true,
  }) {
    if (!includeUppercase && !includeLowercase && !includeNumbers && !includeSymbols) {
      includeLowercase = true; // Fallback to avoid empty pool
    }

    final random = Random.secure();
    final buffer = <String>[];
    final pool = StringBuffer();

    // Ensure at least one character from each selected category
    if (includeUppercase) {
      buffer.add(uppercaseChars[random.nextInt(uppercaseChars.length)]);
      pool.write(uppercaseChars);
    }
    if (includeLowercase) {
      buffer.add(lowercaseChars[random.nextInt(lowercaseChars.length)]);
      pool.write(lowercaseChars);
    }
    if (includeNumbers) {
      buffer.add(numberChars[random.nextInt(numberChars.length)]);
      pool.write(numberChars);
    }
    if (includeSymbols) {
      buffer.add(symbolChars[random.nextInt(symbolChars.length)]);
      pool.write(symbolChars);
    }

    final poolStr = pool.toString();
    while (buffer.length < length) {
      buffer.add(poolStr[random.nextInt(poolStr.length)]);
    }

    // Cryptographic shuffle
    buffer.shuffle(random);
    return buffer.join();
  }

  /// Calculates password strength based on entropy score.
  static PasswordStrength estimateStrength(String password) {
    if (password.isEmpty) return PasswordStrength.weak;

    int poolSize = 0;
    if (password.contains(RegExp(r'[a-z]'))) poolSize += 26;
    if (password.contains(RegExp(r'[A-Z]'))) poolSize += 26;
    if (password.contains(RegExp(r'[0-9]'))) poolSize += 10;
    if (password.contains(RegExp(r'[!@#\$%^&*()_+\-=\[\]{}|;:,.<>?]'))) poolSize += 30;

    if (poolSize == 0) poolSize = 10;

    // Entropy E = L * log2(R)
    final entropy = password.length * (log(poolSize) / log(2));

    if (entropy < 35 || password.length < 8) return PasswordStrength.weak;
    if (entropy < 50) return PasswordStrength.fair;
    if (entropy < 70) return PasswordStrength.good;
    if (entropy < 90) return PasswordStrength.strong;
    return PasswordStrength.veryStrong;
  }
}
