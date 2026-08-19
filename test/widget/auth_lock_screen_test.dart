import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:passkeep/features/auth/presentation/providers/auth_providers.dart';
import 'package:passkeep/features/auth/presentation/providers/supabase_auth_providers.dart';
import 'package:passkeep/features/auth/presentation/screens/auth_lock_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

class FakeAuthNotifier extends StateNotifier<AuthState> implements AuthNotifier {
  FakeAuthNotifier(super.state);

  @override
  Future<void> checkAuthState() async {}

  @override
  Future<bool> setupMasterPin(String pin) async => true;

  @override
  Future<bool> unlockWithPin(String pin) async => true;

  @override
  Future<bool> unlockWithExistingPin(String pin) async => true;

  @override
  Future<bool> verifyMasterPin(String pin) async => true;

  @override
  Future<bool> updateMasterPin(String currentPin, String newPin) async => true;

  @override
  Future<bool> unlockWithBiometrics() async => true;

  @override
  void lockVault() {
    state = state.copyWith(status: AuthStatus.locked);
  }

  @override
  void setOfflineOnlyMode(bool isOffline) {
    state = state.copyWith(isOfflineOnlyMode: isOffline);
  }

  @override
  Future<bool> hasLocalPinConfigured() async => true;

  @override
  void signOut() {
    state = state.copyWith(
      status: AuthStatus.uninitialized,
      clearMasterKey: true,
      isOfflineOnlyMode: false,
    );
  }

  @override
  Future<void> resetSession() async {
    state = state.copyWith(
      status: AuthStatus.uninitialized,
      clearMasterKey: true,
      isOfflineOnlyMode: false,
    );
  }
}

class FakeSupabaseUserNotifier extends StateNotifier<SupabaseUserState>
    implements SupabaseUserNotifier {
  FakeSupabaseUserNotifier(super.state);

  @override
  Future<bool> signIn({required String email, required String password}) async => true;

  @override
  Future<bool> signUp({required String email, required String password}) async => true;

  @override
  Future<void> signOut() async {
    state = const SupabaseUserState.initial();
  }

  @override
  Future<void> syncLocalSaltToCloud(String salt) async {}
}

void main() {
  testWidgets('AuthLockScreen renders title, indicators, keypad, and reset button',
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

    // Verify reset button exists
    expect(find.text('Having trouble? Reset Session / Sign Out'), findsOneWidget);

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

  testWidgets('AuthLockScreen shows reset session dialog and resets on confirm',
      (WidgetTester tester) async {
    final fakeAuth = FakeAuthNotifier(
      const AuthState(status: AuthStatus.locked),
    );
    final fakeSupabase = FakeSupabaseUserNotifier(
      const SupabaseUserState(
        user: sb.User(
          id: 'user-lock-1',
          appMetadata: {},
          userMetadata: {},
          aud: 'authenticated',
          createdAt: '2026-01-01',
          email: 'locked@passkeep.io',
        ),
      ),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authNotifierProvider.overrideWith((ref) => fakeAuth),
          supabaseUserProvider.overrideWith((ref) => fakeSupabase),
        ],
        child: const MaterialApp(
          home: AuthLockScreen(),
        ),
      ),
    );

    final resetBtn = find.text('Having trouble? Reset Session / Sign Out');
    expect(resetBtn, findsOneWidget);
    await tester.ensureVisible(resetBtn);
    await tester.tap(resetBtn);
    await tester.pumpAndSettle();

    // Verify dialog
    expect(find.text('Reset Session / Sign Out'), findsOneWidget);
    expect(
      find.text('This will sign you out and clear local cached session keys. Your cloud data remains safe in Supabase.'),
      findsOneWidget,
    );

    // Tap Cancel first to test dismissal
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.text('Reset Session / Sign Out'), findsNothing);
    expect(fakeAuth.state.status, AuthStatus.locked);

    // Open dialog again and tap confirm
    await tester.tap(resetBtn);
    await tester.pumpAndSettle();

    final confirmBtn = find.widgetWithText(ElevatedButton, 'Reset & Sign Out');
    await tester.tap(confirmBtn);
    await tester.pumpAndSettle();

    // Verify reset
    expect(fakeAuth.state.status, AuthStatus.uninitialized);
    expect(fakeSupabase.state.user, isNull);
  });
}

