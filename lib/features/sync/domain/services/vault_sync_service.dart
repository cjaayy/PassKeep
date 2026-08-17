import '../../../../core/errors/failures.dart';
import '../../../vault/data/datasources/vault_local_datasource.dart';
import '../../../vault/data/models/vault_item.dart';
import '../../data/datasources/vault_remote_datasource.dart';

/// Result summary of a completed synchronization cycle.
class SyncResult {
  final int pushedCount;
  final int pulledCount;
  final int conflictResolvedCount;
  final DateTime syncedAt;
  final bool isSuccess;
  final String? errorMessage;

  const SyncResult({
    required this.pushedCount,
    required this.pulledCount,
    required this.conflictResolvedCount,
    required this.syncedAt,
    this.isSuccess = true,
    this.errorMessage,
  });

  factory SyncResult.failure(String error) {
    return SyncResult(
      pushedCount: 0,
      pulledCount: 0,
      conflictResolvedCount: 0,
      syncedAt: DateTime.now(),
      isSuccess: false,
      errorMessage: error,
    );
  }

  int get totalChanges => pushedCount + pulledCount;

  @override
  String toString() {
    return 'SyncResult(pushed: $pushedCount, pulled: $pulledCount, conflicts: $conflictResolvedCount, success: $isSuccess, at: $syncedAt)';
  }
}

/// Service executing bidirectional Zero-Knowledge sync with timestamp conflict resolution.
class VaultSyncService {
  final IVaultLocalDataSource _localDataSource;
  final IVaultRemoteDataSource _remoteDataSource;

  VaultSyncService({
    required IVaultLocalDataSource localDataSource,
    required IVaultRemoteDataSource remoteDataSource,
  })  : _localDataSource = localDataSource,
        _remoteDataSource = remoteDataSource;

  /// Executes a full bidirectional sync cycle between local Hive database and Supabase.
  Future<SyncResult> sync() async {
    try {
      int pushedCount = 0;
      int pulledCount = 0;
      int conflictResolvedCount = 0;

      // 1. Fetch current states from local and remote
      final localItems = await _localDataSource.getAllVaultItems();
      final remoteItems = await _remoteDataSource.fetchRemoteItems();

      final remoteMap = <String, VaultItem>{
        for (final item in remoteItems) item.id: item,
      };
      final localMap = <String, VaultItem>{
        for (final item in localItems) item.id: item,
      };

      // 2. Process Local items (Push or resolve against existing remote)
      for (final localItem in localItems) {
        if (!remoteMap.containsKey(localItem.id)) {
          // Item exists locally only
          if (!localItem.isSynced) {
            await _remoteDataSource.upsertRemoteItem(localItem);
            await _localDataSource.saveVaultItem(localItem.copyWith(isSynced: true));
            pushedCount++;
          }
        } else {
          // Item exists in both local and remote: Perform timestamp conflict resolution
          final remoteItem = remoteMap[localItem.id]!;

          if (localItem.updatedAt.isAfter(remoteItem.updatedAt)) {
            // Local is newer: Push local version to remote
            await _remoteDataSource.upsertRemoteItem(localItem);
            await _localDataSource.saveVaultItem(localItem.copyWith(isSynced: true));
            pushedCount++;
            conflictResolvedCount++;
          } else if (remoteItem.updatedAt.isAfter(localItem.updatedAt)) {
            // Remote is newer: Overwrite local with remote version
            await _localDataSource.saveVaultItem(remoteItem.copyWith(isSynced: true));
            pulledCount++;
            conflictResolvedCount++;
          } else {
            // Both have identical timestamp: ensure marked synced locally
            if (!localItem.isSynced) {
              await _localDataSource.saveVaultItem(localItem.copyWith(isSynced: true));
            }
          }
        }
      }

      // 3. Process Remote-Only items (Pull into local database)
      for (final remoteItem in remoteItems) {
        if (!localMap.containsKey(remoteItem.id)) {
          // Item exists on remote only (created on another device)
          await _localDataSource.saveVaultItem(remoteItem.copyWith(isSynced: true));
          pulledCount++;
        }
      }

      return SyncResult(
        pushedCount: pushedCount,
        pulledCount: pulledCount,
        conflictResolvedCount: conflictResolvedCount,
        syncedAt: DateTime.now(),
        isSuccess: true,
      );
    } catch (e) {
      if (e is Failure) {
        return SyncResult.failure(e.message);
      }
      return SyncResult.failure('Sync failed: ${e.toString()}');
    }
  }
}
