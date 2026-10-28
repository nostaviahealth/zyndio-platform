# TC-015 pgTAP fail-first replay (assertion-level)

Henry's item 3: show that the TC-015 pgTAP acceptance tests fail **at their
assertions** (not at the first fixture insert) before the fix, and pass after.

Replayed by Leo on 28 Oct 2026, ~13:15–13:25 IST. Local only, no Claude session, nothing pushed.

## Method

1. Throwaway worktree, detached at `c2514d6`. That's the last test-only commit,
   just before the schema commit `038e46b`. At `c2514d6` the four files bail
   on their first insert (`column "identity_hold" of relation "lab_reports"
   does not exist`), so no assertion is reached.
2. Copied `shim_naive_unsafe.sql.txt` into that throwaway worktree only, as
   `supabase/migrations/20261027212000_REPLAY_SHIM_naive_unsafe.sql`. It is stored here
   as `.txt` so it can never be picked up as a migration. **It isn't committed
   anywhere as a migration, and it isn't part of the product.**
3. `supabase db reset`, then
   `supabase test db supabase/tests/000_fixtures.sql 710… 715… 717… 719…`
   → `pgtap-c2514d6-with-shim.txt`.
4. Removed the throwaway worktree. At tip `24c06d7` (real migrations, no shim),
   ran `supabase db reset` and the same five files → `pgtap-tip-24c06d7.txt`.
   Per-assertion TAP lines (each file run with psql on the same DB) are in
   `pgtap-tip-24c06d7-verbose-tap.txt`.

## What the shim is

The shim models the naive, unsafe build the tests exist to reject. It adds the
tables and columns the fixtures need, but:

- no RLS, and SELECT granted to `authenticated`;
- the RPCs are SECURITY DEFINER with no clinic or role scoping;
- no needs-review, unmapped or identity-hold exclusions;
- no audit write;
- `patient_treatments` carries a `dose` column;
- the detail payload is `to_jsonb()` of whole rows, with no whitelist.

It keeps only behaviour that isn't a safety rule: the trend period window
(3M/6M/1Y/ALL, default 6M) and latest-per-analyte ordering. That way each
failure points at the missing safety rule.

## Results

| File | At `c2514d6` + shim | At tip `24c06d7` |
|---|---|---|
| 710 roster/detail isolation | 10 of 18 fail: 1, 4, 6, 9, 13, 14, 15, 16, 17, 18 | 18/18 ok |
| 715 trend/latest exclusions | 8 of 10 fail: 1, 2, 3, 4, 6, 7, 8, 9 | 10/10 ok |
| 717 detail-open audit | 2 of 6 fail: 2, 3 | 6/6 ok |
| 719 no dose | 3 of 5 fail: 1, 3, 4 | 5/5 ok |

Total at `c2514d6` with the shim: 23 of 39 assertions fail (`Result: FAIL`).
At the tip: 39 of 39 pass, plus the fixture file (`Files=5, Tests=40, Result: PASS`).

### Failing assertions at `c2514d6` + shim (have → want)

- **710:**
  - #1 physician_a sees org B lab_results: 1 → 0.
  - #4 org B patient in roster: 1 → 0.
  - #6 org B detail returns the full payload, want NULL.
  - #9 org B trend: 1 → 0.
  - #13 read_only sees lab_results: 2 → 0.
  - #14 read_only detail returns the payload, want NULL.
  - #15 read_only trend: 1 → 0.
  - #16 physician_b selects a1001 lab_results: 1 → 0.
  - #17 physician_b detail returns the payload, want NULL.
  - #18 physician_b trend: 1 → 0.
- **715:**
  - #1 trend ALL: 5 → 4 (identity-hold point included).
  - #2 6M: 4 → 3, and #3 default period: 4 → 3, both because of the identity-hold point.
  - #4 identity-hold 9.9 in trend: 1 → 0.
  - #6 needs-review hsCRP in trend: 1 → 0.
  - #7 unmapped Lp-PLA2 in trend: 1 → 0.
  - #8 latest HbA1c: 9.9 → 5.5.
  - #9 identity-hold value in latest: 1 → 0.
- **717:**
  - #2 one audit row after one open: 0 → 1.
  - #3 a second open: 0 → 2.
- **719:**
  - #1 `patient_treatments` has a `dose` column.
  - #3 the treatment JSON has a `dose` key.
  - #4 non-whitelist keys in the treatment JSON: 4 → 0 (id, org_id, patient_id, dose).

