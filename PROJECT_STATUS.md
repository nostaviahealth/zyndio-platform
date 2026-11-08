# Zyndio — project status

**Last updated:** 9 November 2026 (after the programme-journey work was merged to `main`).

Read this first when you pick the project up. It says what is built, what is left, and what is
waiting on someone outside the code. Update it in the same pull request whenever you finish
or start something significant.

## Where we are

**About 70% of the contract is merged to `main`.** That is an estimate against the whole
PRD ("Zyndio Build: PRD and Technical Plan"): P0 items for acceptance and store submission, P1
items before the first real patient, and P2 items for the outcomes loop.

- **Code:** almost every PRD requirement has code merged, tested in CI and against a local
  Supabase. The patient app is close to feature-complete.
- **What holds the number down:** nothing has run against a hosted (staging or production)
  project yet, the app is not in either store, and several inputs and sign-offs from Zyndio
  are still outstanding (see [Waiting on others](#waiting-on-others)). Those are most of the
  remaining 30%.
- **The PRD itself is not in this repository.** Ask the project owner for the PDF.

Status words used below:

- **Done:** merged to `main`, with tests.
- **Built, not live:** merged and tested locally, but needs a hosted project, credentials or
  a partner to work end to end.
- **Partial:** some of it exists; the gap is described.
- **Not started.**

---

## Patient app (`flutter_app/`)

Five tabs: Today, Progress (body composition), Biomarkers, My Plan, Care. Profile & settings
opens from the avatar on every tab.

| ID | Requirement | Status | Notes |
|---|---|---|---|
| APP-01 | Sign-in from an enrolment invite (magic link or one-time code); no open self-sign-up unless switched on | Done | Email code sign-in; self-sign-up behind a server flag (off). |
| APP-02 | Consent and onboarding: terms, privacy notice, consent text, each stored with version and timestamp | Done, text is placeholder | Versioned consents table. **Final legal text from Zyndio is still needed** (screens say "placeholder text"). |
| APP-03 | Separate, revocable authorisation to share outcomes with the body composition partner | Done | Settings → Privacy and sharing → Partner outcomes sharing. Revoking stops future deliveries. |
| APP-04 | Profile: name, date of birth, sex at birth, height, units | Done | Onboarding profile step and Edit profile. |
| APP-05 | Lab upload by camera, image or PDF, multi-page; shows extracted values; flags name/DOB mismatch | Built, not live | AI extraction is **off** unless `LAB_AI_EXTRACTION_ENABLED=true` and a key is set; no BAA yet. Manual entry works. |
| APP-06 | Biomarker views: trend graph, single-marker history, change since baseline, ranges, bounded alert wording | Done | Uses default ranges until Zyndio supplies its own (POR-05). |
| APP-07 | Connect, view status of and disconnect Apple Health / Health Connect, per-type permissions | Done | Daily wearable upload to `wearable_daily`. |
| APP-08 | Food logging by photo or text | Done | "Food log" row on Today. |
| APP-09 | AI companion within Zyndio's boundaries; clinical questions route to the care team; emergency language shows guidance and alerts the escalation contact | Built, not live | Server routing and escalations exist. **Zyndio's escalation contacts and companion tone are not configured.** |
| APP-10 | Push notifications with no health information in the visible text | Done | Every local and push notification shows fixed neutral text. Push needs Firebase/APNs set up on the hosted project. |
| APP-11 | In-app account deletion request with wording on records Zyndio must keep | Done | Settings → Delete account. |
| APP-12 | No old-brand string anywhere | Done, enforced | `scripts/leak-scan.sh` in CI. See the rule in [CLAUDE.md](./CLAUDE.md). |
| APP-13 | Body composition view: baseline vs follow-up, fat, lean, visceral trends | Done | Progress tab, report-style DEXA view. Real data needs the partner scan feed (INT-05). |
| APP-14 | Milestone reminders for the next scan and lab | Done | Today "Your programme" card (setup checklist, then Day 90 / 180 / 365 track), Progress "Your scan schedule", My Plan → Testing, and local reminders when each 30-day window opens and on the date. |

**Also in the app**

- Client-mockup visual design (Nov 2026): brand row, Longevity score card, pastel tiles,
  sliding tab bar.
- Demo login (`--dart-define=DEMO_LOGIN=true`, debug builds only) with fictional data on every
  tab, including a baseline, Day 90 and Day 180 scan.
- Longevity score ring and Recovery tile only appear with their feature flag **and** a real
  value. Appointments is mock data and stays behind its flag.
- Consumer extras (Shop, Meditate, Cycle tracking, leagues, goals, membership) are hidden
  unless the patient-extras flag is on.

## Physician portal (root React app, `pages/admin/`)

| ID | Requirement | Status | Notes |
|---|---|---|---|
| POR-01 | Sign-in with mandatory MFA; roles Physician, Care coordinator, Admin, Read-only | Done | First admin comes from `npm run admin:setup` ([admin-setup.md](./admin-setup.md)). |
| POR-02 | Patient roster with flags | Done | `clinic/PhysicianRoster.tsx`. |
| POR-03 | Combined timeline | Done | `clinic/PatientTimeline.tsx`. |
| POR-04 | Pre-follow-up brief | Done | `clinic/PrevisitBrief.tsx`. |
| POR-05 | Range and protocol management, versioned, physician-approved | Built, waiting on data | `clinic/ReferenceRanges.tsx`. **Zyndio's ranges have not been supplied.** |
| POR-06 | Data export per patient | Done | |
| POR-07 | Treatment context entry | Done | No dose is ever shown to the patient. |
| POR-08 | Audit log view | Done | `AuditLog.tsx`. |
| POR-09 | Outcomes review queue | Done | `clinic/OutcomesReviewQueue.tsx`. |
| POR-10 | Unmatched partner records queue | Done | `clinic/UnmatchedRecordsQueue.tsx`. |

## Backend and zyndio.com integration (`supabase/`)

| ID | Requirement | Status | Notes |
|---|---|---|---|
| INT-01 | Enrol, update, deactivate a patient by API | Built, not live | `partner-api` Edge Function. Reference: [docs/PARTNER_API.md](./docs/PARTNER_API.md). |
| INT-02 | Account status webhooks | Built, not live | `deliver-webhooks` worker and cron. |
| INT-03 | Programme data read API | Built, not live | |
| INT-04 | Treatment events API | Built, not live | `treatment-events`. |
| INT-05 | Partner measurement ingestion (DEXA) | Built, not live | Field mapping in [docs/integrations/dexa-webhook-fields.md](./docs/integrations/dexa-webhook-fields.md). **Waiting on the real DEXA webhook details.** |
| INT-06 | Outcomes webhook plus retrieval API | Built, not live | `outcomes-sandbox` for testing. |
| — | Zyndio hostname in front of the API (`platform.zyndio.com`) | Not started | Needs DNS and a hosted project. |

## Partner Portal and operations

| ID | Requirement | Status | Notes |
|---|---|---|---|
| PP-01 | Tier and module changes with pro-rating data | Done | `PlanModules.tsx`. |
| PP-02 | Active patients per month with reason | Done | `OperationsBilling.tsx`. |
| PP-03 | API credentials, webhook endpoints, secret rotation, delivery log | Done | `Integrations.tsx`. |
| OPS-01 | Patient data export within 30 days of termination | Done | |
| OPS-02 | Patient deletion with written confirmation, honouring legal holds | Done | |
| OPS-03 | Security incident workflow (notify within 72 hours) | Done | |

---

## Waiting on others

None of these can be finished in code alone.

**From Zyndio**
- Final legal text: terms, privacy notice, consent wording (APP-02).
- Zyndio's reference ranges (POR-05) and clinical sign-off of ranges, alert wording and protocols.
- Escalation contacts and companion name/tone (APP-09).
- The secure clinical portal link (Care tab shows "Coming soon").
- The client's real portrait for the profile avatar, and product photography.
- DEXA webhook details and NAD+ lab API details (INT-05).
- Signed BAA before any real patient data, and before switching on AI lab extraction.

**Accounts and hosting**
- A hosted Supabase project (staging, then production in a US region) with its URL and keys.
- Apple Developer account (iOS `DEVELOPMENT_TEAM` is empty) and Google Play account.
- Firebase / APNs for push, a valid RevenueCat key (the current one is rejected), DNS for
  `platform.zyndio.com`.

## Before store submission / first real patient

1. Stand up the hosted project and run the deploy checklist: Vault pepper, `ADMIN_ORIGIN`,
   `TRUSTED_PROXY_HOPS`, RevenueCat webhook secret, hosted `pg_cron`. Details in
   [docs/RISKS.md](./docs/RISKS.md).
2. Fix or formally accept risk **R-AUTH-M8**: a direct Auth password update skips the
   blocklist and audit. Fix before any real patient data.
3. Build and sign iOS and Android release builds, then submit to the stores.
4. Run the full journey against staging with fictional data: invite → consent → wearable →
   lab upload → bound scan → physician plan → milestone → reviewed outcome.
5. Independent review and UI approval of the combined `main`.

## Known issues

- The `supabase` CI check has failed on the last several merges to `main`. It was already
  failing before the recent app work; investigate before relying on CI.
- About 70 auth screenshot golden tests fail on macOS because of fonts. They pass on Linux
  CI. Regenerate goldens with the `update-goldens` workflow, not on a Mac.
- `flutter test --dart-define=DEMO_BUILD=true test/demo` has 5 failures that assert the
  default flag. They are expected under that flag.
- `scripts/leak-scan.sh` fails locally unless `space/dist`, the Flutter web build and the debug
  APK exist. CI builds them.
- Some legacy screens (shop, leagues, meditation, cardio detail) still use the older visual
  style. They are hidden behind the extras flag.

## How to pick this up

- Setup and commands: [README.md](./README.md) and [CLAUDE.md](./CLAUDE.md).
- Local database: [SUPABASE-SETUP.md](./SUPABASE-SETUP.md).
- Last formal handover: [docs/delivery/2026-11-09-handover.md](./docs/delivery/2026-11-09-handover.md).
- Risks and deploy requirements: [docs/RISKS.md](./docs/RISKS.md).
- Try the app quickly: build the iOS simulator app with `--dart-define=DEMO_LOGIN=true` and tap
  **Explore the demo (sample data)** on the sign-in screen.
- Rules: everything lands through a pull request, fictional data only, no secrets in the repo,
  never weaken a test.
