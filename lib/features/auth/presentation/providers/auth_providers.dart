import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/constants/storage_keys.dart';
import '../../../../core/security/encryption_service.dart';
import '../../../../core/security/key_derivation.dart';
import '../../../../core/security/security_providers.dart';
import '../../../vault/data/datasources/vault_local_datasource.dart';
import '../../../vault/presentation/providers/vault_providers.dart';

/// Authentication Status Lifecycle
enum AuthStatus { loading, uninitialized, locked, authenticated }

/// Immutable state for authentication and vault lock status
class AuthState {
  final AuthStatus status;
  final bool isBiometricsAvailable;
  final String? errorMessage;
  final String? masterKey;
  final bool isOfflineOnlyMode;

  const AuthState({
    required this.status,
    this.isBiometricsAvailable = false,
    this.errorMessage,
    this.masterKey,
    this.isOfflineOnlyMode = false,
  });

  const AuthState.initial()
      : status = AuthStatus.loading,
        isBiometricsAvailable = false,
        errorMessage = null,
        masterKey = null,
        isOfflineOnlyMode = false;

  AuthState copyWith({
    AuthStatus? status,
    bool? isBiometricsAvailable,
    String? errorMessage,
    String? masterKey,
    bool? isOfflineOnlyMode,
    bool clearMasterKey = false,
  }) {
    return AuthState(
      status: status ?? this.status,
      isBiometricsAvailable: isBiometricsAvailable ?? this.isBiometricsAvailable,
      errorMessage: errorMessage,
      masterKey: clearMasterKey ? null : (masterKey ?? this.masterKey),
      isOfflineOnlyMode: isOfflineOnlyMode ?? this.isOfflineOnlyMode,
    );
  }

  @override
  String toString() =>
      'AuthState(status: $status, biometrics: $isBiometricsAvailable, offlineOnly: $isOfflineOnlyMode, error: $errorMessage)';
}

/// Provider for [LocalAuthentication] instance
final localAuthProvider = Provider<LocalAuthentication>((ref) {
  return LocalAuthentication();
});

/// StateNotifier managing master PIN setup, lock screen, and biometric authentication
class AuthNotifier extends StateNotifier<AuthState> {
  final FlutterSecureStorage _secureStorage;
  final EncryptionService _encryptionService;
  final LocalAuthentication _localAuth;
  final IVaultLocalDataSource? _localDataSource;

  AuthNotifier({
    required FlutterSecureStorage secureStorage,
    required EncryptionService encryptionService,
    required LocalAuthentication localAuth,
    IVaultLocalDataSource? localDataSource,
  })  : _secureStorage = secureStorage,
        _encryptionService = encryptionService,
        _localAuth = localAuth,
        _localDataSource = localDataSource,
        super(const AuthState.initial()) {
    checkAuthState();
  }

  /// Evaluates whether the app has an existing PIN configured or needs first-time setup
  Future<void> checkAuthState() async {
    if (state.status == AuthStatus.authenticated) return;
    state = state.copyWith(status: AuthStatus.loading, errorMessage: null);

    try {
      final salt = await _secureStorage.read(key: StorageKeys.masterPinSaltKey);
      final pinHash = await _secureStorage.read(key: StorageKeys.masterPinHashKey);

      if (state.status == AuthStatus.authenticated) return;

      bool biometricsAvailable = false;
      try {
        final canCheck = await _localAuth.canCheckBiometrics;
        final isSupported = await _localAuth.isDeviceSupported();
        biometricsAvailable = canCheck || isSupported;
      } catch (_) {
        biometricsAvailable = false;
      }

      // Guard: Do not downgrade if already authenticated in memory
      if (state.status == AuthStatus.authenticated) {
        state = state.copyWith(isBiometricsAvailable: biometricsAvailable);
        return;
      }

      if (salt == null || pinHash == null) {
        state = state.copyWith(
          status: AuthStatus.uninitialized,
          isBiometricsAvailable: biometricsAvailable,
        );
      } else {
        state = state.copyWith(
          status: AuthStatus.locked,
          isBiometricsAvailable: biometricsAvailable,
        );
      }
    } catch (e) {
      if (state.status != AuthStatus.authenticated) {
        state = state.copyWith(
          status: AuthStatus.uninitialized,
          errorMessage: e.toString(),
        );
      }
    }
  }

