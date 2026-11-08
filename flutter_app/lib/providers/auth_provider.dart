import 'dart:async'; // Added for StreamTransformer
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/supabase_config.dart';
import '../services/revenue_cat_service.dart';
import '../services/notification_service.dart';
import '../main.dart';
import '../demo/demo_build_flag.dart';

/// True only in the offline demo build (`--dart-define=DEMO_BUILD=true`).
///
/// This used to be "Supabase not initialised", which the router read as
/// "skip every sign-in check" - so a build with missing configuration, or a
/// failed Supabase setup, opened the whole app without a session. A missing
/// backend is now handled by `backendReadyRedirect` (fail closed); demo mode
/// is an explicit build choice and never a fallback.
final isDemoModeProvider = Provider<bool>((ref) => kDemoBuild);

/// Auth state provider - watches the authentication stream
final authStateProvider = StreamProvider<User?>((ref) {
  final initialized = ref.watch(supabaseInitializedProvider);
  
  // If Supabase is not initialized there is no session (the router sends
  // every location to the unavailable screen - see backendReadyRedirect).
  if (!initialized) {
    debugPrint('Auth: Supabase not initialized; no session');
    return Stream.value(null);
  }
  
  final client = SupabaseConfig.client;
  if (client == null) {
    debugPrint('Auth: Supabase client is null');
    return Stream.value(null);
  }
  
  debugPrint('Auth: Listening to auth state changes');
  return client.auth.onAuthStateChange.transform(
    StreamTransformer<AuthState, User?>.fromHandlers(
      handleData: (event, sink) {
        debugPrint('Auth state changed: ${event.event}');
        
        if (event.session?.user != null) {
          // Valid session, emit user
          sink.add(event.session!.user);
          
          // Auto-sync FCM Token whenever session is detected/restored
          NotificationService().syncTokenToSupabase();
        } else {
          // Session is null. Check event type.
          if (event.event == AuthChangeEvent.signedOut || 
              event.event == AuthChangeEvent.userDeleted) {
            sink.add(null);
          } else {
            debugPrint('Auth: Ignoring transient null session for event: ${event.event}');
          }
        }
      },
      handleError: (error, stackTrace, sink) {
        debugPrint('🔴 Auth stream error (recovering gracefully): $error');
        // Treat stream errors as signed-out to prevent crash
        sink.add(null);
      },
    ),
  );
});

/// Current user provider
final currentUserProvider = Provider<User?>((ref) {
  return ref.watch(authStateProvider).value;
});

/// Auth notifier for sign in/up/out actions
class AuthNotifier extends Notifier<AsyncValue<void>> {
  @override
  AsyncValue<void> build() {
    return const AsyncValue.data(null);
  }

  bool get _isInitialized => ref.read(supabaseInitializedProvider);

