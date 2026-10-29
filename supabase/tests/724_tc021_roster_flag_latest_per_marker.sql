-- TC-021 item 5 (Ava #11, Henry's ruling 29 Oct): the roster's "Outside range"
-- flag means "the LATEST result for any marker is outside its range", computed
-- per marker from the same rows the patient-detail badge uses
-- (patient_latest_results: latest per analyte_key, identity-held reports and
-- corrected originals excluded). Before this fix the rollup used
-- bool_or(status = 'outside_range') over EVERY result ever recorded, so a
-- fictional Jordan Rivera with an old outside-range HbA1c and a latest 5.4%
-- "Within default range" showed "Outside range" in the list.
--
-- FAILS on 548d726 (the 'older outside, latest within' patient is flagged).
-- Fixtures live in this file's own transaction under ...724... UUIDs and are
-- rolled back.
begin;
select no_plan();

reset role;
select set_config('request.jwt.claims', '', true);

insert into auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data, created_at, updated_at
)
select
  '00000000-0000-0000-0000-000000000000', u.id,
  'authenticated', 'authenticated', 'tc021-flag-' || u.id || '@example.test',
  extensions.crypt('Testpassw0rd!123', extensions.gen_salt('bf', 4)),
  now(), '{"provider":"email","providers":["email"]}'::jsonb, '{}'::jsonb, now(), now()
from (values
  ('00000000-0000-0000-0000-000000724001'::uuid),
  ('00000000-0000-0000-0000-000000724002'::uuid),
  ('00000000-0000-0000-0000-000000724003'::uuid),
  ('00000000-0000-0000-0000-000000724004'::uuid),
  ('00000000-0000-0000-0000-000000724005'::uuid)
) as u(id);

-- 001 "Jordan" : HbA1c 7.1 outside (older)  -> 5.4 within (latest)   => NOT flagged
-- 002          : HbA1c 5.4 within (older)   -> 6.4 outside (latest)  => flagged
-- 003          : HbA1c latest within, glucose latest outside           => flagged (any marker)
-- 004          : HbA1c latest outside but on an identity-held report,
--                older non-held HbA1c within                            => NOT flagged
-- 005          : HbA1c older outside, newest row is a correction (original_value
--                set); covered by the agreement check below, whatever the detail shows
insert into public.patients (id, org_id, display_name, mrn) values
  ('00000000-0000-0000-0000-000000724001', '00000000-0000-0000-0000-00000000000a', 'Flag Jordan',  'ZP-72401'),
  ('00000000-0000-0000-0000-000000724002', '00000000-0000-0000-0000-00000000000a', 'Flag Kestrel', 'ZP-72402'),
  ('00000000-0000-0000-0000-000000724003', '00000000-0000-0000-0000-00000000000a', 'Flag Linden',  'ZP-72403'),
  ('00000000-0000-0000-0000-000000724004', '00000000-0000-0000-0000-00000000000a', 'Flag Marlow',  'ZP-72404'),
  ('00000000-0000-0000-0000-000000724005', '00000000-0000-0000-0000-00000000000a', 'Flag Nolan',   'ZP-72405');

insert into public.lab_reports (id, org_id, patient_id, report_type, data, identity_hold) values
  ('00000000-0000-0000-0000-0000724a0001', '00000000-0000-0000-0000-00000000000a', '00000000-0000-0000-0000-000000724001', 'metabolic_panel', '{}', false),
  ('00000000-0000-0000-0000-0000724a0002', '00000000-0000-0000-0000-00000000000a', '00000000-0000-0000-0000-000000724002', 'metabolic_panel', '{}', false),
  ('00000000-0000-0000-0000-0000724a0003', '00000000-0000-0000-0000-00000000000a', '00000000-0000-0000-0000-000000724003', 'metabolic_panel', '{}', false),
  ('00000000-0000-0000-0000-0000724a0004', '00000000-0000-0000-0000-00000000000a', '00000000-0000-0000-0000-000000724004', 'metabolic_panel', '{}', false),
  ('00000000-0000-0000-0000-0000724a0044', '00000000-0000-0000-0000-00000000000a', '00000000-0000-0000-0000-000000724004', 'metabolic_panel', '{}', true),
  ('00000000-0000-0000-0000-0000724a0005', '00000000-0000-0000-0000-00000000000a', '00000000-0000-0000-0000-000000724005', 'metabolic_panel', '{}', false);

