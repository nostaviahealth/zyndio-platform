-- Data-driven cross-tenant matrix (the card's acceptance criterion: "RLS
-- tests must prove cross-tenant reads AND writes are denied for EACH role,
-- on every table"). Three directions, each actor x table x {select, insert,
-- update, delete}, one pgTAP assertion per cell so a failure names the exact
-- (actor, table, op):
--   1. every org A actor (org_admin_a, physician_a, care_coordinator_a,
--      read_only_a, patient_a1) against org B's row, on every RLS-policy
--      table (organizations, org_members, patients, patient_profiles,
--      lab_reports, consents, invites).
--   2. mirror direction: physician_b (org B) against org A's row, same
--      tables.
--   3. same-org, different-patient: patient_a1 against patient_a2's rows on
--      the four patient-owned tables (patients, patient_profiles,
--      lab_reports, consents) - org_id matches, patient identity doesn't.
--   4. every org A actor against org B's row on the four zero-policy/
--      revoked-grant tables (mfa_recovery_codes, auth_attempt_state,
--      audit_log, notification_outbox) - access is blocked at the grant
--      level regardless of org, so this is select/insert/update/delete all
--      denied rather than an org-filtered row count.
--
-- select: the specific other-tenant row must not appear (count = 0).
-- insert: inserting a row for the other tenant must be denied (exception).
-- update/delete: must affect 0 rows, and the row must be byte-for-byte
-- unchanged afterwards (verified by resetting to the pg_prove session role,
-- which is postgres/superuser and therefore bypasses RLS).
begin;
select no_plan();

create type tests.actor_spec as (label text, user_id uuid);
create type tests.table_spec as (tbl text, pk text, target_pk uuid, insert_sql text, insert_cleanup_sql text);
create type tests.locked_table_spec as (tbl text, touch_col text);

-- Local-only second org A patient (same pattern 030_patients.sql uses with
-- this same auth.users row: insert a patients row inside this file's own
-- transaction, so it never leaks into other test files' patient-count
-- assertions), giving the "same org, other patient" axis a real row.
insert into public.patients (id, org_id, display_name, mrn) values
  ('00000000-0000-0000-0000-0000000a6002', '00000000-0000-0000-0000-00000000000a', 'Fictional Patient A2', 'MRN-A2');
insert into public.patient_profiles (id, org_id, patient_id, data) values
  ('00000000-0000-0000-0000-0000000a6003', '00000000-0000-0000-0000-00000000000a', '00000000-0000-0000-0000-0000000a6002', '{"note":"fictional"}'::jsonb);
insert into public.lab_reports (id, org_id, patient_id, report_type, data) values
  ('00000000-0000-0000-0000-0000000a6004', '00000000-0000-0000-0000-00000000000a', '00000000-0000-0000-0000-0000000a6002', 'basic_panel', '{"result":"fictional"}'::jsonb);
insert into public.consents (id, org_id, patient_id, consent_type, granted) values
  ('00000000-0000-0000-0000-0000000a6005', '00000000-0000-0000-0000-00000000000a', '00000000-0000-0000-0000-0000000a6002', 'data_sharing', true);

-- ---------------------------------------------------------------------------
-- cell runner: one (actor, table) pair -> 5 assertions (select, insert,
-- update, delete, unchanged-after). Generic over the 7 RLS-policy tables and
-- the patient-axis tables alike - all keyed by a single pk column.
-- ---------------------------------------------------------------------------

create or replace function tests.xorg_cell(
  p_actor_label text,
  p_actor_id uuid,
  p_aal text,
  p_table text,
  p_pk text,
  p_target_pk uuid,
  p_insert_sql text,
  p_insert_cleanup_sql text
) returns setof text
language plpgsql
as $fn$
declare
  v_before jsonb;
  v_after jsonb;
  v_count int;
  v_affected int;
