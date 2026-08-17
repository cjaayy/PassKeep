import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:passkeep/app.dart';

void main() {
  testWidgets('PassKeepApp launches and displays brand title', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: PassKeepApp(),
      ),
    );

    expect(find.text('PassKeep'), findsOneWidget);
    expect(find.text('Zero-Knowledge Encrypted Password Manager'), findsOneWidget);
  });
}
