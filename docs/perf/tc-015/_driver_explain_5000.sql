\pset pager off
begin;
set local role authenticated;
select set_config('request.jwt.claims',
  '{"sub":"0000f015-0000-0000-0000-0000000a0002","role":"authenticated","aal":"aal2"}', true);

\echo == row counts (perf org) ==
select
  (select count(*) from public.patients where org_id = public.current_org_id()) as patients,
  (select count(*) from public.patient_roster_summary where org_id = public.current_org_id()) as summary_rows;

\echo == physician_patient_roster(null,'all','recent',8,0) : default first page ==
explain (analyze, buffers) select * from public.physician_patient_roster(null, 'all', 'recent', 8, 0);

\echo == physician_patient_roster(null,'flagged','recent',8,0) ==
explain (analyze, buffers) select * from public.physician_patient_roster(null, 'flagged', 'recent', 8, 0);

\echo == physician_patient_roster(null,'missing_labs','recent',8,0) ==
explain (analyze, buffers) select * from public.physician_patient_roster(null, 'missing_labs', 'recent', 8, 0);

\echo == physician_patient_roster(null,'questions_waiting','recent',8,0) ==
explain (analyze, buffers) select * from public.physician_patient_roster(null, 'questions_waiting', 'recent', 8, 0);

\echo == physician_patient_roster('Patient 123','all','recent',8,0) : name search ==
explain (analyze, buffers) select * from public.physician_patient_roster('Patient 123', 'all', 'recent', 8, 0);

\echo == physician_patient_roster(null,'all','recent',8,8) : page 2 ==
explain (analyze, buffers) select * from public.physician_patient_roster(null, 'all', 'recent', 8, 8);

\echo == physician_roster_chip_counts() ==
explain (analyze, buffers) select * from public.physician_roster_chip_counts();

rollback;