begin
  -- Start from the pg_prove session role (postgres, superuser - bypasses
  -- RLS even under FORCE ROW LEVEL SECURITY) so the "before" snapshot and
  -- fixture lookups are never themselves filtered by a policy.
  execute 'reset role';
  execute format('select to_jsonb(t) from public.%I t where %I = %L', p_table, p_pk, p_target_pk) into v_before;
  if v_before is null then
    raise exception 'xorg_cell: fixture row % = % missing in %', p_pk, p_target_pk, p_table;
  end if;

  perform tests.authenticate_as(p_actor_id, p_aal);

  execute format('select count(*) from public.%I where %I = %L', p_table, p_pk, p_target_pk) into v_count;
  return next is(v_count, 0, format('%s x %s x select other tenant: 0 rows', p_actor_label, p_table));

  begin
    execute p_insert_sql;
    -- Reaching here means the insert was NOT denied - a real policy hole.
    -- Report it as a failed assertion (not an exception) so the rest of the
    -- matrix keeps running, and clean up the illegally-inserted row so it
    -- doesn't corrupt later cells.
    return next fail(format('%s x %s x insert other tenant row: should have been denied', p_actor_label, p_table));
    execute 'reset role';
    execute p_insert_cleanup_sql;
    perform tests.authenticate_as(p_actor_id, p_aal);
  exception when others then
    return next ok(true, format('%s x %s x insert other tenant row: denied (%s)', p_actor_label, p_table, sqlerrm));
  end;

  execute format('update public.%I set created_at = created_at where %I = %L', p_table, p_pk, p_target_pk);
  get diagnostics v_affected = row_count;
  return next is(v_affected, 0, format('%s x %s x update other tenant: 0 rows', p_actor_label, p_table));

  execute format('delete from public.%I where %I = %L', p_table, p_pk, p_target_pk);
  get diagnostics v_affected = row_count;
  return next is(v_affected, 0, format('%s x %s x delete other tenant: 0 rows', p_actor_label, p_table));

  execute 'reset role';
  execute format('select to_jsonb(t) from public.%I t where %I = %L', p_table, p_pk, p_target_pk) into v_after;
  return next ok(v_after is not distinct from v_before, format('%s x %s row unchanged after update/delete attempts', p_actor_label, p_table));
end;
$fn$;

create or replace function tests.run_cross_org_direction(p_actors tests.actor_spec[], p_tables tests.table_spec[])
returns setof text
language plpgsql
as $fn$
declare
  a tests.actor_spec;
  t tests.table_spec;
begin
  foreach a in array p_actors loop
    foreach t in array p_tables loop
      return query select * from tests.xorg_cell(a.label, a.user_id, 'aal2', t.tbl, t.pk, t.target_pk, t.insert_sql, t.insert_cleanup_sql);
    end loop;
  end loop;
end;
$fn$;

create or replace function tests.locked_cell(p_actor_label text, p_actor_id uuid, p_aal text, p_table text, p_touch_col text)
returns setof text
language plpgsql
as $fn$
begin
  execute 'reset role';
  perform tests.authenticate_as(p_actor_id, p_aal);
  return next throws_ok(format('select count(*) from public.%I', p_table), null, null, format('%s x %s x select: permission denied', p_actor_label, p_table));
  return next throws_ok(format('insert into public.%I default values', p_table), null, null, format('%s x %s x insert: permission denied', p_actor_label, p_table));
  return next throws_ok(format('update public.%I set %I = %I', p_table, p_touch_col, p_touch_col), null, null, format('%s x %s x update: permission denied', p_actor_label, p_table));
  return next throws_ok(format('delete from public.%I', p_table), null, null, format('%s x %s x delete: permission denied', p_actor_label, p_table));
end;
$fn$;

create or replace function tests.run_locked_matrix(p_actors tests.actor_spec[], p_tables tests.locked_table_spec[])
returns setof text
language plpgsql
as $fn$
declare
  a tests.actor_spec;
  t tests.locked_table_spec;
begin
  foreach a in array p_actors loop
    foreach t in array p_tables loop
      return query select * from tests.locked_cell(a.label, a.user_id, 'aal2', t.tbl, t.touch_col);
    end loop;
  end loop;
