# TC-012 patient-auth screenshots

Source: **Flutter widget-test / golden captures** of built patient-auth frames
(`flutter_app/lib/screens/auth/screenshot/patient_auth_screenshot_frames.dart`),
Ava state names, fictional data only. Light + dark at **390×844**.

> Correction (Ava): an earlier commit (`1a94579`) copied Ava's design renders
> byte-for-byte. That set is **not** valid evidence. This tree replaces those
> files with real Flutter captures. SHA-256 of every PNG differs from Ava's
> handoff under `/workspace/design/team3/zyndio/handoff/patient-auth/states/`.

Naming: `<screen>/<state>--{light|dark}.png` (same as design `states/`).

Copy notes reflected here (Ava + Henry):
- Send-code / code / wrong / locked: "If your details match a clinic record, we've sent a 6-digit code to your clinic's patient messages."
- Review: "No code yet?" → clinic code path.
- Linked: "We've also sent a notice to your email and your clinic's patient messages."

| Screen | States |
|---|---|
| 08-sign-up | default, filled, invalid, creating, offline, limited |
| 09-verify-email | sent, resent, wait, expired, verified |
| 10-log-in | default, signing, error, locked, offline |
| 11-reset-password | request, sent, new, saved, expired |
| 12-delete-account | settings, reauth, confirm, deleting, error, deleted |
| 13-link-record | intro, choose, code, wrong, locked, clinic, review, linked |

Regenerate:
```bash
cd flutter_app && flutter test test/auth/capture_patient_auth_screenshots_test.dart --update-goldens
```
