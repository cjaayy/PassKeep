import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:local_auth/local_auth.dart';
import 'package:passkeep/core/constants/storage_keys.dart';
import 'package:passkeep/core/security/encryption_service.dart';
import 'package:passkeep/features/auth/presentation/providers/auth_providers.dart';
import 'package:passkeep/features/vault/data/datasources/vault_local_datasource.dart';
import 'package:passkeep/features/vault/data/models/vault_item.dart';

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

class FakeAuthLocalDataSource implements IVaultLocalDataSource {
  final List<VaultItem> items = [];

  @override
  Future<List<VaultItem>> getAllVaultItems() async => List.from(items);

  @override
  Future<VaultItem?> getVaultItemById(String id) async =>
      items.firstWhere((i) => i.id == id);

  @override
  Future<void> saveVaultItem(VaultItem item) async {
    final index = items.indexWhere((i) => i.id == item.id);
    if (index != -1) {
      items[index] = item;
    } else {
      items.add(item);
    }
  }

  @override
  Future<void> deleteVaultItem(String id) async => items.removeWhere((i) => i.id == id);

  @override
  Future<void> clearAll() async => items.clear();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeSecureStorage fakeStorage;
  late EncryptionService encryptionService;
  late FakeLocalAuth fakeLocalAuth;
  late FakeAuthLocalDataSource fakeLocalDataSource;
  late AuthNotifier authNotifier;

