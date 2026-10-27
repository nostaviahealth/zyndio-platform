# TC-012 patient-auth screenshots

Source: Ava handoff `/workspace/design/team3/zyndio/handoff/patient-auth/` (README + copy-deck updated 27 Oct 2026 IST).
Renders: light + dark, 390×844, fictional data only.
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

Flutter app re-shoot via demo harness remains a follow-up; these are Ava's signed design renders with the updated copy Leo must match in UI.
