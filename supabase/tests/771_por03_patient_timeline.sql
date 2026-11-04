-- POR-03: patient timeline over the registered sources.
--
-- Proves: newest-first union of labs / treatment / program / visits; labs
-- grouped per report with effective status; identity-held reports excluded;
-- no dose anywhere; other clinic, unknown id, org_admin, aal1 and anon get an
-- empty timeline; keyset paging; and the registry contract (a SECURITY
-- DEFINER or wrongly-shaped source is refused, a new invoker source is picked
-- up with no dispatcher change).
-- Fixtures live in this transaction (UUIDs ...751...) and are rolled back.
begin;
select no_plan();

reset role;
select set_config('request.jwt.claims', '', true);

insert into public.patient_roster_meta (patient_id, org_id, sex, program_started_on)
values ('00000000-0000-0000-0000-0000000a1001', '00000000-0000-0000-0000-00000000000a', 'female', current_date - 200)
on conflict (patient_id) do update set program_started_on = excluded.program_started_on;
insert into public.patient_treatments (org_id, patient_id, name, started_on, status, source) values
  ('00000000-0000-0000-0000-00000000000a', '00000000-0000-0000-0000-0000000a1001', 'Example GLP-1 medication (fictional)', current_date - 150, 'Active', 'Fictional record');
insert into public.lab_reports (id, org_id, patient_id, report_type, data, identity_hold) values
  ('00000000-0000-0000-0000-000000751a01', '00000000-0000-0000-0000-00000000000a', '00000000-0000-0000-0000-0000000a1001', 'metabolic_panel', '{}', false),
  ('00000000-0000-0000-0000-000000751a02', '00000000-0000-0000-0000-00000000000a', '00000000-0000-0000-0000-0000000a1001', 'metabolic_panel', '{}', true),
  ('00000000-0000-0000-0000-000000751b01', '00000000-0000-0000-0000-00000000000b', '00000000-0000-0000-0000-0000000b1001', 'metabolic_panel', '{}', false);
insert into public.lab_results
  (org_id, patient_id, lab_report_id, analyte_key, analyte_label, value, unit, status, range_high, taken_at) values
  ('00000000-0000-0000-0000-00000000000a', '00000000-0000-0000-0000-0000000a1001', '00000000-0000-0000-0000-000000751a01', 'hba1c', 'HbA1c', 6.1, '%', 'outside_range', 5.7, now() - interval '30 days'),
  ('00000000-0000-0000-0000-00000000000a', '00000000-0000-0000-0000-0000000a1001', '00000000-0000-0000-0000-000000751a01', 'glucose_fasting', 'Glucose, fasting', 90, 'mg/dL', 'within_range', 99, now() - interval '30 days'),
  ('00000000-0000-0000-0000-00000000000a', '00000000-0000-0000-0000-0000000a1001', '00000000-0000-0000-0000-000000751a02', 'hba1c', 'HbA1c', 9.9, '%', 'outside_range', 5.7, now() - interval '5 days'),
  ('00000000-0000-0000-0000-00000000000b', '00000000-0000-0000-0000-0000000b1001', '00000000-0000-0000-0000-000000751b01', 'hba1c', 'HbA1c', 7.0, '%', 'outside_range', 5.7, now() - interval '5 days');

create temp table _tl as select * from public.patient_timeline('00000000-0000-0000-0000-0000000a1001') limit 0;
grant all on _tl to authenticated;

-- ---------------------------------------------------------------------------
-- physician_a
-- ---------------------------------------------------------------------------
select tests.authenticate_as('00000000-0000-0000-0000-0000000a0002', 'aal2');
insert into _tl select * from public.patient_timeline('00000000-0000-0000-0000-0000000a1001');

select ok((select count(*) from _tl where source = 'labs') >= 2, 'labs events present (fixture report + this file''s report)');
select is((select count(*)::int from _tl where ref_id = '00000000-0000-0000-0000-000000751a02'), 0,
  'identity-held report is not on the timeline');
select is((select (detail ->> 'result_count')::int from _tl where ref_id = '00000000-0000-0000-0000-000000751a01'), 2,
  'one event per report, carrying its results');
select is((select status from _tl where ref_id = '00000000-0000-0000-0000-000000751a01'), 'outside_range',
  'report status rolls up to outside_range');
select is((select event_type from _tl where ref_id = '00000000-0000-0000-0000-0000000a3001'), 'lab_report_received',
  'a report with no extracted values is a "received" event');
select is((select count(*)::int from _tl where source = 'treatment'), 1, 'treatment start present');
select is((select count(*)::int from _tl where source = 'program'), 1, 'program start present');
select is((select title from _tl where source = 'treatment'), 'Example GLP-1 medication (fictional)', 'treatment title is the name');
select ok(not exists (select 1 from _tl where detail::text ilike '%dose%'), 'no dose anywhere in the timeline');
select ok((select bool_and(a.occurred_at >= b.occurred_at)
             from (select occurred_at, row_number() over () rn from _tl) a
             join (select occurred_at, row_number() over () rn from _tl) b on b.rn = a.rn + 1),
  'events are newest first');
