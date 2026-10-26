import 'package:flutter/foundation.dart';

import '../../data/fixtures.dart';
import '../../data/zyndio_repository.dart';

enum SignInStage { emailEntry, codeEntry }

/// Masks a local part down to its first character for the "we sent a code
/// to ..." copy, e.g. `jordan.rivera@example.com` -> `j•••••@example.com`.
String maskEmail(String email) {
  final atIndex = email.indexOf('@');
  if (atIndex <= 0) return email;
  return '${email[0]}•••••${email.substring(atIndex)}';
}

/// Maps the screenshot harness's `?state=` query param to a fixture
/// [SignInState]. Unknown/missing values fall back to the default state.
SignInState signInStateForQueryState(String? queryState) => switch (queryState) {
      'sending' => SignInState.sending(),
      // Partial entry (4 1 7) so the focus/cursor lands in box 4 and the
      // filled-digit style is visible in the screenshot (Ava's review).
      'code' => SignInState.code(code: '417'),
      'error' => SignInState.error(email: 'jordan.rivera@exmaple.com'),
      'locked' => SignInState.locked(),
      'offline' => SignInState.offline(),
      _ => SignInState.defaultState(),
    };

/// Immutable view-state for [SignInView]. Each factory matches one of the
/// 6 screenshot states (default, sending, code, error, locked, offline).
@immutable
class SignInState {
  const SignInState({
    this.stage = SignInStage.emailEntry,
    this.email = '',
    this.code = '',
    this.isSending = false,
    this.isOffline = false,
    this.isLocked = false,
    this.emailFieldFocused = false,
    this.errorText,
    this.session,
  });

  factory SignInState.defaultState({String? email}) =>
      SignInState(email: email ?? demoPatient.email, emailFieldFocused: true);

  factory SignInState.sending({String? email}) =>
      SignInState(email: email ?? demoPatient.email, isSending: true);

  factory SignInState.code({String? email, String code = ''}) => SignInState(
        stage: SignInStage.codeEntry,
        email: email ?? demoPatient.email,
        code: code,
      );

  factory SignInState.error({String email = ''}) => SignInState(
        email: email,
        errorText:
            "We couldn't find an enrolment for this email. Check the address, or ask your Zyndio care team for an invite.",
      );

  factory SignInState.locked({String? email}) =>
      SignInState(email: email ?? demoPatient.email, isLocked: true);

  factory SignInState.offline({String? email}) =>
      SignInState(email: email ?? demoPatient.email, isOffline: true);

  final SignInStage stage;
  final String email;
  final String code;
  final bool isSending;
  final bool isOffline;
  final bool isLocked;
  final bool emailFieldFocused;
  final String? errorText;

  /// Set once [CodeVerifyResult.success] comes back from the repository.
  /// Downstream screens (consent, labs, trends) read this to scope their own
  /// repository calls — never another patient's data.
  final RepoSession? session;

  bool get hasError => errorText != null;

  /// The info card ("New to Zyndio?...") is shown on the email step only
  /// when nothing more urgent (an inline error or the lockout banner) is
  /// already holding the user's attention.
  bool get showsInfoCard =>
      stage == SignInStage.emailEntry && !hasError && !isLocked;

  SignInState copyWith({
    SignInStage? stage,
    String? email,
    String? code,
    bool? isSending,
    bool? isOffline,
    bool? isLocked,
    bool? emailFieldFocused,
    String? errorText,
    bool clearError = false,
    RepoSession? session,
  }) {
    return SignInState(
      stage: stage ?? this.stage,
      email: email ?? this.email,
      code: code ?? this.code,
      isSending: isSending ?? this.isSending,
      isOffline: isOffline ?? this.isOffline,
      isLocked: isLocked ?? this.isLocked,
      emailFieldFocused: emailFieldFocused ?? this.emailFieldFocused,
      errorText: clearError ? null : (errorText ?? this.errorText),
      session: session ?? this.session,
    );
  }
}
