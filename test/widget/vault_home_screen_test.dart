import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:passkeep/features/auth/presentation/providers/auth_providers.dart';
import 'package:passkeep/features/auth/presentation/providers/supabase_auth_providers.dart';
import 'package:passkeep/features/vault/data/datasources/vault_local_datasource.dart';
import 'package:passkeep/features/vault/data/models/vault_item.dart';
import 'package:passkeep/features/vault/presentation/providers/vault_providers.dart';
import 'package:passkeep/features/vault/presentation/screens/vault_home_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

class FakeWidgetLocalDataSource implements IVaultLocalDataSource {
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
  testWidgets('VaultHomeScreen displays items and hides Cloud Sync button when offline/unauthenticated',
      (WidgetTester tester) async {
    final fakeLocal = FakeWidgetLocalDataSource();
    fakeLocal.items.add(
      VaultItem(
        id: 'test-1',
        title: 'GitHub Enterprise',
        usernameEncrypted: 'enc_user',
        passwordEncrypted: 'enc_pass',
        iv: 'iv_val',
        category: 'Work',
        updatedAt: DateTime.now(),
      ),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          vaultLocalDataSourceProvider.overrideWithValue(fakeLocal),
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
          home: VaultHomeScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Verify App Bar & Brand
    expect(find.text('PassKeep'), findsOneWidget);

    // Verify Cloud Sync button is HIDDEN
    expect(find.byTooltip('Sync with Cloud'), findsNothing);

    // Verify Search Input
    expect(find.byType(TextField), findsOneWidget);

    // Verify Category Chips
    expect(find.widgetWithText(FilterChip, 'ALL'), findsOneWidget);
    expect(find.widgetWithText(FilterChip, 'WORK'), findsOneWidget);

    // Verify Loaded Item Card
    expect(find.text('GitHub Enterprise'), findsOneWidget);

    // Verify FAB
    expect(find.text('ADD PASSWORD'), findsOneWidget);
  });

  testWidgets('VaultHomeScreen shows Cloud Sync button when cloud user is authenticated and not offline',
      (WidgetTester tester) async {
    final fakeLocal = FakeWidgetLocalDataSource();

    final testUser = sb.User(
      id: 'test-user-id',
      appMetadata: {},
      userMetadata: {},
      aud: 'authenticated',
      createdAt: DateTime.now().toIso8601String(),
      email: 'user@example.com',
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          vaultLocalDataSourceProvider.overrideWithValue(fakeLocal),
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
          home: VaultHomeScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Verify Cloud Sync button is VISIBLE
    expect(find.byTooltip('Sync with Cloud'), findsOneWidget);
  });

  testWidgets('VaultHomeScreen groups multiple accounts under the same platform into an expandable card',
      (WidgetTester tester) async {
    final fakeLocal = FakeWidgetLocalDataSource();
    fakeLocal.items.addAll([
      VaultItem(
        id: 'gmail-1',
        title: 'Gmail',
        usernameEncrypted: 'enc_work',
        passwordEncrypted: 'enc_pass_1',
        iv: 'iv_1',
        category: 'Work',
        updatedAt: DateTime.now(),
      ),
      VaultItem(
        id: 'gmail-2',
        title: 'Gmail',
        usernameEncrypted: 'enc_personal',
        passwordEncrypted: 'enc_pass_2',
        iv: 'iv_2',
        category: 'Personal',
        updatedAt: DateTime.now(),
      ),
    ]);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          vaultLocalDataSourceProvider.overrideWithValue(fakeLocal),
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
          home: VaultHomeScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Verify Group Title & Multi-Account Badge
    expect(find.text('Gmail'), findsOneWidget);
    expect(find.text('2 ACCOUNTS'), findsOneWidget);
    expect(find.text('• Tap to expand'), findsOneWidget);

    // Tap to expand group
    await tester.tap(find.text('Gmail'));
    await tester.pumpAndSettle();

    // Verify both account rows are accessible
    expect(find.byIcon(Icons.account_circle_outlined), findsNWidgets(2));
    expect(find.byIcon(Icons.copy_rounded), findsNWidgets(2));
  });
}
