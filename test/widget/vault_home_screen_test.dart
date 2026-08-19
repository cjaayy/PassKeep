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

  @override
  Future<void> syncLocalSaltToCloud(String salt) async {}
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
  Future<bool> verifyMasterPin(String pin) async => true;

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
  testWidgets('VaultHomeScreen displays items and Bottom Navigation Bar',
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

    // Verify Bottom Navigation Bar Destinations
    expect(find.text('Passwords'), findsOneWidget);
    expect(find.text('Add'), findsOneWidget);
    expect(find.text('Cards'), findsOneWidget);
    expect(find.text('Settings'), findsOneWidget);
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

    // Verify both sub-account rows are accessible with generic labels and View buttons
    expect(find.text('Account 1'), findsOneWidget);
    expect(find.text('Account 2'), findsOneWidget);
    expect(find.text('View'), findsNWidgets(2));
    expect(find.byIcon(Icons.copy_rounded), findsNothing);
  });

  testWidgets('VaultHomeScreen enforces privacy-first subtitle and displays category badge',
      (WidgetTester tester) async {
    final fakeLocal = FakeWidgetLocalDataSource();
    fakeLocal.items.add(
      VaultItem(
        id: 'gcash-1',
        title: 'GCash',
        usernameEncrypted: '',
        passwordEncrypted: 'enc_pass',
        iv: 'iv_val',
        category: 'Finance',
        accountNumber: '09171234567',
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

    // Verify Title and Privacy-First Subtitle
    expect(find.text('GCash'), findsOneWidget);
    expect(find.text('1 Saved Account'), findsOneWidget);
    expect(find.text('09171234567'), findsNothing);
    expect(find.text('View'), findsOneWidget);
  });

  testWidgets('VaultHomeScreen renders all predefined and custom categories in filter bar, and shows empty state',
      (WidgetTester tester) async {
    final fakeLocal = FakeWidgetLocalDataSource();
    fakeLocal.items.add(
      VaultItem(
        id: 'crypto-1',
        title: 'Binance',
        usernameEncrypted: 'enc_user',
        passwordEncrypted: 'enc_pass',
        iv: 'iv_val',
        category: 'Crypto', // Custom category
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

    // Verify predefined chips are present
    expect(find.text('ALL'), findsOneWidget);
    expect(find.text('GENERAL'), findsOneWidget);
    expect(find.text('PERSONAL'), findsOneWidget);
    expect(find.text('WORK'), findsOneWidget);

    // Verify custom category chip 'CRYPTO' is present
    final listFinder = find.byType(ListView).first;
    await tester.drag(listFinder, const Offset(-300, 0));
    await tester.pumpAndSettle();
    expect(find.text('CRYPTO'), findsOneWidget);

    // Tap 'SCHOOL' chip (which has 0 items)
    await tester.drag(listFinder, const Offset(300, 0));
    await tester.pumpAndSettle();
    await tester.tap(find.text('SCHOOL'));
    await tester.pumpAndSettle();

    // Verify empty category state
    expect(find.text('School is Empty'), findsOneWidget);
    expect(find.text('No passwords saved in this category yet.'), findsOneWidget);
  });

  testWidgets('VaultHomeScreen switches to Cards tab without category chips and context-aware Add opens Card form',
      (WidgetTester tester) async {
    final fakeLocal = FakeWidgetLocalDataSource();
    fakeLocal.items.add(
      VaultItem(
        id: 'card-1',
        title: 'BDO Visa Gold',
        type: 'card',
        usernameEncrypted: 'Juan Dela Cruz',
        passwordEncrypted: '4123456789012345',
        iv: 'iv_val',
        category: 'Finance',
        accountNumber: '4123456789012345',
        cardDetailsEnc: '{"cardholderName":"Juan Dela Cruz","cardNumber":"4123 4567 8901 2345","expiryDate":"12/28","cvv":"123"}',
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

    // Switch to Cards tab
    await tester.tap(find.text('Cards'));
    await tester.pumpAndSettle();

    // Verify Cards screen title and card item
    expect(find.text('Payment Cards'), findsOneWidget);
    expect(find.text('BDO Visa Gold'), findsOneWidget);

    // Tap Add button in Bottom Navigation Bar (Context-aware: opens Card form directly)
    await tester.tap(find.text('Add'));
    await tester.pumpAndSettle();

    // Verify AddEditVaultScreen opened in Payment Card mode
    expect(find.text('New Payment Card'), findsOneWidget);
    expect(find.text('CARDHOLDER NAME'), findsOneWidget);
    expect(find.text('CARD NUMBER'), findsOneWidget);
    // Verify Category selection is NOT rendered for cards
    expect(find.text('CATEGORY'), findsNothing);
  });

  testWidgets('VaultHomeScreen strictly isolates Password and Card with identical titles and isolates category filter',
      (WidgetTester tester) async {
    final fakeLocal = FakeWidgetLocalDataSource();
    fakeLocal.items.addAll([
      VaultItem(
        id: 'pw-mari',
        title: 'Maribank',
        type: VaultType.password,
        usernameEncrypted: 'enc_user',
        passwordEncrypted: 'enc_pass',
        iv: 'iv_1',
        category: 'Personal',
        updatedAt: DateTime.now(),
      ),
      VaultItem(
        id: 'card-mari',
        title: 'Maribank',
        type: VaultType.card,
        usernameEncrypted: 'enc_holder',
        passwordEncrypted: 'enc_num',
        iv: 'iv_2',
        category: 'Cards',
        accountNumber: '•••• •••• •••• 1234',
        cardDetailsEnc: '{"cardNumber":"4123456789011234"}',
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

    // On Passwords tab: verify only 1 password entry (not grouped into 2 accounts)
    expect(find.text('VAULT PASSWORDS (1)'), findsOneWidget);
    expect(find.text('2 ACCOUNTS'), findsNothing);
    expect(find.text('Maribank'), findsOneWidget);

    // Select category 'Work' on Passwords tab
    await tester.tap(find.text('WORK'));
    await tester.pumpAndSettle();

    // Passwords tab shows Work is Empty
    expect(find.text('Work is Empty'), findsOneWidget);

    // Switch to Cards tab
    await tester.tap(find.text('Cards'));
    await tester.pumpAndSettle();

    // Cards tab MUST display the Maribank Card despite category being 'Work'
    expect(find.text('PAYMENT CARDS (1)'), findsOneWidget);
    expect(find.text('Maribank'), findsOneWidget);
  });
}