end;
$fn$;

-- ---------------------------------------------------------------------------
-- Direction 1: every org A actor x every RLS-policy table, against org B's
-- row. Sentinel uuids (...e000N) are reserved for throwaway insert attempts
-- and never collide with real fixture ids.
-- ---------------------------------------------------------------------------

select * from tests.run_cross_org_direction(
  array[
    row('org_admin_a', '00000000-0000-0000-0000-0000000a0001'::uuid)::tests.actor_spec,
    row('physician_a', '00000000-0000-0000-0000-0000000a0002'::uuid)::tests.actor_spec,
    row('care_coordinator_a', '00000000-0000-0000-0000-0000000a0003'::uuid)::tests.actor_spec,
    row('read_only_a', '00000000-0000-0000-0000-0000000a0004'::uuid)::tests.actor_spec,
    row('patient_a1', '00000000-0000-0000-0000-0000000a1001'::uuid)::tests.actor_spec
  ],
  array[
    row(
      'organizations', 'id', '00000000-0000-0000-0000-00000000000b'::uuid,
      $i$insert into public.organizations (id, name) values ('00000000-0000-0000-0000-0000000e0001', 'xorg-attempt')$i$,
      $c$delete from public.organizations where id = '00000000-0000-0000-0000-0000000e0001'$c$
    )::tests.table_spec,
    row(
      'org_members', 'user_id', '00000000-0000-0000-0000-0000000b0001'::uuid,
      $i$insert into public.org_members (user_id, org_id, role, status) values ('00000000-0000-0000-0000-0000000a9001', '00000000-0000-0000-0000-00000000000b', 'physician', 'active')$i$,
      $c$delete from public.org_members where user_id = '00000000-0000-0000-0000-0000000a9001'$c$
    )::tests.table_spec,
    row(
      'patients', 'id', '00000000-0000-0000-0000-0000000b1001'::uuid,
      $i$insert into public.patients (id, org_id, display_name, mrn) values ('00000000-0000-0000-0000-0000000a9001', '00000000-0000-0000-0000-00000000000b', 'xorg-attempt', 'MRN-XORG')$i$,
      $c$delete from public.patients where id = '00000000-0000-0000-0000-0000000a9001'$c$
    )::tests.table_spec,
    row(
      'patient_profiles', 'id', '00000000-0000-0000-0000-0000000b2001'::uuid,
      $i$insert into public.patient_profiles (id, org_id, patient_id, data) values ('00000000-0000-0000-0000-0000000e0002', '00000000-0000-0000-0000-00000000000b', '00000000-0000-0000-0000-0000000b1001', '{}')$i$,
      $c$delete from public.patient_profiles where id = '00000000-0000-0000-0000-0000000e0002'$c$
    )::tests.table_spec,
    row(
      'lab_reports', 'id', '00000000-0000-0000-0000-0000000b3001'::uuid,
      $i$insert into public.lab_reports (id, org_id, patient_id, report_type, data) values ('00000000-0000-0000-0000-0000000e0003', '00000000-0000-0000-0000-00000000000b', '00000000-0000-0000-0000-0000000b1001', 'xorg-attempt', '{}')$i$,
      $c$delete from public.lab_reports where id = '00000000-0000-0000-0000-0000000e0003'$c$
    )::tests.table_spec,
    row(
      'consents', 'id', '00000000-0000-0000-0000-0000000b4001'::uuid,
      $i$insert into public.consents (id, org_id, patient_id, consent_type, granted) values ('00000000-0000-0000-0000-0000000e0004', '00000000-0000-0000-0000-00000000000b', '00000000-0000-0000-0000-0000000b1001', 'xorg-attempt', true)$i$,
      $c$delete from public.consents where id = '00000000-0000-0000-0000-0000000e0004'$c$
    )::tests.table_spec,
    row(
      'invites', 'id', '00000000-0000-0000-0000-0000000b5001'::uuid,
      $i$insert into public.invites (id, org_id, email, role, token_hash) values ('00000000-0000-0000-0000-0000000e0005', '00000000-0000-0000-0000-00000000000b', 'xorg-attempt@example.test', 'physician', 'x')$i$,
      $c$delete from public.invites where id = '00000000-0000-0000-0000-0000000e0005'$c$
    )::tests.table_spec
  ]
);

