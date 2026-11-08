-- Held reports: the patient cannot read the row, its results, or the file
-- (and therefore cannot mint a signed URL; storage-api signs after SELECT).
-- The same patient still reads a non-held report and an unfiled object.
-- Another patient, another clinic's physician, read-only, and anon cannot.
-- Own-clinic physician at aal2 still can, for review.
-- Fictional ids only. Rolled back with the transaction.
begin;
select no_plan();

reset role;
select set_config('request.jwt.claims', '', true);
select set_config('storage.allow_delete_query', 'true', true);

insert into storage.objects (bucket_id, name) values
  ('lab-reports', '00000000-0000-0000-0000-0000000a1001/778a0000-0000-4000-8000-000000000001.pdf'),
  ('lab-reports', '00000000-0000-0000-0000-0000000a1001/778a0000-0000-4000-8000-000000000002.pdf'),
  ('lab-reports', '00000000-0000-0000-0000-0000000a1001/778a0000-0000-4000-8000-000000000003.pdf');

insert into public.lab_reports (id, org_id, patient_id, report_type, data, identity_hold, pdf_path) values
  ('00000000-0000-0000-0000-0000000778a1', '00000000-0000-0000-0000-00000000000a',
   '00000000-0000-0000-0000-0000000a1001', 'patient_upload', '{}', false,
   '00000000-0000-0000-0000-0000000a1001/778a0000-0000-4000-8000-000000000001.pdf'),
  ('00000000-0000-0000-0000-0000000778a2', '00000000-0000-0000-0000-00000000000a',
   '00000000-0000-0000-0000-0000000a1001', 'patient_upload', '{}', true,
   '00000000-0000-0000-0000-0000000a1001/778a0000-0000-4000-8000-000000000002.pdf');

insert into public.lab_results
  (org_id, patient_id, lab_report_id, analyte_key, analyte_label, value, unit, status, taken_at)
values
  ('00000000-0000-0000-0000-00000000000a', '00000000-0000-0000-0000-0000000a1001',
   '00000000-0000-0000-0000-0000000778a1', 'hba1c', 'HbA1c', 5.4, '%', 'within_range', now()),
  ('00000000-0000-0000-0000-00000000000a', '00000000-0000-0000-0000-0000000a1001',
   '00000000-0000-0000-0000-0000000778a2', 'ldl', 'LDL', 96, 'mg/dL', 'within_range', now());

-- SYNTHETIC FIXTURE so the held-versus-released check is not vacuous.
insert into public.consent_documents (consent_type, version, document, title, summary, body, required, is_placeholder, published_at)
values ('health_data', 'synthetic-fixture', 'synthetic_health_data_fixture', 'Synthetic fixture',
        'SYNTHETIC FIXTURE - not a legally approved document',
        'SYNTHETIC FIXTURE - not a legally approved document. Not for patient use.',
        false, false, now());
insert into public.consents (org_id, patient_id, consent_type, document, version, granted)
values ('00000000-0000-0000-0000-00000000000a', '00000000-0000-0000-0000-0000000a1001',
        'health_data', 'synthetic_health_data_fixture', 'synthetic-fixture', true);

-- Patient A1: released row and file, not the held ones. Unfiled object stays.
select tests.authenticate_as('00000000-0000-0000-0000-0000000a1001', 'aal1');
select is(
  (select count(*) from public.lab_reports where id = '00000000-0000-0000-0000-0000000778a1')::int,
  1, 'patient A1 reads their released lab report');
select is(
  (select count(*) from public.lab_reports where id = '00000000-0000-0000-0000-0000000778a2')::int,
  0, 'patient A1 cannot read their identity-held lab report');
select is(
  (select count(*) from public.lab_results where lab_report_id = '00000000-0000-0000-0000-0000000778a1')::int,
  1, 'patient A1 reads results of the released report');
select is(
  (select count(*) from public.lab_results where lab_report_id = '00000000-0000-0000-0000-0000000778a2')::int,
  0, 'patient A1 cannot read results of the held report');
select is(
  (select array_agg(name order by name) from storage.objects
    where bucket_id = 'lab-reports' and name like '00000000-0000-0000-0000-0000000a1001/778%'),
  array[
    '00000000-0000-0000-0000-0000000a1001/778a0000-0000-4000-8000-000000000001.pdf',
    '00000000-0000-0000-0000-0000000a1001/778a0000-0000-4000-8000-000000000003.pdf'
  ],
  'patient A1 can select the released file and an unfiled object, not the held file');
select is(
  (select public.own_lab_report_released('00000000-0000-0000-0000-0000000778a2')),
  false, 'own_lab_report_released is false for the held report');
select is(
  (select public.own_lab_file_released('00000000-0000-0000-0000-0000000a1001/778a0000-0000-4000-8000-000000000002.pdf')),
  false, 'own_lab_file_released is false for the held file');

-- Other patient, wrong-clinic physician, read-only, anon: no file.
select tests.authenticate_as('00000000-0000-0000-0000-0000000b1001', 'aal1');
select is(
  (select count(*) from storage.objects where name like '%/778%')::int,
  0, 'patient B1 cannot select clinic A files');
select is(
  (select public.own_lab_report_released('00000000-0000-0000-0000-0000000778a1')),
  false, 'own_lab_report_released is false for another patient''s report');

select tests.authenticate_as('00000000-0000-0000-0000-0000000b0001', 'aal2');
select is(
  (select count(*) from storage.objects where name like '%/778%')::int,
  0, 'physician B cannot select clinic A files, held or not');

select tests.authenticate_as('00000000-0000-0000-0000-0000000a0004', 'aal2');
select is(
  (select count(*) from storage.objects where name like '%/778%')::int,
  0, 'read-only staff cannot select lab files');

select tests.authenticate_as_anon();
select is(
  (select count(*) from storage.objects where bucket_id = 'lab-reports' and name like '%/778%')::int,
  0, 'anon cannot select the files');
select throws_ok(
  $$ select public.own_lab_report_released('00000000-0000-0000-0000-0000000778a1') $$,
  '42501', null, 'anon cannot execute own_lab_report_released');

-- Own-clinic physician still reviews the held row and file.
select tests.authenticate_as('00000000-0000-0000-0000-0000000a0002', 'aal2');
select is(
  (select count(*) from public.lab_reports where id = '00000000-0000-0000-0000-0000000778a2')::int,
  1, 'physician A reads the held report');
select is(
  (select count(*) from storage.objects
    where name = '00000000-0000-0000-0000-0000000a1001/778a0000-0000-4000-8000-000000000002.pdf')::int,
  1, 'physician A can select the held file');

select * from finish();
rollback;