### Assertions that pass even with the shim, and why

- **Positive paths, which are supposed to pass:** 710 #2, #3, #5, #7, #8, #10, #11, #12; 715 #5 and #10; 717 #1; 719 #2.
- **717 #4–#6** ("no row for an invisible patient") pass trivially, because the
  shim writes no audit rows at all. These assertions only bite against an
  implementation that audits without checking visibility. They are a guard,
  and this shim doesn't exercise it.
- **719 #5** (no top-level `dose` key) passes, because the shim nests the
  treatment row under `treatment`. The nested dose is caught by #3 and #4.

## Clara L32: shim variant B ("audits without a visibility check")

Under the naive shim, 717 #4–#6 passed trivially because it never audits. To make
them bite, `shim_audit_no_visibility.sql.txt` repeats the naive shim with one
change: `open_patient_detail` writes a `patient_detail_opened` row on every
call, before and without any visibility check. Like the first shim, it is test-only
(`.sql.txt`) and was applied only in a throwaway worktree at `c2514d6` (removed afterwards).

Replay on 28 Oct 2026, ~15:05 IST: `supabase db reset`, then `supabase test db 000_fixtures.sql 717_…sql`.
The output is in `pgtap-c2514d6-l32-shim-717.txt`.

| 717 assertion | Variant B result |
|---|---|
| #1 open succeeds | ok |
| #2 one row after one open | ok |
| #3 a second open adds one row | ok |
| #4 cross-org open writes no row | **not ok** (have 1, want 0) |
| #5 read_only open writes no row | **not ok** (have 1, want 0) |
| #6 unknown-id open writes no row | **not ok** (have 1, want 0) |

So all six 717 assertions have now failed at their assertions against an
unsafe implementation: #2–#3 under the naive shim, and #4–#6 under variant B. #1
is a positive `lives_ok` and is expected to pass.
Note: #5 encodes the pre-flip rule that read_only gets no detail. The read-only
fix round replaces it (read_only opens must now be audited); see the
read-only section below once it lands.

## Read-only: no raw lab_reports

1826162 ("read_only can view own-clinic detail + trends, audited") restored a
`lab_reports_staff_read_only_select` policy so read_only could pass through
`patient_trend`'s NOT EXISTS check and `patient_latest_results`'s join on
`lab_reports`. Leo's fix-round ruling: that is broader than the card.
read_only gets the roster, the detail (header + treatment whitelist) and the
Labs tab data (`lab_results`, trends, latest) - not the raw `lab_reports`
rows/`data` (the report viewer is TC-016). Henry's H2 ruling stands for
`lab_reports` (also `patient_profiles`, `consents`).

`704e8ef` restored `050_lab_reports.sql`, `210_in_org_role_matrix.sql` and
`500_review_probes.sql` to their exact pre-1826162 content (read_only sees 0
`lab_reports` rows again), added `716_tc015_read_only_exclusions.sql`
asserting the identity-hold exclusion still holds for read_only, and added
migration `20261028153000_tc015_read_only_no_raw_reports.sql` which drops
only `lab_reports_staff_read_only_select`. With nothing else changed, the
identity-hold exclusion in `patient_trend` and `patient_latest_results`
depends on a join/NOT EXISTS against `lab_reports` that read_only can no
longer see, so it silently fails open instead of excluding:

Replay (9-file prefix, `supabase db reset` then `supabase test db` over
000_fixtures/050/210/500/710/715/716/717/719):
`pgtap-prefix-read-only-no-raw-reports.txt`.

| Assertion | Result |
|---|---|
| 050/210/500 (H2 restored) | ok |
| 710 #17 `read_only_a gets latest results for a1001` | **not ok** (have 0, want 1) |
| 716 #2 `read_only_a HbA1c trend has only the visible point` | **not ok** (have 2, want 1 - identity-hold 9.9 leaks in) |
| 716 #3 `identity-hold HbA1c value (9.9) is absent from the trend` | **not ok** (have 1, want 0) |
| 716 #6 `latest HbA1c is the visible 5.5` | **not ok** (have NULL, want 5.5 - the join excludes everything once lab_reports is unreadable) |

