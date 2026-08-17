import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:passkeep/core/errors/failures.dart';
import 'package:passkeep/features/auth/data/datasources/supabase_auth_datasource.dart';
import 'package:passkeep/features/auth/presentation/providers/supabase_auth_providers.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

class FakeSupabaseAuthDataSource implements ISupabaseAuthDataSource {
  sb.User? mockUser;
  bool shouldThrow = false;
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
    final user = sb.User(
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
    final user = sb.User(
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
    late SupabaseUserNotifier notifier;

    setUp(() {
      fakeAuthDataSource = FakeSupabaseAuthDataSource();
      notifier = SupabaseUserNotifier(authDataSource: fakeAuthDataSource);
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
      // First sign in
      await notifier.signIn(
        email: 'tester@example.com',
        password: 'securePassword123',
      );
      expect(notifier.state.isAuthenticated, isTrue);

      // Now sign out
      await notifier.signOut();
      expect(notifier.state.isAuthenticated, isFalse);
      expect(notifier.state.user, isNull);
      expect(notifier.state.email, isNull);
    });
  });
}
