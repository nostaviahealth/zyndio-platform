# DELIVERY-NOV9

Owner: Leo / Henry integration. Independent review: Clara. UI: Ava.
Branch: `cursor/nov9-fictional-test-candidate-80a4` (pull request 43). Not a merge approval.

## Acceptance

A tester can reset a local synthetic database, run the patient and clinic paths, and see only fictional data. The extractor stays off unless a local flag is set. No production project, no real report, no live notification, no Brett sample.

This card is not a claim that the candidate is ready. Clara and Ava have not approved the head.

## Scope now in the branch

Pull requests 35–42 and `c2-outcomes-engine` `ebbed40` are already ancestors of this branch. Confirmed 8 Nov 2026: `ebbed40` parent is `main` `7f283f5`, and the outcomes files are present.

Still to integrate, each one commit on `main`, heads rechecked this session:

| Branch | Head | What it adds |
|---|---|---|
| `ai-kill-switch` | `d018f71ce289` | Per-clinic and per-feature AI switches |
| `claude/bold-cerf-605f7b` | `3ee151fd37be` | APP-03, POR-07, POR-08, INT-04 |
| `claude/ops-billing-ops01-03-pp02` | `62f1925bf886` | PP-02, OPS-01, OPS-02, OPS-03 |
| `claude/ecstatic-kepler-1ff6a6` | `da2551cd2ced` | APP-06 lab wording |

`normalisation-engine` is Leo's repository. This branch does not edit it and does not copy it.

## Priority 1, this checkpoint

1. Secrets: the live fixture in `777` must not look like an API key. Commit `ebbed40` still contains the old fixture. The scanner keeps its rules. One exact historical string is ignored so the full-history scan can pass without a rewrite.
2. Database: patient lab reads in older tests get an explicit synthetic non-placeholder health-data grant inside that test. Withdrawing a consent stays irreversible; tests that need the grant again insert a new row. The last-admin protection stays; the deletion test keeps a second admin. `761` checks the revoked row only.
3. Paused local edits kept: iOS startup timeout, no FCM token log, ATS arbitrary loads removed, deployment target 16.1, Facebook advertiser and auto-log off, lab size and magic-byte checks, emergency copy without a hard-coded country hotline. iOS is not verified without a Mac build.

## DELIVERY-NOV9-C2 (outcomes, already in this branch)

`c2-outcomes-engine` `ebbed40` is an ancestor of this branch. Clara’s review of that commit is a release blocker here. Acceptance for this slice:

- A partner key is bound to one clinic. `X-Partner-Org-Id` cannot choose another clinic, and no scan or outcome write runs when it does.
- `anon` and `authenticated` cannot `TRUNCATE` `body_composition_scans` or `outcome_records`.
- A delivered outcome cannot be cycled back to `in_review` and then rewritten. A correction is a new `record_version`.
- Binding an unmatched scan requires an explicit patient plus a matching MRN and partner patient id. The queue does not preselect a patient. A mismatch, another clinic, and a reject path are tested.
- Partnership disclosure uses the latest `partner_disclosure` row only. A granted `data_sharing` row does not override a withdrawn or missing partner disclosure. The APP-03 row stores the current document version and the server hash of that document.
- HOMA-IR uses the documented same-draw formula after unit conversion. Unknown units, a zero baseline, and negative glucose do not become a clinical trend. Insulin pmol/L uses 6.945.
- DEXA dates and body measures are checked. A caller-supplied document URL is refused. There is no live storage bucket and no PDF parser in this branch; the document route does not pretend to parse a file.

## DELIVERY-NOV9-OPS (PP-02, OPS-01, OPS-02, OPS-03)

Clara’s review of `62f1925` is in this branch. Acceptance for this slice:

- `record_patient_monthly_activity` authorises `auth.uid()` and `auth.role()`, never `current_user`. A patient can meter only themself. A physician or care coordinator at MFA can meter a patient in their own clinic. Read-only staff and other clinics are refused. The stored month is the server UTC clock. The first write for a patient-month is audited. Patient login and a new lab report call this path.
- Schedule B amounts stay 0 through 1,000, then $0.50, $0.35, and $0.25. 10,000 active patients is $3,375.
- A deletion certificate is inserted only after lab reports, profiles, consents, treatments, roster birth date, account name, auth email, and storage objects for that patient are verified gone or anonymised. A failed check returns `pending` and writes no certificate. Legal hold still blocks the delete. Audit rows are not deleted.
- A security incident flag does not mean anyone was notified. The row stays a draft or `pending_approval`. Approval marks `approved_unsent`. A passed deadline becomes `overdue`. The outbox row says `sent: false`. No message is sent.
- A termination export manifest includes display names and lab payloads. While `readonly_until` is in the future, clinical writes are refused. Deletion scrub is the exception.

## Still after this checkpoint

Kill-switch findings H1–H3, then the three remaining branches, then APP-06 wording. Wearable lows, M8 password blocklist, and native iOS remain open until their own commits say otherwise.

## Run

```bash
supabase start
supabase db reset && supabase test db
```

Extractor unset. Fictional data only.
