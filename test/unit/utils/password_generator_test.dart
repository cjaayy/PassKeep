import 'package:flutter_test/flutter_test.dart';
import 'package:passkeep/core/utils/password_generator.dart';

void main() {
  group('PasswordGenerator Tests', () {
    test('should generate password of specified length', () {
      final pwd8 = PasswordGenerator.generate(length: 8);
      expect(pwd8.length, 8);

      final pwd32 = PasswordGenerator.generate(length: 32);
      expect(pwd32.length, 32);
    });

    test('should respect character set toggles', () {
      // Numbers only
      final numbersOnly = PasswordGenerator.generate(
        length: 20,
        includeUppercase: false,
        includeLowercase: false,
        includeNumbers: true,
        includeSymbols: false,
      );
      expect(RegExp(r'^[0-9]+$').hasMatch(numbersOnly), isTrue);

      // Uppercase + Lowercase only
      final lettersOnly = PasswordGenerator.generate(
        length: 20,
        includeUppercase: true,
        includeLowercase: true,
        includeNumbers: false,
        includeSymbols: false,
      );
      expect(RegExp(r'^[a-zA-Z]+$').hasMatch(lettersOnly), isTrue);
    });

    test('should estimate password strength accurately', () {
      expect(PasswordGenerator.estimateStrength(''), PasswordStrength.weak);
      expect(PasswordGenerator.estimateStrength('12345'), PasswordStrength.weak);
      expect(PasswordGenerator.estimateStrength('pass123'), PasswordStrength.weak);
      expect(PasswordGenerator.estimateStrength('password123'), PasswordStrength.good);
      expect(PasswordGenerator.estimateStrength('PassKeep2026'), PasswordStrength.strong);
      expect(PasswordGenerator.estimateStrength('K8#mQ9!vL2@zX7\$pW1~R4'), PasswordStrength.veryStrong);
    });
  });
}
