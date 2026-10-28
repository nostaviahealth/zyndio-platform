import 'dart:async';

import 'package:zyndio_patient/providers/auth_provider.dart';

/// Configurable AuthNotifier for screenshot + widget tests.
/// Hang a Completer to freeze loading UI; set throw*/result* for outcomes.
class CaptureAuthNotifier extends AuthNotifier {
  Completer<void>? hangSignIn;
  Completer<void>? hangSignUp;
  Completer<void>? hangDelete;
  Completer<void>? hangRequestLink;

  Object? signInError;
  Object? signUpError;
  Object? deleteError;
  Object? requestLinkError;
  Object? resetError;
  Object? verifyError;

  Map<String, dynamic> redeemTelehealthResult = const {'ok': true};
  Map<String, dynamic> redeemClinicResult = const {'ok': true};

  Future<void> _maybeHang(Completer<void>? c) async {
    if (c != null) await c.future;
  }

  Never _rethrow(Object e) {
    if (e is Exception) throw e;
    throw Exception(e);
  }

  @override
  Future<void> signIn(String email, String password) async {
    await _maybeHang(hangSignIn);
    if (signInError != null) _rethrow(signInError!);
  }

  @override
  Future<void> patientSignUp(String email, String password) async {
    await _maybeHang(hangSignUp);
    if (signUpError != null) _rethrow(signUpError!);
  }

  @override
  Future<void> requestPasswordReset(String email) async {
    if (resetError != null) _rethrow(resetError!);
  }

  @override
  Future<void> completePasswordReset(String token, String newPassword) async {
    if (resetError != null) _rethrow(resetError!);
  }

  @override
  Future<void> resendVerification(String email) async {}

  @override
  Future<void> verifyEmailToken(String token) async {
    if (verifyError != null) _rethrow(verifyError!);
  }

  @override
  Future<void> deleteAccount(String password) async {
    await _maybeHang(hangDelete);
    if (deleteError != null) _rethrow(deleteError!);
  }

  @override
  Future<void> requestTelehealthLinkCode() async {
    await _maybeHang(hangRequestLink);
    if (requestLinkError != null) _rethrow(requestLinkError!);
  }

  @override
  Future<Map<String, dynamic>> redeemTelehealthLinkCode(String code) async {
    return redeemTelehealthResult;
  }

  @override
  Future<Map<String, dynamic>> redeemClinicLinkCode(String code) async {
    return redeemClinicResult;
  }

  @override
  Future<Map<String, dynamic>> unlinkPatientRecord() async {
    return const {'ok': true};
  }
}

CaptureAuthNotifier createCaptureAuth() => CaptureAuthNotifier();

List<dynamic> captureOverrides(CaptureAuthNotifier auth) => [
      authNotifierProvider.overrideWith(() => auth),
    ];
