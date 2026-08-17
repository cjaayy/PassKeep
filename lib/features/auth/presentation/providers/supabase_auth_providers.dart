import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;
import '../../../../core/errors/failures.dart';
import '../../../sync/presentation/providers/sync_providers.dart';
import '../../data/datasources/supabase_auth_datasource.dart';

/// State representation for Supabase cloud account authentication
class SupabaseUserState {
  final sb.User? user;
  final bool isLoading;
  final String? errorMessage;

  const SupabaseUserState({
    this.user,
    this.isLoading = false,
    this.errorMessage,
  });

  const SupabaseUserState.initial()
      : user = null,
        isLoading = false,
        errorMessage = null;

  bool get isAuthenticated => user != null;
  String? get email => user?.email;
  String? get userId => user?.id;

  SupabaseUserState copyWith({
    sb.User? user,
    bool? isLoading,
    String? errorMessage,
    bool clearUser = false,
  }) {
    return SupabaseUserState(
      user: clearUser ? null : (user ?? this.user),
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
    );
  }

  @override
  String toString() =>
      'SupabaseUserState(authenticated: $isAuthenticated, email: $email, loading: $isLoading, error: $errorMessage)';
}

/// Provider for [ISupabaseAuthDataSource]
final supabaseAuthDataSourceProvider = Provider<ISupabaseAuthDataSource>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return SupabaseAuthDataSource(client: client);
});

/// StateNotifier managing Supabase Cloud account lifecycle
class SupabaseUserNotifier extends StateNotifier<SupabaseUserState> {
  final ISupabaseAuthDataSource _authDataSource;
  StreamSubscription<sb.AuthState>? _authSubscription;

  SupabaseUserNotifier({required ISupabaseAuthDataSource authDataSource})
      : _authDataSource = authDataSource,
        super(const SupabaseUserState.initial()) {
    _init();
  }

  void _init() {
    state = state.copyWith(user: _authDataSource.currentUser);
    _authSubscription = _authDataSource.authStateChanges.listen((data) {
      state = state.copyWith(
        user: data.session?.user,
        clearUser: data.session?.user == null,
      );
    });
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }

  /// Signs in to Supabase with email and password
  Future<bool> signIn({required String email, required String password}) async {
    state = state.copyWith(isLoading: true, errorMessage: null);

    try {
      final response = await _authDataSource.signInWithEmail(
        email: email,
        password: password,
      );

      state = state.copyWith(
        user: response.user,
        isLoading: false,
        errorMessage: null,
      );
      return response.user != null;
    } catch (e) {
      final message = e is Failure ? e.message : e.toString();
      state = state.copyWith(
        isLoading: false,
        errorMessage: message,
      );
      return false;
    }
  }

  /// Registers a new Supabase account with email and password
  Future<bool> signUp({required String email, required String password}) async {
    state = state.copyWith(isLoading: true, errorMessage: null);

    try {
      final response = await _authDataSource.signUpWithEmail(
        email: email,
        password: password,
      );

      state = state.copyWith(
        user: response.user,
        isLoading: false,
        errorMessage: null,
      );
      return response.user != null;
    } catch (e) {
      final message = e is Failure ? e.message : e.toString();
      state = state.copyWith(
        isLoading: false,
        errorMessage: message,
      );
      return false;
    }
  }

  /// Signs out of the active Supabase account
  Future<void> signOut() async {
    state = state.copyWith(isLoading: true, errorMessage: null);

    try {
      await _authDataSource.signOut();
      state = state.copyWith(
        clearUser: true,
        isLoading: false,
        errorMessage: null,
      );
    } catch (e) {
      final message = e is Failure ? e.message : e.toString();
      state = state.copyWith(
        isLoading: false,
        errorMessage: message,
      );
    }
  }
}

/// Provider for [SupabaseUserNotifier]
final supabaseUserProvider =
    StateNotifierProvider<SupabaseUserNotifier, SupabaseUserState>((ref) {
  final authDataSource = ref.watch(supabaseAuthDataSourceProvider);
  return SupabaseUserNotifier(authDataSource: authDataSource);
});
