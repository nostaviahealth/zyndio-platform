-- APP-09 / POR-02: companion escalations. A patient files clinical questions
-- and emergencies; the roster's open-question count follows them; an
-- emergency queues alerts (ids only) to the clinic's escalation contacts or,
-- when none is set, its active physicians; own-clinic physicians and
-- coordinators (aal2) read and resolve them; nobody else sees them.
-- Fictional data only.
begin;
select no_plan();

-- Row counts of DML run under RLS (a data-modifying WITH must be top level).
create temp table app09_counts (k text primary key, n int);
grant all on app09_counts to anon, authenticated;

reset role;
select set_config('request.jwt.claims', '', true);

-- Actors (global fixtures): patient A1 a1001 (clinic A), patient B1 b1001
-- (clinic B), physician A a0002, coordinator A a0003, read_only A a0004,
-- physician B b0001.

select has_table('public', 'companion_escalations', 'companion_escalations exists');
select is((select relforcerowsecurity from pg_class where oid = 'public.companion_escalations'::regclass), true,
          'companion_escalations forces RLS');
select ok(not has_function_privilege('authenticated', 'public.companion_escalations_sync_roster()', 'EXECUTE'),
          'roster sync trigger is not callable by clients');
select ok(not has_function_privilege('authenticated', 'public.companion_escalations_alert_emergency()', 'EXECUTE'),
          'emergency alert trigger is not callable by clients');

create temp table app09_outbox_before as
  select count(*)::int as n from public.notification_outbox where type = 'companion_emergency';

-- ---------------------------------------------------------------------------
-- Patient A1 files a question and an emergency
-- ---------------------------------------------------------------------------
select tests.authenticate_as('00000000-0000-0000-0000-0000000a1001', 'aal1');

select lives_ok($$
  insert into public.companion_escalations (id, patient_id, kind, question, status, org_id)
  values ('00000000-0000-0000-0000-0000000e9a01', '00000000-0000-0000-0000-0000000a1001',
          'clinical_question', 'Should my dose change if I feel nauseous?', 'closed',
          '00000000-0000-0000-0000-00000000000b')
$$, 'patient files a clinical question');
select lives_ok($$
  insert into public.companion_escalations (id, patient_id, kind, question)
  values ('00000000-0000-0000-0000-0000000e9a02', '00000000-0000-0000-0000-0000000a1001',
          'emergency', 'I have chest pain')
$$, 'patient files an emergency');

select results_eq(
  $$ select status, org_id from public.companion_escalations where id = '00000000-0000-0000-0000-0000000e9a01' $$,
  $$ values ('open'::text, '00000000-0000-0000-0000-00000000000a'::uuid) $$,
  'a new escalation is always open and filed under the patient''s own clinic');

select throws_ok($$
  insert into public.companion_escalations (patient_id, kind, question)
  values ('00000000-0000-0000-0000-0000000b1001', 'clinical_question', 'x')
$$, '42501', null, 'patient cannot file for another patient');
with u as (update public.companion_escalations set status = 'closed' where id = '00000000-0000-0000-0000-0000000e9a01' returning 1)
  insert into app09_counts select 'q1', count(*)::int from u;
select is((select n from app09_counts where k = 'q1'), 0, 'patient cannot close their own escalation');
select is((select count(*)::int from public.companion_escalations), 2, 'patient sees their own escalations');

reset role;
select set_config('request.jwt.claims', '', true);
select is((select open_questions from public.patient_roster_meta where patient_id = '00000000-0000-0000-0000-0000000a1001'),
          2, 'roster open-question count follows open escalations');
select is((select count(*)::int from public.notification_outbox where type = 'companion_emergency')
            - (select n from app09_outbox_before), 1,
          'the emergency alerts clinic A''s active physician (no escalation contact set)');
select tests.authenticate_as('00000000-0000-0000-0000-0000000a1001', 'aal1');
select lives_ok($$
  insert into public.companion_escalations (patient_id, kind, question)
  values ('00000000-0000-0000-0000-0000000a1001', 'clinical_question', 'chest pain, cannot breathe')
$$, 'a mislabelled emergency is still filed');
reset role;
select set_config('request.jwt.claims', '', true);
select is((select kind from public.companion_escalations where question = 'chest pain, cannot breathe'),
          'emergency', 'the server upgrades emergency language the client marked clinical');