-- ---------------------------------------------------------------------------
-- Direction 2 (mirror): physician_b (org B staff) against org A's row, same
-- tables.
-- ---------------------------------------------------------------------------

select * from tests.run_cross_org_direction(
  array[
    row('physician_b', '00000000-0000-0000-0000-0000000b0001'::uuid)::tests.actor_spec
  ],
  array[
    row(
      'organizations', 'id', '00000000-0000-0000-0000-00000000000a'::uuid,
      $i$insert into public.organizations (id, name) values ('00000000-0000-0000-0000-0000000e0011', 'xorg-attempt')$i$,
      $c$delete from public.organizations where id = '00000000-0000-0000-0000-0000000e0011'$c$
    )::tests.table_spec,
    row(
      'org_members', 'user_id', '00000000-0000-0000-0000-0000000a0002'::uuid,
      $i$insert into public.org_members (user_id, org_id, role, status) values ('00000000-0000-0000-0000-0000000a9001', '00000000-0000-0000-0000-00000000000a', 'physician', 'active')$i$,
      $c$delete from public.org_members where user_id = '00000000-0000-0000-0000-0000000a9001'$c$
    )::tests.table_spec,
    row(
      'patients', 'id', '00000000-0000-0000-0000-0000000a1001'::uuid,
      $i$insert into public.patients (id, org_id, display_name, mrn) values ('00000000-0000-0000-0000-0000000a9001', '00000000-0000-0000-0000-00000000000a', 'xorg-attempt', 'MRN-XORG')$i$,
      $c$delete from public.patients where id = '00000000-0000-0000-0000-0000000a9001'$c$
    )::tests.table_spec,
    row(
      'patient_profiles', 'id', '00000000-0000-0000-0000-0000000a2001'::uuid,
      $i$insert into public.patient_profiles (id, org_id, patient_id, data) values ('00000000-0000-0000-0000-0000000e0012', '00000000-0000-0000-0000-00000000000a', '00000000-0000-0000-0000-0000000a1001', '{}')$i$,
      $c$delete from public.patient_profiles where id = '00000000-0000-0000-0000-0000000e0012'$c$
    )::tests.table_spec,
    row(
      'lab_reports', 'id', '00000000-0000-0000-0000-0000000a3001'::uuid,
      $i$insert into public.lab_reports (id, org_id, patient_id, report_type, data) values ('00000000-0000-0000-0000-0000000e0013', '00000000-0000-0000-0000-00000000000a', '00000000-0000-0000-0000-0000000a1001', 'xorg-attempt', '{}')$i$,
      $c$delete from public.lab_reports where id = '00000000-0000-0000-0000-0000000e0013'$c$
    )::tests.table_spec,
    row(
      'consents', 'id', '00000000-0000-0000-0000-0000000a4001'::uuid,
      $i$insert into public.consents (id, org_id, patient_id, consent_type, granted) values ('00000000-0000-0000-0000-0000000e0014', '00000000-0000-0000-0000-00000000000a', '00000000-0000-0000-0000-0000000a1001', 'xorg-attempt', true)$i$,
      $c$delete from public.consents where id = '00000000-0000-0000-0000-0000000e0014'$c$
    )::tests.table_spec,
    row(
      'invites', 'id', '00000000-0000-0000-0000-0000000a5001'::uuid,
      $i$insert into public.invites (id, org_id, email, role, token_hash) values ('00000000-0000-0000-0000-0000000e0015', '00000000-0000-0000-0000-00000000000a', 'xorg-attempt@example.test', 'physician', 'x')$i$,
      $c$delete from public.invites where id = '00000000-0000-0000-0000-0000000e0015'$c$
    )::tests.table_spec
  ]
);

