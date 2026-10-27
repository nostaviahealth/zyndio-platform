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
