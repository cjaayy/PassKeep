import 'dart:convert';
import 'package:encrypt/encrypt.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../constants/storage_keys.dart';
import '../errors/failures.dart';
import 'encryption_result.dart';

/// Service providing Client-Side AES-256 Zero-Knowledge encryption and decryption.
///
/// Features:
/// - AES-256 in CBC Mode with PKCS7 Padding
/// - Cryptographically secure 16-byte IV generation per encryption operation
/// - In-memory session key caching and optional persistent secure storage integration
class EncryptionService {
  final FlutterSecureStorage _secureStorage;
  String? _activeKeyBase64;

  EncryptionService({FlutterSecureStorage? secureStorage})
      : _secureStorage = secureStorage ?? const FlutterSecureStorage();

  /// Returns true if an active master key is cached in-memory for this session.
  bool get hasActiveKey => _activeKeyBase64 != null && _activeKeyBase64!.isNotEmpty;

  /// Returns the current active base64 master key, if any.
  String? get activeKeyBase64 => _activeKeyBase64;

  /// Sets the active in-memory 256-bit encryption key (Base64-encoded).
  void setActiveKey(String keyBase64) {
    if (keyBase64.isEmpty) {
      throw ArgumentError('Active key cannot be empty');
    }
    _activeKeyBase64 = keyBase64;
  }

  /// Generates a cryptographically secure 16-byte random IV encoded as Base64.
  String generateRandomIv() {
    return IV.fromSecureRandom(16).base64;
  }

  /// Encrypts [plainText] using AES-256-CBC with PKCS7 padding and a 16-byte IV.
  ///
  /// Uses [customKeyBase64] if provided, otherwise falls back to the in-memory active key.
  /// Uses [customIvBase64] if provided, otherwise generates a fresh random 16-byte IV.
  /// Returns an [EncryptionResult] containing the Base64 ciphertext and Base64 IV.
  EncryptionResult encrypt(
    String plainText, {
    String? customKeyBase64,
    String? customIvBase64,
  }) {
    final keyString = customKeyBase64 ?? _activeKeyBase64;
    if (keyString == null || keyString.isEmpty) {
      throw const EncryptionFailure('No active encryption key available to perform encryption.');
    }

    if (plainText.isEmpty) {
      final iv = customIvBase64 ?? generateRandomIv();
      return EncryptionResult(
        cipherTextBase64: '',
        ivBase64: iv,
      );
    }

    try {
      final key = Key.fromBase64(keyString);
      final iv = customIvBase64 != null
          ? IV.fromBase64(customIvBase64)
          : IV.fromSecureRandom(16);
      final encrypter = Encrypter(AES(key, mode: AESMode.cbc, padding: 'PKCS7'));

      final encrypted = encrypter.encrypt(plainText, iv: iv);

      return EncryptionResult(
        cipherTextBase64: encrypted.base64,
        ivBase64: iv.base64,
      );
    } catch (e) {
      if (e is Failure) rethrow;
      throw EncryptionFailure('Encryption failed: ${e.toString()}');
    }
  }

  /// Decrypts [cipherTextBase64] using AES-256-CBC and the provided [ivBase64].
  ///
  /// Uses [customKeyBase64] if provided, otherwise falls back to the in-memory active key.
  /// Throws [DecryptionFailure] if decryption fails due to corrupted data, invalid key, or tampered payload.
  String decrypt({
    required String cipherTextBase64,
    required String ivBase64,
    String? customKeyBase64,
  }) {
    if (cipherTextBase64.isEmpty) {
      return '';
    }

    final keyString = customKeyBase64 ?? _activeKeyBase64;
    if (keyString == null || keyString.isEmpty) {
      throw const DecryptionFailure('No active encryption key available to perform decryption.');
    }

    try {
      final key = Key.fromBase64(keyString);
      final iv = IV.fromBase64(ivBase64);
      final encrypter = Encrypter(AES(key, mode: AESMode.cbc, padding: 'PKCS7'));

      final decrypted = encrypter.decrypt64(cipherTextBase64, iv: iv);

      // Validate decrypted output is clean printable UTF-8.
      // Wrong-key decryption with AES-CBC can silently produce garbled bytes
      // that pass PKCS7 unpadding (~1/256 chance). Detect this case.
      _validateDecryptedOutput(decrypted);

      return decrypted;
    } catch (e) {
      if (e is DecryptionFailure) rethrow;
      throw DecryptionFailure(
        'Decryption failed. The payload may be corrupted, tampered with, or encrypted with a different key. (${e.toString()})',
      );
    }
  }

  /// Validates that decrypted plaintext contains only printable UTF-8 characters.
  ///
  /// Detects garbled output from wrong-key decryption by checking for:
  /// - Unicode replacement character (U+FFFD) from malformed UTF-8
  /// - NUL bytes (0x00) that indicate binary garbage
  /// - Excessive non-printable ASCII control characters (0x00-0x08, 0x0E-0x1F)
  void _validateDecryptedOutput(String decrypted) {
    // Check 1: Re-encode and decode with strict UTF-8 to catch malformed sequences
    try {
      final bytes = utf8.encode(decrypted);
      final reDecoded = utf8.decode(bytes, allowMalformed: false);
      if (reDecoded.contains('\uFFFD')) {
        throw const DecryptionFailure(
          'Decryption produced malformed UTF-8. The data was likely encrypted with a different Master Key.',
        );
      }
    } catch (e) {
      if (e is DecryptionFailure) rethrow;
      throw const DecryptionFailure(
        'Decryption produced invalid UTF-8 byte sequences. Master key mismatch or corrupted payload.',
      );
    }

    // Check 2: Detect NUL bytes (strong indicator of binary garbage)
    if (decrypted.contains('\x00')) {
      throw const DecryptionFailure(
        'Decryption output contains NUL bytes. The data was likely encrypted with a different Master Key.',
      );
    }

    // Check 3: Count non-printable control characters (excluding tab, newline, carriage return)
    // Normal credentials should contain almost zero control chars.
    final controlCharCount = decrypted.codeUnits.where((c) =>
      (c >= 0x00 && c <= 0x08) || (c >= 0x0E && c <= 0x1F) || c == 0x7F
    ).length;

    // If more than 10% of characters are control chars, it's garbled
    if (decrypted.isNotEmpty && controlCharCount / decrypted.length > 0.1) {
      throw const DecryptionFailure(
        'Decryption produced non-printable characters. The data was likely encrypted with a different Master Key.',
      );
    }
  }

  /// Persists the derived master key into [FlutterSecureStorage] and caches it in-memory.
  Future<void> saveMasterKeyToStorage(String keyBase64) async {
    setActiveKey(keyBase64);
    await _secureStorage.write(
      key: StorageKeys.masterKeyStorageKey,
      value: keyBase64,
    );
  }

  /// Loads the persisted master key from [FlutterSecureStorage] and sets it active.
  Future<String?> loadMasterKeyFromStorage() async {
    final key = await _secureStorage.read(key: StorageKeys.masterKeyStorageKey);
    if (key != null && key.isNotEmpty) {
      _activeKeyBase64 = key;
    }
    return key;
  }

  /// Clears only the in-memory cached active key.
  void clearActiveKey() {
    _activeKeyBase64 = null;
  }

  /// Clears the master key from memory and deletes it from [FlutterSecureStorage].
  Future<void> clearMasterKey() async {
    clearActiveKey();
    await _secureStorage.delete(key: StorageKeys.masterKeyStorageKey);
  }
}
