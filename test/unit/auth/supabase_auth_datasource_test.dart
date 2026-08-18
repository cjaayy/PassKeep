import 'dart:async';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:passkeep/core/constants/storage_keys.dart';
import 'package:passkeep/core/errors/failures.dart';
import 'package:passkeep/features/auth/data/datasources/supabase_auth_datasource.dart';
import 'package:passkeep/features/auth/presentation/providers/supabase_auth_providers.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

class FakeSecureStorage extends Fake implements FlutterSecureStorage {
  final Map<String, String> _data = {};

  @override
  Future<String?> read({
    required String key,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async => _data[key];

  @override
  Future<void> write({
    required String key,
    required String? value,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    if (value != null) {
      _data[key] = value;
    } else {
      _data.remove(key);
    }
  }
}

class FakeSupabaseAuthDataSource implements ISupabaseAuthDataSource {
  sb.User? mockUser;
  bool shouldThrow = false;
  Map<String, dynamic>? lastUpdatedMetadata;
  final _controller = StreamController<sb.AuthState>.broadcast();

  @override
  sb.User? get currentUser => mockUser;

  @override
  Stream<sb.AuthState> get authStateChanges => _controller.stream;

  @override
  Future<sb.AuthResponse> signInWithEmail({
    required String email,
    required String password,
  }) async {
    if (shouldThrow) {
      throw const AuthFailure('Invalid login credentials');
    }
    final user = mockUser ??
        sb.User(
          id: 'mock-user-123',
          appMetadata: {},
          userMetadata: {},
          aud: 'authenticated',
          email: email,
          createdAt: DateTime.now().toIso8601String(),
        );
    mockUser = user;
    return sb.AuthResponse(
      session: sb.Session(
        accessToken: 'mock-token',
        tokenType: 'bearer',
        user: user,
      ),
      user: user,
    );
  }

  @override
  Future<sb.AuthResponse> signUpWithEmail({
    required String email,
    required String password,
  }) async {
    if (shouldThrow) {
      throw const AuthFailure('User already registered');
    }
    final user = mockUser ??
        sb.User(
          id: 'mock-user-456',
          appMetadata: {},
          userMetadata: {},
          aud: 'authenticated',
          email: email,
          createdAt: DateTime.now().toIso8601String(),
        );
    mockUser = user;
    return sb.AuthResponse(
      session: sb.Session(
        accessToken: 'mock-token',
        tokenType: 'bearer',
        user: user,
      ),
      user: user,
    );
  }

  @override
  Future<sb.UserResponse> updateUserMetadata(Map<String, dynamic> data) async {
    if (shouldThrow) {
      throw const AuthFailure('Failed to update metadata');
    }
    lastUpdatedMetadata = data;
    if (mockUser != null) {
      final updatedMeta = Map<String, dynamic>.from(mockUser!.userMetadata ?? {});
      updatedMeta.addAll(data);
      mockUser = sb.User(
        id: mockUser!.id,
        appMetadata: mockUser!.appMetadata,
        userMetadata: updatedMeta,
        aud: mockUser!.aud,
        email: mockUser!.email,
        createdAt: mockUser!.createdAt,
      );
    }
    return sb.UserResponse.fromJson({'user': mockUser});
  }

  @override
  Future<void> signOut() async {
    if (shouldThrow) {
      throw const AuthFailure('Network error on sign out');
    }
    mockUser = null;
  }

  void dispose() {
    _controller.close();
  }
}

void main() {
  group('SupabaseUserNotifier Authentication Tests', () {
    late FakeSupabaseAuthDataSource fakeAuthDataSource;
    late FakeSecureStorage fakeSecureStorage;
    late SupabaseUserNotifier notifier;

    setUp(() {
      fakeAuthDataSource = FakeSupabaseAuthDataSource();
      fakeSecureStorage = FakeSecureStorage();
      notifier = SupabaseUserNotifier(
        authDataSource: fakeAuthDataSource,
        secureStorage: fakeSecureStorage,
      );
    });

    tearDown(() {
      fakeAuthDataSource.dispose();
      notifier.dispose();
    });

    test('initial state when not authenticated', () {
      expect(notifier.state.isAuthenticated, isFalse);
      expect(notifier.state.user, isNull);
      expect(notifier.state.isLoading, isFalse);
      expect(notifier.state.errorMessage, isNull);
    });

    test('signIn with valid credentials updates user and authenticated status', () async {
      final result = await notifier.signIn(
        email: 'tester@example.com',
        password: 'securePassword123',
      );

      expect(result, isTrue);
      expect(notifier.state.isAuthenticated, isTrue);
      expect(notifier.state.email, 'tester@example.com');
      expect(notifier.state.userId, 'mock-user-123');
      expect(notifier.state.errorMessage, isNull);
    });

    test('signIn restores master_pin_salt from cloud user metadata to secure storage', () async {
      fakeAuthDataSource.mockUser = sb.User(
        id: 'cloud-user-with-salt',
        appMetadata: {},
        userMetadata: {'master_pin_salt': 'restored_cloud_salt_abc123'},
        aud: 'authenticated',
        email: 'clouduser@example.com',
        createdAt: DateTime.now().toIso8601String(),
      );

      final result = await notifier.signIn(
        email: 'clouduser@example.com',
        password: 'securePassword123',
      );

      expect(result, isTrue);
      // Verify salt was saved to secure storage
      final storedSalt = await fakeSecureStorage.read(key: StorageKeys.masterPinSaltKey);
      expect(storedSalt, 'restored_cloud_salt_abc123');
    });

    test('signIn uploads local salt to cloud metadata if cloud has no salt', () async {
      // Local storage has an existing salt
      await fakeSecureStorage.write(
        key: StorageKeys.masterPinSaltKey,
        value: 'local_offline_salt_xyz789',
      );

      // Cloud user has no salt in metadata
      fakeAuthDataSource.mockUser = sb.User(
        id: 'cloud-user-no-salt',
        appMetadata: {},
        userMetadata: {},
        aud: 'authenticated',
        email: 'newsaltuser@example.com',
        createdAt: DateTime.now().toIso8601String(),
      );

      final result = await notifier.signIn(
        email: 'newsaltuser@example.com',
        password: 'securePassword123',
      );

      expect(result, isTrue);
      // Verify local salt was uploaded to cloud metadata
      expect(fakeAuthDataSource.lastUpdatedMetadata?['master_pin_salt'], 'local_offline_salt_xyz789');
    });

    test('signIn with invalid credentials sets error message', () async {
      fakeAuthDataSource.shouldThrow = true;

      final result = await notifier.signIn(
        email: 'wrong@example.com',
        password: 'badPassword',
      );

      expect(result, isFalse);
      expect(notifier.state.isAuthenticated, isFalse);
      expect(notifier.state.errorMessage, contains('Invalid login credentials'));
    });

    test('signUp with valid details creates user and authenticates', () async {
      final result = await notifier.signUp(
        email: 'newuser@example.com',
        password: 'newPassword123',
      );

      expect(result, isTrue);
      expect(notifier.state.isAuthenticated, isTrue);
      expect(notifier.state.email, 'newuser@example.com');
      expect(notifier.state.userId, 'mock-user-456');
    });

    test('signOut clears active user state', () async {
      await notifier.signIn(
        email: 'tester@example.com',
        password: 'securePassword123',
      );
      expect(notifier.state.isAuthenticated, isTrue);

      await notifier.signOut();
      expect(notifier.state.isAuthenticated, isFalse);
      expect(notifier.state.user, isNull);
      expect(notifier.state.email, isNull);
    });
  });
}
