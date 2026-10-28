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
