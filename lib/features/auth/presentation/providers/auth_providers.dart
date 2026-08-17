import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';
import '../../../../core/constants/storage_keys.dart';
import '../../../../core/security/encryption_service.dart';
import '../../../../core/security/key_derivation.dart';
import '../../../../core/security/security_providers.dart';

/// Authentication Status Lifecycle
enum AuthStatus { loading, uninitialized, locked, authenticated }

/// Immutable state for authentication and vault lock status
class AuthState {
  final AuthStatus status;
  final bool isBiometricsAvailable;
  final String? errorMessage;

  const AuthState({
    required this.status,
    this.isBiometricsAvailable = false,
    this.errorMessage,
  });

  const AuthState.initial()
      : status = AuthStatus.loading,
        isBiometricsAvailable = false,
        errorMessage = null;

  AuthState copyWith({
    AuthStatus? status,
    bool? isBiometricsAvailable,
    String? errorMessage,
  }) {
    return AuthState(
      status: status ?? this.status,
      isBiometricsAvailable: isBiometricsAvailable ?? this.isBiometricsAvailable,
      errorMessage: errorMessage,
    );
  }

  @override
  String toString() => 'AuthState(status: $status, biometrics: $isBiometricsAvailable, error: $errorMessage)';
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

  AuthNotifier({
    required FlutterSecureStorage secureStorage,
    required EncryptionService encryptionService,
    required LocalAuthentication localAuth,
  })  : _secureStorage = secureStorage,
        _encryptionService = encryptionService,
        _localAuth = localAuth,
        super(const AuthState.initial()) {
    checkAuthState();
  }

  /// Evaluates whether the app has an existing PIN configured or needs first-time setup
  Future<void> checkAuthState() async {
    state = state.copyWith(status: AuthStatus.loading, errorMessage: null);

    try {
      final salt = await _secureStorage.read(key: StorageKeys.masterPinSaltKey);
      final pinHash = await _secureStorage.read(key: StorageKeys.masterPinHashKey);

      bool biometricsAvailable = false;
      try {
        final canCheck = await _localAuth.canCheckBiometrics;
        final isSupported = await _localAuth.isDeviceSupported();
        biometricsAvailable = canCheck || isSupported;
      } catch (_) {
        biometricsAvailable = false;
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
      state = state.copyWith(
        status: AuthStatus.uninitialized,
        errorMessage: e.toString(),
      );
    }
  }

  /// First-time onboarding: derives encryption key and persists cryptographic salt + hash
  Future<bool> setupMasterPin(String pin) async {
    if (pin.length < 6) {
      state = state.copyWith(errorMessage: 'PIN must be exactly 6 digits');
      return false;
    }

    try {
      final salt = KeyDerivation.generateRandomSalt(16);
      final masterKey = KeyDerivation.deriveKey256(password: pin, salt: salt);
      final pinHash = sha256.convert(utf8.encode('$pin:$salt')).toString();

      await _secureStorage.write(key: StorageKeys.masterPinSaltKey, value: salt);
      await _secureStorage.write(key: StorageKeys.masterPinHashKey, value: pinHash);
      await _encryptionService.saveMasterKeyToStorage(masterKey);

      state = state.copyWith(
        status: AuthStatus.authenticated,
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

      final masterKey = KeyDerivation.deriveKey256(password: pin, salt: salt);
      _encryptionService.setActiveKey(masterKey);

      state = state.copyWith(
        status: AuthStatus.authenticated,
        errorMessage: null,
      );
      return true;
    } catch (e) {
      state = state.copyWith(errorMessage: 'Authentication error: ${e.toString()}');
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
          state = state.copyWith(
            status: AuthStatus.authenticated,
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

  /// Locks the vault and clears active keys from memory
  void lockVault() {
    _encryptionService.clearActiveKey();
    state = state.copyWith(status: AuthStatus.locked, errorMessage: null);
  }
}

/// Provider for [AuthNotifier]
final authNotifierProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  final secureStorage = ref.watch(secureStorageProvider);
  final encryptionService = ref.watch(encryptionServiceProvider);
  final localAuth = ref.watch(localAuthProvider);

  return AuthNotifier(
    secureStorage: secureStorage,
    encryptionService: encryptionService,
    localAuth: localAuth,
  );
});
