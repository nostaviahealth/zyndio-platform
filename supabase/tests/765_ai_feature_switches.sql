-- Clause 9.2. Audit columns are event_type and org_id.
begin;
select no_plan();

select has_table('public', 'ai_feature_switches', 'ai_feature_switches table exists');
select is(
  (select relrowsecurity and relforcerowsecurity from pg_class where oid = 'public.ai_feature_switches'::regclass),
  true,
  'ai_feature_switches has RLS enabled and forced'
);

select ok(
  not has_table_privilege('anon', 'public.ai_feature_switches', 'SELECT')
  and not has_table_privilege('anon', 'public.ai_feature_switches', 'INSERT')
  and not has_table_privilege('anon', 'public.ai_feature_switches', 'UPDATE')
  and not has_table_privilege('anon', 'public.ai_feature_switches', 'DELETE')
  and not has_table_privilege('authenticated', 'public.ai_feature_switches', 'SELECT')
  and not has_table_privilege('authenticated', 'public.ai_feature_switches', 'INSERT')
  and not has_table_privilege('authenticated', 'public.ai_feature_switches', 'UPDATE')
  and not has_table_privilege('authenticated', 'public.ai_feature_switches', 'DELETE'),
  'anon and authenticated cannot read or write ai_feature_switches'
);
select ok(
  not has_function_privilege('anon', 'public.ai_feature_switches_audit()', 'EXECUTE')
  and not has_function_privilege('authenticated', 'public.ai_feature_switches_audit()', 'EXECUTE'),
  'anon and authenticated cannot execute the audit trigger function'
);

select throws_ok(
  $$insert into public.ai_feature_switches (org_id, feature, enabled, reason)
    values ('00000000-0000-0000-0000-00000000000a', 'invalid_feature', false, 'Valid reason')$$,
  '23514', null, 'rejects an unknown feature name'
);
select throws_ok(
  $$insert into public.ai_feature_switches (org_id, feature, enabled, reason)
    values ('00000000-0000-0000-0000-00000000000a', 'companion', false, 'no')$$,
  '23514', null, 'rejects a reason shorter than 3 characters'
);

insert into public.ai_feature_switches (id, org_id, feature, enabled, reason)
values (
  '00000000-0000-0000-0000-000000009210',
  '00000000-0000-0000-0000-00000000000a',
  'companion',
  false,
  'Regulatory pause for clinic companion'
);
select is(
  (select count(*)::int from public.audit_log
    where event_type = 'ai_feature_switch_insert'
      and org_id = '00000000-0000-0000-0000-00000000000a'
      and metadata->>'feature' = 'companion'
      and (metadata->>'enabled')::boolean = false),
  1,
  'insert writes ai_feature_switch_insert with event_type and org_id'
);

select throws_ok(
  $$insert into public.ai_feature_switches (org_id, feature, enabled, reason)
    values ('00000000-0000-0000-0000-00000000000a', 'companion', true, 'Duplicate clinic row')$$,
  '23505', null, 'unique index rejects a duplicate clinic feature'
);

update public.ai_feature_switches
set enabled = true, reason = 'Re-enabled after review', changed_at = '2000-01-01T00:00:00Z'
where id = '00000000-0000-0000-0000-000000009210';
select ok(
  (select changed_at > '2020-01-01T00:00:00Z'::timestamptz
     from public.ai_feature_switches where id = '00000000-0000-0000-0000-000000009210'),
  'the trigger replaces a caller-supplied changed_at'
);
select is(
  (select count(*)::int from public.audit_log
    where event_type = 'ai_feature_switch_update'
      and org_id = '00000000-0000-0000-0000-00000000000a'
      and (metadata->>'enabled')::boolean = true),
  1,
  'update writes ai_feature_switch_update'
);

delete from public.ai_feature_switches where id = '00000000-0000-0000-0000-000000009210';
select is(
  (select count(*)::int from public.audit_log
    where event_type = 'ai_feature_switch_delete'
      and org_id = '00000000-0000-0000-0000-00000000000a'
      and metadata->>'feature' = 'companion'),
  1,
  'delete writes ai_feature_switch_delete'
);

select * from finish();
rollback;
