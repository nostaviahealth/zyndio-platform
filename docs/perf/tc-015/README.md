# TC-015 roster / trend query-plan evidence

Raw `EXPLAIN (ANALYZE, BUFFERS)` and timing output for the physician roster and
patient-trend RPCs, captured against the local Supabase stack loaded with the
500-patient perf seed (`scripts/seed-perf-500.sh` →
`supabase/seed/perf_500_patients.sql`). All queries run inside a physician JWT
context (`role = authenticated`, `aal2`, `sub` = the perf-org physician) via
`tests.authenticate_as`, so RLS is fully in force — the same path the app takes.

## Dataset

One perf org (`0000f015-…-00000000000a`), queried as physician
`0000f015-…-0000000a0002`:

| table                 | rows  |
|-----------------------|-------|
| patients              | 500   |
| patient_roster_meta   | 500   |
| patient_treatments    | 250   (every even patient) |
| lab_reports           | 571   (500 primary + 71 identity-hold) |
| lab_results           | 2 496 |

Lab states covered: needs-review (hsCRP), unmapped (Lp-PLA2), corrected
(`original_value`), no-range, single-result, and identity-hold.

## Timings (`timings.txt`)

Roster first page — `physician_patient_roster(null, 'all', 'recent', 8, 0)`,
500 patients, 5 consecutive runs:

```
122.1 ms, 115.4 ms, 117.8 ms, 119.3 ms, 119.4 ms   (≈ 119 ms median)
```

Chip counts — `physician_roster_chip_counts()`: ~126 ms (whole-org single pass).

`patient_trend(…, 'hba1c', 'ALL')`: **5.4 ms** (`trend-explain.txt`).

Budget was "first page well under 1 s" — met with ~8× headroom.

## Plans and indexes (`roster-explain.txt`, `trend-explain.txt`)

Roster — one set-based statement; the SQL function inlines to a chain of
nested-loop joins driven entirely by index scans, no sequential scans:

- `patients_org_id_idx` — org scoping (`org_id = current_org_id()`), 500 rows.
- `patient_roster_meta_pkey` — per-patient meta lookup.
- `lab_results_patient_analyte_taken_idx` — the per-patient lateral labs
  aggregate (latest draw / flag rollup).
- `lab_reports_pkey` — the identity-hold join on each result.
- `patient_treatments_patient_id_idx` — the `limit 1` clinical-context probe.

`count(*) over ()` supplies the pre-limit total in the same pass, and a top-N
heapsort (default `last_activity_at desc, display_name`) feeds the `limit 8`.

Trend — `lab_results_patient_analyte_taken_idx` is a covering match for the
`(patient_id, analyte_key, taken_at)` predicate; the plan touches only the
target patient's handful of rows (buffers hit 914, 5 points returned).

## Why there is no N+1

Both RPCs are single SQL statements. The per-patient work in the roster is
expressed as `LEFT JOIN LATERAL` subqueries, so the planner runs them as
index-driven nested loops inside one query plan — 500 bounded index probes, not
500 round-trips from the application. The roster returns a complete, paginated,
counted page in one call; the trend returns a full analyte series in one call.
No part of the page requires a follow-up query per row.

## Reproduce

```bash
supabase start                 # if not already running
bash scripts/seed-perf-500.sh  # idempotent
# then EXPLAIN/timing under tests.authenticate_as('0000f015-…-0000000a0002','aal2')
```

## Fix round, 28 Oct 2026: 5,000 patients (card item 7 target)

Seed: `scripts/seed-perf-5000.sh` → `supabase/seed/perf_5000_patients.sql`
(fictional, local only; same perf org and physician as the 500 seed; MRNs
`lpad(n,5)`). Captured by Leo on the committed migrations
(`20261028160000_tc015_roster_summary.sql`) with
`_driver_explain_5000.sql`, `_driver_inline.sql` and `_driver_timings_5000.sql`,
all under the perf-org physician JWT (`authenticated`, aal2), so the same
access path as the app.

Design: (B) a maintained per-patient `patient_roster_summary` table, kept
current by triggers on `lab_results`, `lab_reports` (identity_hold) and
`patient_treatments`. (A) paginate-then-summarise only meets the budget for the
`all` view: `flagged`, `missing_labs` and the chip counts need flag state for
every patient. `physician_roster_base()` is SECURITY DEFINER with a one-time
staff gate (aal2, physician / care_coordinator / read_only, own org only).
`roster-explain-5000.txt` ends with the same body run as invoker: 314 ms and
~92k buffers, mostly per-row RLS helper calls. That is why the gate runs once.

`timings-5000.txt` (psql `\timing`, 5 runs each, round trip included):

| Call (first page, limit 8)          | median   | max      | < 200 ms |
|-------------------------------------|----------|----------|----------|
| roster all / recent                 | 8.8 ms   | 13.6 ms  | PASS     |
| roster flagged                      | 7.6 ms   | 7.8 ms   | PASS     |
| roster missing_labs                 | 6.4 ms   | 8.4 ms   | PASS     |
| roster questions_waiting            | 6.5 ms   | 6.6 ms   | PASS     |
| roster name search "Patient 123"    | 10.1 ms  | 12.0 ms  | PASS     |
| roster all / page 2 (offset 8)      | 8.8 ms   | 8.9 ms   | PASS     |
| `physician_roster_chip_counts()`    | 6.7 ms   | 7.2 ms   | PASS     |

`EXPLAIN (ANALYZE, BUFFERS)` execution times for the shipped RPCs at 5,000:
5.6–11.6 ms. There is no `lab_results` node and no `loops=5000` in any shipped
plan. Parity with the old per-result computation is covered by
`supabase/tests/720_tc015_roster_perf_parity.sql` (37 assertions, fail-first in
`docs/evidence/tc-015/failfirst-replay/pgtap-prefix-roster-perf.txt`).

### Re-timed after the definer hardening (28 Oct, 17:1x IST)

These times were taken after `search_path=''`, the PUBLIC/anon revoke and the `lab_report_held` org scope, with the same driver and 5,000-patient seed (`timings-5000-hardened.txt`). Each is the median/max of 5 runs:

| Query | ms |
|---|---|
| all / first page | 9.9 / 14.6 |
| flagged | 7.5 / 8.1 |
| missing_labs | 7.8 / 9.0 |
| questions_waiting | 6.7 / 9.5 |
| name search | 14.2 / 15.8 |
| page 2 | 12.5 / 20.0 |
| chip counts | 9.4 / 10.0 |

Every query is still well under 200 ms.
