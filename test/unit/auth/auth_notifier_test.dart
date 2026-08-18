import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:local_auth/local_auth.dart';
import 'package:passkeep/core/constants/storage_keys.dart';
import 'package:passkeep/core/security/encryption_service.dart';
import 'package:passkeep/features/auth/presentation/providers/auth_providers.dart';

class FakeSecureStorage extends Fake implements FlutterSecureStorage {
  final Map<String, String> _storage = {};

  @override
  Future<String?> read({
    required String key,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    return _storage[key];
  }

  @override
  Future<void> write({
    required String key,
    required String? value,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    if (value != null) {
      _storage[key] = value;
    } else {
      _storage.remove(key);
    }
  }

  @override
  Future<void> delete({
    required String key,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    _storage.remove(key);
  }
}

class FakeLocalAuth extends Fake implements LocalAuthentication {
  bool authenticateResult = true;

  @override
  Future<bool> get canCheckBiometrics async => true;

  @override
  Future<bool> isDeviceSupported() async => true;

  @override
  Future<bool> authenticate({
    required String localizedReason,
    dynamic authMessages,
    AuthenticationOptions options = const AuthenticationOptions(),
  }) async {
    return authenticateResult;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeSecureStorage fakeStorage;
  late EncryptionService encryptionService;
  late FakeLocalAuth fakeLocalAuth;
  late AuthNotifier authNotifier;

  setUp(() {
    fakeStorage = FakeSecureStorage();
    encryptionService = EncryptionService(secureStorage: fakeStorage);
    fakeLocalAuth = FakeLocalAuth();

    authNotifier = AuthNotifier(
      secureStorage: fakeStorage,
      encryptionService: encryptionService,
      localAuth: fakeLocalAuth,
    );
  });

  group('AuthNotifier Authentication Tests', () {
    test('initial check with empty storage should transition to uninitialized status', () async {
      await authNotifier.checkAuthState();
      expect(authNotifier.state.status, AuthStatus.uninitialized);
    });

    test('setupMasterPin should derive key, save salt/hash, and authenticate', () async {
      final result = await authNotifier.setupMasterPin('123456');
      expect(result, isTrue);
      expect(authNotifier.state.status, AuthStatus.authenticated);

      final salt = await fakeStorage.read(key: StorageKeys.masterPinSaltKey);
      final hash = await fakeStorage.read(key: StorageKeys.masterPinHashKey);
      expect(salt, isNotNull);
      expect(hash, isNotNull);
    });

    test('setupMasterPin with less than 6 digits should fail', () async {
      final result = await authNotifier.setupMasterPin('1234');
      expect(result, isFalse);
      expect(authNotifier.state.errorMessage, contains('exactly 6 digits'));
    });

    test('unlockWithPin with correct PIN should authenticate', () async {
      await authNotifier.setupMasterPin('987654');
      authNotifier.lockVault();
      expect(authNotifier.state.status, AuthStatus.locked);

      final success = await authNotifier.unlockWithPin('987654');
      expect(success, isTrue);
      expect(authNotifier.state.status, AuthStatus.authenticated);
    });

    test('unlockWithPin with incorrect PIN should return false and set error message', () async {
      await authNotifier.setupMasterPin('987654');
      authNotifier.lockVault();

      final success = await authNotifier.unlockWithPin('000000');
      expect(success, isFalse);
      expect(authNotifier.state.errorMessage, contains('Incorrect PIN'));
    });

    test('setupMasterPin reuses existing cloud salt if present in storage', () async {
      const existingCloudSalt = 'cloud_restored_salt_999';
      await fakeStorage.write(
        key: StorageKeys.masterPinSaltKey,
        value: existingCloudSalt,
      );

      final result = await authNotifier.setupMasterPin('654321');
      expect(result, isTrue);

      final storedSalt = await fakeStorage.read(key: StorageKeys.masterPinSaltKey);
      expect(storedSalt, existingCloudSalt);
    });

    test('lockVault should clear active encryption key and lock state', () async {
      await authNotifier.setupMasterPin('112233');
      expect(authNotifier.state.status, AuthStatus.authenticated);

      authNotifier.lockVault();
      expect(authNotifier.state.status, AuthStatus.locked);
    });
  });
}
