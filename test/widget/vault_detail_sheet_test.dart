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
}
