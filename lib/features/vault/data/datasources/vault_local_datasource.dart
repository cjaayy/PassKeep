import 'package:hive/hive.dart';
import '../../../../core/constants/storage_keys.dart';
import '../../../../core/database/database_service.dart';
import '../../../../core/errors/failures.dart';
import '../models/vault_item.dart';

/// Abstract interface for local Vault storage operations
abstract class IVaultLocalDataSource {
  Future<List<VaultItem>> getAllVaultItems();
  Future<VaultItem?> getVaultItemById(String id);
  Future<void> saveVaultItem(VaultItem item);
  Future<void> deleteVaultItem(String id);
  Future<void> clearAll();
}

/// Local data source implementation managing CRUD operations on the Hive vault box.
class VaultLocalDataSource implements IVaultLocalDataSource {
  final DatabaseService? _databaseService;
  final Box<VaultItem>? _injectedBox;

  VaultLocalDataSource({
    DatabaseService? databaseService,
    Box<VaultItem>? box,
  })  : _databaseService = databaseService ?? (box == null ? DatabaseService() : null),
        _injectedBox = box;

  Future<Box<VaultItem>> get _box async {
    if (_injectedBox != null && _injectedBox.isOpen) {
      return _injectedBox;
    }
    if (Hive.isBoxOpen(StorageKeys.vaultBoxName)) {
      return Hive.box<VaultItem>(StorageKeys.vaultBoxName);
    }
    return await (_databaseService ?? DatabaseService()).openVaultBox();
  }

  @override
  Future<List<VaultItem>> getAllVaultItems() async {
    try {
      final box = await _box;
      return box.values.toList();
    } catch (e) {
      if (e is Failure) rethrow;
      throw DatabaseFailure('Failed to retrieve vault items: ${e.toString()}');
    }
  }

  @override
  Future<VaultItem?> getVaultItemById(String id) async {
    try {
      final box = await _box;
      return box.get(id);
    } catch (e) {
      if (e is Failure) rethrow;
      throw DatabaseFailure('Failed to get vault item by ID ($id): ${e.toString()}');
    }
  }

  @override
  Future<void> saveVaultItem(VaultItem item) async {
    try {
      final box = await _box;
      await box.put(item.id, item);
    } catch (e) {
      if (e is Failure) rethrow;
      throw DatabaseFailure('Failed to save vault item (${item.id}): ${e.toString()}');
    }
  }

  @override
  Future<void> deleteVaultItem(String id) async {
    try {
      final box = await _box;
      await box.delete(id);
    } catch (e) {
      if (e is Failure) rethrow;
      throw DatabaseFailure('Failed to delete vault item ($id): ${e.toString()}');
    }
  }

  @override
  Future<void> clearAll() async {
    try {
      final box = await _box;
      await box.clear();
    } catch (e) {
      if (e is Failure) rethrow;
      throw DatabaseFailure('Failed to clear vault storage: ${e.toString()}');
    }
  }
}
