# TC-012 patient-auth screenshots

Source: **Flutter widget-test / golden captures** that pump the **real production
screens** (`SignupScreen`, `VerifyEmailScreen`, `LoginScreen`,
`ForgotPasswordScreen`, `ResetPasswordScreen`, `DeleteAccountScreen`,
`LinkRecordScreen`) under `BrandTheme` light/dark, with faked
`CaptureAuthNotifier` to reach Ava's states.

Surface: **390×844** logical at **devicePixelRatio 2** (physical 780×1688),
fonts: **Inter** + MaterialIcons + Lucide (FontLoader; not Ahem).

No `FICTIONAL DATA · Flutter capture` footer overlay (filename / this INDEX
carry the label). Fictional data only.

> Earlier commits used a string-list "frame" harness (`patient_auth_screenshot_frames.dart`)
> that drew copy into one rounded box (title `ZYNDIOPLACEHOLDER`, fake Back). That
> harness is retired; these PNGs replace it.

Naming: `<screen>/<state>--{light|dark}.png` (same as design `states/`).

| Screen | States captured |
|---|---|
| 08-sign-up | default, filled, invalid, creating, offline, limited |
| 09-verify-email | sent, resent, wait, expired, verified |
| 10-log-in | default, signing, error, locked, offline |
| 11-reset-password | request, sent, new, saved, expired |
| 12-delete-account | reauth, confirm, deleting, error, deleted |
| 13-link-record | intro, choose, code, wrong, locked, clinic, review, linked |

## Missing (not reachable via the real widget)

| State | Why |
|---|---|
| `12-delete-account/settings` | Ava's "settings" entry is the Delete-account row on Settings, not `DeleteAccountScreen`. Capturing Settings would not be this screen's widget. |
| Dedicated 2FA screen | No separate patient 2FA/auth screen in `lib/screens/auth/`; telehealth proof is `LinkRecordScreen`. |

Regenerate:
```bash
cd flutter_app && flutter test test/auth/capture_patient_auth_screenshots_test.dart --update-goldens
```
