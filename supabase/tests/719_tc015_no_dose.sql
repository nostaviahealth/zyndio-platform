-- TC-015 slice 1, fail-first "no dose anywhere" (Leo rulings 4 and 8).
--
-- Treatment context is stored so it CANNOT carry a dose: patient_treatments
-- has explicit columns (name, started_on, status, source) and no dose column.
-- open_patient_detail builds the treatment JSON from an explicit key whitelist
-- (name/start/status/source) - never by stripping - so no dose key can ever
-- reach the client even if a dose were stored somewhere.
--
-- Expect FAIL until patient_treatments + open_patient_detail land.
begin;
select no_plan();

-- Storage structurally cannot hold a dose.
select hasnt_column(
  'public', 'patient_treatments', 'dose',
  'patient_treatments has no dose column - treatment storage cannot hold a dose'
);

reset role;
select set_config('request.jwt.claims', '', true);

insert into public.lab_reports (id, org_id, patient_id, report_type, data, identity_hold) values
  ('00000000-0000-0000-0000-00000015a301', '00000000-0000-0000-0000-00000000000a', '00000000-0000-0000-0000-0000000a1001', 'metabolic_panel', '{}', false);
insert into public.patient_treatments (org_id, patient_id, name, started_on, status, source) values
  ('00000000-0000-0000-0000-00000000000a', '00000000-0000-0000-0000-0000000a1001', 'Example GLP-1 medication (fictional)', date '2026-04-02', 'Active', 'Zyndio record, Oct 20, 2026');

select tests.authenticate_as('00000000-0000-0000-0000-0000000a0002', 'aal2'); -- physician_a

-- The treatment block carries exactly name/started_on/status/source, no dose.
select is(
  (select (public.open_patient_detail('00000000-0000-0000-0000-0000000a1001') -> 'treatment' ->> 'name')),
  'Example GLP-1 medication (fictional)',
  'open_patient_detail exposes the treatment name'
);
select ok(
  not ((public.open_patient_detail('00000000-0000-0000-0000-0000000a1001') -> 'treatment') ? 'dose'),
  'treatment JSON has no dose key'
);
select is(
  (select count(*)::int from jsonb_object_keys(
     public.open_patient_detail('00000000-0000-0000-0000-0000000a1001') -> 'treatment') k
   where k not in ('name', 'started_on', 'status', 'source')),
  0,
  'treatment JSON keys are exactly the whitelist (name/started_on/status/source)'
);
-- Belt-and-braces: no "dose" key anywhere in the whole detail payload.
select ok(
  not exists (
    select 1 from jsonb_object_keys(public.open_patient_detail('00000000-0000-0000-0000-0000000a1001')) k
    where k = 'dose'
  ),
  'no dose key at the top level of the detail payload'
);

select * from finish();
rollback;
