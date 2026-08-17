import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/errors/failures.dart';

/// Abstract interface for Supabase Authentication operations
abstract class ISupabaseAuthDataSource {
  /// Signs up a new user with email and password
  Future<AuthResponse> signUpWithEmail({
    required String email,
    required String password,
  });

  /// Signs in an existing user with email and password
  Future<AuthResponse> signInWithEmail({
    required String email,
    required String password,
  });

  /// Signs out the currently authenticated user
  Future<void> signOut();

  /// Returns the current authenticated [User], if any
  User? get currentUser;

  /// Stream of Supabase [AuthState] events
  Stream<AuthState> get authStateChanges;
}

/// Implementation of [ISupabaseAuthDataSource] using Supabase GoTrue client
class SupabaseAuthDataSource implements ISupabaseAuthDataSource {
  final SupabaseClient? _client;

  SupabaseAuthDataSource({SupabaseClient? client}) : _client = client;

  SupabaseClient get _supabase {
    if (_client != null) return _client;
    return Supabase.instance.client;
  }

  @override
  User? get currentUser {
    try {
      return _supabase.auth.currentUser;
    } catch (_) {
      return null;
    }
  }

  @override
  Stream<AuthState> get authStateChanges {
    try {
      return _supabase.auth.onAuthStateChange;
    } catch (_) {
      return const Stream.empty();
    }
  }

  @override
  Future<AuthResponse> signUpWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      final response = await _supabase.auth.signUp(
        email: email.trim(),
        password: password,
      );
      return response;
    } on AuthException catch (e) {
      throw AuthFailure(e.message);
    } catch (e) {
      if (e is Failure) rethrow;
      throw AuthFailure('Failed to create account: ${e.toString()}');
    }
  }

  @override
  Future<AuthResponse> signInWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      final response = await _supabase.auth.signInWithPassword(
        email: email.trim(),
        password: password,
      );
      return response;
    } on AuthException catch (e) {
      throw AuthFailure(e.message);
    } catch (e) {
      if (e is Failure) rethrow;
      throw AuthFailure('Failed to sign in: ${e.toString()}');
    }
  }

  @override
  Future<void> signOut() async {
    try {
      await _supabase.auth.signOut();
    } on AuthException catch (e) {
      throw AuthFailure(e.message);
    } catch (e) {
      if (e is Failure) rethrow;
      throw AuthFailure('Failed to sign out: ${e.toString()}');
    }
  }
}