`145b2b5` fixes this: `20261028154000_tc015_identity_hold_helper.sql` adds
`public.lab_report_held(uuid)` - SECURITY DEFINER, STABLE, fails CLOSED (an
unreadable or nonexistent report counts as held) - and switches
`physician_roster_base`, `patient_trend` and `patient_latest_results` to call
it instead of joining/NOT EXISTS'ing `lab_reports` directly. All three RPCs
stay SECURITY INVOKER; only the one boolean check moved to a definer
function. Full `supabase test db`: 959/959 green (49 files).

## Read-only fix round: shim replays of the new tests (28 Oct 2026, ~15:30 IST)

The new read-only assertions are in 710 #12–#31, 716 #1–#7 and 717 #6–#7. 717 #5 now
covers unknown ids, after the renumbering. Each assertion was replayed with the fix-round
test files copied into a throwaway worktree at `c2514d6`, with one shim loaded per run.
Each worktree was removed after its run. Outputs:

- `pgtap-c2514d6-naive_unsafe-fixround-710-716-717.txt`: the naive shim (`shim_naive_unsafe.sql.txt`).
- `pgtap-c2514d6-read_only_writes-fixround-710-716-717.txt`: variant C, `shim_read_only_writes.sql.txt`.
  It is the naive shim plus permissive no-op versions of `flag_lab_report_needs_review`,
  `create_patient_record`, `change_member_role` and `request_mfa_reset`, and
  INSERT/UPDATE/DELETE grants on the TC-015 tables.
- `pgtap-c2514d6-audit_no_visibility-fixround-710-716-717.txt`: variant B (L32).
- `pgtap-1826162-716.txt`: 716 run at `1826162`, the intermediate commit that briefly gave read_only SELECT on raw lab_reports.

Pre-fix runs on the real code are also here:
- `pgtap-prefix-76a43d5-read-only.txt`: the tests run before the RLS/RPC flip.
- `pgtap-prefix-read-only-no-raw-reports.txt`: the state before the `lab_report_held()` fix.
- `vitest-prefix-readonly-links.txt`: the UI link test.

| Requirement | Assertions | Fails at its assertion against |
|---|---|---|
| (a) own clinic: list, detail, trends, latest | 710 #13, #14, #16, #17 | pre-fix code (`76a43d5`): have 0 / NULL, want 1 / non-null |
| (a) detail is whitelisted | 710 #15 | naive shim (have 3 non-whitelisted keys, want 0) |
| (a) list row | 710 #12 | none: a positive assertion that already held before the fix |
| (a) identity-hold, needs-review and unmapped excluded for read_only | 716 #2–#7 | naive shim (all six). #2, #3 and #6 also fail on the pre-fix `lab_report_held` state |
| (a) no raw lab_reports (H2 stands) | 716 #1 | `1826162` (have 2, want 0) |
| (b) nothing from another clinic | 710 #18–#23 | naive shim (have 1, want 0). #23 got an org-B treatment fixture this round; before that it passed vacuously |
| (c) refused every write/action RPC | 710 #24–#27 | variant C only (`caught: no exception, wanted: 42501`) |
| (c) refused direct writes | 710 #28–#31 | naive shim and variant C (no exception) |
| (d) audit row on every read-only open | 717 #6–#7 | pre-fix code and naive shim (have 0, want 1 / 2) |
| (L32) no audit row for invisible opens | 717 #4 (cross-org), #5 (unknown id) | variant B (have 1, want 0) |

L32, after the flip: the read-only open used to sit at 717 #5 and expected 0 audit rows.
That assertion now lives at #6–#7 and expects one audit row per open, so variant B
correctly passes it. The two invisible-patient assertions (#4 and #5) still fail
against variant B. The earlier L32 run above used the pre-flip 717.

## Roster speed: 720 parity and 721 privileges (28 Oct 2026)

- `720_tc015_roster_perf_parity.sql` (37 assertions, by C3):
  `pgtap-prefix-roster-perf.txt`. Before the summary-table migration, the 10
  structural assertions fail and the 27 parity and drift assertions pass. The
  test checks the new summary against the old per-result computation, so it is
  meant to pass before the migration.
- `721_tc015_roster_summary_privs.sql` (6 assertions, Leo's review of C3):
  `pgtap-prefix-721-summary-privs.txt`. At 5b3d0c7, #2 and #4 fail:
  `authenticated` could execute the SECURITY DEFINER
  `refresh_roster_summary(uuid)` and `refresh_roster_summary_all()` through
  Supabase's default privileges. Fixed in `20261028161500_tc015_roster_summary_revoke.sql`.
