import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../vault/presentation/providers/vault_providers.dart';
import '../../data/datasources/vault_remote_datasource.dart';
import '../../domain/services/vault_sync_service.dart';

/// State representation for synchronization operations.
class SyncState {
  final bool isSyncing;
  final DateTime? lastSyncedAt;
  final int lastSyncedCount;
  final bool isSuccess;
  final String? errorMessage;

  const SyncState({
    this.isSyncing = false,
    this.lastSyncedAt,
    this.lastSyncedCount = 0,
    this.isSuccess = false,
    this.errorMessage,
  });

  const SyncState.initial()
      : isSyncing = false,
        lastSyncedAt = null,
        lastSyncedCount = 0,
        isSuccess = false,
        errorMessage = null;

  SyncState copyWith({
    bool? isSyncing,
    DateTime? lastSyncedAt,
    int? lastSyncedCount,
    bool? isSuccess,
    String? errorMessage,
  }) {
    return SyncState(
      isSyncing: isSyncing ?? this.isSyncing,
      lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
      lastSyncedCount: lastSyncedCount ?? this.lastSyncedCount,
      isSuccess: isSuccess ?? this.isSuccess,
      errorMessage: errorMessage,
    );
  }

  @override
  String toString() {
    return 'SyncState(isSyncing: $isSyncing, lastSyncedAt: $lastSyncedAt, syncedCount: $lastSyncedCount, error: $errorMessage)';
  }
}

/// Optional Supabase Client Provider (falls back gracefully if not initialized)
final supabaseClientProvider = Provider<SupabaseClient?>((ref) {
  try {
    return Supabase.instance.client;
  } catch (_) {
    return null;
  }
});

/// Provider for [IVaultRemoteDataSource]
final vaultRemoteDataSourceProvider = Provider<IVaultRemoteDataSource>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return VaultRemoteDataSource(client: client);
});

/// Provider for [VaultSyncService]
final vaultSyncServiceProvider = Provider<VaultSyncService>((ref) {
  final localDataSource = ref.watch(vaultLocalDataSourceProvider);
  final remoteDataSource = ref.watch(vaultRemoteDataSourceProvider);
  return VaultSyncService(
    localDataSource: localDataSource,
    remoteDataSource: remoteDataSource,
  );
});

/// StateNotifier managing synchronization lifecycle
class SyncNotifier extends StateNotifier<SyncState> {
  final VaultSyncService _syncService;
  final Ref? _ref;

  SyncNotifier({
    required VaultSyncService syncService,
    Ref? ref,
  })  : _syncService = syncService,
        _ref = ref,
        super(const SyncState.initial());

  /// Executes synchronization cycle and notifies dependent listeners.
  Future<SyncResult> sync() async {
    state = state.copyWith(isSyncing: true, errorMessage: null);

    final result = await _syncService.sync();

    if (result.isSuccess) {
      state = state.copyWith(
        isSyncing: false,
        lastSyncedAt: result.syncedAt,
        lastSyncedCount: result.totalChanges,
        isSuccess: true,
        errorMessage: null,
      );

      // Refresh local vault state if ref is attached
      _ref?.read(vaultNotifierProvider.notifier).loadVaultItems();
    } else {
      state = state.copyWith(
        isSyncing: false,
        isSuccess: false,
        errorMessage: result.errorMessage,
      );
    }

    return result;
  }
}

/// Provider for [SyncNotifier]
final syncNotifierProvider = StateNotifierProvider<SyncNotifier, SyncState>((ref) {
  final syncService = ref.watch(vaultSyncServiceProvider);
  return SyncNotifier(syncService: syncService, ref: ref);
});
