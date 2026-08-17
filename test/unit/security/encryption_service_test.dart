import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:passkeep/core/constants/storage_keys.dart';
import 'package:passkeep/core/errors/failures.dart';
import 'package:passkeep/core/security/encryption_service.dart';
import 'package:passkeep/core/security/key_derivation.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('KeyDerivation (PBKDF2-HMAC-SHA256) Tests', () {
    const password = 'SuperSecretMasterPassword123!';
    const salt = 'random_salt_123456';

    test('should derive a 256-bit (32-byte) key as Base64 string', () {
      final derivedKeyBase64 = KeyDerivation.deriveKey256(
        password: password,
        salt: salt,
        iterations: 1000,
      );

      expect(derivedKeyBase64, isNotEmpty);
      final keyBytes = base64.decode(derivedKeyBase64);
      expect(keyBytes.length, 32); // 256 bits = 32 bytes
    });

    test('should produce deterministic output for identical password and salt', () {
      final key1 = KeyDerivation.deriveKey256(
        password: password,
        salt: salt,
        iterations: 1000,
      );
      final key2 = KeyDerivation.deriveKey256(
        password: password,
        salt: salt,
        iterations: 1000,
      );

      expect(key1, equals(key2));
    });

    test('should produce distinct keys for different salts', () {
      final key1 = KeyDerivation.deriveKey256(
        password: password,
        salt: 'salt_A_12345678',
        iterations: 1000,
      );
      final key2 = KeyDerivation.deriveKey256(
        password: password,
        salt: 'salt_B_12345678',
        iterations: 1000,
      );

      expect(key1, isNot(equals(key2)));
    });

    test('should produce distinct keys for different passwords', () {
      final key1 = KeyDerivation.deriveKey256(
        password: 'PasswordOne!',
        salt: salt,
        iterations: 1000,
      );
      final key2 = KeyDerivation.deriveKey256(
        password: 'PasswordTwo!',
        salt: salt,
        iterations: 1000,
      );

      expect(key1, isNot(equals(key2)));
    });

    test('should generate unique random salts', () {
      final salt1 = KeyDerivation.generateRandomSalt();
      final salt2 = KeyDerivation.generateRandomSalt();

      expect(salt1, isNotEmpty);
      expect(salt2, isNotEmpty);
      expect(salt1, isNot(equals(salt2)));
      expect(base64.decode(salt1).length, 16);
    });

    test('should throw ArgumentError for empty password or empty salt', () {
      expect(
        () => KeyDerivation.deriveKey256(password: '', salt: salt),
        throwsA(isA<ArgumentError>()),
      );
      expect(
        () => KeyDerivation.deriveKey256(password: password, salt: ''),
        throwsA(isA<ArgumentError>()),
      );
    });
  });

  group('EncryptionService AES-256-CBC Tests', () {
    late EncryptionService encryptionService;
    late String testKeyBase64;
    final Map<String, String> mockStorage = {};

    setUp(() {
      mockStorage.clear();

      // Mock FlutterSecureStorage platform channel
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
        (MethodCall methodCall) async {
          final args = methodCall.arguments as Map<dynamic, dynamic>?;
          final key = args?['key'] as String?;

          switch (methodCall.method) {
            case 'write':
              final value = args?['value'] as String?;
              if (key != null && value != null) {
                mockStorage[key] = value;
              }
              return null;
            case 'read':
              return key != null ? mockStorage[key] : null;
            case 'delete':
              if (key != null) {
                mockStorage.remove(key);
              }
              return null;
            case 'deleteAll':
              mockStorage.clear();
              return null;
            default:
              return null;
          }
        },
      );

      encryptionService = EncryptionService(
        secureStorage: const FlutterSecureStorage(),
      );

      testKeyBase64 = KeyDerivation.deriveKey256(
        password: 'TestMasterPassword#2026',
        salt: 'secure_test_salt_999',
        iterations: 1000,
      );
      encryptionService.setActiveKey(testKeyBase64);
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
        null,
      );
    });

    test('should encrypt plaintext producing valid ciphertext and 16-byte IV', () {
      const plainText = 'MySecretPasswordToProtect';
      final result = encryptionService.encrypt(plainText);

      expect(result.cipherTextBase64, isNotEmpty);
      expect(result.ivBase64, isNotEmpty);

      // Verify IV is 16 bytes (128-bit block size for AES)
      final ivBytes = base64.decode(result.ivBase64);
      expect(ivBytes.length, 16);
    });

    test('should generate unique IVs for consecutive encryptions of the same plaintext', () {
      const plainText = 'IdenticalSecretText';
      final result1 = encryptionService.encrypt(plainText);
      final result2 = encryptionService.encrypt(plainText);

      expect(result1.ivBase64, isNot(equals(result2.ivBase64)));
      expect(result1.cipherTextBase64, isNot(equals(result2.cipherTextBase64)));
    });

    test('should decrypt ciphertext back to original plaintext accurately', () {
      const plainText = 'SensitiveAccountPassword_999!#\$%';
      final result = encryptionService.encrypt(plainText);

      final decrypted = encryptionService.decrypt(
        cipherTextBase64: result.cipherTextBase64,
        ivBase64: result.ivBase64,
      );

      expect(decrypted, equals(plainText));
    });

    test('should support complex unicode, emojis, and multiline text payloads', () {
      const complexText = '''
🚀 Vault Secret #1234
Master Note: Contains sensitive Unicode: üñîçødë & Emojis 🔒🔑🛡️
Line 3: Special characters: `~!@#\$%^&*()_+=-{}[]:;"'<>,.?/
''';
      final result = encryptionService.encrypt(complexText);
      final decrypted = encryptionService.decrypt(
        cipherTextBase64: result.cipherTextBase64,
        ivBase64: result.ivBase64,
      );

      expect(decrypted, equals(complexText));
    });

    test('should throw DecryptionFailure on tampered/corrupted ciphertext', () {
      const plainText = 'OriginalSecret';
      final result = encryptionService.encrypt(plainText);

      // Corrupt the ciphertext
      final corruptedCipherBytes = base64.decode(result.cipherTextBase64);
      corruptedCipherBytes[0] ^= 0xFF; // Flip bits
      final corruptedCipherBase64 = base64.encode(corruptedCipherBytes);

      expect(
        () => encryptionService.decrypt(
          cipherTextBase64: corruptedCipherBase64,
          ivBase64: result.ivBase64,
        ),
        throwsA(isA<DecryptionFailure>()),
      );
    });

    test('should throw DecryptionFailure on malformed/invalid IV', () {
      const plainText = 'SecretPayload';
      final result = encryptionService.encrypt(plainText);

      // Malformed Base64 / wrong length IV
      const malformedIv = 'invalid_iv_base64_not_16_bytes!!!';

      expect(
        () => encryptionService.decrypt(
          cipherTextBase64: result.cipherTextBase64,
          ivBase64: malformedIv,
        ),
        throwsA(isA<DecryptionFailure>()),
      );
    });

    test('should fail or produce corrupted output when decrypted with a mismatched IV', () {
      const plainText = 'SecretPayload';
      final result = encryptionService.encrypt(plainText);

      final differentIv = KeyDerivation.generateRandomSalt(16);
      try {
        final decrypted = encryptionService.decrypt(
          cipherTextBase64: result.cipherTextBase64,
          ivBase64: differentIv,
        );
        expect(decrypted, isNot(equals(plainText)));
      } on DecryptionFailure {
        // Successfully caught decryption/padding failure
        expect(true, isTrue);
      }
    });

    test('should throw DecryptionFailure when decrypted with a different key', () {
      const plainText = 'SecretPayloadWithKeyA';
      final result = encryptionService.encrypt(plainText);

      final wrongKeyBase64 = KeyDerivation.deriveKey256(
        password: 'CompletelyDifferentPassword',
        salt: 'other_salt_999',
        iterations: 1000,
      );

      expect(
        () => encryptionService.decrypt(
          cipherTextBase64: result.cipherTextBase64,
          ivBase64: result.ivBase64,
          customKeyBase64: wrongKeyBase64,
        ),
        throwsA(isA<DecryptionFailure>()),
      );
    });

    test('should throw EncryptionFailure if no active key is provided', () {
      final uninitializedService = EncryptionService();

      expect(
        () => uninitializedService.encrypt('Some text'),
        throwsA(isA<EncryptionFailure>()),
      );
    });

    test('should throw DecryptionFailure if no active key is provided', () {
      final uninitializedService = EncryptionService();

      expect(
        () => uninitializedService.decrypt(
          cipherTextBase64: 'abc==',
          ivBase64: 'def==',
        ),
        throwsA(isA<DecryptionFailure>()),
      );
    });

    test('should save, load, and clear master key in FlutterSecureStorage', () async {
      await encryptionService.saveMasterKeyToStorage(testKeyBase64);
      expect(mockStorage[StorageKeys.masterKeyStorageKey], testKeyBase64);

      // Clear memory key
      encryptionService.clearActiveKey();
      expect(encryptionService.hasActiveKey, isFalse);

      // Load from storage
      final loadedKey = await encryptionService.loadMasterKeyFromStorage();
      expect(loadedKey, testKeyBase64);
      expect(encryptionService.hasActiveKey, isTrue);

      // Clear entire master key (memory + storage)
      await encryptionService.clearMasterKey();
      expect(encryptionService.hasActiveKey, isFalse);
      expect(mockStorage.containsKey(StorageKeys.masterKeyStorageKey), isFalse);
    });
  });
}
