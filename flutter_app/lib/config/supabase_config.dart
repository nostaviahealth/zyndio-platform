import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/secure_local_storage.dart';

/// Supabase Configuration
class SupabaseConfig {
  // Credentials - can be overridden with --dart-define at build time
  static const String url = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: '',
  );

  static const String anonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: '',
  );

  static bool _initialized = false;

  /// Test-only seam (TC-026): lets tests inject a SupabaseClient wired to a
  /// fake HTTP client instead of the real `Supabase.initialize()` singleton,
  /// without changing every provider's call sites. Never set in production
  /// code - see flutter_app/test/support/fake_supabase_rest.dart.
  @visibleForTesting
  static SupabaseClient? debugClientOverride;

  /// Check if Supabase is initialized
  static bool get isInitialized => _initialized;

  /// Check if credentials are provided
  static bool get hasCredentials => url.isNotEmpty && anonKey.isNotEmpty;

  /// Initialize Supabase client
  static Future<bool> initialize() async {
    if (_initialized) {
      debugPrint('Supabase already initialized');
      return true;
    }

    if (!hasCredentials) {
      debugPrint('Supabase credentials not provided');
      _initialized = false;
      return false;
    }

    try {
      debugPrint('Initializing Supabase with URL: $url');
      await Supabase.initialize(
        url: url,
        anonKey: anonKey,
        authOptions: FlutterAuthClientOptions(
          authFlowType: AuthFlowType.pkce,
          // TC-012 / PSU-SES-01: access + refresh tokens in Keychain /
          // EncryptedSharedPreferences, never SharedPreferences plaintext.
          localStorage: SecureLocalStorage(),
        ),
        realtimeClientOptions: const RealtimeClientOptions(
          logLevel: RealtimeLogLevel.info,
        ),
      );
      _initialized = true;
      debugPrint('Supabase initialized successfully');
      return true;
    } catch (e, stackTrace) {
      debugPrint('Supabase initialization failed: $e');
      debugPrint('Stack trace: $stackTrace');
      _initialized = false;
      return false;
    }
  }

  /// Get the Supabase client instance (only if initialized)
  static SupabaseClient? get client {
    if (debugClientOverride != null) return debugClientOverride;
    if (!_initialized) {
      debugPrint('Warning: Trying to access Supabase client before initialization');
      return null;
    }
    try {
      return Supabase.instance.client;
    } catch (e) {
      debugPrint('Error accessing Supabase client: $e');
      return null;
    }
  }

  /// Get the current authenticated user
  static User? get currentUser => client?.auth.currentUser;

  /// Get the current session
  static Session? get currentSession => client?.auth.currentSession;

  /// Check if user is authenticated
  static bool get isAuthenticated => currentUser != null;
}
