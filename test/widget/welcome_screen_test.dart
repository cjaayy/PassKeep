import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:passkeep/features/auth/presentation/providers/auth_providers.dart';
import 'package:passkeep/features/auth/presentation/providers/supabase_auth_providers.dart';
import 'package:passkeep/features/auth/presentation/screens/setup_master_pin_screen.dart';
import 'package:passkeep/features/auth/presentation/screens/verify_master_pin_screen.dart';
import 'package:passkeep/features/auth/presentation/screens/welcome_screen.dart';
import 'package:passkeep/features/auth/presentation/widgets/supabase_auth_sheet.dart';
import 'package:passkeep/features/sync/domain/services/vault_sync_service.dart';
import 'package:passkeep/features/sync/presentation/providers/sync_providers.dart';
import 'package:passkeep/features/vault/data/datasources/vault_local_datasource.dart';
import 'package:passkeep/features/vault/data/models/vault_item.dart';
import 'package:passkeep/features/vault/presentation/providers/vault_providers.dart';
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

  @override
  Future<void> syncLocalSaltToCloud(String salt) async {}
}

class FakeLocalDataSource implements IVaultLocalDataSource {
  final List<VaultItem> items = [];

  @override
  Future<List<VaultItem>> getAllVaultItems() async => List.from(items);

  @override
  Future<VaultItem?> getVaultItemById(String id) async =>
      items.firstWhere((i) => i.id == id);

  @override
  Future<void> saveVaultItem(VaultItem item) async => items.add(item);

  @override
  Future<void> deleteVaultItem(String id) async => items.removeWhere((i) => i.id == id);

  @override
  Future<void> clearAll() async => items.clear();
}

class FakeSyncNotifier extends StateNotifier<SyncState> implements SyncNotifier {
  FakeSyncNotifier() : super(const SyncState());

  @override
  Future<SyncResult> sync() async => SyncResult(
        pushedCount: 0,
        pulledCount: 0,
        conflictResolvedCount: 0,
        syncedAt: DateTime.now(),
      );

  @override
  Future<SyncResult> migrateAndSync(String userId) async => SyncResult(
        pushedCount: 0,
        pulledCount: 0,
        conflictResolvedCount: 0,
        syncedAt: DateTime.now(),
      );

  @override
  Future<SyncResult> forceUploadLocalVault() async => SyncResult(
        pushedCount: 0,
        pulledCount: 0,
        conflictResolvedCount: 0,
        syncedAt: DateTime.now(),
      );

  @override
  Future<SyncResult> wipeRemoteAndResync() async => SyncResult(
        pushedCount: 0,
        pulledCount: 0,
        conflictResolvedCount: 0,
        syncedAt: DateTime.now(),
      );
}