  /// Sign in with email and password
  Future<void> signIn(String email, String password) async {
    // Demo mode - simulate successful login
    if (!_isInitialized) {
      debugPrint('Demo mode: Simulating sign in');
      state = const AsyncValue.loading();
      await Future.delayed(const Duration(milliseconds: 500));
      state = const AsyncValue.data(null);
      return;
    }

    final client = SupabaseConfig.client;
    if (client == null) {
      state = AsyncValue.error('Supabase not available', StackTrace.current);
      return;
    }

    state = const AsyncValue.loading();
    try {
      debugPrint('Signing in with email: $email');
      // PSU-RL-03: patient email/password login goes through patient-login
      // Edge Function (per-IP failure throttle) rather than GoTrue directly.
      final response = await client.functions.invoke(
        'patient-login',
        body: {'email': email, 'password': password},
      );
      final data = response.data;
      if (data is Map && data['error'] != null) {
        throw PatientAuthException(data['error'].toString());
      }
      if (data is! Map || data['access_token'] == null || data['refresh_token'] == null) {
        throw PatientAuthException('invalid_credentials');
      }
      // setSession exchanges the refresh token for a persisted session
      // (SecureLocalStorage / PSU-SES-01).
      await client.auth.setSession(data['refresh_token'] as String);
      debugPrint('Sign in successful: ${client.auth.currentUser?.email}');

      NotificationService().syncTokenToSupabase();

      state = const AsyncValue.data(null);
    } on FunctionException catch (e, st) {
      final details = e.details;
      final code = (details is Map && details['error'] != null)
          ? details['error'].toString()
          : 'invalid_credentials';
      state = AsyncValue.error(PatientAuthException(code), st);
      throw PatientAuthException(code);
    } catch (e, st) {
      debugPrint('Sign in error: $e');
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  /// Sign up with email, password, and name
  Future<void> signUp(String email, String password, String name) async {
    // Demo mode - simulate successful signup
    if (!_isInitialized) {
      debugPrint('Demo mode: Simulating sign up');
      state = const AsyncValue.loading();
      await Future.delayed(const Duration(milliseconds: 500));
      state = const AsyncValue.data(null);
      return;
    }

    final client = SupabaseConfig.client;
    if (client == null) {
      state = AsyncValue.error('Supabase not available', StackTrace.current);
      return;
    }

    state = const AsyncValue.loading();
    try {
      debugPrint('Signing up with email: $email');
      await client.auth.signUp(
        email: email,
        password: password,
        data: {'name': name},
      );
      state = const AsyncValue.data(null);
      
      // Sync FCM token for push notifications
      NotificationService().syncTokenToSupabase();
    } catch (e, st) {
      debugPrint('Sign up error: $e');
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  /// Sign out
  Future<void> signOut() async {
    if (!_isInitialized) {
      state = const AsyncValue.data(null);
      return;
    }

    final client = SupabaseConfig.client;
    if (client == null) {
      state = const AsyncValue.data(null);
      return;
    }

    state = const AsyncValue.loading();
    try {
      await client.auth.signOut();
      
      // CRITICAL: Log out of RevenueCat to prevent entitlement bleed 
      // where the next user on the same device inherits premium status.
      await RevenueCatService().logOut();
      
      state = const AsyncValue.data(null);
    } catch (e, st) {
      debugPrint('Sign out error: $e');
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }


  // ---------------------------------------------------------------------
  // TC-012 slice 1: patient self-signup / verify / resend / reset / delete.
  // Every call here hits one of the patient-* Edge Functions (service role
  // on the server side) rather than the GoTrue client SDK directly - signup
  // in particular can't use client.auth.signUp() at all, since [auth]
  // enable_signup stays false (staff-creation-only) in supabase/config.toml.
  // ---------------------------------------------------------------------

  Future<void> _invokePatientAuth(String functionName, Map<String, dynamic> body) async {
    if (!_isInitialized) {
      await Future.delayed(const Duration(milliseconds: 400));
      return;
    }
    final client = SupabaseConfig.client;
    if (client == null) throw PatientAuthException('internal_error');

    try {
      final response = await client.functions.invoke(functionName, body: body);
      final data = response.data;
      if (data is Map && data['error'] != null) {
        throw PatientAuthException(data['error'].toString());
      }
    } on FunctionException catch (e) {
      final details = e.details;
      final code = (details is Map && details['error'] != null)
          ? details['error'].toString()
          : 'internal_error';
      throw PatientAuthException(code);
    }
  }

  /// PSU-ENUM-01: always succeeds from the caller's point of view unless the
  /// caller's own input was invalid (bad email shape, weak/blocklisted
  /// password) - the UI must always navigate to "Check your email" next,
  /// never branch on whether the account already existed.
  Future<void> patientSignUp(String email, String password) =>
      _invokePatientAuth('patient-signup', {'email': email, 'password': password});

  /// PSU-ENUM-04: same generic success regardless of unknown/already-verified/
  /// real-unverified email - the 60s cooldown lives in the UI's own timer.
  Future<void> resendVerification(String email) =>
      _invokePatientAuth('patient-resend-verification', {'email': email});

  Future<void> verifyEmailToken(String token) =>
      _invokePatientAuth('patient-verify-email', {'token': token});

  /// PSU-ENUM-03: same "if an account exists" response either way.
  Future<void> requestPasswordReset(String email) =>
      _invokePatientAuth('patient-request-password-reset', {'email': email});

  /// Revokes every other session server-side (force_sign_out) on success.
  Future<void> completePasswordReset(String token, String newPassword) => _invokePatientAuth(
      'patient-reset-password', {'token': token, 'password': newPassword});

  /// Re-auth (current password) + Apple 5.1.1(v) in-app deletion. Signs the
  /// local session out once the server confirms deletion.
  Future<void> deleteAccount(String password) async {
    await _invokePatientAuth('patient-delete-account', {'password': password});
    if (_isInitialized) {
      final client = SupabaseConfig.client;
      await client?.auth.signOut();
    }
  }

  /// PSU-EV-05: request change to [newEmail]. Old email stays authoritative
  /// for login until [confirmEmailChange] redeems the token mailed to the
  /// new address.
  Future<void> requestEmailChange(String newEmail) =>
      _invokePatientAuth('patient-request-email-change', {'new_email': newEmail});

  Future<void> confirmEmailChange(String token) =>
      _invokePatientAuth('patient-confirm-email-change', {'token': token});

  /// PSU-TO-14: identical success copy whether 0/1/many matches.
  Future<void> requestTelehealthLinkCode() =>
      _invokePatientAuth('patient-request-link-code', {});

  Future<Map<String, dynamic>> redeemTelehealthLinkCode(String code) async {
    final client = SupabaseConfig.client;
    if (client == null) throw PatientAuthException('internal_error');
    final res = await client.rpc('redeem_telehealth_link_code', params: {'p_code': code});
    if (res is Map<String, dynamic>) return res;
    if (res is Map) return Map<String, dynamic>.from(res);
    throw PatientAuthException('internal_error');
  }

  Future<Map<String, dynamic>> redeemClinicLinkCode(String code) async {
    final client = SupabaseConfig.client;
    if (client == null) throw PatientAuthException('internal_error');
    final res = await client.rpc('redeem_clinic_link_code', params: {'p_code': code});
    if (res is Map<String, dynamic>) return res;
    if (res is Map) return Map<String, dynamic>.from(res);
    throw PatientAuthException('internal_error');
  }

  Future<Map<String, dynamic>> unlinkPatientRecord() async {
    final client = SupabaseConfig.client;
    if (client == null) throw PatientAuthException('internal_error');
    final res = await client.rpc('unlink_patient_record');
    if (res is Map<String, dynamic>) return res;
    if (res is Map) return Map<String, dynamic>.from(res);
    throw PatientAuthException('internal_error');
  }
}

/// Auth notifier provider
final authNotifierProvider = NotifierProvider<AuthNotifier, AsyncValue<void>>(() {
  return AuthNotifier();
});

/// Thrown by the patient-auth Edge Function calls below. [code] is the
/// machine-readable `error` field from the function's JSON body (e.g.
/// 'password_too_common', 'rate_limited', 'invalid_or_expired_link') - UI
/// code maps it to Ava's copy rather than showing raw server text.
class PatientAuthException implements Exception {
  PatientAuthException(this.code);
  final String code;

  @override
  String toString() => 'PatientAuthException: $code';
}
