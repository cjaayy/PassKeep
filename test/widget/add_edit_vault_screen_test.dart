import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:passkeep/core/security/encryption_service.dart';
import 'package:passkeep/core/security/security_providers.dart';
import 'package:passkeep/features/vault/data/datasources/vault_local_datasource.dart';
import 'package:passkeep/features/vault/data/models/vault_item.dart';
import 'package:passkeep/features/vault/presentation/providers/vault_providers.dart';
import 'package:passkeep/features/vault/presentation/screens/add_edit_vault_screen.dart';

class FakeSecureStorage extends Fake implements FlutterSecureStorage {}

class FakeLocalDataSource implements IVaultLocalDataSource {
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
  test('TitleCase function correctly formats strings', () {
    expect(toTitleCase('work vpn'), 'Work Vpn');
    expect(toTitleCase('my secure bank app'), 'My Secure Bank App');
    expect(toTitleCase('GITHUB'), 'Github');
    expect(toTitleCase(''), '');
  });

  testWidgets('AddEditVaultScreen saves custom service with Title Case formatting',
      (WidgetTester tester) async {
    final fakeLocal = FakeLocalDataSource();
    final encryptionService = EncryptionService(secureStorage: FakeSecureStorage());
    encryptionService.setActiveKey('0123456789abcdef0123456789abcdef');

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          vaultLocalDataSourceProvider.overrideWithValue(fakeLocal),
          encryptionServiceProvider.overrideWithValue(encryptionService),
        ],
        child: const MaterialApp(
          home: AddEditVaultScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Verify Title / Platform Service Dropdown exists
    expect(find.text('TITLE / PLATFORM SERVICE'), findsOneWidget);
    expect(find.text('Google / Gmail'), findsOneWidget);

    // Select 'Custom...' from Service Dropdown
    await tester.tap(find.text('Google / Gmail'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Custom...').last);
    await tester.pumpAndSettle();

    // Enter custom service name in lowercase
    final customServiceFinder = find.byWidgetPredicate(
      (widget) =>
          widget is TextField &&
          widget.decoration?.hintText == 'Enter custom service name (e.g. Work Vpn)',
    );
    expect(customServiceFinder, findsOneWidget);
    await tester.enterText(customServiceFinder, 'work vpn portal');
    await tester.pumpAndSettle();

    // Select 'Work' Category
    await tester.tap(find.text('General'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Work').last);
    await tester.pumpAndSettle();

    // Enter username & password
    final usernameFinder = find.byWidgetPredicate(
      (widget) =>
          widget is TextField &&
          widget.decoration?.hintText == 'name@example.com',
    );
    await tester.enterText(usernameFinder, 'alex@company.com');

    final passwordFinder = find.byWidgetPredicate(
      (widget) =>
          widget is TextField &&
          widget.decoration?.hintText == 'Enter or generate password / PIN',
    );
    await tester.enterText(passwordFinder, 'SuperSecretPass123!');
    await tester.pumpAndSettle();

    // Tap Save button in AppBar or bottom
    await tester.tap(find.byTooltip('Save Item'));
    await tester.pumpAndSettle();

    // Verify saved item
    expect(fakeLocal.items.length, 1);
    final savedItem = fakeLocal.items.first;
    expect(savedItem.title, 'Work Vpn Portal');
    expect(savedItem.category, 'Work');
  });

  testWidgets('AddEditVaultScreen saves item with only Account/Phone Number (e-wallet/banking)',
      (WidgetTester tester) async {
    final fakeLocal = FakeLocalDataSource();
    final encryptionService = EncryptionService(secureStorage: FakeSecureStorage());
    encryptionService.setActiveKey('0123456789abcdef0123456789abcdef');

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          vaultLocalDataSourceProvider.overrideWithValue(fakeLocal),
          encryptionServiceProvider.overrideWithValue(encryptionService),
        ],
        child: const MaterialApp(
          home: AddEditVaultScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Leave username empty, only enter Account / Phone Number
    final accountFinder = find.byWidgetPredicate(
      (widget) =>
          widget is TextField &&
          widget.decoration?.hintText == 'e.g. 09171234567, 1234-5678-90',
    );
    expect(accountFinder, findsOneWidget);
    await tester.enterText(accountFinder, '09189876543');

    // Enter PIN
    final passwordFinder = find.byWidgetPredicate(
      (widget) =>
          widget is TextField &&
          widget.decoration?.hintText == 'Enter or generate password / PIN',
    );
    await tester.enterText(passwordFinder, '654321');
    await tester.pumpAndSettle();

    // Save item
    await tester.tap(find.byTooltip('Save Item'));
    await tester.pumpAndSettle();

    // Verify saved item without username
    expect(fakeLocal.items.length, 1);
    final savedItem = fakeLocal.items.first;
    expect(savedItem.category, 'General');
    expect(savedItem.accountNumber, '09189876543');
  });

  testWidgets('AddEditVaultScreen rejects submission if both Username and Account Number are empty',
      (WidgetTester tester) async {
    final fakeLocal = FakeLocalDataSource();
    final encryptionService = EncryptionService(secureStorage: FakeSecureStorage());
    encryptionService.setActiveKey('0123456789abcdef0123456789abcdef');

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          vaultLocalDataSourceProvider.overrideWithValue(fakeLocal),
          encryptionServiceProvider.overrideWithValue(encryptionService),
        ],
        child: const MaterialApp(
          home: AddEditVaultScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Enter password only
    final passwordFinder = find.byWidgetPredicate(
      (widget) =>
          widget is TextField &&
          widget.decoration?.hintText == 'Enter or generate password / PIN',
    );
    await tester.enterText(passwordFinder, 'SecretPass123!');
    await tester.pumpAndSettle();

    // Attempt save
    await tester.tap(find.byTooltip('Save Item'));
    await tester.pumpAndSettle();

    // Verify item was NOT saved and validation error is shown
    expect(fakeLocal.items.isEmpty, true);
    expect(
      find.text('Enter either Username/Email or Account/Phone Number'),
      findsWidgets,
    );
  });
}