  /// First-time onboarding: derives encryption key and persists cryptographic salt + hash
  Future<bool> setupMasterPin(String pin) async {
    if (pin.length < 6) {
      state = state.copyWith(errorMessage: 'PIN must be exactly 6 digits');
      return false;
    }

    try {
      // 1. Check if a salt already exists in local secure storage (e.g. restored from cloud metadata)
      final existingSalt = await _secureStorage.read(key: StorageKeys.masterPinSaltKey);
      final salt = (existingSalt != null && existingSalt.isNotEmpty)
          ? existingSalt
          : KeyDerivation.generateRandomSalt(16);
      final masterKey = await KeyDerivation.deriveKey256Async(password: pin, salt: salt);
      final pinHash = sha256.convert(utf8.encode('$pin:$salt')).toString();

      await _secureStorage.write(key: StorageKeys.masterPinSaltKey, value: salt);
      await _secureStorage.write(key: StorageKeys.masterPinHashKey, value: pinHash);
      await _encryptionService.saveMasterKeyToStorage(masterKey);
      _encryptionService.setActiveKey(masterKey);

      // 2. Best effort: If user is authenticated in Supabase, update their cloud metadata with this salt
      try {
        final currentUser = Supabase.instance.client.auth.currentUser;
        if (currentUser != null) {
          final cloudSalt = currentUser.userMetadata?['master_pin_salt'] as String?;
          if (cloudSalt == null || cloudSalt.isEmpty) {
            await Supabase.instance.client.auth.updateUser(
              UserAttributes(data: {'master_pin_salt': salt}),
            );
          }
        }
      } catch (_) {
        // Ignore offline or uninitialized Supabase errors
      }

      state = state.copyWith(
        status: AuthStatus.authenticated,
        masterKey: masterKey,
        errorMessage: null,
      );
      return true;
    } catch (e) {
      state = state.copyWith(errorMessage: 'Failed to configure Master PIN: ${e.toString()}');
      return false;
    }
  }

  /// Unlocks the vault using the user's Master PIN
  Future<bool> unlockWithPin(String pin) async {
    state = state.copyWith(errorMessage: null);

    try {
      final salt = await _secureStorage.read(key: StorageKeys.masterPinSaltKey);
      final storedHash = await _secureStorage.read(key: StorageKeys.masterPinHashKey);

      if (salt == null || storedHash == null) {
        state = state.copyWith(
          status: AuthStatus.uninitialized,
          errorMessage: 'No PIN configured.',
        );
        return false;
      }

      final computedHash = sha256.convert(utf8.encode('$pin:$salt')).toString();
      if (computedHash != storedHash) {
        state = state.copyWith(errorMessage: 'Incorrect PIN. Please try again.');
        return false;
      }

      final masterKey = await KeyDerivation.deriveKey256Async(password: pin, salt: salt);
      _encryptionService.setActiveKey(masterKey);

      state = state.copyWith(
        status: AuthStatus.authenticated,
        masterKey: masterKey,
        errorMessage: null,
      );
      return true;
    } catch (e) {
      state = state.copyWith(errorMessage: 'Authentication error: ${e.toString()}');
      return false;
    }
  }

