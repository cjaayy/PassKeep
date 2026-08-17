/// Example configuration template for Supabase.
///
/// Duplicate this file as `supabase_config.dart` and fill in your credentials,
/// or provide them via `--dart-define` at build/run time.
class SupabaseConfig {
  SupabaseConfig._();

  /// The Supabase Project URL.
  static const String supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://your-project-id.supabase.co',
  );

  /// The Supabase Anon / Public API Key.
  static const String supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: 'your-anon-key-here',
  );

  /// Helper indicating whether valid (non-placeholder) credentials have been configured.
  static bool get isConfigured {
    return supabaseUrl.isNotEmpty &&
        supabaseAnonKey.isNotEmpty &&
        !supabaseUrl.contains('your-project-id') &&
        supabaseAnonKey != 'your-anon-key-here';
  }
}
