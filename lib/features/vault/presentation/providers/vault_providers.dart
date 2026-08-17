import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../sync/data/datasources/vault_remote_datasource.dart';
import '../../../sync/presentation/providers/sync_providers.dart';
import '../../data/datasources/vault_local_datasource.dart';
import '../../data/models/vault_item.dart';
import '../../data/repositories/vault_repository_impl.dart';
import '../../domain/repositories/vault_repository.dart';
import 'vault_state.dart';

/// Provider for [IVaultLocalDataSource]
final vaultLocalDataSourceProvider = Provider<IVaultLocalDataSource>((ref) {
  return VaultLocalDataSource();
});

/// Provider for [IVaultRepository]
final vaultRepositoryProvider = Provider<IVaultRepository>((ref) {
  final localDataSource = ref.watch(vaultLocalDataSourceProvider);
  return VaultRepositoryImpl(localDataSource: localDataSource);
});

/// StateNotifier managing reactive Vault operations and dynamic filtering
class VaultNotifier extends StateNotifier<VaultState> {
  final IVaultRepository _repository;
  final IVaultRemoteDataSource? _remoteDataSource;

  VaultNotifier({
    required IVaultRepository repository,
    IVaultRemoteDataSource? remoteDataSource,
  })  : _repository = repository,
        _remoteDataSource = remoteDataSource,
        super(const VaultState.initial());

  /// Fetches all vault items from the repository and applies current active filters.
  Future<void> loadVaultItems() async {
    state = state.copyWith(status: VaultStatus.loading, errorMessage: null);

    try {
      final items = await _repository.getAllVaultItems();
      final filtered = _applyFilters(
        items: items,
        category: state.selectedCategory,
        query: state.searchQuery,
      );

      state = state.copyWith(
        status: VaultStatus.success,
        allItems: items,
        filteredItems: filtered,
      );
    } catch (e) {
      state = state.copyWith(
        status: VaultStatus.error,
        errorMessage: e.toString(),
      );
    }
  }

  /// Saves (creates or updates) a [VaultItem] and refreshes state.
  Future<void> saveItem(VaultItem item) async {
    try {
      await _repository.saveVaultItem(item);
      await loadVaultItems();
    } catch (e) {
      state = state.copyWith(
        status: VaultStatus.error,
        errorMessage: e.toString(),
      );
    }
  }

  /// Deletes a [VaultItem] by [id] from local storage AND remote Supabase, then refreshes state.
  Future<void> deleteItem(String id) async {
    try {
      // 1. Delete from local Hive storage
      await _repository.deleteVaultItem(id);

      // 2. Delete from remote Supabase (fire-and-forget, best effort)
      try {
        await _remoteDataSource?.deleteRemoteItem(id);
      } catch (_) {
        // Remote deletion failure is non-blocking; sync will reconcile later
      }

      await loadVaultItems();
    } catch (e) {
      state = state.copyWith(
        status: VaultStatus.error,
        errorMessage: e.toString(),
      );
    }
  }

  /// Updates the active category filter (e.g. 'All', 'Social', 'Work', 'Finance', 'Personal').
  void setCategoryFilter(String category) {
    final filtered = _applyFilters(
      items: state.allItems,
      category: category,
      query: state.searchQuery,
    );

    state = state.copyWith(
      selectedCategory: category,
      filteredItems: filtered,
    );
  }

  /// Updates the search query and filters the list in real-time.
  void setSearchQuery(String query) {
    final filtered = _applyFilters(
      items: state.allItems,
      category: state.selectedCategory,
      query: query,
    );

    state = state.copyWith(
      searchQuery: query,
      filteredItems: filtered,
    );
  }

  /// Clears all stored items (e.g. on vault reset).
  Future<void> clearVault() async {
    try {
      await _repository.clearVault();
      state = state.copyWith(
        status: VaultStatus.success,
        allItems: const [],
        filteredItems: const [],
      );
    } catch (e) {
      state = state.copyWith(
        status: VaultStatus.error,
        errorMessage: e.toString(),
      );
    }
  }

  /// Refreshes items from the database.
  Future<void> refresh() => loadVaultItems();

  /// Applies category and search query filters to a given list of items.
  List<VaultItem> _applyFilters({
    required List<VaultItem> items,
    required String category,
    required String query,
  }) {
    var result = items;

    // Filter by Category
    if (category.trim().isNotEmpty && category.trim().toLowerCase() != 'all') {
      final normCategory = category.trim().toLowerCase();
      result = result
          .where((item) => item.category.trim().toLowerCase() == normCategory)
          .toList();
    }

    // Filter by Search Query (title or category)
    if (query.trim().isNotEmpty) {
      final normQuery = query.trim().toLowerCase();
      result = result
          .where((item) =>
              item.title.toLowerCase().contains(normQuery) ||
              item.category.toLowerCase().contains(normQuery))
          .toList();
    }

    return result;
  }
}

/// Provider for [VaultNotifier]
final vaultNotifierProvider = StateNotifierProvider<VaultNotifier, VaultState>((ref) {
  final repository = ref.watch(vaultRepositoryProvider);

  // Inject remote datasource for deletion sync (graceful null if Supabase not initialized)
  IVaultRemoteDataSource? remoteDataSource;
  try {
    remoteDataSource = ref.watch(vaultRemoteDataSourceProvider);
  } catch (_) {
    remoteDataSource = null;
  }

  return VaultNotifier(
    repository: repository,
    remoteDataSource: remoteDataSource,
  );
});
