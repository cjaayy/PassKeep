import 'package:flutter_test/flutter_test.dart';
import 'package:passkeep/features/vault/data/datasources/vault_local_datasource.dart';
import 'package:passkeep/features/vault/data/models/vault_item.dart';
import 'package:passkeep/features/vault/data/repositories/vault_repository_impl.dart';

/// In-memory fake implementation of [IVaultLocalDataSource]
class FakeVaultLocalDataSource implements IVaultLocalDataSource {
  final List<VaultItem> items = [];

  @override
  Future<List<VaultItem>> getAllVaultItems() async => List.from(items);

  @override
  Future<VaultItem?> getVaultItemById(String id) async {
    try {
      return items.firstWhere((item) => item.id == id);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> saveVaultItem(VaultItem item) async {
    final index = items.indexWhere((i) => i.id == item.id);
    if (index >= 0) {
      items[index] = item;
    } else {
      items.add(item);
    }
  }

  @override
  Future<void> deleteVaultItem(String id) async {
    items.removeWhere((i) => i.id == id);
  }

  @override
  Future<void> clearAll() async {
    items.clear();
  }
}

void main() {
  group('VaultRepositoryImpl Tests', () {
    late FakeVaultLocalDataSource fakeDataSource;
    late VaultRepositoryImpl repository;

    final itemOld = VaultItem(
      id: 'id-old',
      title: 'GitHub',
      usernameEncrypted: 'enc_user_gh',
      passwordEncrypted: 'enc_pass_gh',
      iv: 'iv_gh',
      category: 'Work',
      updatedAt: DateTime.parse('2026-08-10T10:00:00Z'),
    );

    final itemNew = VaultItem(
      id: 'id-new',
      title: 'Twitter / X',
      usernameEncrypted: 'enc_user_tw',
      passwordEncrypted: 'enc_pass_tw',
      iv: 'iv_tw',
      category: 'Social',
      updatedAt: DateTime.parse('2026-08-17T12:00:00Z'),
    );

    final itemMid = VaultItem(
      id: 'id-mid',
      title: 'Chase Bank',
      usernameEncrypted: 'enc_user_ch',
      passwordEncrypted: 'enc_pass_ch',
      iv: 'iv_ch',
      category: 'Finance',
      updatedAt: DateTime.parse('2026-08-15T15:00:00Z'),
    );

    setUp(() {
      fakeDataSource = FakeVaultLocalDataSource();
      fakeDataSource.items.addAll([itemOld, itemNew, itemMid]);
      repository = VaultRepositoryImpl(localDataSource: fakeDataSource);
    });

    test('should return all vault items sorted by updatedAt descending', () async {
      final items = await repository.getAllVaultItems();

      expect(items.length, 3);
      expect(items[0].id, 'id-new'); // 2026-08-17
      expect(items[1].id, 'id-mid'); // 2026-08-15
      expect(items[2].id, 'id-old'); // 2026-08-10
    });

    test('should filter vault items by category', () async {
      final socialItems = await repository.getVaultItemsFiltered(category: 'Social');
      expect(socialItems.length, 1);
      expect(socialItems.first.title, 'Twitter / X');

      final workItems = await repository.getVaultItemsFiltered(category: 'work'); // case-insensitive
      expect(workItems.length, 1);
      expect(workItems.first.title, 'GitHub');

      final allCategoryItems = await repository.getVaultItemsFiltered(category: 'All');
      expect(allCategoryItems.length, 3);
    });

    test('should filter vault items by search query matching title', () async {
      final searchResults = await repository.getVaultItemsFiltered(searchQuery: 'chase');
      expect(searchResults.length, 1);
      expect(searchResults.first.title, 'Chase Bank');
    });

    test('should filter vault items by search query matching category', () async {
      final searchResults = await repository.getVaultItemsFiltered(searchQuery: 'finance');
      expect(searchResults.length, 1);
      expect(searchResults.first.title, 'Chase Bank');
    });

    test('should filter vault items with combined category and search query', () async {
      final results = await repository.getVaultItemsFiltered(
        category: 'Social',
        searchQuery: 'twitter',
      );
      expect(results.length, 1);
      expect(results.first.title, 'Twitter / X');

      final noMatchResults = await repository.getVaultItemsFiltered(
        category: 'Work',
        searchQuery: 'twitter',
      );
      expect(noMatchResults, isEmpty);
    });

    test('should get item by ID', () async {
      final item = await repository.getVaultItemById('id-mid');
      expect(item, isNotNull);
      expect(item!.title, 'Chase Bank');
    });

    test('should save and delete item', () async {
      final newItem = VaultItem(
        id: 'id-new-4',
        title: 'ProtonMail',
        usernameEncrypted: 'enc_user_pm',
        passwordEncrypted: 'enc_pass_pm',
        iv: 'iv_pm',
        category: 'Personal',
        updatedAt: DateTime.parse('2026-08-17T18:00:00Z'),
      );

      await repository.saveVaultItem(newItem);
      final retrieved = await repository.getVaultItemById('id-new-4');
      expect(retrieved, isNotNull);
      expect(retrieved!.title, 'ProtonMail');

      await repository.deleteVaultItem('id-new-4');
      final afterDelete = await repository.getVaultItemById('id-new-4');
      expect(afterDelete, isNull);
    });

    test('should clear vault', () async {
      await repository.clearVault();
      final items = await repository.getAllVaultItems();
      expect(items, isEmpty);
    });
  });
}