  setUp(() {
    fakeStorage = FakeSecureStorage();
    encryptionService = EncryptionService(secureStorage: fakeStorage);
    fakeLocalAuth = FakeLocalAuth();
    fakeLocalDataSource = FakeAuthLocalDataSource();

    authNotifier = AuthNotifier(
      secureStorage: fakeStorage,
      encryptionService: encryptionService,
      localAuth: fakeLocalAuth,
      localDataSource: fakeLocalDataSource,
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

    test('verifyMasterPin validates correct and incorrect PINs accurately', () async {
      await authNotifier.setupMasterPin('123456');

      expect(await authNotifier.verifyMasterPin('123456'), isTrue);
      expect(await authNotifier.verifyMasterPin('654321'), isFalse);
      expect(await authNotifier.verifyMasterPin('000000'), isFalse);
    });

    test('updateMasterPin successfully re-encrypts vault items and updates salt/hash', () async {
      // 1. Initial setup with PIN 111111
      await authNotifier.setupMasterPin('111111');
      final initialSalt = await fakeStorage.read(key: StorageKeys.masterPinSaltKey);
      final initialHash = await fakeStorage.read(key: StorageKeys.masterPinHashKey);

      // Create an item encrypted with initial key
      final initialIv = encryptionService.generateRandomIv();
      final encUsername = encryptionService.encrypt('my_user', customIvBase64: initialIv);
      final encPassword = encryptionService.encrypt('my_pass_123', customIvBase64: initialIv);

      final testItem = VaultItem(
        id: 'item-1',
        title: 'GitHub',
        type: 'login',
        usernameEncrypted: encUsername.cipherTextBase64,
        passwordEncrypted: encPassword.cipherTextBase64,
        iv: initialIv,
        category: 'Work',
        updatedAt: DateTime.now(),
      );
      fakeLocalDataSource.items.add(testItem);

      // 2. Change PIN to 222222
      final updateSuccess = await authNotifier.updateMasterPin('111111', '222222');
      expect(updateSuccess, isTrue);

      // Verify salt and hash have changed
      final newSalt = await fakeStorage.read(key: StorageKeys.masterPinSaltKey);
      final newHash = await fakeStorage.read(key: StorageKeys.masterPinHashKey);
      expect(newSalt, isNotNull);
      expect(newSalt, isNot(equals(initialSalt)));
      expect(newHash, isNotNull);
      expect(newHash, isNot(equals(initialHash)));

      // Verify that old PIN no longer verifies
      expect(await authNotifier.verifyMasterPin('111111'), isFalse);
      expect(await authNotifier.verifyMasterPin('222222'), isTrue);

      // Verify decrypted vault items decrypt cleanly with active (new) key
      final updatedItem = fakeLocalDataSource.items.first;
      final decryptedUser = encryptionService.decrypt(
        cipherTextBase64: updatedItem.usernameEncrypted,
        ivBase64: updatedItem.iv,
      );
      final decryptedPass = encryptionService.decrypt(
        cipherTextBase64: updatedItem.passwordEncrypted,
        ivBase64: updatedItem.iv,
      );

      expect(decryptedUser, 'my_user');
      expect(decryptedPass, 'my_pass_123');
    });

    test('updateMasterPin fails if current PIN is incorrect', () async {
      await authNotifier.setupMasterPin('123456');

      final updateSuccess = await authNotifier.updateMasterPin('999999', '654321');
      expect(updateSuccess, isFalse);
      expect(authNotifier.state.errorMessage, contains('Current Master PIN is incorrect'));

      // Old PIN still works
      expect(await authNotifier.verifyMasterPin('123456'), isTrue);
    });

    test('updateMasterPin fails if new PIN is not 6 digits', () async {
      await authNotifier.setupMasterPin('123456');

      final updateSuccess = await authNotifier.updateMasterPin('123456', '123');
      expect(updateSuccess, isFalse);
      expect(authNotifier.state.errorMessage, contains('exactly 6 digits'));
    });

    test('unlockWithExistingPin restores session and stores hash/masterKey when remote salt is present', () async {
      // Simulate remote salt saved to secure storage during cloud sign-in on fresh install
      const remoteSalt = 'remote_fetched_salt_1234';
      await fakeStorage.write(
        key: StorageKeys.masterPinSaltKey,
        value: remoteSalt,
      );

      // Verify no hash exists yet
      expect(await fakeStorage.read(key: StorageKeys.masterPinHashKey), isNull);

      final success = await authNotifier.unlockWithExistingPin('654321');
      expect(success, isTrue);
      expect(authNotifier.state.status, AuthStatus.authenticated);

      // Hash and master key are now persisted
      final storedHash = await fakeStorage.read(key: StorageKeys.masterPinHashKey);
      expect(storedHash, isNotNull);

      // Verify active key works for encryption/decryption
      final iv = encryptionService.generateRandomIv();
      final enc = encryptionService.encrypt('restored_secret', customIvBase64: iv);
      final dec = encryptionService.decrypt(cipherTextBase64: enc.cipherTextBase64, ivBase64: iv);
      expect(dec, 'restored_secret');
    });

    test('unlockWithExistingPin fails if salt is not present in storage', () async {
      await authNotifier.checkAuthState();
      final success = await authNotifier.unlockWithExistingPin('123456');
      expect(success, isFalse);
      expect(authNotifier.state.errorMessage, contains('No existing Master PIN salt found'));
    });

    test('unlockWithExistingPin fails if PIN length is not 6 digits', () async {
      await authNotifier.checkAuthState();
      await fakeStorage.write(
        key: StorageKeys.masterPinSaltKey,
        value: 'some_salt',
      );

      final success = await authNotifier.unlockWithExistingPin('1234');
      expect(success, isFalse);
      expect(authNotifier.state.errorMessage, contains('exactly 6 digits'));
    });

    test('unlockWithExistingPin fails if stored hash exists and PIN is incorrect', () async {
      await authNotifier.setupMasterPin('123456');
      authNotifier.lockVault();

      final success = await authNotifier.unlockWithExistingPin('999999');
      expect(success, isFalse);
      expect(authNotifier.state.errorMessage, contains('Incorrect Master PIN'));
    });

    test('hasLocalPinConfigured returns true when salt and hash exist, false otherwise', () async {
      await authNotifier.checkAuthState();
      expect(await authNotifier.hasLocalPinConfigured(), isFalse);

      await fakeStorage.write(key: StorageKeys.masterPinSaltKey, value: 'salt123');
      expect(await authNotifier.hasLocalPinConfigured(), isFalse);

      await fakeStorage.write(key: StorageKeys.masterPinHashKey, value: 'hash123');
      expect(await authNotifier.hasLocalPinConfigured(), isTrue);
    });

    test('signOut clears active encryption key, masterKey, and transitions to uninitialized', () async {
      await authNotifier.setupMasterPin('123456');
      expect(authNotifier.state.status, AuthStatus.authenticated);
      expect(authNotifier.state.masterKey, isNotNull);
      expect(encryptionService.hasActiveKey, isTrue);

      authNotifier.setOfflineOnlyMode(true);
      expect(authNotifier.state.isOfflineOnlyMode, isTrue);

      authNotifier.signOut();
      expect(authNotifier.state.status, AuthStatus.uninitialized);
      expect(authNotifier.state.masterKey, isNull);
      expect(authNotifier.state.isOfflineOnlyMode, isFalse);
      expect(encryptionService.hasActiveKey, isFalse);
    });
  });
}

