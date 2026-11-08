# Zyndio — 9 Nov 2026 fictional-data test candidate

Task card and acceptance checklist for one reviewable integration branch.
This document is the scope of the candidate. It is not a claim that the
product is complete, and it is not review approval of pull requests #35–#42.

| Role | Who |
|---|---|
| Implementation | This branch |
| Technical acceptance | Henry |
| Independent review | Clara (original pull requests, separately) |
| UI pass | Ava |

Base: `main` `7f283f57103d37e4781b265ebcb769ae8b63deb3` (4 Nov 2026 00:50:57 IST, pull request #34).

## What this candidate is

A single branch a tester can run **locally** on **9 Nov 2026 IST** with **fictional data only**:

- Patient app shell: Today, Progress, Biomarkers, My Plan, Care.
- Safe lab path: no hard-coded extraction sample, no schema mismatch that writes invented biomarkers, no fixed “Normal” status. Structured output is validated. Results persist and the patient view reads the same stored fields. The extractor stays off unless explicitly configured, and only for fictional reports until a BAA exists.
- Held lab reports blocked on the server for the patient (row, file, and signing), not only by a client filter.
- Physician portal, admin 2FA and roles, invite-code sign-in, wearable daily upload, and partner API / webhooks, taken from the open pull requests below.
- DEXASCAN / outcomes code taken from `c2-outcomes-engine` where that branch already defines behaviour. Missing clinical inputs stay unavailable.

## What this candidate is not

- Not a production deploy, not a hosted project change, not access to real patients.
- Not an iOS install. The Apple team id stays empty until Apple setup exists. No iOS build is claimed without a signed build log.
- Not approval to merge. Critical and high issues block acceptance. Exact-head CI must be green, and Clara and Ava review this pull request, before anyone merges.
- Not permission to rewrite other contributors’ branches. Those refs stay where they are.

## Integration provenance

`#42` already contains `#35` (`fa7de1b`). `#35` is not merged a second time.

| Source | Ref at integration | Head SHA | Migrations added |
|---|---|---|---|
| #36 iOS Xcode 27 | `origin/fix/ios-xcode27-build` | `40dd7617804d41dfca3db27d5db164a3528e597b` | none |
| #37 app compliance | `origin/app-compliance` | `67def8365a05acd7468f982d3d57d3703953b00e` | `20261104120000`, `20261104130000` |
| #38 partner API | `origin/claude/elegant-panini-18fe8f` | `cd66fb4857435ba85d2e98141c2bcbfc2e210463` | `20261104150000`–`20261104150200` |
| #41 invite, consents, profile | `origin/claude/reverent-allen-35c586` | `44ec861c337d6e6a45e20538019e3a7eba7872ce` | `20261104160000`–`20261104162000` |
| #40 physician portal P0 | `origin/claude/goofy-mestorf-14b730` | `81382b31ab5951536804476df732914fc169bc53` | `20261105100000`–`20261105104000` |
| #39 wearables | `origin/app-07-wearables` | `9b3bfcd3922b4515e3c44931e39ebafbd5bd1a03` | `20261105120000` |
| #42 lab pipeline (includes #35) | `origin/app-05-lab-pipeline` | `2bd25e2190299a81262fbd5df85edda40374a575` | `20261105130000` |
| Outcomes / DEXASCAN | `origin/c2-outcomes-engine` | `ebbed40fca55f1a91088d39ead94c877c02b6cef` | `20261105160000` |
| #35 alone | not merged separately | `fa7de1b9d236c6a5b0331d5d671045a54af69969` | included via #42 |

Order follows migration timestamps, then the outcomes branch. Overlapping files (`App.tsx`, admin sidebar, iOS project, `supabase/tests/747_tc040_function_execute_allowlist.sql`) are combined on this branch only. Each source pull request stays open for Clara.

Recorded CI on those heads (3–4 Nov 2026) is historical. Acceptance uses a **fresh** run on this branch’s head SHA.

## Acceptance checklist

### Lab path

- [ ] `analyze-lab-report` does not send a hard-coded biomarker string and does not write columns that are not on `lab_reports`.
- [ ] With the extractor unset, the function returns unavailable and writes nothing.
- [ ] With the extractor configured, only validated structured output is stored, and `lab_results` matches what Biomarkers shows.
- [ ] A patient-entered value does not get a fixed clinical status such as Normal.
- [ ] Logs and error responses do not include file paths, raw provider errors, or marker values.
- [ ] Tests cover the unavailable path and a fictional fixture path. No test is deleted or weakened to go green.

### Held reports

- [ ] A patient cannot select a held `lab_reports` row, read the stored object, or create a signed URL for it.
- [ ] The same patient can still read their own non-held report and file.
- [ ] Another patient, another clinic, and a role that should not see the file still cannot.
- [ ] Staff who already may see held rows for review still can, under the existing clinic and AAL2 rules.
- [ ] Enforcement is in Postgres / storage policies, not only in the Flutter query.
- [ ] `supabase/tests/747_tc040_function_execute_allowlist.sql` still passes. New client functions are allowlisted only when a client calls them. Internal helpers stay revoked.

### Progress, My Plan, Care

- [ ] Progress shows body-composition data when the outcomes tables have a reviewed fictional row, and an empty state when they do not.
- [ ] Ordinary My Plan does not fall through to `ProtocolData.mock`.
- [ ] Care does not invent a care team, phone number, or clinical advice. Missing product inputs render as unavailable.
- [ ] Loading, empty, error, and success are distinct.
- [ ] Fictional seeds are labelled and are not compiled in as if they were the patient’s plan.

### Integrated surfaces

- [ ] Physician roster / detail plus the P0 pages from #40 load against the local schema.
- [ ] Admin 2FA and roles still behave as on main.
- [ ] Invite-code sign-in, consents, and profile from #41 are present.
- [ ] Wearable daily upload from #39 is present.
- [ ] Partner API and Integrations from #38 are present.
- [ ] Cross-clinic and wrong-role cases stay denied.

### Safety residuals (report, do not hide)

- [ ] M8 (direct Auth password update bypassing the blocklist) is fixed on the local stack or listed as a residual blocker with owner Henry / Leo.
- [ ] Deploy checklist items that need a hosted project (Vault pepper, admin origin, RevenueCat secret, hosted `pg_cron`) stay documented and are not “fixed” by committing secrets.

### Proof required before calling a surface tested

- [ ] Command, SHA, and pass/fail recorded in the handover.
- [ ] A fresh local run is labelled separately from recorded GitHub CI on the source pull requests.
- [ ] Android debug APK only if a build log for this SHA exists.
- [ ] iOS not claimed.
- [ ] UI screenshots are from a running app, or the surface is marked not screenshotted.

## Local run (fictional)

From the repository root, after this branch is checked out. Do not point these commands at a hosted project.

```bash
cp .env.example .env
cp flutter_app/dart_defines.example.json flutter_app/dart_defines.json
# fill with the local `supabase status` URL and anon key only

supabase start
supabase db reset
supabase test db
npm ci
npm test
npm run lint
npm run dev
```

Patient app, when Flutter is available:

```bash
cd flutter_app && flutter pub get && flutter test
flutter build apk --debug --dart-define-from-file=dart_defines.json
```

Leave `LAB_AI_EXTRACTION_ENABLED` unset. The lab path must answer unavailable. Set it only on a machine where every report is fictional, and only with a key that is not committed.

## Tracker (integration branch only)

Original pull-request approvals do not cover this head. Nothing here is cleared for patient use, production, or a live notification.

| Finding | State on this branch |
|---|---|
| PR #38 M1 account enumeration | Fixed in the partner handler: existing and missing emails share `500 internal_error`. Deno test covers sandbox and a second client. |
| PR #38 M2 webhook SSRF | Fixed: resolve A/AAAA, refuse non-public addresses, pinned connect or `dns_pin_unavailable`. Mock DNS tests. No live metadata request. |
| PR #38 M3 withdrawn data_sharing | Fixed in `partner_patient_summary`. pgTAP 760 expects an empty summary, then a re-grant. |
| PR #37 H1 false “care team has been alerted” | Fixed. 911 guidance is always shown. A saved row says it was saved and that nobody is confirmed to have seen it. A failed save says nothing was filed. |
| PR #37 H2 escalated text reaches the model | Fixed. Those turns are marked withheld and omitted from model history, summary, memory, and the saved session text. |
| PR #37 M3 crisis phrases | Added the reported phrases, plus a short negation guard. Not a clinical triage. |
| PR #37 M4 client `kind` trusted | Server rewrites `kind` from the question text before the alert trigger. Mislabelled emergency language still alerts. Ordinary text labelled emergency does not. |
| PR #41 H1 consent timestamp two-step | Server owns `granted_at` / `revoked_at` for every role, including a null-to-past update. |
| PR #41 H2 health data without approved consent | Patient lab and file policies require the current non-placeholder `health_data` grant. Placeholder documents leave `documents_ready` false. The app does not enter clinical pages while status is loading, null, or unready. |
| PR #41 M3 date of birth | Profile trigger rejects under-18, future, and pre-1900 on insert and on a date change. A null date is left null. |
| PR #41 M4 resurrecting a withdrawal | Clearing `revoked_at` raises for staff and for the table owner. A new grant is a new row. |
| PR #41 M5 login-code budget and X-Forwarded-For | Reissue keeps the attempt count until the lock window ends. The rate-limit identity is the last forwarded hop. A rate-limit RPC error returns 503, not success. |
| PR #40 deletion versus freeze triggers | Deleting a user may only null that user’s foreign key after the user row is gone. Deleting a clinic may remove range sets and plan history only because the clinic row is gone. Direct edits still raise. Overlapping plan periods raise. |
| PR #40 timeline cursor | `patient_timeline` takes `(occurred_at, source, ref_id)`. The timeline page sends that tuple. |
| PR #40 CSV formula cells | A formula marker after a BOM, space, or newline is prefixed before quoting. |
| PR #39 wearable lows, PR #40 brief aggregation, PR #36 iOS startup, PR #42 magic-byte and size checks | Not in this pass. Recorded, not claimed fixed. |
| Facebook token still in git history | Not rotated and history not rewritten. A founder has to rotate that credential in the Facebook account. |

## Partner API review (8 Nov 2026)

Clara **blocks original pull request #38** at `cd66fb4857435ba85d2e98141c2bcbfc2e210463`
despite recorded CI 8/8 (run 41897253868). That block is on the original
branch. Fixes below are on this integration branch only. #38 itself is unchanged.
Recorded head tests (pgTAP 2113, Deno 152, vitest 298) did not catch these.

| Gate | On this branch |
|---|---|
| M1 POST /v1/patients disclosed account existence (409 `email_unavailable` vs 201), including a sandbox client probing another environment | External response is generic `500 internal_error` for an existing address and for any other create failure. A new address is still 201. `patient_already_exists` stays, because that is the caller's own id. |
| M2 webhook SSRF: a public-looking name can resolve to link-local or loopback and still pass SQL plus `isDeliverableUrl` | Delivery resolves A and AAAA. Any non-public address, including IPv4-mapped IPv6, denies the host. The connection target is the resolved address; SNI stays the hostname. No redirect is followed. If this runtime cannot pin, delivery records `dns_pin_unavailable` and does not call `fetch`. Tests use a mock resolver. No live metadata request. |
| M3 withdrawn `data_sharing` still returned lab values | `partner_patient_summary` returns empty health fields and `consent: not_granted` unless the latest `data_sharing` row is granted. pgTAP 760 now expects that denial, then re-grants and checks the positive summary. The withdrawal webhook still says `granted: false` and must not contain analyte names. |

Lows:

| Item | State |
|---|---|
| Idempotency cache stored webhook secrets for 7 days | Stripped in the handler and again in `partner_idempotency_complete`. Replay does not return `secret`. |
| Client secret hash compared with `<>` | `partner_issue_token` uses `_sha256_hex_equal`. |
| Sign-in ban ran after the deactivation write | Ban runs first. If it fails, the patient stays active. |
| Enrolment writes an invite into `notification_outbox` | Still true. Local send is the existing outbox stub (`emailStub.ts`), not a direct provider call. No new live send was added. A per-client enrolment rate limit is **not** added. |
| Shared webhook worker has no per-clinic cap | **Not done.** |

## Review status (8 Nov 2026, 11:38 IST)

Clara approved **pull request #35** at `fa7de1b9d236c6a5b0331d5d671045a54af69969`.
She reported no Medium or High findings. Recorded CI on that head was 8/8, with
pgTAP 1883, Flutter 737, Deno 118, and integration 101. Those counts are
Clara's recorded run on **#35**, not a run of this integration branch.

Ava has **not** approved the #35 UI.

Low from that review: `LabReportFileOpener.maxAttempts = 3` still passed tests
because the assertion read the constant. This branch pins the open path to
**two attempts** (the first try plus one fresh link) with literal `2`s in
`flutter_app/test/screens/lab_report_file_open_test.dart`. A third attempt
fails that test. The assertion was not loosened.

Clara is reviewing **pull request #42** at `2bd25e2190299a81262fbd5df85edda40374a575`.
Approval of #35 or #42 does **not** approve this integration head. Clara and
Ava review this branch's pull request on its own SHA. Original branches are
unchanged.

## Checklist progress on this branch

Done in code, pending a fresh run on this head:

- [x] File open retries exactly twice, and a 3-attempt mutation fails the test.
- [x] Manual biomarker insert does not store a fixed Normal status, range, or insight.
- [x] Patient held-report row, result, and file select are server policies (`20261105170000`, pgTAP `778`). Staff review access is unchanged. Allowlists `743` and `747` name the two new helpers.
- [x] Progress reads stored `body_composition_scans` or shows the empty state. It does not invent a score.
- [x] My Plan does not fall through to `ProtocolData.mock`.
- [x] Care says the care-team profile is unavailable and keeps Lab Results and Appointments.

Not done:

- [x] Fresh `npm test` (436 passed) and `npm run lint` on the admin app, and fresh `flutter test` (854 passed, 37 skipped) with Flutter 3.47.8. See the handover for the SHA. These are local reruns, not the recorded #35 counts.
- [ ] pgTAP, Deno edge tests, and the vitest integration suite. No Supabase CLI, Docker, or Deno in this environment. Not claimed.
- [ ] Android debug APK. Flutter is installed; the Android SDK is not. Not claimed.
- [ ] iOS signing. Not claimed.
- [ ] M8 (direct Auth password update). Still the accepted residual in `docs/RISKS.md`. No hosted GoTrue change was made.
- [ ] Ava UI pass and Clara review of **this** head.

## Out of scope for this milestone

Store listing, paid GoTrue leaked-password protection, a live telehealth adapter, a BAA, production DNS, and any real wearable or lab vendor account.
