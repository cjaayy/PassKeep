import 'package:flutter_test/flutter_test.dart';
import 'package:passkeep/features/sync/data/datasources/vault_remote_datasource.dart';
import 'package:passkeep/features/sync/domain/services/vault_sync_service.dart';
import 'package:passkeep/features/vault/data/datasources/vault_local_datasource.dart';
import 'package:passkeep/features/vault/data/models/vault_item.dart';

class FakeMigrationLocalDataSource implements IVaultLocalDataSource {
  final Map<String, VaultItem> items = {};

  @override
  Future<List<VaultItem>> getAllVaultItems() async => items.values.toList();

  @override
  Future<VaultItem?> getVaultItemById(String id) async => items[id];

  @override
  Future<void> saveVaultItem(VaultItem item) async {
    items[item.id] = item;
  }

  @override
  Future<void> deleteVaultItem(String id) async {
    items.remove(id);
  }

  @override
  Future<void> clearAll() async {
    items.clear();
  }
}

class FakeMigrationRemoteDataSource implements IVaultRemoteDataSource {
  final Map<String, VaultItem> remoteItems = {};

  @override
  Future<List<VaultItem>> fetchRemoteItems() async => remoteItems.values.toList();

  @override
  Future<void> upsertRemoteItem(VaultItem item) async {
    remoteItems[item.id] = item;
  }

  @override
  Future<void> upsertRemoteItems(List<VaultItem> items) async {
    for (final item in items) {
      remoteItems[item.id] = item;
    }
  }

  @override
  Future<void> deleteRemoteItem(String id) async {
    remoteItems.remove(id);
  }
}

void main() {
  group('Vault Migration Tests (Local to Authenticated Cloud Account)', () {
    late FakeMigrationLocalDataSource localDataSource;
    late FakeMigrationRemoteDataSource remoteDataSource;
    late VaultSyncService syncService;

    setUp(() {
      localDataSource = FakeMigrationLocalDataSource();
      remoteDataSource = FakeMigrationRemoteDataSource();
      syncService = VaultSyncService(
        localDataSource: localDataSource,
        remoteDataSource: remoteDataSource,
      );
    });

    test('migrateLocalVaultToUser marks all local items as unsynced and pushes them to remote', () async {
      // 1. Create local items created while offline (some marked synced, some not)
      final item1 = VaultItem(
        id: 'offline-item-1',
        title: 'Personal Email',
        usernameEncrypted: 'enc_user_1',
        passwordEncrypted: 'enc_pass_1',
        iv: 'iv_1',
        category: 'Personal',
        isSynced: true, // legacy state
        updatedAt: DateTime.now(),
      );

      final item2 = VaultItem(
        id: 'offline-item-2',
        title: 'Bank Account',
        usernameEncrypted: 'enc_user_2',
        passwordEncrypted: 'enc_pass_2',
        iv: 'iv_2',
        category: 'Finance',
        isSynced: false,
        updatedAt: DateTime.now(),
      );

      await localDataSource.saveVaultItem(item1);
      await localDataSource.saveVaultItem(item2);

      expect(remoteDataSource.remoteItems, isEmpty);

      // 2. Perform migration upon sign in
      const newUserId = 'user-uuid-12345';
      final syncResult = await syncService.migrateLocalVaultToUser(newUserId);

      expect(syncResult.isSuccess, isTrue);
      expect(syncResult.pushedCount, 2);

      // 3. Verify remote contains both migrated items
      expect(remoteDataSource.remoteItems.length, 2);
      expect(remoteDataSource.remoteItems.containsKey('offline-item-1'), isTrue);
      expect(remoteDataSource.remoteItems.containsKey('offline-item-2'), isTrue);

      // 4. Verify local items are marked isSynced = true
      final updatedLocal1 = await localDataSource.getVaultItemById('offline-item-1');
      final updatedLocal2 = await localDataSource.getVaultItemById('offline-item-2');
      expect(updatedLocal1?.isSynced, isTrue);
      expect(updatedLocal2?.isSynced, isTrue);
    });
  });
}
