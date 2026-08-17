import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:passkeep/features/auth/presentation/screens/auth_lock_screen.dart';

void main() {
  testWidgets('AuthLockScreen renders title, indicators, and numeric keypad',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: AuthLockScreen(),
        ),
      ),
    );

    // Verify title and prompt
    expect(find.text('PassKeep Vault'), findsOneWidget);
    expect(find.text('Enter Master PIN to Unlock'), findsOneWidget);

    // Verify keypad buttons 0-9
    for (int i = 0; i <= 9; i++) {
      expect(find.text('$i'), findsOneWidget);
    }

    // Tap digit '1' and digit '2'
    await tester.tap(find.text('1'));
    await tester.pump();
    await tester.tap(find.text('2'));
    await tester.pump();

    // Verify backspace icon is present and clickable
    expect(find.byIcon(Icons.backspace_outlined), findsOneWidget);
    await tester.tap(find.byIcon(Icons.backspace_outlined));
    await tester.pump();
  });
}
