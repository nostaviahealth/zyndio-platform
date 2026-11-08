import 'dart:async'; // Added for StreamTransformer
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/supabase_config.dart';
import '../services/revenue_cat_service.dart';
import '../services/notification_service.dart';
import '../main.dart';

/// Demo mode provider - true when Supabase is not configured
final isDemoModeProvider = Provider<bool>((ref) {
  final initialized = ref.watch(supabaseInitializedProvider);
  return !initialized;
});

/// Auth state provider - watches the authentication stream
final authStateProvider = StreamProvider<User?>((ref) {
  final initialized = ref.watch(supabaseInitializedProvider);
  
  // If Supabase is not initialized, return a stream with null (demo mode)
  if (!initialized) {
    debugPrint('Auth: Running in demo mode (Supabase not initialized)');
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
      final signedInId = client.auth.currentUser?.id;
      if (signedInId != null) {
        try {
          await client.rpc('record_patient_monthly_activity', params: {
            'p_patient_id': signedInId,
            'p_reason': 'sign_in',
          });
        } catch (meterError) {
          debugPrint('Active-patient meter was not recorded: $meterError');
        }
      }

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
    await _invokePatientAuthData(functionName, body);
  }

  /// Like [_invokePatientAuth] but returns the function's JSON body. Empty
  /// map in demo mode.
  Future<Map<String, dynamic>> _invokePatientAuthData(
      String functionName, Map<String, dynamic> body) async {
    if (!_isInitialized) {
      await Future.delayed(const Duration(milliseconds: 400));
      return const {};
    }
    final client = SupabaseConfig.client;
    if (client == null) throw PatientAuthException('internal_error');

    try {
      final response = await client.functions.invoke(functionName, body: body);
      final data = response.data;
      if (data is Map && data['error'] != null) {
        throw PatientAuthException.fromBody(data);
      }
      return data is Map ? Map<String, dynamic>.from(data) : const {};
    } on FunctionException catch (e) {
      final details = e.details;
      if (details is Map && details['error'] != null) {
        throw PatientAuthException.fromBody(details);
      }
      throw PatientAuthException('internal_error');
    }
  }

  // ---------------------------------------------------------------------
  // APP-01: invite-based sign-in with an emailed one-time code. Patients are
  // enrolled by their care team (create-patient / integration API) and sign
  // in with that email; no password. Server policy: 6 digits, 10 minutes,
  // single use, 5 wrong tries lock the email for 15 minutes.
  // ---------------------------------------------------------------------

  /// Emails a 6-digit code. Succeeds the same way for any well-formed email
  /// (PSU-ENUM-01), so the UI always moves on to code entry.
  Future<void> requestLoginCode(String email) =>
      _invokePatientAuth('patient-request-login-code', {'email': email});

  /// Redeems [code] for [email] and stores the resulting session. Throws
  /// [PatientAuthException] with `invalid_code`, `code_expired`, `locked`
  /// (with [PatientAuthException.retryAfterSeconds]) or `rate_limited`.
  Future<void> verifyLoginCode(String email, String code) async {
    if (!_isInitialized) {
      state = const AsyncValue.loading();
      await Future.delayed(const Duration(milliseconds: 400));
      state = const AsyncValue.data(null);
      return;
    }
    final client = SupabaseConfig.client;
    if (client == null) throw PatientAuthException('internal_error');

    state = const AsyncValue.loading();
    try {
      final data = await _invokePatientAuthData(
          'patient-verify-login-code', {'email': email, 'code': code});
      final refreshToken = data['refresh_token'];
      if (refreshToken is! String || refreshToken.isEmpty) {
        throw PatientAuthException('internal_error');
      }
      // Same as signIn(): setSession persists via SecureLocalStorage (PSU-SES-01).
      await client.auth.setSession(refreshToken);
      NotificationService().syncTokenToSupabase();
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  /// Apple 5.1.1(v) deletion for a passwordless (invited) patient: the
  /// re-auth is a fresh code sent with [requestLoginCode] to their own email.
  Future<void> deleteAccountWithCode(String code) async {
    await _invokePatientAuth('patient-delete-account', {'code': code});
    if (_isInitialized) {
      final client = SupabaseConfig.client;
      await client?.auth.signOut();
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
  PatientAuthException(this.code, {this.retryAfterSeconds});

  /// Reads `{ error, retry_after_seconds? }` from a function's JSON body.
  factory PatientAuthException.fromBody(Map<dynamic, dynamic> body) {
    final retry = body['retry_after_seconds'];
    return PatientAuthException(
      body['error'].toString(),
      retryAfterSeconds: retry is num ? retry.ceil() : null,
    );
  }

  final String code;

  /// Set with `locked`: seconds until the sign-in lock ends.
  final int? retryAfterSeconds;

  @override
  String toString() => 'PatientAuthException: $code';
}

/// APP-01: whether this deployment's org has open self-sign-up turned on
/// (organizations.patient_self_signup_enabled, via patient-auth-config).
/// Off by default, on any error, and in demo mode: patients join from a
/// care-team invite. patient-signup enforces the same setting server-side.
final selfSignupEnabledProvider = FutureProvider<bool>((ref) async {
  if (!ref.watch(supabaseInitializedProvider)) return false;
  final client = SupabaseConfig.client;
  if (client == null) return false;
  try {
    final response = await client.functions.invoke('patient-auth-config', body: const {});
    final data = response.data;
    return data is Map && data['self_signup_enabled'] == true;
  } catch (e) {
    debugPrint('patient-auth-config failed: $e');
    return false;
  }
});
