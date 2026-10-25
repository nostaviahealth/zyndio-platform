import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/demo_backend.dart';
import '../../data/fixtures.dart';
import '../../providers/demo_providers.dart';
import 'signin_state.dart';

/// Drives [SignInState] off the fake backend's real policies (code expiry,
/// lockout) for the interactive demo build and the Step 6 end-to-end test.
class SignInController extends Notifier<SignInState> {
  @override
  SignInState build() => SignInState.defaultState(email: '');

  DemoBackend get _backend => ref.read(demoBackendProvider);

  void updateEmail(String email) {
    state = state.copyWith(email: email, clearError: true);
  }

  /// Validates and sends the code. Ignores repeat taps while already
  /// sending, per C05's "busy" spec.
  void sendCode() {
    if (state.isSending) return;
    final email = state.email.trim().toLowerCase();
    if (email != demoPatient.email) {
      state = state.copyWith(
        errorText:
            "We couldn't find an enrolment for this email. Check the address, or ask your Zyndio care team for an invite.",
      );
      return;
    }
    state = state.copyWith(isSending: true, clearError: true);
    _backend.sendCode(email);
    state = state.copyWith(
      isSending: false,
      stage: SignInStage.codeEntry,
      code: '',
      clearError: true,
    );
  }

  void updateCode(String code) {
    state = state.copyWith(code: code, clearError: true);
  }

  /// Verifies the entered code against the backend's expiry/lockout
  /// policies. Returns the outcome so the caller can navigate on success.
  CodeVerifyResult submitCode() {
    final result = _backend.verifyCode(state.code);
    if (result == CodeVerifyResult.locked) {
      state = state.copyWith(isLocked: true);
    }
    return result;
  }

  void backToEmail() {
    state = state.copyWith(stage: SignInStage.emailEntry, code: '', clearError: true);
  }
}

final signInControllerProvider = NotifierProvider<SignInController, SignInState>(
  SignInController.new,
);
