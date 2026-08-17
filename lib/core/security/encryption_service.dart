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

  /// Encrypts [plainText] using AES-256-CBC with PKCS7 padding and a freshly generated 16-byte IV.
  ///
  /// Uses [customKeyBase64] if provided, otherwise falls back to the in-memory active key.
  /// Returns an [EncryptionResult] containing the Base64 ciphertext and Base64 IV.
  EncryptionResult encrypt(
    String plainText, {
    String? customKeyBase64,
  }) {
    final keyString = customKeyBase64 ?? _activeKeyBase64;
    if (keyString == null || keyString.isEmpty) {
      throw const EncryptionFailure('No active encryption key available to perform encryption.');
    }

    try {
      final key = Key.fromBase64(keyString);
      final iv = IV.fromSecureRandom(16);
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
    final keyString = customKeyBase64 ?? _activeKeyBase64;
    if (keyString == null || keyString.isEmpty) {
      throw const DecryptionFailure('No active encryption key available to perform decryption.');
    }

    try {
      final key = Key.fromBase64(keyString);
      final iv = IV.fromBase64(ivBase64);
      final encrypter = Encrypter(AES(key, mode: AESMode.cbc, padding: 'PKCS7'));

      return encrypter.decrypt64(cipherTextBase64, iv: iv);
    } catch (e) {
      throw DecryptionFailure(
        'Decryption failed. The payload may be corrupted, tampered with, or encrypted with a different key. (${e.toString()})',
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