select is((select count(*)::int from public.notification_outbox
            where type = 'companion_emergency'
              and payload ->> 'escalation_id' = (select id::text from public.companion_escalations
                                                  where question = 'chest pain, cannot breathe')),
          1, 'the upgraded row alerts; the payload stays id-only');
select tests.authenticate_as('00000000-0000-0000-0000-0000000a1001', 'aal1');
select lives_ok($$
  insert into public.companion_escalations (patient_id, kind, question)
  values ('00000000-0000-0000-0000-0000000a1001', 'emergency', 'What should I eat for breakfast?')
$$, 'an ordinary message labelled emergency is still filed');
reset role;
select set_config('request.jwt.claims', '', true);
select is((select kind from public.companion_escalations where question = 'What should I eat for breakfast?'),
          'clinical_question', 'the server does not alert on a client emergency label alone');
select is((select count(*)::int from public.notification_outbox
            where type = 'companion_emergency'
              and payload ? 'escalation_id' and (select count(*) from jsonb_object_keys(payload)) = 1),
          (select count(*)::int from public.notification_outbox where type = 'companion_emergency'),
          'alert payload carries only the escalation id (no message text)');

-- With an escalation contact set, only the contact is alerted.
update public.org_members set is_escalation_contact = true
 where user_id = '00000000-0000-0000-0000-0000000a0003';
select tests.authenticate_as('00000000-0000-0000-0000-0000000a1001', 'aal1');
insert into public.companion_escalations (patient_id, kind, question)
values ('00000000-0000-0000-0000-0000000a1001', 'emergency', 'I can''t breathe');
reset role;
select set_config('request.jwt.claims', '', true);
select is((select array_agg(user_id) from public.notification_outbox
            where type = 'companion_emergency'
              and payload ->> 'escalation_id' = (select id::text from public.companion_escalations
                                                  where question = 'I can''t breathe')),
          array['00000000-0000-0000-0000-0000000a0003'::uuid],
          'with an escalation contact set, only that contact is alerted');

-- ---------------------------------------------------------------------------
-- Staff
-- ---------------------------------------------------------------------------
select tests.authenticate_as('00000000-0000-0000-0000-0000000a0002', 'aal2');
select is((select count(*)::int from public.companion_escalations), 5, 'own-clinic physician reads escalations');
select lives_ok($$
  update public.companion_escalations set status = 'answered' where id = '00000000-0000-0000-0000-0000000e9a01'
$$, 'physician marks a question answered');
select throws_ok($$
  update public.companion_escalations set question = 'edited' where id = '00000000-0000-0000-0000-0000000e9a01'
$$, '42501', null, 'nobody can rewrite the question');

reset role;
select set_config('request.jwt.claims', '', true);
select results_eq(
  $$ select resolved_by, resolved_at is not null from public.companion_escalations
      where id = '00000000-0000-0000-0000-0000000e9a01' $$,
  $$ values ('00000000-0000-0000-0000-0000000a0002'::uuid, true) $$,
  'resolution is stamped with who and when');
select is((select open_questions from public.patient_roster_meta where patient_id = '00000000-0000-0000-0000-0000000a1001'),
          4, 'answering one lowers the open count');
select ok(exists (select 1 from public.audit_log where event_type = 'companion_escalation_status_changed'),
          'status change is audited');

select tests.authenticate_as('00000000-0000-0000-0000-0000000a0002', 'aal1');
select is((select count(*)::int from public.companion_escalations), 0, 'physician without aal2 reads nothing');

select tests.authenticate_as('00000000-0000-0000-0000-0000000a0004', 'aal2');
select is((select count(*)::int from public.companion_escalations), 0, 'read_only reads no escalation text');

select tests.authenticate_as('00000000-0000-0000-0000-0000000b0001', 'aal2');
select is((select count(*)::int from public.companion_escalations), 0, 'other-clinic physician reads nothing');

select tests.authenticate_as('00000000-0000-0000-0000-0000000b1001', 'aal1');
select is((select count(*)::int from public.companion_escalations), 0, 'other patient reads nothing');

select tests.authenticate_as_anon();
select throws_ok($$ select count(*) from public.companion_escalations $$, '42501', null,
  'anon has no access to escalations');

select * from finish();
rollback;
