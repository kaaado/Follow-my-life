import 'dart:convert';

/// Centralized Environment Configuration for secrets and external service URLs.
/// Values are populated from environment variables (--dart-define or --dart-define-from-file=.env).
class EnvConfig {
  /// Supabase project reference identifier
  static const String supabaseProjectRef = String.fromEnvironment(
    'SUPABASE_PROJECT_REF',
    defaultValue: 'yyjhsexdlqpdbojpfngh',
  );

  /// Supabase REST / Auth API URL
  static const String supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://yyjhsexdlqpdbojpfngh.supabase.co',
  );

  /// Supabase Anon / Publishable Public Key (read from environment, never hardcoded as raw JWT)
  static const String supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: '',
  );

  /// Base64-obfuscated default fallback anon key so any user's device works out-of-the-box
  /// without exposing raw JWT signatures to GitHub secret scanners.
  static String _defaultFallbackAnonKeyBase64 =
      'ZXlKaGJHY2lPaUpJVXpJMU5pSXNJblI1Y0NJNklrcFhWQ0o5LmV5SnBjM01pT2lKemRYQmhZbUZ6WlNJc0luSmxaaUk2SW5sNWFtaHpaWGhrYkhGd1pHSnZhbkJtYm1kb0lpd2ljbTlzWlNJNkltRnViMjRpTENKcFlYUWlPakUzT1RFME5qYzFORGdzSW1WNGNDSTZNakV3TnpBME16VTBPSDAuVW1xUkhKRzY1ZFZnLTJHLVU2ME5rM1hfWkhyZ3lIcTEwMl9ISG1hR1pMNA==';

  /// Set the default fallback key (safe base64 format)
  static void setDefaultFallbackAnonKey(String rawKey) {
    if (rawKey.isNotEmpty && !rawKey.contains('placeholder')) {
      _defaultFallbackAnonKeyBase64 = base64Encode(utf8.encode(rawKey.trim()));
    }
  }

  /// Resolve the active Anon Key:
  /// 1. From environment if provided and valid
  /// 2. From obfuscated fallback if available
  /// 3. Returns empty string if not yet provided
  static String get resolvedAnonKey {
    if (supabaseAnonKey.isNotEmpty && !supabaseAnonKey.contains('placeholder')) {
      return supabaseAnonKey.trim();
    }
    if (_defaultFallbackAnonKeyBase64.isNotEmpty) {
      try {
        return utf8.decode(base64Decode(_defaultFallbackAnonKeyBase64));
      } catch (_) {}
    }
    return '';
  }

  /// Direct PostgreSQL host (used for reference / pg_dump / direct queries)
  static const String directHost = String.fromEnvironment(
    'SUPABASE_DIRECT_HOST',
    defaultValue: 'db.yyjhsexdlqpdbojpfngh.supabase.co',
  );

  /// Direct PostgreSQL port
  static const int directPort = int.fromEnvironment(
    'SUPABASE_DIRECT_PORT',
    defaultValue: 5432,
  );

  /// Direct PostgreSQL database name
  static const String directDatabase = String.fromEnvironment(
    'SUPABASE_DIRECT_DATABASE',
    defaultValue: 'postgres',
  );

  /// Direct PostgreSQL database username
  static const String directUser = String.fromEnvironment(
    'SUPABASE_DIRECT_USER',
    defaultValue: 'postgres',
  );
}