select is((select count(*)::int from public.patient_timeline('00000000-0000-0000-0000-0000000a1001', null, 2)), 2,
  'p_limit caps the page');
select ok(not exists (
    select 1 from public.patient_timeline('00000000-0000-0000-0000-0000000a1001', now() - interval '60 days', 100)
    where occurred_at >= now() - interval '60 days'),
  'p_before pages to strictly older events');

-- read_only and care_coordinator see it too
select tests.authenticate_as('00000000-0000-0000-0000-0000000a0004', 'aal2');
select ok((select count(*) from public.patient_timeline('00000000-0000-0000-0000-0000000a1001')) > 0, 'read_only sees the timeline');
select tests.authenticate_as('00000000-0000-0000-0000-0000000a0003', 'aal2');
select ok((select count(*) from public.patient_timeline('00000000-0000-0000-0000-0000000a1001')) > 0, 'care_coordinator sees the timeline');

-- ---------------------------------------------------------------------------
-- Not visible -> empty (never an error that confirms the patient exists)
-- ---------------------------------------------------------------------------
select tests.authenticate_as('00000000-0000-0000-0000-0000000b0001', 'aal2');
select is((select count(*)::int from public.patient_timeline('00000000-0000-0000-0000-0000000a1001')), 0, 'other clinic: empty');
select tests.authenticate_as('00000000-0000-0000-0000-0000000a0002', 'aal2');
select is((select count(*)::int from public.patient_timeline('00000000-0000-0000-0000-0000009e9e9e')), 0, 'unknown id: empty');
select tests.authenticate_as('00000000-0000-0000-0000-0000000a0001', 'aal2');
select is((select count(*)::int from public.patient_timeline('00000000-0000-0000-0000-0000000a1001')), 0, 'org_admin: empty');
select tests.authenticate_as('00000000-0000-0000-0000-0000000a0002', 'aal1');
select is((select count(*)::int from public.patient_timeline('00000000-0000-0000-0000-0000000a1001')), 0, 'aal1: empty');
select tests.authenticate_as_anon();
select throws_ok($$ select * from public.patient_timeline('00000000-0000-0000-0000-0000000a1001') $$, '42501', null, 'anon cannot call it');
-- A source called directly is still RLS-scoped.
select tests.authenticate_as('00000000-0000-0000-0000-0000000b0001', 'aal2');
select is((select count(*)::int from public.timeline_source_labs('00000000-0000-0000-0000-0000000a1001')), 0,
  'a source called directly by another clinic returns nothing (RLS)');

-- ---------------------------------------------------------------------------
-- Registry contract + extension point
-- ---------------------------------------------------------------------------
reset role;
select set_config('request.jwt.claims', '', true);
create function public.tl751_definer(p uuid) returns setof public.timeline_event
  language sql security definer set search_path = pg_catalog, public as $$ select null::public.timeline_event where false $$;
create function public.tl751_wrong_shape(p uuid) returns setof text
  language sql security invoker set search_path = pg_catalog as $$ select 'x' where false $$;
create function public.tl751_extra(p_patient_id uuid) returns setof public.timeline_event
  language sql stable security invoker set search_path = pg_catalog, public as $$
    select now() - interval '1 day', 'extra', 'extra_event', 'Extra', null::text, p_patient_id, '{}'::jsonb
    from public.patients where id = p_patient_id $$;
grant execute on function public.tl751_extra(uuid) to authenticated;

select throws_ok($$ insert into public.timeline_sources (source_key, fn, label) values ('bad1', 'public.tl751_definer(uuid)', 'Bad') $$,
  '42501', null, 'a SECURITY DEFINER source is refused');
select throws_ok($$ insert into public.timeline_sources (source_key, fn, label) values ('bad2', 'public.tl751_wrong_shape(uuid)', 'Bad') $$,
  '22023', null, 'a source with the wrong return type is refused');
select lives_ok($$ insert into public.timeline_sources (source_key, fn, label) values ('extra', 'public.tl751_extra(uuid)', 'Extra') $$,
  'a correctly-shaped invoker source registers');
select tests.authenticate_as('00000000-0000-0000-0000-0000000a0002', 'aal2');
select is((select count(*)::int from public.patient_timeline('00000000-0000-0000-0000-0000000a1001') where source = 'extra'), 1,
  'the new source appears with no dispatcher change');
select tests.authenticate_as('00000000-0000-0000-0000-0000000a0002', 'aal2');
select throws_ok($$ insert into public.timeline_sources (source_key, fn, label) values ('x', 'public.tl751_extra(uuid)', 'X') $$,
  '42501', null, 'clients cannot register sources');

select * from finish();
rollback;
