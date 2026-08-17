import '../../data/models/vault_item.dart';

/// Repository interface for local & remote encrypted Vault operations.
abstract class IVaultRepository {
  /// Fetches all stored vault items from the local database.
  Future<List<VaultItem>> getAllVaultItems();

  /// Fetches vault items with optional category filtering and search query filtering.
  Future<List<VaultItem>> getVaultItemsFiltered({
    String? category,
    String? searchQuery,
  });

  /// Gets a specific vault item by its unique ID.
  Future<VaultItem?> getVaultItemById(String id);

  /// Saves or updates a vault item.
  Future<void> saveVaultItem(VaultItem item);

  /// Deletes a vault item by ID.
  Future<void> deleteVaultItem(String id);

  /// Clears all stored vault items (e.g. on account reset / logout).
  Future<void> clearVault();
}
