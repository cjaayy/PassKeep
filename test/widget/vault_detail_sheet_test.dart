import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:passkeep/core/security/encryption_service.dart';
import 'package:passkeep/core/security/security_providers.dart';
import 'package:passkeep/features/vault/data/models/vault_item.dart';
import 'package:passkeep/features/vault/presentation/widgets/vault_detail_sheet.dart';

class FakeSecureStorage extends Fake implements FlutterSecureStorage {}

void main() {
  testWidgets('VaultDetailSheet renders Account/Phone Number and hides Username when username is empty',
      (WidgetTester tester) async {
    final encryptionService = EncryptionService(secureStorage: FakeSecureStorage());
    encryptionService.setActiveKey('0123456789abcdef0123456789abcdef');

    final userEnc = encryptionService.encrypt('09171234567');
    final passEnc = encryptionService.encrypt('123456', customIvBase64: userEnc.ivBase64);

    final item = VaultItem(
      id: 'gcash-1',
      title: 'GCash',
      usernameEncrypted: userEnc.cipherTextBase64,
      passwordEncrypted: passEnc.cipherTextBase64,
      iv: userEnc.ivBase64,
      category: 'Finance',
      accountNumber: '09171234567',
      updatedAt: DateTime.now(),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          encryptionServiceProvider.overrideWithValue(encryptionService),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: VaultDetailSheet(item: item),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Verify Title
    expect(find.text('GCash'), findsOneWidget);

    // Verify Username/Email tile is NOT present (because plainUsername == accountNumber)
    expect(find.text('Username / Email'), findsNothing);

    // Verify Account/Phone Number tile IS present with copy action
    expect(find.text('Account / Phone Number'), findsOneWidget);
    expect(find.text('09171234567'), findsOneWidget);
    expect(find.byTooltip('Copy Account Number'), findsOneWidget);
  });

  testWidgets('VaultDetailSheet renders Username/Email and hides Account/Phone Number when account number is empty',
      (WidgetTester tester) async {
    final encryptionService = EncryptionService(secureStorage: FakeSecureStorage());
    encryptionService.setActiveKey('0123456789abcdef0123456789abcdef');

    final userEnc = encryptionService.encrypt('user@example.com');
    final passEnc = encryptionService.encrypt('SecretPassword!', customIvBase64: userEnc.ivBase64);

    final item = VaultItem(
      id: 'github-1',
      title: 'GitHub',
      usernameEncrypted: userEnc.cipherTextBase64,
      passwordEncrypted: passEnc.cipherTextBase64,
      iv: userEnc.ivBase64,
      category: 'Work',
      updatedAt: DateTime.now(),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          encryptionServiceProvider.overrideWithValue(encryptionService),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: VaultDetailSheet(item: item),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Verify Title
    expect(find.text('GitHub'), findsOneWidget);

    // Verify Username/Email tile IS present with copy action
    expect(find.text('Username / Email'), findsOneWidget);
    expect(find.text('user@example.com'), findsOneWidget);
    expect(find.byTooltip('Copy Username'), findsOneWidget);

    // Verify Account/Phone Number tile is NOT present
    expect(find.text('Account / Phone Number'), findsNothing);
  });

  testWidgets('VaultDetailSheet renders virtual Payment Card and dedicated fields correctly',
      (WidgetTester tester) async {
    final encryptionService = EncryptionService(secureStorage: FakeSecureStorage());
    encryptionService.setActiveKey('0123456789abcdef0123456789abcdef');

    const cardPayload = '{"cardholderName":"JUAN DELA CRUZ","cardNumber":"4123 4567 8901 2345","expiryDate":"12/28","cvv":"123"}';
    final enc = encryptionService.encrypt(cardPayload);

    final cardItem = VaultItem(
      id: 'card-1',
      title: 'BPI Gold Visa',
      type: 'card',
      usernameEncrypted: '',
      passwordEncrypted: '',
      cardDetailsEnc: enc.cipherTextBase64,
      iv: enc.ivBase64,
      category: 'Finance',
      accountNumber: '•••• •••• •••• 2345',
      updatedAt: DateTime.now(),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          encryptionServiceProvider.overrideWithValue(encryptionService),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: VaultDetailSheet(item: cardItem),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Verify Title & Type Badge
    expect(find.text('BPI Gold Visa'), findsOneWidget);
    expect(find.text('PAYMENT CARD'), findsOneWidget);

    // Verify Card Brand is detected
    expect(find.text('VISA'), findsOneWidget);

    // Verify Cardholder Name
    expect(find.text('JUAN DELA CRUZ'), findsWidgets);

    // Verify Masked Card Number
    expect(find.text('•••• •••• •••• 2345'), findsWidgets);

    // Verify Expiry & CVV
    expect(find.text('12/28'), findsWidgets);
    expect(find.text('•••'), findsOneWidget);

    // Tap to show CVV
    await tester.tap(find.byTooltip('Toggle CVV'));
    await tester.pumpAndSettle();
    expect(find.text('123'), findsOneWidget);
  });
}
