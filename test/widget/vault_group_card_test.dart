import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:passkeep/features/vault/data/models/vault_item.dart';
import 'package:passkeep/features/vault/presentation/providers/vault_state.dart';
import 'package:passkeep/features/vault/presentation/widgets/vault_group_card.dart';

void main() {
  testWidgets('VaultGroupCard displays generic account labels, brand icons, and explicit View button on expansion',
      (WidgetTester tester) async {
    VaultItem? tappedItem;

    final item1 = VaultItem(
      id: 'google-1',
      title: 'Google',
      usernameEncrypted: 'enc_primary@gmail.com',
      passwordEncrypted: 'enc_pass1',
      iv: 'iv_1',
      category: 'Personal',
      updatedAt: DateTime.now(),
    );

    final item2 = VaultItem(
      id: 'google-2',
      title: 'Google',
      usernameEncrypted: 'enc_work@google.com',
      passwordEncrypted: 'enc_pass2',
      iv: 'iv_2',
      category: 'Work',
      updatedAt: DateTime.now(),
    );

    final group = VaultItemGroup(
      title: 'Google',
      items: [item1, item2],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: VaultGroupCard(
            group: group,
            onItemTap: (item) => tappedItem = item,
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Verify Group Header
    expect(find.text('Google'), findsOneWidget);
    expect(find.text('2 ACCOUNTS'), findsOneWidget);
    expect(find.text('• Tap to expand'), findsOneWidget);

    // Expand Group
    await tester.tap(find.text('Google'));
    await tester.pumpAndSettle();

    // Verify Sub-Accounts are labeled generically as "Account 1" and "Account 2"
    expect(find.text('Account 1'), findsOneWidget);
    expect(find.text('Account 2'), findsOneWidget);

    // Verify raw emails are NOT visible
    expect(find.text('primary@gmail.com'), findsNothing);
    expect(find.text('work@google.com'), findsNothing);
    expect(find.text('enc_primary@gmail.com'), findsNothing);

    // Verify NO copy buttons exist on sub-account rows
    expect(find.byIcon(Icons.copy_rounded), findsNothing);

    // Verify explicit "View" buttons exist on each sub-account row
    final viewButtons = find.text('View');
    expect(viewButtons, findsNWidgets(2));

    // Tap "View" button for Account 1
    await tester.tap(viewButtons.first);
    await tester.pumpAndSettle();

    expect(tappedItem, isNotNull);
    expect(tappedItem!.id, 'google-1');

    // Tap "View" button for Account 2
    await tester.tap(viewButtons.last);
    await tester.pumpAndSettle();

    expect(tappedItem!.id, 'google-2');
  });
}
