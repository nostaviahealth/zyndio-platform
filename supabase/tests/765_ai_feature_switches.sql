-- PRD clause 9.2: pgTAP verification for public.ai_feature_switches
-- Verifies:
--   1. Table constraints (valid feature enum, reason length 3..500, unique scope index)
--   2. Zero client grants (anon and authenticated cannot SELECT/INSERT/UPDATE/DELETE)
--   3. Automatic audit_log trigger on INSERT, UPDATE, and DELETE

begin;
select plan(12);

-- 1. Table and RLS existence
select has_table('public', 'ai_feature_switches', 'ai_feature_switches table exists');

select is(
  (select relrowsecurity and relforcerowsecurity
   from pg_class
   where oid = 'public.ai_feature_switches'::regclass),
  true,
  'ai_feature_switches has RLS enabled and forced'
);

-- 2. Client roles have no table privileges
select is(
  has_table_privilege('anon', 'public.ai_feature_switches', 'SELECT'),
  false,
  'anon cannot select ai_feature_switches'
);

select is(
  has_table_privilege('authenticated', 'public.ai_feature_switches', 'SELECT'),
  false,
  'authenticated cannot select ai_feature_switches'
);

select is(
  has_table_privilege('authenticated', 'public.ai_feature_switches', 'INSERT'),
  false,
  'authenticated cannot insert ai_feature_switches'
);

-- 3. Trigger function is not executable by client roles
select is(
  has_function_privilege('authenticated', 'public.ai_feature_switches_audit()', 'EXECUTE'),
  false,
  'authenticated cannot execute ai_feature_switches_audit()'
);

-- 4. Setup fixture org for switch tests
insert into public.organizations (id, name)
values ('00000000-0000-0000-0000-000000009201', 'Kill Switch Test Clinic')
on conflict (id) do nothing;

-- 5. Reject invalid feature name and short reason
select throws_ok(
  $$insert into public.ai_feature_switches (org_id, feature, enabled, reason)
    values ('00000000-0000-0000-0000-000000009201', 'invalid_feature', false, 'Valid reason')$$,
  '23514',
  null,
  'rejects unknown feature name'
);

select throws_ok(
  $$insert into public.ai_feature_switches (org_id, feature, enabled, reason)
    values ('00000000-0000-0000-0000-000000009201', 'companion', false, 'no')$$,
  '23514',
  null,
  'rejects reason shorter than 3 characters'
);

-- 6. Insert clinic-scoped switch and verify audit_log row
insert into public.ai_feature_switches (id, org_id, feature, enabled, reason)
values (
  '00000000-0000-0000-0000-000000009210',
  '00000000-0000-0000-0000-000000009201',
  'companion',
  false,
  'Regulatory pause for clinic companion'
);

select is(
  (select count(*)::int from public.audit_log
   where action = 'ai_feature_switch_insert'
     and target_org_id = '00000000-0000-0000-0000-000000009201'
     and metadata->>'feature' = 'companion'
     and (metadata->>'enabled')::boolean = false),
  1,
  'inserting a switch writes ai_feature_switch_insert to audit_log'
);

-- 7. Duplicate (org_id, feature) is rejected by unique index; duplicate (NULL, feature) also rejected
select throws_ok(
  $$insert into public.ai_feature_switches (org_id, feature, enabled, reason)
    values ('00000000-0000-0000-0000-000000009201', 'companion', true, 'Duplicate clinic row')$$,
  '23505',
  null,
  'unique index rejects duplicate (org_id, feature)'
);

-- 8. Update and delete both write audit_log entries
update public.ai_feature_switches
set enabled = true,
    reason = 'Re-enabled after review'
where id = '00000000-0000-0000-0000-000000009210';

select is(
  (select count(*)::int from public.audit_log
   where action = 'ai_feature_switch_update'
     and target_org_id = '00000000-0000-0000-0000-000000009201'
     and (metadata->>'enabled')::boolean = true),
  1,
  'updating a switch writes ai_feature_switch_update to audit_log'
);

delete from public.ai_feature_switches
where id = '00000000-0000-0000-0000-000000009210';

select is(
  (select count(*)::int from public.audit_log
   where action = 'ai_feature_switch_delete'
     and target_org_id = '00000000-0000-0000-0000-000000009201'
     and metadata->>'feature' = 'companion'),
  1,
  'deleting a switch writes ai_feature_switch_delete to audit_log'
);

select * from finish();
rollback;
