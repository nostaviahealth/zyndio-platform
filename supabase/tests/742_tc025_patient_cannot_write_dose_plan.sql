-- TC-025 C2: a patient (authenticated, own clinic, linked to their own patient
-- record) can NEVER write dose / plan / protocol / treatment data - not a new
-- row, not even their OWN row - by INSERT, UPDATE or DELETE, and there is no
-- authenticated-executable function that writes it for them.
--
-- Tables/columns holding dose/plan/protocol/treatment data (found by grepping
-- supabase/migrations for dose|dosage|protocol|regimen|prescription|medication|
-- supplement|therap|treatment|plan|intervention):
--   * public.patient_treatments  - POR-07 treatment context: name/started_on/
--     status/source. This is the ONLY table holding treatment/protocol data;
--     the schema deliberately has NO dose column
--     (20261027212000_tc015_schema.sql:11-13). DML is revoked from
--     authenticated+anon (same file L106); SELECT is allowed to the patient on
--     their own row and to in-clinic staff via policy.
--   * public.patient_roster_summary.has_treatment - a DERIVED boolean rollup of
--     "does this patient have any treatment row", maintained only by
--     SECURITY DEFINER triggers/refresh fns. Not dose data itself, but we assert
--     the patient cannot write it either (all DML revoked, L46 of
--     20261028160000_tc015_roster_summary.sql).
--   subscription_plan (patient_accounts) is a billing plan, not a care plan, so
--   it is out of scope here (covered by TC-026 742/734-style column lockdown).
--
-- No care-plan / medication / supplement / therapy / regimen / prescription
-- table exists in the schema; patient_treatments is the whole surface.
--
-- Function enumeration: we also assert, programmatically and structurally, that
-- NO function authenticated can EXECUTE writes to these tables, so a future
-- definer RPC that inserts/updates/deletes treatment rows can't slip in without
-- failing this test. (Today the only writers are refresh_roster_summary[_all],
-- SECURITY DEFINER with EXECUTE revoked from authenticated.)
begin;
select no_plan();

-- Seed one treatment row for patient A1 as the pg_prove superuser (DML is
-- revoked from authenticated/anon only, so the table owner can seed). This
-- gives the UPDATE/DELETE assertions a real OWN row to target, and firing the
-- insert trigger materialises patient_roster_summary for A1 too.
insert into public.patient_treatments (id, org_id, patient_id, name, started_on, status, source)
values (
  '00000000-0000-0000-0000-0000000a8001',
  '00000000-0000-0000-0000-00000000000a',
  '00000000-0000-0000-0000-0000000a1001',
  'Fictional Protocol A',
  '2026-01-10',
  'active',
  'clinic'
);

-- Act as patient A1 (own clinic A, linked to their own patient record).
select tests.authenticate_as('00000000-0000-0000-0000-0000000a1001', 'aal2');

-- Sanity: the patient CAN read their own treatment row (positive control, so a
-- blanket "deny everything" that also broke reads would be visible).
select is(
  (select name from public.patient_treatments
     where id = '00000000-0000-0000-0000-0000000a8001'),
  'Fictional Protocol A',
  'patient A1 can READ their own treatment row (positive control)'
);

-- ── patient_treatments: no write path, including the patient's OWN row ──
select throws_ok(
  $$ insert into public.patient_treatments (org_id, patient_id, name, status, source)
     values ('00000000-0000-0000-0000-00000000000a',
             '00000000-0000-0000-0000-0000000a1001',
             'Self-prescribed Protocol', 'active', 'patient') $$,
  '42501', null,
  'patient A1 cannot INSERT a treatment row (even for themselves)'
);

select throws_ok(
  $$ update public.patient_treatments set status = 'stopped'
       where id = '00000000-0000-0000-0000-0000000a8001' $$,
  '42501', null,
  'patient A1 cannot UPDATE their OWN treatment row'
);

select throws_ok(
  $$ update public.patient_treatments set name = 'Doubled Dose'
       where patient_id = '00000000-0000-0000-0000-0000000a1001' $$,
  '42501', null,
  'patient A1 cannot UPDATE treatment rows by patient_id either'
);

select throws_ok(
  $$ delete from public.patient_treatments
       where id = '00000000-0000-0000-0000-0000000a8001' $$,
  '42501', null,
  'patient A1 cannot DELETE their OWN treatment row'
);

-- Nothing the patient attempted changed the seeded row.
select is(
  (select status from public.patient_treatments
     where id = '00000000-0000-0000-0000-0000000a8001'),
  'active',
  'treatment row is byte-for-byte unchanged after every blocked write'
);

-- ── patient_roster_summary.has_treatment: derived flag, also unwritable ──
select throws_ok(
  $$ update public.patient_roster_summary set has_treatment = false
       where patient_id = '00000000-0000-0000-0000-0000000a1001' $$,
  '42501', null,
  'patient A1 cannot UPDATE the derived has_treatment rollup flag'
);

select throws_ok(
  $$ insert into public.patient_roster_summary (patient_id, org_id, has_treatment)
     values ('00000000-0000-0000-0000-0000000a1001',
             '00000000-0000-0000-0000-00000000000a', false) $$,
  '42501', null,
  'patient A1 cannot INSERT into patient_roster_summary'
);

select throws_ok(
  $$ delete from public.patient_roster_summary
       where patient_id = '00000000-0000-0000-0000-0000000a1001' $$,
  '42501', null,
  'patient A1 cannot DELETE from patient_roster_summary'
);

-- ── Structural: no authenticated-executable function writes these tables ──
-- has_function_privilege over pg_proc catches any current OR future function
-- (definer or invoker, any non-system schema) that both (a) authenticated may
-- EXECUTE and (b) writes patient_treatments. Expected set is empty: the only
-- treatment-adjacent writers are refresh_roster_summary[_all], which are
-- SECURITY DEFINER with EXECUTE revoked from authenticated.
select is(
  (select coalesce(
      array_agg(n.nspname || '.' || pr.proname order by n.nspname, pr.proname),
      array[]::text[])
   from pg_proc pr
   join pg_namespace n on n.oid = pr.pronamespace
   where n.nspname not in ('pg_catalog', 'information_schema', 'extensions', 'pgtap', 'tests')
     and has_function_privilege('authenticated', pr.oid, 'execute')
     and (
       pr.prosrc ~* 'insert\s+into\s+(public\.)?patient_treatments'
       or pr.prosrc ~* 'update\s+(public\.)?patient_treatments'
       or pr.prosrc ~* 'delete\s+from\s+(public\.)?patient_treatments'
     )),
  array[]::text[],
  'no authenticated-executable function writes to patient_treatments'
);

select is(
  (select coalesce(
      array_agg(n.nspname || '.' || pr.proname order by n.nspname, pr.proname),
      array[]::text[])
   from pg_proc pr
   join pg_namespace n on n.oid = pr.pronamespace
   where n.nspname not in ('pg_catalog', 'information_schema', 'extensions', 'pgtap', 'tests')
     and has_function_privilege('authenticated', pr.oid, 'execute')
     and (
       pr.prosrc ~* 'insert\s+into\s+(public\.)?patient_roster_summary'
       or pr.prosrc ~* 'update\s+(public\.)?patient_roster_summary'
       or pr.prosrc ~* 'delete\s+from\s+(public\.)?patient_roster_summary'
     )),
  array[]::text[],
  'no authenticated-executable function writes to patient_roster_summary'
);

select * from finish();
rollback;
