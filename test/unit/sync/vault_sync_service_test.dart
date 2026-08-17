import 'package:flutter_test/flutter_test.dart';
import 'package:passkeep/core/errors/failures.dart';
import 'package:passkeep/features/sync/data/datasources/vault_remote_datasource.dart';
import 'package:passkeep/features/sync/domain/services/vault_sync_service.dart';
import 'package:passkeep/features/vault/data/datasources/vault_local_datasource.dart';
import 'package:passkeep/features/vault/data/models/vault_item.dart';

/// Fake local datasource for sync unit testing
class FakeSyncLocalDataSource implements IVaultLocalDataSource {
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

/// Fake remote datasource simulating Supabase database operations
class FakeSyncRemoteDataSource implements IVaultRemoteDataSource {
  final Map<String, VaultItem> remoteItems = {};
  bool shouldThrow = false;

  @override
  Future<List<VaultItem>> fetchRemoteItems() async {
    if (shouldThrow) throw const SyncFailure('Network connection failed');
    return remoteItems.values.toList();
  }

  @override
  Future<void> upsertRemoteItem(VaultItem item) async {
    if (shouldThrow) throw const SyncFailure('Remote write error');
    remoteItems[item.id] = item;
  }

  @override
  Future<void> deleteRemoteItem(String id) async {
    if (shouldThrow) throw const SyncFailure('Remote delete error');
    remoteItems.remove(id);
  }
}

void main() {
  group('VaultSyncService Bidirectional Sync Tests', () {
    late FakeSyncLocalDataSource localDataSource;
    late FakeSyncRemoteDataSource remoteDataSource;
    late VaultSyncService syncService;

    setUp(() {
      localDataSource = FakeSyncLocalDataSource();
      remoteDataSource = FakeSyncRemoteDataSource();
      syncService = VaultSyncService(
        localDataSource: localDataSource,
        remoteDataSource: remoteDataSource,
      );
    });

    test('should push unsynced local items to remote and mark them isSynced = true', () async {
      final localUnsynced = VaultItem(
        id: 'item-1',
        title: 'Twitter / X',
        usernameEncrypted: 'enc_user_1',
        passwordEncrypted: 'enc_pass_1',
        iv: 'iv_1',
        category: 'Social',
        isSynced: false,
        updatedAt: DateTime.parse('2026-08-17T10:00:00Z'),
      );

      await localDataSource.saveVaultItem(localUnsynced);

      final result = await syncService.sync();

      expect(result.isSuccess, isTrue);
      expect(result.pushedCount, 1);
      expect(result.pulledCount, 0);

      // Verify remote has received the item
      expect(remoteDataSource.remoteItems.containsKey('item-1'), isTrue);

      // Verify local item has been marked as synced
      final localStored = await localDataSource.getVaultItemById('item-1');
      expect(localStored!.isSynced, isTrue);
    });

    test('should pull new remote items into local storage', () async {
      final remoteItem = VaultItem(
        id: 'item-remote-2',
        title: 'Work Email',
        usernameEncrypted: 'enc_work_user',
        passwordEncrypted: 'enc_work_pass',
        iv: 'iv_work',
        category: 'Work',
        isSynced: false,
        updatedAt: DateTime.parse('2026-08-17T11:00:00Z'),
      );

      await remoteDataSource.upsertRemoteItem(remoteItem);

      final result = await syncService.sync();

      expect(result.isSuccess, isTrue);
      expect(result.pulledCount, 1);
      expect(result.pushedCount, 0);

      // Verify item is now in local database with isSynced = true
      final localStored = await localDataSource.getVaultItemById('item-remote-2');
      expect(localStored, isNotNull);
      expect(localStored!.title, 'Work Email');
      expect(localStored.isSynced, isTrue);
    });

    test('conflict resolution: should overwrite remote when local updatedAt is newer', () async {
      final olderRemote = VaultItem(
        id: 'item-shared',
        title: 'Old Title on Remote',
        usernameEncrypted: 'enc_user',
        passwordEncrypted: 'old_pass',
        iv: 'iv_old',
        category: 'Finance',
        isSynced: true,
        updatedAt: DateTime.parse('2026-08-17T10:00:00Z'),
      );

      final newerLocal = VaultItem(
        id: 'item-shared',
        title: 'New Title Updated Locally',
        usernameEncrypted: 'enc_user',
        passwordEncrypted: 'new_pass',
        iv: 'iv_new',
        category: 'Finance',
        isSynced: false,
        updatedAt: DateTime.parse('2026-08-17T15:00:00Z'), // 5 hours newer
      );

      await remoteDataSource.upsertRemoteItem(olderRemote);
      await localDataSource.saveVaultItem(newerLocal);

      final result = await syncService.sync();

      expect(result.isSuccess, isTrue);
      expect(result.pushedCount, 1);
      expect(result.conflictResolvedCount, 1);

      // Remote must now have the newer local title & data
      final remoteUpdated = remoteDataSource.remoteItems['item-shared']!;
      expect(remoteUpdated.title, 'New Title Updated Locally');

      // Local is marked as synced
      final localItem = await localDataSource.getVaultItemById('item-shared');
      expect(localItem!.isSynced, isTrue);
    });

    test('conflict resolution: should overwrite local when remote updatedAt is newer', () async {
      final olderLocal = VaultItem(
        id: 'item-shared',
        title: 'Old Local Title',
        usernameEncrypted: 'enc_user',
        passwordEncrypted: 'old_pass',
        iv: 'iv_old',
        category: 'Work',
        isSynced: true,
        updatedAt: DateTime.parse('2026-08-17T08:00:00Z'),
      );

      final newerRemote = VaultItem(
        id: 'item-shared',
        title: 'New Remote Title',
        usernameEncrypted: 'enc_user',
        passwordEncrypted: 'new_remote_pass',
        iv: 'iv_remote',
        category: 'Work',
        isSynced: false,
        updatedAt: DateTime.parse('2026-08-17T14:00:00Z'), // Newer
      );

      await localDataSource.saveVaultItem(olderLocal);
      await remoteDataSource.upsertRemoteItem(newerRemote);

      final result = await syncService.sync();

      expect(result.isSuccess, isTrue);
      expect(result.pulledCount, 1);
      expect(result.conflictResolvedCount, 1);

      // Local database now contains the newer remote data
      final localUpdated = await localDataSource.getVaultItemById('item-shared');
      expect(localUpdated!.title, 'New Remote Title');
      expect(localUpdated.passwordEncrypted, 'new_remote_pass');
      expect(localUpdated.isSynced, isTrue);
    });

    test('should return failure result when remote throws exception', () async {
      remoteDataSource.shouldThrow = true;

      final result = await syncService.sync();

      expect(result.isSuccess, isFalse);
      expect(result.errorMessage, contains('Network connection failed'));
    });
  });
}
