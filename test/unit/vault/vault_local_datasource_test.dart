import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:passkeep/core/errors/failures.dart';
import 'package:passkeep/features/vault/data/datasources/vault_local_datasource.dart';
import 'package:passkeep/features/vault/data/models/vault_item.dart';

/// In-memory Fake implementation of [Box<VaultItem>] for isolated unit testing
class FakeVaultBox implements Box<VaultItem> {
  final Map<dynamic, VaultItem> _storage = {};
  final bool _isOpen = true;
  bool shouldThrow = false;

  @override
  bool get isOpen => _isOpen;

  @override
  Iterable<VaultItem> get values {
    if (shouldThrow) throw Exception('Simulated Hive read disk error');
    return _storage.values;
  }

  @override
  VaultItem? get(key, {VaultItem? defaultValue}) {
    if (shouldThrow) throw Exception('Simulated Hive get error');
    return _storage[key] ?? defaultValue;
  }

  @override
  Future<void> put(key, VaultItem value) async {
    if (shouldThrow) throw Exception('Simulated Hive put disk full error');
    _storage[key] = value;
  }

  @override
  Future<void> delete(key) async {
    if (shouldThrow) throw Exception('Simulated Hive delete error');
    _storage.remove(key);
  }

  @override
  Future<int> clear() async {
    if (shouldThrow) throw Exception('Simulated Hive clear error');
    final count = _storage.length;
    _storage.clear();
    return count;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('VaultLocalDataSource Tests', () {
    late FakeVaultBox fakeBox;
    late VaultLocalDataSource dataSource;

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
      title: 'Netflix Account',
      usernameEncrypted: 'enc_user_2',
      passwordEncrypted: 'enc_pass_2',
      iv: 'iv_2',
      category: 'Personal',
      updatedAt: DateTime.parse('2026-08-17T11:00:00Z'),
    );

    setUp(() {
      fakeBox = FakeVaultBox();
      dataSource = VaultLocalDataSource(box: fakeBox);
    });

    test('should save items and retrieve all items successfully', () async {
      await dataSource.saveVaultItem(item1);
      await dataSource.saveVaultItem(item2);

      final items = await dataSource.getAllVaultItems();
      expect(items.length, 2);
      expect(items, contains(item1));
      expect(items, contains(item2));
    });

    test('should get a specific vault item by ID', () async {
      await dataSource.saveVaultItem(item1);

      final found = await dataSource.getVaultItemById('id-1');
      expect(found, isNotNull);
      expect(found!.id, 'id-1');
      expect(found.title, 'Google Account');

      final notFound = await dataSource.getVaultItemById('non-existing-id');
      expect(notFound, isNull);
    });

    test('should update an existing vault item with same ID', () async {
      await dataSource.saveVaultItem(item1);

      final updatedItem = item1.copyWith(title: 'Google Workspace Updated');
      await dataSource.saveVaultItem(updatedItem);

      final result = await dataSource.getVaultItemById('id-1');
      expect(result!.title, 'Google Workspace Updated');
      final all = await dataSource.getAllVaultItems();
      expect(all.length, 1);
    });

    test('should delete an item by ID', () async {
      await dataSource.saveVaultItem(item1);
      await dataSource.saveVaultItem(item2);

      await dataSource.deleteVaultItem('id-1');

      final all = await dataSource.getAllVaultItems();
      expect(all.length, 1);
      expect(all.first.id, 'id-2');
    });

    test('should clear all items in vault storage', () async {
      await dataSource.saveVaultItem(item1);
      await dataSource.saveVaultItem(item2);

      await dataSource.clearAll();

      final all = await dataSource.getAllVaultItems();
      expect(all, isEmpty);
    });

    test('should throw DatabaseFailure when Hive operations encounter errors', () async {
      fakeBox.shouldThrow = true;

      expect(() => dataSource.getAllVaultItems(), throwsA(isA<DatabaseFailure>()));
      expect(() => dataSource.getVaultItemById('id-1'), throwsA(isA<DatabaseFailure>()));
      expect(() => dataSource.saveVaultItem(item1), throwsA(isA<DatabaseFailure>()));
      expect(() => dataSource.deleteVaultItem('id-1'), throwsA(isA<DatabaseFailure>()));
      expect(() => dataSource.clearAll(), throwsA(isA<DatabaseFailure>()));
    });
  });
}
