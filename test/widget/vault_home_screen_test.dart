import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:passkeep/features/vault/data/datasources/vault_local_datasource.dart';
import 'package:passkeep/features/vault/data/models/vault_item.dart';
import 'package:passkeep/features/vault/presentation/providers/vault_providers.dart';
import 'package:passkeep/features/vault/presentation/screens/vault_home_screen.dart';

class FakeWidgetLocalDataSource implements IVaultLocalDataSource {
  final List<VaultItem> items = [];

  @override
  Future<List<VaultItem>> getAllVaultItems() async => List.from(items);

  @override
  Future<VaultItem?> getVaultItemById(String id) async =>
      items.firstWhere((i) => i.id == id);

  @override
  Future<void> saveVaultItem(VaultItem item) async => items.add(item);

  @override
  Future<void> deleteVaultItem(String id) async => items.removeWhere((i) => i.id == id);

  @override
  Future<void> clearAll() async => items.clear();
}

void main() {
  testWidgets('VaultHomeScreen displays title, search bar, categories, and FAB',
      (WidgetTester tester) async {
    final fakeLocal = FakeWidgetLocalDataSource();
    fakeLocal.items.add(
      VaultItem(
        id: 'test-1',
        title: 'GitHub Enterprise',
        usernameEncrypted: 'enc_user',
        passwordEncrypted: 'enc_pass',
        iv: 'iv_val',
        category: 'Work',
        updatedAt: DateTime.now(),
      ),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          vaultLocalDataSourceProvider.overrideWithValue(fakeLocal),
        ],
        child: const MaterialApp(
          home: VaultHomeScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Verify App Bar & Brand
    expect(find.text('PassKeep'), findsOneWidget);

    // Verify Search Input
    expect(find.byType(TextField), findsOneWidget);

    // Verify Category Chips
    expect(find.widgetWithText(FilterChip, 'All'), findsOneWidget);
    expect(find.widgetWithText(FilterChip, 'Work'), findsOneWidget);
    expect(find.widgetWithText(FilterChip, 'Social'), findsOneWidget);
    expect(find.widgetWithText(FilterChip, 'Finance'), findsOneWidget);
    expect(find.widgetWithText(FilterChip, 'Personal'), findsOneWidget);

    // Verify Loaded Item Card
    expect(find.text('GitHub Enterprise'), findsOneWidget);

    // Verify FAB
    expect(find.text('Add Password'), findsOneWidget);
  });
}
