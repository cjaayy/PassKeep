import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:passkeep/features/vault/data/models/vault_item.dart';
import 'package:passkeep/features/vault/presentation/widgets/vault_item_card.dart';

void main() {
  testWidgets('VaultItemCard displays privacy-first subtitle and explicit View button for password item',
      (WidgetTester tester) async {
    bool wasTapped = false;

    final item = VaultItem(
      id: 'pw-1',
      title: 'GitHub Enterprise',
      usernameEncrypted: 'enc_user_secret@example.com',
      passwordEncrypted: 'enc_pass',
      iv: 'iv_val',
      category: 'Work',
      updatedAt: DateTime.now(),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: VaultItemCard(
            item: item,
            onTap: () => wasTapped = true,
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Verify Title & Category
    expect(find.text('GitHub Enterprise'), findsOneWidget);
    expect(find.text('WORK'), findsOneWidget);

    // Verify Privacy: displays generic "1 Saved Account", NOT raw username/email
    expect(find.text('1 Saved Account'), findsOneWidget);
    expect(find.text('enc_user_secret@example.com'), findsNothing);
    expect(find.text('user_secret@example.com'), findsNothing);

    // Verify Explicit "View" Action Button
    expect(find.text('View'), findsOneWidget);
    expect(find.byIcon(Icons.visibility_outlined), findsOneWidget);

    // Tap "View" button
    await tester.tap(find.text('View'));
    await tester.pumpAndSettle();

    expect(wasTapped, isTrue);
  });

  testWidgets('VaultItemCard displays "1 Saved Card" and explicit View button for payment card',
      (WidgetTester tester) async {
    bool wasTapped = false;

    final item = VaultItem(
      id: 'card-1',
      title: 'BDO Visa Gold',
      type: VaultType.card,
      usernameEncrypted: 'Juan Dela Cruz',
      passwordEncrypted: 'enc_pass',
      iv: 'iv_val',
      category: 'Finance',
      accountNumber: '4123456789012345',
      updatedAt: DateTime.now(),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: VaultItemCard(
            item: item,
            onTap: () => wasTapped = true,
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Verify Title & Type
    expect(find.text('BDO Visa Gold'), findsOneWidget);
    expect(find.text('CARD'), findsOneWidget);

    // Verify Privacy: displays "1 Saved Card"
    expect(find.text('1 Saved Card'), findsOneWidget);
    expect(find.text('4123456789012345'), findsNothing);

    // Verify Explicit "View" button
    expect(find.text('View'), findsOneWidget);

    // Tap "View" button
    await tester.tap(find.text('View'));
    await tester.pumpAndSettle();

    expect(wasTapped, isTrue);
  });
}