-- ---------------------------------------------------------------------------
-- Direction 3: patient_a1 against patient_a2's rows (same org, different
-- patient) on the four patient-owned tables. On lab_reports/consents this
-- exercises the WITH CHECK (patient_id = auth.uid()) clause directly;
-- patients/patient_profiles have no patient-self-insert policy at all, so
-- those two are denied regardless of whose id is used.
-- ---------------------------------------------------------------------------

select * from tests.run_cross_org_direction(
  array[
    row('patient_a1', '00000000-0000-0000-0000-0000000a1001'::uuid)::tests.actor_spec
  ],
  array[
    row(
      'patients', 'id', '00000000-0000-0000-0000-0000000a6002'::uuid,
      $i$insert into public.patients (id, org_id, display_name, mrn) values ('00000000-0000-0000-0000-0000000a9001', '00000000-0000-0000-0000-00000000000a', 'xorg-attempt', 'MRN-XORG')$i$,
      $c$delete from public.patients where id = '00000000-0000-0000-0000-0000000a9001'$c$
    )::tests.table_spec,
    row(
      'patient_profiles', 'id', '00000000-0000-0000-0000-0000000a6003'::uuid,
      $i$insert into public.patient_profiles (id, org_id, patient_id, data) values ('00000000-0000-0000-0000-0000000e0021', '00000000-0000-0000-0000-00000000000a', '00000000-0000-0000-0000-0000000a6002', '{}')$i$,
      $c$delete from public.patient_profiles where id = '00000000-0000-0000-0000-0000000e0021'$c$
    )::tests.table_spec,
    row(
      'lab_reports', 'id', '00000000-0000-0000-0000-0000000a6004'::uuid,
      $i$insert into public.lab_reports (id, org_id, patient_id, report_type, data) values ('00000000-0000-0000-0000-0000000e0022', '00000000-0000-0000-0000-00000000000a', '00000000-0000-0000-0000-0000000a6002', 'xorg-attempt', '{}')$i$,
      $c$delete from public.lab_reports where id = '00000000-0000-0000-0000-0000000e0022'$c$
    )::tests.table_spec,
    row(
      'consents', 'id', '00000000-0000-0000-0000-0000000a6005'::uuid,
      $i$insert into public.consents (id, org_id, patient_id, consent_type, granted) values ('00000000-0000-0000-0000-0000000e0023', '00000000-0000-0000-0000-00000000000a', '00000000-0000-0000-0000-0000000a6002', 'xorg-attempt', true)$i$,
      $c$delete from public.consents where id = '00000000-0000-0000-0000-0000000e0023'$c$
    )::tests.table_spec
  ]
);

-- ---------------------------------------------------------------------------
-- Direction 4: every org A actor x the four zero-policy/revoked-grant
-- tables. Access is blocked at the grant level for everyone regardless of
-- org (070-100_*.sql already prove this per-table); this confirms it holds
-- for every role, not just the one or two actors sampled there.
-- ---------------------------------------------------------------------------

select * from tests.run_locked_matrix(
  array[
    row('org_admin_a', '00000000-0000-0000-0000-0000000a0001'::uuid)::tests.actor_spec,
    row('physician_a', '00000000-0000-0000-0000-0000000a0002'::uuid)::tests.actor_spec,
    row('care_coordinator_a', '00000000-0000-0000-0000-0000000a0003'::uuid)::tests.actor_spec,
    row('read_only_a', '00000000-0000-0000-0000-0000000a0004'::uuid)::tests.actor_spec,
    row('patient_a1', '00000000-0000-0000-0000-0000000a1001'::uuid)::tests.actor_spec
  ],
  array[
    row('mfa_recovery_codes', 'user_id')::tests.locked_table_spec,
    row('auth_attempt_state', 'user_id')::tests.locked_table_spec,
    row('audit_log', 'event_type')::tests.locked_table_spec,
    row('notification_outbox', 'type')::tests.locked_table_spec
  ]
);

select * from finish();
rollback;
