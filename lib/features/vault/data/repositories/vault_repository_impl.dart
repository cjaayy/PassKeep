import '../../domain/repositories/vault_repository.dart';
import '../datasources/vault_local_datasource.dart';
import '../models/vault_item.dart';

/// Implementation of [IVaultRepository] interacting with [IVaultLocalDataSource].
class VaultRepositoryImpl implements IVaultRepository {
  final IVaultLocalDataSource _localDataSource;

  VaultRepositoryImpl({
    IVaultLocalDataSource? localDataSource,
  }) : _localDataSource = localDataSource ?? VaultLocalDataSource();

  @override
  Future<List<VaultItem>> getAllVaultItems() async {
    final items = await _localDataSource.getAllVaultItems();
    return _sortItemsDescending(items);
  }

  @override
  Future<List<VaultItem>> getVaultItemsFiltered({
    String? category,
    String? searchQuery,
  }) async {
    final allItems = await _localDataSource.getAllVaultItems();

    var filtered = allItems;

    // Filter by Category if specified and not 'All'
    if (category != null &&
        category.trim().isNotEmpty &&
        category.trim().toLowerCase() != 'all') {
      final normalizedCategory = category.trim().toLowerCase();
      filtered = filtered
          .where((item) => item.category.trim().toLowerCase() == normalizedCategory)
          .toList();
    }

    // Filter by Search Query (matching title or category)
    if (searchQuery != null && searchQuery.trim().isNotEmpty) {
      final query = searchQuery.trim().toLowerCase();
      filtered = filtered
          .where((item) =>
              item.title.toLowerCase().contains(query) ||
              item.category.toLowerCase().contains(query))
          .toList();
    }

    return _sortItemsDescending(filtered);
  }

  @override
  Future<VaultItem?> getVaultItemById(String id) async {
    return await _localDataSource.getVaultItemById(id);
  }

  @override
  Future<void> saveVaultItem(VaultItem item) async {
    await _localDataSource.saveVaultItem(item);
  }

  @override
  Future<void> deleteVaultItem(String id) async {
    await _localDataSource.deleteVaultItem(id);
  }

  @override
  Future<void> clearVault() async {
    await _localDataSource.clearAll();
  }

  /// Sorts items by [updatedAt] in descending order (newest first).
  List<VaultItem> _sortItemsDescending(List<VaultItem> items) {
    final sorted = List<VaultItem>.from(items);
    sorted.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return sorted;
  }
}
