import 'package:hive/hive.dart';
import '../../../../core/database/database_service.dart';
import '../models/vault_item.dart';

/// Local data source managing CRUD operations on the Hive vault box.
class VaultLocalDataSource {
  final DatabaseService _databaseService;

  VaultLocalDataSource({DatabaseService? databaseService})
      : _databaseService = databaseService ?? DatabaseService();

  Future<Box<VaultItem>> get _box async => await _databaseService.openVaultBox();

  Future<List<VaultItem>> getAllItems() async {
    final box = await _box;
    return box.values.toList();
  }

  Future<VaultItem?> getItemById(String id) async {
    final box = await _box;
    return box.get(id);
  }

  Future<void> putItem(VaultItem item) async {
    final box = await _box;
    await box.put(item.id, item);
  }

  Future<void> deleteItem(String id) async {
    final box = await _box;
    await box.delete(id);
  }

  Future<void> clearAll() async {
    final box = await _box;
    await box.clear();
  }
}
