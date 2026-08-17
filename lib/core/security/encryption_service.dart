/// Abstract interface for Zero-Knowledge cryptographic operations
abstract class IEncryptionService {
  /// Encrypts plain text using AES-256 with a given initialization vector and key.
  String encrypt({
    required String plainText,
    required String key,
    required String iv,
  });

  /// Decrypts encrypted text using AES-256 with a given initialization vector and key.
  String decrypt({
    required String cipherText,
    required String key,
    required String iv,
  });

  /// Generates a cryptographically secure random Initialization Vector (IV).
  String generateRandomIv();

  /// Derives a 256-bit encryption key from a master password and salt using PBKDF2/Argon2.
  Future<String> deriveKey({
    required String masterPassword,
    required String salt,
  });
}
