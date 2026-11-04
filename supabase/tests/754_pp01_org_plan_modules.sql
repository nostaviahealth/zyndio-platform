-- PP-01: clinic tier and module configuration with billing history.
--
-- Proves: catalog has 5 core + standard modules; every clinic starts on Core
-- with an open billing period; only the clinic's org admin at aal2 can change
-- the plan or read its history; Core allows at most two distinct standard
-- modules from the catalog; each change closes the open period and opens a
-- new one (no overlap), writes one audit row, and a no-op change writes
-- nothing; history is append-only even for the service role; clinics are
-- isolated.
-- Fixtures live in this transaction and are rolled back.
begin;
select no_plan();

reset role;
select set_config('request.jwt.claims', '', true);

select is((select count(*)::int from public.plan_modules where kind = 'core'), 5, 'five core modules');
select ok((select count(*) from public.plan_modules where kind = 'standard') >= 2, 'at least two standard modules to choose from');
select is((select kind from public.plan_modules where module_key = 're_test_recall'), 'standard', 'Re-Test Recall (named in the PRD) is a standard module');
select ok(not (select is_placeholder from public.plan_modules where module_key = 're_test_recall'), 'Re-Test Recall is not a placeholder');
select ok((select bool_and(is_placeholder) from public.plan_modules where module_key <> 're_test_recall'),
  'every other module is marked placeholder until Schedule B is confirmed');
select is((select tier from public.org_plans where org_id = '00000000-0000-0000-0000-00000000000a'), 'core', 'clinic A starts on Core');
select is((select count(*)::int from public.org_plan_history where org_id = '00000000-0000-0000-0000-00000000000a' and effective_to is null), 1,
  'clinic A has one open billing period');
insert into public.organizations (id, name) values ('00000000-0000-0000-0000-000000754c00', 'Fictional Clinic 754');
select is((select tier from public.org_plans where org_id = '00000000-0000-0000-0000-000000754c00'), 'core', 'a new clinic gets a Core plan');
select is((select count(*)::int from public.org_plan_history where org_id = '00000000-0000-0000-0000-000000754c00'), 1,
  'a new clinic gets its first billing period');
select ok(not has_table_privilege('authenticated', 'public.org_plans', 'UPDATE'), 'authenticated has no UPDATE on org_plans');
select ok(not has_table_privilege('authenticated', 'public.org_plan_history', 'INSERT'), 'authenticated has no INSERT on org_plan_history');

-- ---------------------------------------------------------------------------
-- Who may change it
-- ---------------------------------------------------------------------------
select tests.authenticate_as('00000000-0000-0000-0000-0000000a0002', 'aal2'); -- physician_a
select throws_ok($$ select public.set_org_plan('core', array['wearables'], null) $$, '42501', null, 'physician cannot change the plan');
select throws_ok($$ select * from public.list_org_plan_history() $$, '42501', null, 'physician cannot read billing history');
select is((public.get_org_plan() ->> 'tier'), 'core', 'physician can read the current plan');
select is(jsonb_array_length(public.get_org_plan() -> 'catalog'), (select count(*)::int from public.plan_modules), 'plan carries the catalog');
select is((select count(*)::int from public.org_plan_history), 0, 'physician: RLS hides billing history');
select tests.authenticate_as('00000000-0000-0000-0000-0000000a0004', 'aal2'); -- read_only_a
select throws_ok($$ select public.set_org_plan('core', array['wearables'], null) $$, '42501', null, 'read_only cannot change the plan');
select tests.authenticate_as('00000000-0000-0000-0000-0000000a0001', 'aal1'); -- org_admin_a at aal1
select throws_ok($$ select public.set_org_plan('core', array['wearables'], null) $$, '42501', null, 'org admin at aal1 cannot change the plan');
select tests.authenticate_as_anon();
select throws_ok($$ select public.set_org_plan('core', array['wearables'], null) $$, '42501', null, 'anon cannot call set_org_plan');

-- ---------------------------------------------------------------------------
-- Shape rules
-- ---------------------------------------------------------------------------
select tests.authenticate_as('00000000-0000-0000-0000-0000000a0001', 'aal2'); -- org_admin_a
select throws_ok($$ select public.set_org_plan('core', array['wearables', 'ai_companion', 'gamification'], null) $$, '22023', null,
  'Core: three standard modules refused');
select throws_ok($$ select public.set_org_plan('core', array['patient_app'], null) $$, '22023', null,
  'a core module is not a standard choice');
select throws_ok($$ select public.set_org_plan('core', array['not_a_module'], null) $$, '22023', null, 'unknown module refused');
select throws_ok($$ select public.set_org_plan('core', array['wearables', 'wearables'], null) $$, '22023', null, 'duplicates refused');
select throws_ok($$ select public.set_org_plan('enterprise', array['wearables'], null) $$, '22023', null, 'unknown tier refused');

-- ---------------------------------------------------------------------------
-- Changes and history
-- ---------------------------------------------------------------------------
select lives_ok($$ select public.set_org_plan('core', array['wearables', 'ai_companion'], 'Signed order form') $$,
  'org admin picks two standard modules');
select is((select standard_modules from public.org_plans where org_id = '00000000-0000-0000-0000-00000000000a'),
  array['ai_companion', 'wearables'], 'plan stores the chosen modules (sorted)');
select lives_ok($$ select public.set_org_plan('core', array['ai_companion', 'wearables'], null) $$, 'same modules again is a no-op');
select is((select count(*)::int from public.list_org_plan_history()), 2, 'history: initial period + one change (no-op wrote nothing)');
select is((select count(*)::int from public.list_org_plan_history() where effective_to is null), 1, 'exactly one open period');
select is((select reason from public.list_org_plan_history() where effective_to is null), 'Signed order form', 'reason kept');

reset role;
select set_config('request.jwt.claims', '', true);
-- Periods tile: each closed period ends exactly where the next begins.
select ok(not exists (
    select 1 from (
      select effective_to, lead(effective_from) over (order by effective_from, id) as next_from
      from public.org_plan_history where org_id = '00000000-0000-0000-0000-00000000000a') p
    where p.next_from is not null and p.effective_to is distinct from p.next_from),
  'billing periods do not overlap or leave gaps');
select is((select count(*)::int from public.audit_log where event_type = 'org_plan_changed'
            and org_id = '00000000-0000-0000-0000-00000000000a'), 1, 'one audit row for the one real change');
select is((select metadata #>> '{to,standard_modules,0}' from public.audit_log where event_type = 'org_plan_changed'
            and org_id = '00000000-0000-0000-0000-00000000000a'), 'ai_companion', 'audit row records the new modules');

select tests.authenticate_as_service_role();
select throws_ok($$ update public.org_plan_history set tier = 'core', reason = 'rewritten' where org_id = '00000000-0000-0000-0000-00000000000a' $$,
  '42501', null, 'history rows cannot be rewritten, even by the service role');
select throws_ok($$ delete from public.org_plan_history where org_id = '00000000-0000-0000-0000-00000000000a' $$,
  '42501', null, 'history rows cannot be deleted');
reset role;

-- Clinic isolation: clinic B's admin view does not see A (B has no admin
-- fixture; physician_b reads only its own plan).
select tests.authenticate_as('00000000-0000-0000-0000-0000000b0001', 'aal2');
select is((public.get_org_plan() -> 'standard_modules'), '[]'::jsonb, 'clinic B''s plan is untouched by clinic A''s change');
select is((select count(*)::int from public.org_plans), 1, 'clinic B sees only its own plan row');

select * from finish();
rollback;
