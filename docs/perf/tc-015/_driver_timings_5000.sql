\pset pager off
begin;
set local role authenticated;
select set_config('request.jwt.claims',
  '{"sub":"0000f015-0000-0000-0000-0000000a0002","role":"authenticated","aal":"aal2"}', true);
\timing on

\echo == all / recent / first page (limit 8) x5 ==
select count(*) from public.physician_patient_roster(null, 'all', 'recent', 8, 0);
select count(*) from public.physician_patient_roster(null, 'all', 'recent', 8, 0);
select count(*) from public.physician_patient_roster(null, 'all', 'recent', 8, 0);
select count(*) from public.physician_patient_roster(null, 'all', 'recent', 8, 0);
select count(*) from public.physician_patient_roster(null, 'all', 'recent', 8, 0);

\echo == flagged x5 ==
select count(*) from public.physician_patient_roster(null, 'flagged', 'recent', 8, 0);
select count(*) from public.physician_patient_roster(null, 'flagged', 'recent', 8, 0);
select count(*) from public.physician_patient_roster(null, 'flagged', 'recent', 8, 0);
select count(*) from public.physician_patient_roster(null, 'flagged', 'recent', 8, 0);
select count(*) from public.physician_patient_roster(null, 'flagged', 'recent', 8, 0);

\echo == missing_labs x5 ==
select count(*) from public.physician_patient_roster(null, 'missing_labs', 'recent', 8, 0);
select count(*) from public.physician_patient_roster(null, 'missing_labs', 'recent', 8, 0);
select count(*) from public.physician_patient_roster(null, 'missing_labs', 'recent', 8, 0);
select count(*) from public.physician_patient_roster(null, 'missing_labs', 'recent', 8, 0);
select count(*) from public.physician_patient_roster(null, 'missing_labs', 'recent', 8, 0);

\echo == questions_waiting x5 ==
select count(*) from public.physician_patient_roster(null, 'questions_waiting', 'recent', 8, 0);
select count(*) from public.physician_patient_roster(null, 'questions_waiting', 'recent', 8, 0);
select count(*) from public.physician_patient_roster(null, 'questions_waiting', 'recent', 8, 0);
select count(*) from public.physician_patient_roster(null, 'questions_waiting', 'recent', 8, 0);
select count(*) from public.physician_patient_roster(null, 'questions_waiting', 'recent', 8, 0);

\echo == name search ('Patient 123') x5 ==
select count(*) from public.physician_patient_roster('Patient 123', 'all', 'recent', 8, 0);
select count(*) from public.physician_patient_roster('Patient 123', 'all', 'recent', 8, 0);
select count(*) from public.physician_patient_roster('Patient 123', 'all', 'recent', 8, 0);
select count(*) from public.physician_patient_roster('Patient 123', 'all', 'recent', 8, 0);
select count(*) from public.physician_patient_roster('Patient 123', 'all', 'recent', 8, 0);

\echo == all / page 2 (offset 8) x5 ==
select count(*) from public.physician_patient_roster(null, 'all', 'recent', 8, 8);
select count(*) from public.physician_patient_roster(null, 'all', 'recent', 8, 8);
select count(*) from public.physician_patient_roster(null, 'all', 'recent', 8, 8);
select count(*) from public.physician_patient_roster(null, 'all', 'recent', 8, 8);
select count(*) from public.physician_patient_roster(null, 'all', 'recent', 8, 8);

\echo == chip counts x5 ==
select * from public.physician_roster_chip_counts();
select * from public.physician_roster_chip_counts();
select * from public.physician_roster_chip_counts();
select * from public.physician_roster_chip_counts();
select * from public.physician_roster_chip_counts();

\timing off
rollback;
