import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:passkeep/features/auth/presentation/providers/auth_providers.dart';
import 'package:passkeep/features/auth/presentation/providers/supabase_auth_providers.dart';
import 'package:passkeep/features/settings/presentation/screens/settings_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

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
}

class FakeAuthNotifier extends StateNotifier<AuthState> implements AuthNotifier {
  FakeAuthNotifier(super.state);

  @override
  Future<void> checkAuthState() async {}

  @override
  Future<bool> setupMasterPin(String pin) async => true;

  @override
  Future<bool> unlockWithPin(String pin) async => true;

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
}

void main() {
  testWidgets('SettingsScreen hides Account & Cloud Sync section in Offline-Only Mode',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authNotifierProvider.overrideWith(
            (ref) => FakeAuthNotifier(
              const AuthState(
                status: AuthStatus.authenticated,
                isOfflineOnlyMode: true,
              ),
            ),
          ),
          supabaseUserProvider.overrideWith(
            (ref) => FakeSupabaseUserNotifier(
              const SupabaseUserState.initial(),
            ),
          ),
        ],
        child: const MaterialApp(
          home: SettingsScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Verify Settings Title
    expect(find.text('Settings & Vault'), findsOneWidget);

    // Verify Account & Cloud Sync section is HIDDEN
    expect(find.text('ACCOUNT & CLOUD SYNC'), findsNothing);
    expect(find.text('Cloud Synchronization'), findsNothing);

    // Verify other sections remain accessible
    expect(find.text('DATA TRANSFER & BACKUPS'), findsOneWidget);
    expect(find.text('SECURITY & ACCESS'), findsOneWidget);
    expect(find.text('ABOUT PASSKEEP'), findsOneWidget);
  });

  testWidgets('SettingsScreen renders Account & Cloud Sync when cloud account is connected',
      (WidgetTester tester) async {
    final testUser = sb.User(
      id: 'test-user-id',
      appMetadata: {},
      userMetadata: {},
      aud: 'authenticated',
      createdAt: DateTime.now().toIso8601String(),
      email: 'alex@passkeep.io',
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authNotifierProvider.overrideWith(
            (ref) => FakeAuthNotifier(
              const AuthState(
                status: AuthStatus.authenticated,
                isOfflineOnlyMode: false,
              ),
            ),
          ),
          supabaseUserProvider.overrideWith(
            (ref) => FakeSupabaseUserNotifier(
              SupabaseUserState(user: testUser),
            ),
          ),
        ],
        child: const MaterialApp(
          home: SettingsScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Verify Account & Cloud Sync section is VISIBLE
    expect(find.text('ACCOUNT & CLOUD SYNC'), findsOneWidget);
    expect(find.text('alex@passkeep.io'), findsOneWidget);
    expect(find.text('Cloud Synchronization'), findsOneWidget);
  });
}
