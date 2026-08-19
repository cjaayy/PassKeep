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
  Future<void> saveVaultItem(VaultItem item) async {
    final idx = items.indexWhere((i) => i.id == item.id);
    if (idx >= 0) {
      items[idx] = item;
    } else {
      items.add(item);
    }
  }

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

    // Ensure Category dropdown is visible and select 'Work'
    await tester.ensureVisible(find.text('General'));
    await tester.pumpAndSettle();
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

  testWidgets('AddEditVaultScreen encrypts account number into usernameEncrypted when email is empty',
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

    // Verify saved item
    expect(fakeLocal.items.length, 1);
    final savedItem = fakeLocal.items.first;
    expect(savedItem.accountNumber, '09189876543');

    // Verify usernameEncrypted holds the encrypted account number (not empty string)
    expect(savedItem.usernameEncrypted.isNotEmpty, true);
    final decryptedUser = encryptionService.decrypt(
      cipherTextBase64: savedItem.usernameEncrypted,
      ivBase64: savedItem.iv,
    );
    expect(decryptedUser, '09189876543');
    expect(savedItem.getPrimaryIdentifier(decryptedUsername: decryptedUser), '09189876543');
  });

  testWidgets('AddEditVaultScreen in edit mode correctly populates account number field',
      (WidgetTester tester) async {
    final fakeLocal = FakeLocalDataSource();
    final encryptionService = EncryptionService(secureStorage: FakeSecureStorage());
    encryptionService.setActiveKey('0123456789abcdef0123456789abcdef');

    final userEnc = encryptionService.encrypt('09189876543');
    final passEnc = encryptionService.encrypt('654321', customIvBase64: userEnc.ivBase64);

    final existingItem = VaultItem(
      id: 'gcash-item-1',
      title: 'GCash',
      usernameEncrypted: userEnc.cipherTextBase64,
      passwordEncrypted: passEnc.cipherTextBase64,
      iv: userEnc.ivBase64,
      category: 'Finance',
      accountNumber: '09189876543',
      updatedAt: DateTime.now(),
    );

    fakeLocal.items.add(existingItem);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          vaultLocalDataSourceProvider.overrideWithValue(fakeLocal),
          encryptionServiceProvider.overrideWithValue(encryptionService),
        ],
        child: MaterialApp(
          home: AddEditVaultScreen(existingItem: existingItem),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Verify account number field contains 09189876543
    expect(find.text('09189876543'), findsOneWidget);

    // Verify username field is empty
    final usernameFinder = find.byWidgetPredicate(
      (widget) =>
          widget is TextField &&
          widget.decoration?.hintText == 'name@example.com',
    );
    final usernameField = tester.widget<TextField>(usernameFinder);
    expect(usernameField.controller?.text, '');
  });

  testWidgets('AddEditVaultScreen rejects submission if all credential fields are empty',
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

    // Leave all credential fields (username, email, account, phone, pin, password) empty
    // Attempt save
    await tester.tap(find.byTooltip('Save Item'));
    await tester.pumpAndSettle();

    // Verify item was NOT saved and validation error is shown
    expect(fakeLocal.items.isEmpty, true);
    expect(
      find.textContaining('at least one credential field'),
      findsWidgets,
    );
  });

  testWidgets('AddEditVaultScreen creates and saves Payment Card entry successfully',
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
          home: AddEditVaultScreen(vaultType: VaultType.card),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Enter Card Title
    final cardTitleFinder = find.byWidgetPredicate(
      (widget) =>
          widget is TextField &&
          widget.decoration?.hintText == 'e.g. BPI Gold Visa, GCash Card, Maya Card',
    );
    await tester.enterText(cardTitleFinder, 'BPI Gold Visa');
    await tester.pumpAndSettle();

    // Enter Cardholder Name
    final cardholderFinder = find.byWidgetPredicate(
      (widget) =>
          widget is TextField &&
          widget.decoration?.hintText == 'e.g. JUAN DELA CRUZ',
    );
    await tester.enterText(cardholderFinder, 'JUAN DELA CRUZ');
    await tester.pumpAndSettle();

    // Enter Card Number
    final cardNumberFinder = find.byWidgetPredicate(
      (widget) =>
          widget is TextField &&
          widget.decoration?.hintText == 'XXXX XXXX XXXX XXXX',
    );
    await tester.enterText(cardNumberFinder, '4123456789012345');
    await tester.pumpAndSettle();

    // Enter Expiry
    final expiryFinder = find.byWidgetPredicate(
      (widget) =>
          widget is TextField &&
          widget.decoration?.hintText == 'MM/YY',
    );
    await tester.enterText(expiryFinder, '1228');
    await tester.pumpAndSettle();

    // Enter CVV
    final cvvFinder = find.byWidgetPredicate(
      (widget) =>
          widget is TextField &&
          widget.decoration?.hintText == '123',
    );
    await tester.enterText(cvvFinder, '456');
    await tester.pumpAndSettle();

    // Save Card
    await tester.tap(find.byTooltip('Save Item'));
    await tester.pumpAndSettle();

    // Verify saved item
    expect(fakeLocal.items.length, 1);
    final savedCard = fakeLocal.items.first;
    expect(savedCard.isCard, isTrue);
    expect(savedCard.type, 'card');
    expect(savedCard.title, 'Bpi Gold Visa');
    expect(savedCard.category, 'Cards');
    expect(savedCard.accountNumber, '•••• •••• •••• 2345');
    expect(savedCard.cardDetailsEnc, isNotNull);
  });

  testWidgets('AddEditVaultScreen formats phone number with selected country code',
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

    // Verify default country code +63 flag is rendered
    expect(find.text('🇵🇭'), findsOneWidget);
    expect(find.text('+63'), findsOneWidget);

    // Enter local phone number digits
    final phoneFinder = find.byWidgetPredicate(
      (widget) =>
          widget is TextField &&
          widget.decoration?.hintText == '917 123 4567',
    );
    expect(phoneFinder, findsOneWidget);
    await tester.enterText(phoneFinder, '9171234567');
    await tester.pumpAndSettle();

    // Save item
    await tester.tap(find.byTooltip('Save Item'));
    await tester.pumpAndSettle();

    // Verify saved item phone number has country code prefix
    expect(fakeLocal.items.length, 1);
    final savedItem = fakeLocal.items.first;
    expect(savedItem.phoneNumber, '+63 9171234567');
  });
}
