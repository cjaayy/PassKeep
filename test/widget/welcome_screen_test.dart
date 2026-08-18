import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:passkeep/features/auth/presentation/providers/auth_providers.dart';
import 'package:passkeep/features/auth/presentation/screens/setup_master_pin_screen.dart';
import 'package:passkeep/features/auth/presentation/screens/welcome_screen.dart';
import 'package:passkeep/features/auth/presentation/widgets/supabase_auth_sheet.dart';

void main() {
  testWidgets('WelcomeScreen renders branding, value props, and all action buttons',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: WelcomeScreen(),
        ),
      ),
    );

    // Verify branding
    expect(find.text('PassKeep'), findsOneWidget);
    expect(find.text('Zero-Knowledge Password Manager'), findsOneWidget);
    expect(find.byIcon(Icons.shield_rounded), findsOneWidget);

    // Verify feature highlights
    expect(find.text('Client-Side AES-256 Encryption'), findsOneWidget);
    expect(find.text('Offline-First & Local-First'), findsOneWidget);
    expect(find.text('Optional Cloud Synchronization'), findsOneWidget);

    // Verify action buttons
    expect(find.text('Create Account'), findsOneWidget);
    expect(find.text('Sign In to Existing Account'), findsOneWidget);
    expect(find.text('Continue Offline (Local Storage Only)'), findsOneWidget);
  });

  testWidgets('Tapping Continue Offline navigates to SetupMasterPinScreen',
      (WidgetTester tester) async {
    final container = ProviderContainer();

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: WelcomeScreen(),
        ),
      ),
    );

    final continueBtn = find.text('Continue Offline (Local Storage Only)');
    expect(continueBtn, findsOneWidget);

    await tester.ensureVisible(continueBtn);
    await tester.pumpAndSettle();
    await tester.tap(continueBtn);
    await tester.pumpAndSettle();

    // Verify navigation to PIN setup screen
    expect(find.byType(SetupMasterPinScreen), findsOneWidget);
    expect(find.text('Create Master PIN'), findsOneWidget);

    // Verify offlineOnly state was set
    expect(container.read(authNotifierProvider).isOfflineOnlyMode, isTrue);

    container.dispose();
  });

  testWidgets('Tapping Create Account opens SupabaseAuthSheet with Register tab',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: WelcomeScreen(),
        ),
      ),
    );

    final createBtn = find.text('Create Account');
    await tester.ensureVisible(createBtn);
    await tester.pumpAndSettle();
    await tester.tap(createBtn);
    await tester.pumpAndSettle();

    expect(find.byType(SupabaseAuthSheet), findsOneWidget);
    expect(find.text('Supabase Cloud Account'), findsOneWidget);
    expect(find.text('Create Account & Connect'), findsOneWidget);
  });

  testWidgets('Tapping Sign In opens SupabaseAuthSheet with Sign In tab',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: WelcomeScreen(),
        ),
      ),
    );

    final signInBtn = find.text('Sign In to Existing Account');
    await tester.ensureVisible(signInBtn);
    await tester.pumpAndSettle();
    await tester.tap(signInBtn);
    await tester.pumpAndSettle();

    expect(find.byType(SupabaseAuthSheet), findsOneWidget);
    expect(find.text('Supabase Cloud Account'), findsOneWidget);
    expect(find.text('Sign In & Sync Vault'), findsOneWidget);
  });
}