insert into public.lab_results
  (org_id, patient_id, lab_report_id, analyte_key, analyte_label, value, original_value, unit, status, range_high, taken_at) values
  ('00000000-0000-0000-0000-00000000000a', '00000000-0000-0000-0000-000000724001', '00000000-0000-0000-0000-0000724a0001', 'hba1c', 'HbA1c', 7.1, null, '%', 'outside_range', 5.7, now() - interval '60 days'),
  ('00000000-0000-0000-0000-00000000000a', '00000000-0000-0000-0000-000000724001', '00000000-0000-0000-0000-0000724a0001', 'hba1c', 'HbA1c', 5.4, null, '%', 'within_range',  5.7, now() - interval '5 days'),
  ('00000000-0000-0000-0000-00000000000a', '00000000-0000-0000-0000-000000724002', '00000000-0000-0000-0000-0000724a0002', 'hba1c', 'HbA1c', 5.4, null, '%', 'within_range',  5.7, now() - interval '60 days'),
  ('00000000-0000-0000-0000-00000000000a', '00000000-0000-0000-0000-000000724002', '00000000-0000-0000-0000-0000724a0002', 'hba1c', 'HbA1c', 6.4, null, '%', 'outside_range', 5.7, now() - interval '5 days'),
  ('00000000-0000-0000-0000-00000000000a', '00000000-0000-0000-0000-000000724003', '00000000-0000-0000-0000-0000724a0003', 'hba1c', 'HbA1c', 5.4, null, '%', 'within_range',  5.7, now() - interval '5 days'),
  ('00000000-0000-0000-0000-00000000000a', '00000000-0000-0000-0000-000000724003', '00000000-0000-0000-0000-0000724a0003', 'glucose_fasting', 'Glucose, fasting', 112, null, 'mg/dL', 'outside_range', 99, now() - interval '5 days'),
  ('00000000-0000-0000-0000-00000000000a', '00000000-0000-0000-0000-000000724004', '00000000-0000-0000-0000-0000724a0004', 'hba1c', 'HbA1c', 5.4, null, '%', 'within_range',  5.7, now() - interval '60 days'),
  ('00000000-0000-0000-0000-00000000000a', '00000000-0000-0000-0000-000000724004', '00000000-0000-0000-0000-0000724a0044', 'hba1c', 'HbA1c', 6.9, null, '%', 'outside_range', 5.7, now() - interval '5 days'),
  ('00000000-0000-0000-0000-00000000000a', '00000000-0000-0000-0000-000000724005', '00000000-0000-0000-0000-0000724a0005', 'hba1c', 'HbA1c', 6.3, null, '%', 'outside_range', 5.7, now() - interval '60 days'),
  ('00000000-0000-0000-0000-00000000000a', '00000000-0000-0000-0000-000000724005', '00000000-0000-0000-0000-0000724a0005', 'hba1c', 'HbA1c', 5.5, 6.5,  '%', 'within_range',  5.7, now() - interval '5 days');

create function public._tc724_flagged(p uuid) returns boolean
language sql stable security invoker set search_path = pg_catalog, public as $$
  select 'outside_range' = any(flags) from public.physician_roster_base() where patient_id = p;
$$;
create function public._tc724_detail_outside(p uuid) returns boolean
language sql stable security invoker set search_path = pg_catalog, public as $$
  select coalesce(bool_or(status = 'outside_range'), false) from public.patient_latest_results(p);
