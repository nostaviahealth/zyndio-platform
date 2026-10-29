# ADR-0001: Named SECURITY DEFINER exception — `public.physician_roster_base()`

- Status: Accepted, conditional on Henry's review (28 Oct 2026, T3 room). Merge waits on Henry.
- Card: TC-015 (physician patient list and detail), fix round item 5 (5,000-patient speed).
- Supersedes, for this one function only: "Leo ruling 3" — every clinical read RPC is `SECURITY INVOKER` and relies on RLS.

## Context

At 5,000 patients the invoker form of the roster base re-evaluated the per-row RLS
helpers (`current_org_id()`, `has_aal2()`, `current_role()`, each an `org_members`
lookup) on `patients`, `patient_roster_meta` and `patient_roster_summary`. The first page took
~290–314 ms, which is over the < 200 ms budget. Switching to `SECURITY DEFINER` with a
staff gate that runs once brings the first page to 9.9 ms median at 5,000 patients
(`docs/perf/tc-015/timings-5000-hardened.txt`).

## Decision

`public.physician_roster_base()` is the **only** clinical read function allowed to
be `SECURITY DEFINER`. The callers are the invoker RPCs `physician_patient_roster()` and
`physician_roster_chip_counts()`. Any other definer read needs its own ADR.

The exception holds only while all of these conditions are true. Each one is enforced by a pgTAP test:

| # | Condition | Where | Test |
|---|-----------|-------|------|
| 1 | `search_path` pinned to `''`; every relation and helper in the body is schema-qualified (`public.*`). Built-ins resolve from `pg_catalog`, which Postgres always searches implicitly. | `20261028170000_tc015_roster_base_definer_hardening.sql` | 722 #1 |
| 2 | `EXECUTE` revoked from `PUBLIC` and `anon`. Only `authenticated` and `service_role` keep it. | same | 722 #3–5, #14–15 |
| 3 | No parameters. The clinic comes only from `public.current_org_id()`, which is the caller's own **active** `org_members` row, looked up by `auth.uid()` from the verified JWT. A forged `org_id` claim (top-level or `app_metadata`) is ignored. | same | 722 #6, #9 |
| 4 | Staff gate, evaluated once: the session is aal2 **and** the role is in `physician`, `care_coordinator`, `read_only` (otherwise zero rows). Rows are filtered explicitly to `p.org_id = current_org_id()`. | `20261028160000_tc015_roster_summary.sql` | 722 #7–15 |
| 5 | Zero rows for each of these callers: a physician from another clinic, an org_admin, an aal1 session, a patient, a deactivated member, and anon. | — | 722 #8, #10–15 (fail-first replays below) |
| 6 | Same visibility and flags as the invoker definition it replaced. | — | 720 (parity oracle) |

Related hardening in the same round: the definer helper `public.lab_report_held()` is now
scoped to `current_org_id()` and fails closed, so a report in another clinic returns the same answer as a
report that does not exist (test 723). The roster-summary maintenance path uses
`public.lab_report_held_unscoped()`, which no client can call (EXECUTE is revoked from PUBLIC, anon,
authenticated and service_role).

## Consequences

- If the gate or the org scope ever regresses, 722 fails. The replays below show that it does:
  - `docs/evidence/tc-015/failfirst-replay/pgtap-722-gate-removed-role_aal.txt`: the role/aal gate is removed and the org scope kept. The org_admin and aal1 tests fail.
  - `docs/evidence/tc-015/failfirst-replay/pgtap-722-gate-removed-all.txt`: the whole gate is removed. The other-clinic, forged-claim, org_admin, aal1, patient and deactivated tests fail.
  - `docs/evidence/tc-015/failfirst-replay/pgtap-722-current-code.txt`: 14e1296, where the search_path was not yet pinned.
- The anon case still passes in both shims. That is expected, because anon is blocked by the grant, not by the gate.
- RLS stays on every table underneath. The definer bypasses it only inside this one gated function.
- Revisit this exception if Postgres or Supabase gets cheap per-statement caching of the RLS helpers. The invoker form would then meet the budget.
