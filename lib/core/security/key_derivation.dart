import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';

class _DeriveKeyArgs {
  final String password;
  final String salt;
  final int iterations;

  const _DeriveKeyArgs({
    required this.password,
    required this.salt,
    required this.iterations,
  });
}

String _deriveKeyWorker(_DeriveKeyArgs args) {
  return KeyDerivation.deriveKey256(
    password: args.password,
    salt: args.salt,
    iterations: args.iterations,
  );
}

/// Cryptographic Key Derivation helper using PBKDF2 with HMAC-SHA256.
abstract final class KeyDerivation {
  /// Default recommended iteration count for PBKDF2 key derivation.
  static const int defaultIterations = 100000;

  /// Asynchronously derives a 256-bit (32-byte) key on a background isolate to keep UI thread at 60fps.
  static Future<String> deriveKey256Async({
    required String password,
    required String salt,
    int iterations = defaultIterations,
  }) {
    // In test harnesses, return synchronously to prevent isolate message starvation in FakeAsync
    if (const bool.fromEnvironment('FLUTTER_TEST') || Zone.current[#test.declarer] != null) {
      return Future.value(deriveKey256(
        password: password,
        salt: salt,
        iterations: iterations,
      ));
    }

    return compute(
      _deriveKeyWorker,
      _DeriveKeyArgs(
        password: password,
        salt: salt,
        iterations: iterations,
      ),
    );
  }

  /// Derives a 256-bit (32-byte) key from [password] and [salt] using PBKDF2-HMAC-SHA256.
  ///
  /// Returns the Base64-encoded 256-bit key.
  static String deriveKey256({
    required String password,
    required String salt,
    int iterations = defaultIterations,
  }) {
    if (password.isEmpty) {
      throw ArgumentError('Password cannot be empty');
    }
    if (salt.isEmpty) {
      throw ArgumentError('Salt cannot be empty');
    }
    if (iterations < 1) {
      throw ArgumentError('Iterations must be greater than 0');
    }

    final passwordBytes = utf8.encode(password);
    final saltBytes = utf8.encode(salt);

    final keyBytes = pbkdf2HmacSha256(
      password: passwordBytes,
      salt: saltBytes,
      iterations: iterations,
      keyLength: 32,
    );

    return base64.encode(keyBytes);
  }

  /// Generates a cryptographically secure random Base64-encoded salt.
  static String generateRandomSalt([int length = 16]) {
    final random = Random.secure();
    final values = List<int>.generate(length, (_) => random.nextInt(256));
    return base64.encode(values);
  }

  /// Standard PBKDF2 algorithm (RFC 8018) using HMAC-SHA256.
  static Uint8List pbkdf2HmacSha256({
    required List<int> password,
    required List<int> salt,
    required int iterations,
    required int keyLength,
  }) {
    final hmac = Hmac(sha256, password);
    const int hLen = 32; // SHA-256 produces 32-byte digest
    final int numBlocks = (keyLength + hLen - 1) ~/ hLen;
    final derivedKey = Uint8List(numBlocks * hLen);

    for (int block = 1; block <= numBlocks; block++) {
      // U1 = PRF(Password, Salt || INT_32_BE(block))
      final initialInput = Uint8List(salt.length + 4);
      initialInput.setRange(0, salt.length, salt);
      final byteData = ByteData.sublistView(initialInput, salt.length, salt.length + 4);
      byteData.setUint32(0, block, Endian.big);

      var u = Uint8List.fromList(hmac.convert(initialInput).bytes);
      final blockResult = Uint8List.fromList(u);

      for (int i = 1; i < iterations; i++) {
        u = Uint8List.fromList(hmac.convert(u).bytes);
        for (int k = 0; k < hLen; k++) {
          blockResult[k] ^= u[k];
        }
      }

      derivedKey.setRange((block - 1) * hLen, block * hLen, blockResult);
    }

    return Uint8List.sublistView(derivedKey, 0, keyLength);
  }
}
