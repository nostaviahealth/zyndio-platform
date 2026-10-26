import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/demo_backend.dart';
import '../../data/zyndio_repository.dart';
import '../../providers/demo_providers.dart';
import 'signin_state.dart';

final RegExp _emailShape = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

/// Drives [SignInState] off the repository's real server-side policies (code
/// expiry, lockout, single-use) for the interactive demo build and the
/// Step 6 end-to-end test.
class SignInController extends Notifier<SignInState> {
  @override
  SignInState build() => SignInState.defaultState(email: '');

  ZyndioRepository get _repo => ref.read(zyndioRepositoryProvider);

  void updateEmail(String email) {
    state = state.copyWith(email: email, clearError: true);
  }

  /// Validates and sends the code. Ignores repeat taps while already
  /// sending, per C05's "busy" spec. An unknown-but-well-formed email takes
  /// exactly the same path as a known one — the repository silently no-ops
  /// for accounts it doesn't recognise (no self-sign-up API), so there's
  /// nothing here that could leak which emails are enrolled.
  void sendCode() {
    if (state.isSending) return;
    final email = state.email.trim().toLowerCase();
    if (!_emailShape.hasMatch(email)) {
      state = state.copyWith(errorText: 'Enter a valid email address.');
      return;
    }
    state = state.copyWith(isSending: true, clearError: true);
    _repo.sendCode(email);
    state = state.copyWith(
      isSending: false,
      stage: SignInStage.codeEntry,
      email: email,
      code: '',
      clearError: true,
    );
  }

  void updateCode(String code) {
    state = state.copyWith(code: code, clearError: true);
  }

  /// Verifies the entered code against the repository's expiry/lockout
  /// policies. Returns the outcome so the caller can navigate on success;
  /// on success the resulting session is stored on [state] for downstream
  /// screens to scope their own repository calls with.
  CodeVerifyResult submitCode() {
    final email = state.email.trim().toLowerCase();
    final (result, session) = _repo.verifyCode(email, state.code);
    if (result == CodeVerifyResult.locked) {
      state = state.copyWith(isLocked: true);
    } else if (result == CodeVerifyResult.success) {
      state = state.copyWith(session: session);
      ref.read(currentSessionProvider.notifier).set(session);
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
