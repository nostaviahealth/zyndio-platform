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

## Out of scope for this milestone

Store listing, paid GoTrue leaked-password protection, a live telehealth adapter, a BAA, production DNS, and any real wearable or lab vendor account.
