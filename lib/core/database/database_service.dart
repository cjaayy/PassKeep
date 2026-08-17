import 'package:hive_flutter/hive_flutter.dart';
import '../../features/vault/data/models/vault_item.dart';
import '../constants/storage_keys.dart';

/// Service responsible for managing local Hive database initialization and boxes.
class DatabaseService {
  static final DatabaseService _instance = DatabaseService._internal();
  factory DatabaseService() => _instance;
  DatabaseService._internal();

  bool _isInitialized = false;

  /// Initializes Hive, registers TypeAdapters, and opens the required boxes.
  Future<void> initialize() async {
    if (_isInitialized) return;

    await Hive.initFlutter();

    // Register VaultItemAdapter if not already registered
    if (!Hive.isAdapterRegistered(StorageKeys.vaultItemTypeId)) {
      Hive.registerAdapter(VaultItemAdapter());
    }

    _isInitialized = true;
  }

  /// Opens and returns the Box for [VaultItem].
  Future<Box<VaultItem>> openVaultBox() async {
    if (!_isInitialized) {
      await initialize();
    }
    return await Hive.openBox<VaultItem>(StorageKeys.vaultBoxName);
  }

  /// Returns the already opened [VaultItem] Box.
  Box<VaultItem> getVaultBox() {
    return Hive.box<VaultItem>(StorageKeys.vaultBoxName);
  }
}