$$;
grant execute on function public._tc724_flagged(uuid) to authenticated;
grant execute on function public._tc724_detail_outside(uuid) to authenticated;

-- physician_a (org A, aal2) reads both the roster and the detail.
select tests.authenticate_as('00000000-0000-0000-0000-0000000a0002', 'aal2');

-- The Jordan Rivera case from Ava's #11 review.
select is(
  (select status from public.patient_latest_results('00000000-0000-0000-0000-000000724001') where analyte_key = 'hba1c'),
  'within_range',
  'detail: latest HbA1c 5.4% is within range'
);
select is(public._tc724_flagged('00000000-0000-0000-0000-000000724001'), false,
  'list: an older outside-range HbA1c does NOT flag the patient when the latest is within range');
select is(public._tc724_flagged('00000000-0000-0000-0000-000000724002'), true,
  'list: latest HbA1c outside range flags the patient');
select is(public._tc724_flagged('00000000-0000-0000-0000-000000724003'), true,
  'list: any marker whose latest result is outside range flags the patient');
select is(public._tc724_flagged('00000000-0000-0000-0000-000000724004'), false,
  'list: a latest outside-range value on an identity-held report is ignored (detail ignores it too)');

-- One source: for every patient here, the list flag equals "any detail badge
-- reads Outside range".
select is(
  (select count(*)::int
     from (values
       ('00000000-0000-0000-0000-000000724001'::uuid),
       ('00000000-0000-0000-0000-000000724002'::uuid),
       ('00000000-0000-0000-0000-000000724003'::uuid),
       ('00000000-0000-0000-0000-000000724004'::uuid),
       ('00000000-0000-0000-0000-000000724005'::uuid)) v(p)
    where public._tc724_flagged(v.p) is distinct from public._tc724_detail_outside(v.p)),
  0,
  'list flag and detail badges agree for every fixture patient'
);

-- Drift: the trigger path keeps them in step. A newer within-range result for
-- patient 002 clears the flag; a newer outside one for 001 sets it.
reset role; select set_config('request.jwt.claims', '', true);
insert into public.lab_results
  (org_id, patient_id, lab_report_id, analyte_key, analyte_label, value, unit, status, range_high, taken_at) values
  ('00000000-0000-0000-0000-00000000000a', '00000000-0000-0000-0000-000000724002', '00000000-0000-0000-0000-0000724a0002', 'hba1c', 'HbA1c', 5.5, '%', 'within_range',  5.7, now() - interval '1 day'),
  ('00000000-0000-0000-0000-00000000000a', '00000000-0000-0000-0000-000000724001', '00000000-0000-0000-0000-0000724a0001', 'hba1c', 'HbA1c', 6.0, '%', 'outside_range', 5.7, now() - interval '1 day');
select tests.authenticate_as('00000000-0000-0000-0000-0000000a0002', 'aal2');
select is(public._tc724_flagged('00000000-0000-0000-0000-000000724002'), false,
  'drift: a newer within-range result clears the flag');
select is(public._tc724_flagged('00000000-0000-0000-0000-000000724001'), true,
  'drift: a newer outside-range result sets the flag');

-- The batch builder (backfill / perf seed path) gives the same answer.
reset role; select set_config('request.jwt.claims', '', true);
select public.refresh_roster_summary_all();
select tests.authenticate_as('00000000-0000-0000-0000-0000000a0002', 'aal2');
select is(
  (select count(*)::int
     from (values
       ('00000000-0000-0000-0000-000000724001'::uuid),
       ('00000000-0000-0000-0000-000000724002'::uuid),
       ('00000000-0000-0000-0000-000000724003'::uuid),
       ('00000000-0000-0000-0000-000000724004'::uuid),
       ('00000000-0000-0000-0000-000000724005'::uuid)) v(p)
    where public._tc724_flagged(v.p) is distinct from public._tc724_detail_outside(v.p)),
  0,
  'refresh_roster_summary_all(): list flag and detail badges still agree'
);

select * from finish();
rollback;
