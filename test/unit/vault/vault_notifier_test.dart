import 'package:flutter_test/flutter_test.dart';
import 'package:passkeep/core/errors/failures.dart';
import 'package:passkeep/features/vault/data/models/vault_item.dart';
import 'package:passkeep/features/vault/domain/repositories/vault_repository.dart';
import 'package:passkeep/features/vault/presentation/providers/vault_providers.dart';
import 'package:passkeep/features/vault/presentation/providers/vault_state.dart';

/// Fake implementation of [IVaultRepository] for testing VaultNotifier
class MockVaultRepository implements IVaultRepository {
  final List<VaultItem> items = [];
  bool shouldThrow = false;

  @override
  Future<List<VaultItem>> getAllVaultItems() async {
    if (shouldThrow) throw const DatabaseFailure('Database read error');
    final sorted = List<VaultItem>.from(items);
    sorted.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return sorted;
  }

  @override
  Future<List<VaultItem>> getVaultItemsFiltered({
    String? category,
    String? searchQuery,
  }) async {
    final all = await getAllVaultItems();
    var filtered = all;
    if (category != null && category.isNotEmpty && category.toLowerCase() != 'all') {
      filtered = filtered
          .where((i) => i.category.toLowerCase() == category.toLowerCase())
          .toList();
    }
    if (searchQuery != null && searchQuery.isNotEmpty) {
      filtered = filtered
          .where((i) =>
              i.title.toLowerCase().contains(searchQuery.toLowerCase()) ||
              i.category.toLowerCase().contains(searchQuery.toLowerCase()))
          .toList();
    }
    return filtered;
  }

  @override
  Future<VaultItem?> getVaultItemById(String id) async {
    try {
      return items.firstWhere((i) => i.id == id);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> saveVaultItem(VaultItem item) async {
    if (shouldThrow) throw const DatabaseFailure('Database save error');
    final index = items.indexWhere((i) => i.id == item.id);
    if (index >= 0) {
      items[index] = item;
    } else {
      items.add(item);
    }
  }

  @override
  Future<void> deleteVaultItem(String id) async {
    if (shouldThrow) throw const DatabaseFailure('Database delete error');
    items.removeWhere((i) => i.id == id);
  }

  @override
  Future<void> clearVault() async {
    if (shouldThrow) throw const DatabaseFailure('Database clear error');
    items.clear();
  }
}

void main() {
  group('VaultNotifier Tests', () {
    late MockVaultRepository mockRepository;
    late VaultNotifier notifier;

    final item1 = VaultItem(
      id: 'id-1',
      title: 'Google Account',
      usernameEncrypted: 'enc_user_1',
      passwordEncrypted: 'enc_pass_1',
      iv: 'iv_1',
      category: 'Work',
      updatedAt: DateTime.parse('2026-08-17T10:00:00Z'),
    );

    final item2 = VaultItem(
      id: 'id-2',
      title: 'Discord Server',
      usernameEncrypted: 'enc_user_2',
      passwordEncrypted: 'enc_pass_2',
      iv: 'iv_2',
      category: 'Social',
      updatedAt: DateTime.parse('2026-08-17T11:00:00Z'),
    );

    setUp(() {
      mockRepository = MockVaultRepository();
      mockRepository.items.addAll([item1, item2]);
      notifier = VaultNotifier(repository: mockRepository);
    });

    test('initial state should be empty with default category "All"', () {
      expect(notifier.state.status, VaultStatus.initial);
      expect(notifier.state.allItems, isEmpty);
      expect(notifier.state.filteredItems, isEmpty);
      expect(notifier.state.selectedCategory, 'All');
      expect(notifier.state.searchQuery, '');
    });

    test('loadVaultItems should transition to loading then success with sorted items', () async {
      await notifier.loadVaultItems();

      expect(notifier.state.status, VaultStatus.success);
      expect(notifier.state.allItems.length, 2);
      expect(notifier.state.filteredItems.length, 2);
      expect(notifier.state.allItems.first.id, 'id-2'); // Newest first
    });

    test('saveItem should add new item and update state', () async {
      await notifier.loadVaultItems();

      final newItem = VaultItem(
        id: 'id-3',
        title: 'Fidelity Investments',
        usernameEncrypted: 'enc_user_3',
        passwordEncrypted: 'enc_pass_3',
        iv: 'iv_3',
        category: 'Finance',
        updatedAt: DateTime.parse('2026-08-17T14:00:00Z'),
      );

      await notifier.saveItem(newItem);

      expect(notifier.state.allItems.length, 3);
      expect(notifier.state.filteredItems.length, 3);
      expect(notifier.state.allItems.first.title, 'Fidelity Investments');
    });

    test('deleteItem should remove item and update state', () async {
      await notifier.loadVaultItems();
      expect(notifier.state.allItems.length, 2);

      await notifier.deleteItem('id-1');

      expect(notifier.state.allItems.length, 1);
      expect(notifier.state.filteredItems.length, 1);
      expect(notifier.state.allItems.first.id, 'id-2');
    });

    test('setCategoryFilter should filter items dynamically', () async {
      await notifier.loadVaultItems();

      notifier.setCategoryFilter('Social');
      expect(notifier.state.selectedCategory, 'Social');
      expect(notifier.state.filteredItems.length, 1);
      expect(notifier.state.filteredItems.first.title, 'Discord Server');

      notifier.setCategoryFilter('Work');
      expect(notifier.state.selectedCategory, 'Work');
      expect(notifier.state.filteredItems.length, 1);
      expect(notifier.state.filteredItems.first.title, 'Google Account');

      notifier.setCategoryFilter('All');
      expect(notifier.state.filteredItems.length, 2);
    });

    test('setSearchQuery should filter items in real-time', () async {
      await notifier.loadVaultItems();

      notifier.setSearchQuery('google');
      expect(notifier.state.searchQuery, 'google');
      expect(notifier.state.filteredItems.length, 1);
      expect(notifier.state.filteredItems.first.title, 'Google Account');

      notifier.setSearchQuery('discord');
      expect(notifier.state.filteredItems.length, 1);
      expect(notifier.state.filteredItems.first.title, 'Discord Server');

      notifier.setSearchQuery('');
      expect(notifier.state.filteredItems.length, 2);
    });

    test('should handle repository failures gracefully with error status', () async {
      mockRepository.shouldThrow = true;

      await notifier.loadVaultItems();
      expect(notifier.state.status, VaultStatus.error);
      expect(notifier.state.errorMessage, contains('Database read error'));
    });
  });
}