class WelcomeScreenFakeAuthNotifier extends StateNotifier<AuthState>
    implements AuthNotifier {
  WelcomeScreenFakeAuthNotifier({bool hasPin = false})
      : _hasPin = hasPin,
        super(const AuthState(status: AuthStatus.uninitialized));

  final bool _hasPin;

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
  Future<bool> hasLocalPinConfigured() async => _hasPin;

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

void main() {
  testWidgets('WelcomeScreen renders branding, value props, and all action buttons',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authNotifierProvider.overrideWith(
            (ref) => WelcomeScreenFakeAuthNotifier(),
          ),
        ],
        child: const MaterialApp(
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
    expect(find.text('Continue Offline'), findsOneWidget);
  });

  testWidgets('Tapping Continue Offline with no local PIN navigates to SetupMasterPinScreen',
      (WidgetTester tester) async {
    final fakeAuth = WelcomeScreenFakeAuthNotifier(hasPin: false);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authNotifierProvider.overrideWith((ref) => fakeAuth),
        ],
        child: const MaterialApp(
          home: WelcomeScreen(),
        ),
      ),
    );

    final continueBtn = find.text('Continue Offline');
    expect(continueBtn, findsOneWidget);

    await tester.ensureVisible(continueBtn);
    await tester.pumpAndSettle();
    await tester.tap(continueBtn);
    await tester.pumpAndSettle();

    // Since FakeAuthNotifier has _hasPin = false (no PIN configured),
    // it should navigate to SetupMasterPinScreen
    expect(find.byType(SetupMasterPinScreen), findsOneWidget);
    expect(find.text('Create Master PIN'), findsOneWidget);

    // Verify offlineOnly state was set
    expect(fakeAuth.state.isOfflineOnlyMode, isTrue);
  });

  testWidgets('Tapping Continue Offline with existing local PIN locks vault to prompt for Master PIN',
      (WidgetTester tester) async {
    final fakeAuth = WelcomeScreenFakeAuthNotifier(hasPin: true);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authNotifierProvider.overrideWith((ref) => fakeAuth),
        ],
        child: const MaterialApp(
          home: WelcomeScreen(),
        ),
      ),
    );

    final continueBtn = find.text('Continue Offline');
    expect(continueBtn, findsOneWidget);

    await tester.ensureVisible(continueBtn);
    await tester.pumpAndSettle();
    await tester.tap(continueBtn);
    await tester.pumpAndSettle();

    // With existing PIN, lockVault() is called (status becomes locked)
    expect(fakeAuth.state.status, AuthStatus.locked);
    expect(fakeAuth.state.isOfflineOnlyMode, isTrue);
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

  testWidgets('Successful sign-in with existing remote salt routes to VerifyMasterPinScreen',
      (WidgetTester tester) async {
    final existingUser = sb.User(
      id: 'existing-user-123',
      appMetadata: {},
      userMetadata: {'master_pin_salt': 'existing_cloud_salt_abc'},
      aud: 'authenticated',
      createdAt: DateTime.now().toIso8601String(),
      email: 'alex@passkeep.io',
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          syncNotifierProvider.overrideWith((ref) => FakeSyncNotifier()),
          vaultLocalDataSourceProvider.overrideWithValue(FakeLocalDataSource()),
          supabaseUserProvider.overrideWith(
            (ref) => FakeSupabaseUserNotifier(
              SupabaseUserState(user: existingUser),
            ),
          ),
        ],
        child: const MaterialApp(
          home: WelcomeScreen(),
        ),
      ),
    );

    // Tap Sign In to open sheet
    final signInBtn = find.text('Sign In to Existing Account');
    await tester.ensureVisible(signInBtn);
    await tester.pumpAndSettle();
    await tester.tap(signInBtn);
    await tester.pumpAndSettle();

    // Enter email and password
    final emailField = find.widgetWithText(TextFormField, 'Email address');
    final passField = find.widgetWithText(TextFormField, 'Account password');
    await tester.enterText(emailField, 'alex@passkeep.io');
    await tester.enterText(passField, 'password123');
    await tester.pumpAndSettle();

    // In the sheet, tap Sign In button
    final submitBtn = find.widgetWithText(ElevatedButton, 'Sign In & Sync Vault');
    await tester.ensureVisible(submitBtn);
    await tester.pumpAndSettle();
    await tester.tap(submitBtn);
    await tester.pumpAndSettle();

    // Verify routed to VerifyMasterPinScreen because remote salt exists
    expect(find.byType(VerifyMasterPinScreen), findsOneWidget);
    expect(find.text('Enter Master PIN'), findsOneWidget);
    expect(find.text('Enter your existing Master PIN to unlock and decrypt your vault'), findsOneWidget);
    expect(find.text('alex@passkeep.io'), findsOneWidget);
  });

  testWidgets('Successful sign-up without remote salt routes to SetupMasterPinScreen',
      (WidgetTester tester) async {
    final newUser = sb.User(
      id: 'new-user-123',
      appMetadata: {},
      userMetadata: {}, // No master_pin_salt
      aud: 'authenticated',
      createdAt: DateTime.now().toIso8601String(),
      email: 'newuser@passkeep.io',
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          syncNotifierProvider.overrideWith((ref) => FakeSyncNotifier()),
          vaultLocalDataSourceProvider.overrideWithValue(FakeLocalDataSource()),
          supabaseUserProvider.overrideWith(
            (ref) => FakeSupabaseUserNotifier(
              SupabaseUserState(user: newUser),
            ),
          ),
        ],
        child: const MaterialApp(
          home: WelcomeScreen(),
        ),
      ),
    );

    // Tap Create Account to open sheet
    final createBtn = find.text('Create Account');
    await tester.ensureVisible(createBtn);
    await tester.pumpAndSettle();
    await tester.tap(createBtn);
    await tester.pumpAndSettle();

    // Enter email and passwords
    final emailField = find.widgetWithText(TextFormField, 'Email address');
    final passField = find.widgetWithText(TextFormField, 'Password (min. 6 characters)');
    final confirmPassField = find.widgetWithText(TextFormField, 'Confirm password');
    await tester.enterText(emailField, 'newuser@passkeep.io');
    await tester.enterText(passField, 'password123');
    await tester.enterText(confirmPassField, 'password123');
    await tester.pumpAndSettle();

    // In the sheet, tap Create Account & Connect
    final submitBtn = find.widgetWithText(ElevatedButton, 'Create Account & Connect');
    await tester.ensureVisible(submitBtn);
    await tester.pumpAndSettle();
    await tester.tap(submitBtn);
    await tester.pumpAndSettle();

    // Verify routed to SetupMasterPinScreen
    expect(find.byType(SetupMasterPinScreen), findsOneWidget);
    expect(find.text('Create Master PIN'), findsOneWidget);
  });
}