  /// Verifies if a given Master PIN is correct and ensures the active encryption key is loaded
  Future<bool> verifyMasterPin(String pin) async {
    try {
      final salt = await _secureStorage.read(key: StorageKeys.masterPinSaltKey);
      final storedHash = await _secureStorage.read(key: StorageKeys.masterPinHashKey);

      if (salt == null || storedHash == null) return false;

      final computedHash = sha256.convert(utf8.encode('$pin:$salt')).toString();
      if (computedHash != storedHash) return false;

      final masterKey = await KeyDerivation.deriveKey256Async(password: pin, salt: salt);
      _encryptionService.setActiveKey(masterKey);
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Unlocks the vault using device Biometrics (Fingerprint / Face ID)
  Future<bool> unlockWithBiometrics() async {
    state = state.copyWith(errorMessage: null);

    try {
      final authenticated = await _localAuth.authenticate(
        localizedReason: 'Authenticate to access PassKeep Vault',
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: true,
        ),
      );

      if (authenticated) {
        final masterKey = await _encryptionService.loadMasterKeyFromStorage();
        if (masterKey != null && masterKey.isNotEmpty) {
          _encryptionService.setActiveKey(masterKey);
          state = state.copyWith(
            status: AuthStatus.authenticated,
            masterKey: masterKey,
            errorMessage: null,
          );
          return true;
        } else {
          state = state.copyWith(
            errorMessage: 'Biometric key not found. Please unlock with your Master PIN.',
          );
          return false;
        }
      }
      return false;
    } catch (e) {
      state = state.copyWith(
        errorMessage: 'Biometric authentication failed: ${e.toString()}',
      );
      return false;
    }
  }

  /// Updates the user's Master PIN:
  /// 1. Verifies the [currentPin] against stored credentials.
  /// 2. Derives the old master key to decrypt any existing items.
  /// 3. Generates a new cryptographic salt and derives a new 256-bit master key.
  /// 4. Re-encrypts all local vault items with the new master key and saves them to local storage.
  /// 5. Saves the new salt, PIN hash, and master key to secure storage and activates the key.
  /// 6. Synchronizes the new salt with Supabase user metadata if connected.
  Future<bool> updateMasterPin(String currentPin, String newPin) async {
    if (newPin.length != 6) {
      state = state.copyWith(errorMessage: 'New PIN must be exactly 6 digits');
      return false;
    }

    try {
      final oldSalt = await _secureStorage.read(key: StorageKeys.masterPinSaltKey);
      final storedHash = await _secureStorage.read(key: StorageKeys.masterPinHashKey);

      if (oldSalt == null || storedHash == null) {
        state = state.copyWith(errorMessage: 'Current PIN not found.');
        return false;
      }

      final computedHash = sha256.convert(utf8.encode('$currentPin:$oldSalt')).toString();
      if (computedHash != storedHash) {
        state = state.copyWith(errorMessage: 'Current Master PIN is incorrect.');
        return false;
      }

      final oldMasterKey = await KeyDerivation.deriveKey256Async(password: currentPin, salt: oldSalt);
      final newSalt = KeyDerivation.generateRandomSalt(16);
      final newMasterKey = await KeyDerivation.deriveKey256Async(password: newPin, salt: newSalt);
      final newPinHash = sha256.convert(utf8.encode('$newPin:$newSalt')).toString();

      // Re-encrypt local vault items if data source is available
      if (_localDataSource != null) {
        final items = await _localDataSource.getAllVaultItems();
        for (final item in items) {
          String? newCardDetailsEnc;
          String newUsernameEncrypted = '';
          String newPasswordEncrypted = '';
          String? newPinEncrypted;
          final newIv = _encryptionService.generateRandomIv();

          // 1. Payment Card details
          if (item.isCard && item.cardDetailsEnc != null && item.cardDetailsEnc!.isNotEmpty) {
            try {
              final decryptedCardJson = _encryptionService.decrypt(
                cipherTextBase64: item.cardDetailsEnc!,
                ivBase64: item.iv,
                customKeyBase64: oldMasterKey,
              );
              newCardDetailsEnc = _encryptionService.encrypt(
                decryptedCardJson,
                customIvBase64: newIv,
                customKeyBase64: newMasterKey,
              ).cipherTextBase64;
            } catch (_) {
              newCardDetailsEnc = item.cardDetailsEnc;
            }
          }

          // 2. Username / Identifier
          if (item.usernameEncrypted.isNotEmpty) {
            try {
              final decryptedUser = _encryptionService.decrypt(
                cipherTextBase64: item.usernameEncrypted,
                ivBase64: item.iv,
                customKeyBase64: oldMasterKey,
              );
              newUsernameEncrypted = _encryptionService.encrypt(
                decryptedUser,
                customIvBase64: newIv,
                customKeyBase64: newMasterKey,
              ).cipherTextBase64;
            } catch (_) {
              newUsernameEncrypted = item.usernameEncrypted;
            }
          }

          // 3. Password / Card Number
          if (item.passwordEncrypted.isNotEmpty) {
            try {
              final decryptedPass = _encryptionService.decrypt(
                cipherTextBase64: item.passwordEncrypted,
                ivBase64: item.iv,
                customKeyBase64: oldMasterKey,
              );
              newPasswordEncrypted = _encryptionService.encrypt(
                decryptedPass,
                customIvBase64: newIv,
                customKeyBase64: newMasterKey,
              ).cipherTextBase64;
            } catch (_) {
              newPasswordEncrypted = item.passwordEncrypted;
            }
          }

          // 4. PIN Encrypted
          if (item.pinEncrypted != null && item.pinEncrypted!.isNotEmpty) {
            try {
              final decryptedPin = _encryptionService.decrypt(
                cipherTextBase64: item.pinEncrypted!,
                ivBase64: item.iv,
                customKeyBase64: oldMasterKey,
              );
              newPinEncrypted = _encryptionService.encrypt(
                decryptedPin,
                customIvBase64: newIv,
                customKeyBase64: newMasterKey,
              ).cipherTextBase64;
            } catch (_) {
              newPinEncrypted = item.pinEncrypted;
            }
          }

          final updatedItem = item.copyWith(
            usernameEncrypted: newUsernameEncrypted,
            passwordEncrypted: newPasswordEncrypted,
            cardDetailsEnc: newCardDetailsEnc,
            pinEncrypted: newPinEncrypted,
            iv: newIv,
            isSynced: false, // Flag for remote sync update
            updatedAt: DateTime.now(),
          );
          await _localDataSource.saveVaultItem(updatedItem);
        }
      }

      // Update secure storage with new credentials
      await _secureStorage.write(key: StorageKeys.masterPinSaltKey, value: newSalt);
      await _secureStorage.write(key: StorageKeys.masterPinHashKey, value: newPinHash);
      await _encryptionService.saveMasterKeyToStorage(newMasterKey);
      _encryptionService.setActiveKey(newMasterKey);

      // Best effort: Update Supabase metadata if connected
      try {
        final currentUser = Supabase.instance.client.auth.currentUser;
        if (currentUser != null) {
          await Supabase.instance.client.auth.updateUser(
            UserAttributes(data: {'master_pin_salt': newSalt}),
          );
        }
      } catch (_) {}

      state = state.copyWith(
        status: AuthStatus.authenticated,
        masterKey: newMasterKey,
        errorMessage: null,
      );
      return true;
    } catch (e) {
      state = state.copyWith(errorMessage: 'Failed to update Master PIN: ${e.toString()}');
      return false;
    }
  }

  /// Sets whether the user explicitly selected offline-only local storage mode
  void setOfflineOnlyMode(bool isOffline) {
    state = state.copyWith(isOfflineOnlyMode: isOffline);
  }

  /// Locks the vault and clears active keys from memory
  void lockVault() {
    _encryptionService.clearActiveKey();
    state = state.copyWith(
      status: AuthStatus.locked,
      errorMessage: null,
      clearMasterKey: true,
    );
  }
}

/// Provider for [AuthNotifier]
final authNotifierProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  final secureStorage = ref.watch(secureStorageProvider);
  final encryptionService = ref.watch(encryptionServiceProvider);
  final localAuth = ref.watch(localAuthProvider);
  final localDataSource = ref.watch(vaultLocalDataSourceProvider);

  return AuthNotifier(
    secureStorage: secureStorage,
    encryptionService: encryptionService,
    localAuth: localAuth,
    localDataSource: localDataSource,
  );
});
