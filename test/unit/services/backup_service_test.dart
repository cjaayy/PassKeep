import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:passkeep/core/errors/failures.dart';
import 'package:passkeep/core/security/encryption_service.dart';
import 'package:passkeep/core/security/key_derivation.dart';
import 'package:passkeep/core/services/backup_service.dart';
import 'package:passkeep/features/vault/data/datasources/vault_local_datasource.dart';
import 'package:passkeep/features/vault/data/models/vault_item.dart';

class FakeSecureStorage extends Fake implements FlutterSecureStorage {
  final Map<String, String> _data = {};

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
    if (value != null) _data[key] = value;
  }

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
    return _data[key];
  }
}

class FakeVaultLocalDataSource implements IVaultLocalDataSource {
  final Map<String, VaultItem> _storage = {};

  @override
  Future<List<VaultItem>> getAllVaultItems() async {
    return _storage.values.toList();
  }

  @override
  Future<VaultItem?> getVaultItemById(String id) async {
    return _storage[id];
  }

  @override
  Future<void> saveVaultItem(VaultItem item) async {
    _storage[item.id] = item;
  }

  @override
  Future<void> deleteVaultItem(String id) async {
    _storage.remove(id);
  }

  @override
  Future<void> clearAll() async {
    _storage.clear();
  }
}

void main() {
  late FakeVaultLocalDataSource fakeDataSource;
  late EncryptionService encryptionService;
  late BackupService backupService;
  late String masterKey;

  final sampleItem1 = VaultItem(
    id: 'vault-item-1',
    title: 'GitHub Work',
    usernameEncrypted: 'enc_work_user',
    passwordEncrypted: 'enc_work_pass',
    iv: 'sample_iv_123',
    category: 'Work',
    notes: 'Primary dev account',
    updatedAt: DateTime(2026, 1, 1, 10, 0),
    isSynced: true,
  );

  final sampleItem2 = VaultItem(
    id: 'vault-item-2',
    title: 'Banking App',
    usernameEncrypted: 'enc_bank_user',
    passwordEncrypted: 'enc_bank_pass',
    iv: 'sample_iv_456',
    category: 'Finance',
    notes: 'Personal checking',
    updatedAt: DateTime(2026, 1, 2, 12, 0),
    isSynced: true,
  );

  setUp(() {
    fakeDataSource = FakeVaultLocalDataSource();
    encryptionService = EncryptionService(secureStorage: FakeSecureStorage());
    masterKey = KeyDerivation.deriveKey256(password: '123456', salt: 'test_salt_123456');
    encryptionService.setActiveKey(masterKey);

    backupService = BackupService(
      localDataSource: fakeDataSource,
      encryptionService: encryptionService,
    );
  });

  group('BackupService Encrypted Export Tests', () {
    test('createEncryptedBackupPayload creates valid envelope with encrypted items', () async {
      await fakeDataSource.saveVaultItem(sampleItem1);
      await fakeDataSource.saveVaultItem(sampleItem2);

      final payloadString = await backupService.createEncryptedBackupPayload();
      expect(payloadString, isNotEmpty);

      final envelope = jsonDecode(payloadString) as Map<String, dynamic>;
      expect(envelope['app'], equals('PassKeep'));
      expect(envelope['format'], equals('passkeep-encrypted-backup'));
      expect(envelope['version'], equals(1));
      expect(envelope['itemCount'], equals(2));
      expect(envelope['cipherText'], isNotNull);
      expect(envelope['iv'], isNotNull);

      // Verify that decrypting the payload produces original items
      final decryptedJson = encryptionService.decrypt(
        cipherTextBase64: envelope['cipherText'],
        ivBase64: envelope['iv'],
      );
      final list = jsonDecode(decryptedJson) as List<dynamic>;
      expect(list.length, equals(2));
      expect(list[0]['title'], equals('GitHub Work'));
      expect(list[1]['title'], equals('Banking App'));
    });

    test('createEncryptedBackupPayload handles empty vault cleanly', () async {
      final payloadString = await backupService.createEncryptedBackupPayload();
      final envelope = jsonDecode(payloadString) as Map<String, dynamic>;
      expect(envelope['itemCount'], equals(0));

      final decryptedJson = encryptionService.decrypt(
        cipherTextBase64: envelope['cipherText'],
        ivBase64: envelope['iv'],
      );
      final list = jsonDecode(decryptedJson) as List<dynamic>;
      expect(list, isEmpty);
    });

    test('createEncryptedBackupPayload throws BackupFailure if no active key', () async {
      encryptionService.clearActiveKey();

      expect(
        () => backupService.createEncryptedBackupPayload(),
        throwsA(isA<BackupFailure>()),
      );
    });
  });

  group('BackupService Encrypted Import Tests', () {
    test('importVaultDataFromPayload successfully decrypts and restores items', () async {
      // 1. Export payload from source
      await fakeDataSource.saveVaultItem(sampleItem1);
      await fakeDataSource.saveVaultItem(sampleItem2);
      final payloadString = await backupService.createEncryptedBackupPayload();

      // 2. Clear datasource to simulate fresh device
      await fakeDataSource.clearAll();
      expect(await fakeDataSource.getAllVaultItems(), isEmpty);

      // 3. Import payload
      final count = await backupService.importVaultDataFromPayload(payloadString);
      expect(count, equals(2));

      final restoredItems = await fakeDataSource.getAllVaultItems();
      expect(restoredItems.length, equals(2));

      final restoredItem1 = await fakeDataSource.getVaultItemById('vault-item-1');
      expect(restoredItem1, isNotNull);
      expect(restoredItem1!.title, equals('GitHub Work'));
      expect(restoredItem1.notes, equals('Primary dev account'));
      // Restored items should be marked isSynced = false for subsequent cloud sync
      expect(restoredItem1.isSynced, isFalse);
    });

    test('importVaultDataFromPayload throws BackupFailure on invalid envelope format', () async {
      const invalidJson = '{"app": "PassKeep", "corrupted": true}';

      expect(
        () => backupService.importVaultDataFromPayload(invalidJson),
        throwsA(isA<BackupFailure>()),
      );
    });

    test('importVaultDataFromPayload throws BackupFailure on wrong encryption key', () async {
      await fakeDataSource.saveVaultItem(sampleItem1);
      final payloadString = await backupService.createEncryptedBackupPayload();

      // Switch to an incorrect master key
      final wrongKey = KeyDerivation.deriveKey256(password: 'wrong_pin', salt: 'wrong_salt');
      encryptionService.setActiveKey(wrongKey);

      expect(
        () => backupService.importVaultDataFromPayload(payloadString),
        throwsA(isA<BackupFailure>()),
      );
    });
  });
}
