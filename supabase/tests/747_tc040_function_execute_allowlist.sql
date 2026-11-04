-- TC-040 (#34 review M1 + L3): EXECUTE on functions is an explicit allowlist.
--
-- PostgreSQL grants EXECUTE to PUBLIC on every new function, and Supabase's
-- default ACLs add anon/authenticated in schema public. Migration
-- 20261103233000 revokes both defaults for the migration role and revokes
-- anon/authenticated EXECUTE on every existing public function, granting
-- back only what clients call (inventory in the migration header and #34).
--
-- This file fails on:
--   * any function in an exposed schema (public, graphql_public - see
--     supabase/config.toml [api] schemas) that anon or authenticated can
--     execute and that is not in the allowlist below - definer, invoker and
--     trigger functions alike (L3: no prosecdef filter);
--   * any allowlisted grant that has gone missing (clients would break);
--   * a default ACL of any role owning functions in public that would hand a
--     future function to PUBLIC, anon or authenticated;
--   * a function created after the migrations (clara_future_internal & co,
--     created right here as the migration role) being executable by anon or
--     authenticated, checked by has_function_privilege AND a real call.
begin;
set local search_path = public, extensions, pg_catalog;
select no_plan();

create temp table tc040_allow (fn text, grantee text, why text) on commit drop;
insert into tc040_allow values
  -- Supabase-managed pg_graphql entry point (owner supabase_admin, not ours).
  ('graphql_public.graphql(text, text, jsonb, jsonb)', 'anon',          'supabase-managed pg_graphql'),
  ('graphql_public.graphql(text, text, jsonb, jsonb)', 'authenticated', 'supabase-managed pg_graphql'),
  -- Used by RLS policies (all policies are TO authenticated).
  ('public."current_role"()',                    'authenticated', 'RLS policies; open_patient_detail'),
  ('public.current_org_id()',                    'authenticated', 'RLS policies; open_patient_detail'),
  ('public.has_aal2()',                          'authenticated', 'RLS policies; open_patient_detail'),
  ('public.is_org_admin()',                      'authenticated', 'RLS policies'),
  ('public.current_email_confirmed()',           'authenticated', 'RLS policies'),
  ('public.current_patient_linked()',            'authenticated', 'RLS policies'),
  -- Web (apps/web) .rpc( call sites.
  ('public.change_member_role(uuid, app_role)',  'authenticated', 'web rpc'),
  ('public.consume_recovery_code(text)',         'authenticated', 'web rpc'),
  ('public.generate_recovery_codes()',           'authenticated', 'web rpc'),
  ('public.flag_lab_report_needs_review(uuid)',  'authenticated', 'web rpc'),
  ('public.is_zyndio_admin()',                   'authenticated', 'web rpc'),
  ('public.list_org_members()',                  'authenticated', 'web rpc'),
  ('public.request_mfa_reset(uuid, text)',       'authenticated', 'web rpc'),
  ('public.physician_patient_roster(text, text, text, integer, integer)', 'authenticated', 'web rpc'),
  ('public.physician_roster_chip_counts()',      'authenticated', 'web rpc'),
  ('public.open_patient_detail(uuid)',           'authenticated', 'web rpc'),
  ('public.patient_trend(uuid, text, text)',     'authenticated', 'web rpc'),
  ('public.patient_latest_results(uuid)',        'authenticated', 'web rpc'),
  -- Flutter (apps/mobile) .rpc( call sites.
  ('public.redeem_telehealth_link_code(text)',   'authenticated', 'flutter rpc'),
  ('public.redeem_clinic_link_code(text)',       'authenticated', 'flutter rpc'),
  ('public.unlink_patient_record()',             'authenticated', 'flutter rpc'),
  ('public.patient_leaderboard_top10()',         'authenticated', 'flutter rpc'),
  -- APP-02 / APP-04 onboarding gate, consents and profile (flutter rpc).
  ('public.patient_onboarding_status()',         'authenticated', 'flutter rpc'),
  ('public.grant_patient_consents(jsonb)',       'authenticated', 'flutter rpc'),
  ('public.revoke_patient_consent(text)',        'authenticated', 'flutter rpc'),
  ('public.my_patient_profile()',                'authenticated', 'flutter rpc'),
  ('public.update_patient_profile(text, date, text, numeric, text)', 'authenticated', 'flutter rpc'),
  -- create-patient edge function calls it with the CALLER's JWT client.
  ('public.create_patient_record(uuid, text, text)', 'authenticated', 'create-patient edge fn (caller JWT)'),
  -- Called inside SECURITY INVOKER rpcs above, so the caller needs EXECUTE.
  ('public.physician_roster_base()',             'authenticated', 'callee of physician_patient_roster / chip_counts (invoker)'),
  ('public.lab_report_held(uuid)',               'authenticated', 'callee of patient_trend / patient_latest_results (invoker)'),
  ('public.write_audit_log(text, uuid, uuid, uuid, jsonb)', 'authenticated', 'callee of open_patient_detail (invoker)');

create temp view tc040_exec as
select format('%I.%I(%s)', n.nspname, p.proname, oidvectortypes(p.proargtypes)) as fn, r.grantee
  from pg_proc p
  join pg_namespace n on n.oid = p.pronamespace
 cross join (values ('anon'), ('authenticated')) r(grantee)
 where n.nspname in ('public', 'graphql_public')
   and has_function_privilege(r.grantee, p.oid, 'EXECUTE');
grant select on tc040_exec, tc040_allow to anon, authenticated;

-- ---------------------------------------------------------------------------
-- 1. Allowlist: exact, in both directions.
-- ---------------------------------------------------------------------------
select is_empty(
  $$ select fn || ' -> ' || grantee from tc040_exec except select fn || ' -> ' || grantee from tc040_allow $$,
  'no function in an exposed schema is executable by anon/authenticated unless allowlisted (definer, invoker and trigger functions alike)');
select is_empty(
  $$ select fn || ' -> ' || grantee from tc040_allow except select fn || ' -> ' || grantee from tc040_exec $$,
  'every allowlisted client function is still executable by its role');
select is((select count(*)::int from tc040_exec where grantee = 'anon' and fn like 'public.%'), 0,
  'anon can execute no function in public at all');

-- spot checks for internal helpers that used to be reachable
select ok(not has_function_privilege('authenticated', 'public.normalise_link_code(text)', 'EXECUTE'),
  'authenticated cannot execute internal normalise_link_code()');
select ok(not has_function_privilege('authenticated', 'public.can_grant_role(public.app_role, public.app_role)', 'EXECUTE'),
  'authenticated cannot execute internal can_grant_role()');
select ok(not has_function_privilege('authenticated', 'public.award_patient_points(uuid, integer, integer, integer, text, jsonb)', 'EXECUTE'),
  'authenticated cannot execute award_patient_points() (service_role only, TC-030)');
select ok(not has_function_privilege('authenticated', 'public.enforce_last_admin()', 'EXECUTE'),
  'authenticated cannot execute trigger function enforce_last_admin() directly');
select ok(has_function_privilege('service_role', 'public.password_is_blocked(text)', 'EXECUTE'),
  'service_role (edge functions) keeps password_is_blocked()');

-- ---------------------------------------------------------------------------
-- 2. Default ACLs: no role that owns functions in public (and not postgres,
--    the migration role, in any case) hands future functions to PUBLIC, anon
--    or authenticated - globally or in schema public.
-- ---------------------------------------------------------------------------
create temp view tc040_default_leaks as
with owners as (
  select distinct proowner as o from pg_proc where pronamespace = (select oid from pg_namespace where nspname = 'public')
  union select (select oid from pg_roles where rolname = 'postgres')
), acls as (
  select o, 'global' as scope,
         coalesce((select defaclacl from pg_default_acl
                    where defaclrole = o and defaclnamespace = 0 and defaclobjtype = 'f'),
                  acldefault('f', o)) as acl
    from owners
  union all
  select o, 'schema public',
         (select defaclacl from pg_default_acl
           where defaclrole = o and defaclnamespace = (select oid from pg_namespace where nspname = 'public') and defaclobjtype = 'f')
    from owners
)
select pg_get_userbyid(a.o) || ' ' || a.scope || ' -> '
       || case e.grantee when 0 then 'PUBLIC' else pg_get_userbyid(e.grantee) end as leak
  from acls a, aclexplode(coalesce(a.acl, '{}'::aclitem[])) e
 where e.privilege_type = 'EXECUTE'
   and (e.grantee = 0 or e.grantee in (select oid from pg_roles where rolname in ('anon', 'authenticated')));
select is_empty($$ select leak from tc040_default_leaks $$,
  'no function owner in public has a default ACL granting EXECUTE to PUBLIC, anon or authenticated');

-- ---------------------------------------------------------------------------
-- 3. Fail-first probe (Clara): functions created after the migrations, by
--    the migration role, are not executable by anon/authenticated.
-- ---------------------------------------------------------------------------
set local role postgres;
create function public.clara_future_internal(p uuid) returns uuid
  language sql security definer set search_path = pg_catalog as $$ select p $$;
create function public.clara_future_invoker(p uuid) returns uuid
  language sql security invoker set search_path = pg_catalog as $$ select p $$;
create function public.clara_future_trigger() returns trigger
  language plpgsql security definer set search_path = pg_catalog as $$ begin return new; end $$;
reset role;

select ok(not has_function_privilege(r, f::regprocedure, 'EXECUTE'),
          format('%s cannot execute %s (has_function_privilege)', r, f))
  from unnest(array['public.clara_future_internal(uuid)', 'public.clara_future_invoker(uuid)',
                    'public.clara_future_trigger()']) f,
       unnest(array['anon', 'authenticated']) r;
select is_empty(
  $$ select p.proname || ' ' || case e.grantee when 0 then 'PUBLIC' else pg_get_userbyid(e.grantee) end
       from pg_proc p, aclexplode(coalesce(p.proacl, acldefault('f', p.proowner))) e
      where p.proname like 'clara\_future\_%' and p.pronamespace = (select oid from pg_namespace where nspname = 'public')
        and (e.grantee = 0 or e.grantee in (select oid from pg_roles where rolname in ('anon', 'authenticated'))) $$,
  'new functions carry no PUBLIC/anon/authenticated EXECUTE in their ACL');
select is_empty(
  $$ select fn || ' -> ' || grantee from tc040_exec except select fn || ' -> ' || grantee from tc040_allow $$,
  'the allowlist still holds with the new functions present (an unlisted new function would fail it)');

select tests.authenticate_as_anon();
select throws_ok($$ select public.clara_future_internal('00000000-0000-0000-0000-0000000a1001') $$,
  '42501', null, 'anon: real call of new SECURITY DEFINER clara_future_internal() is refused');
select throws_ok($$ select public.clara_future_invoker('00000000-0000-0000-0000-0000000a1001') $$,
  '42501', null, 'anon: real call of new invoker function is refused');
select throws_ok($$ select public.normalise_link_code('abcd-efgh') $$,
  '42501', null, 'anon: real call of an existing internal helper is refused');
reset role;
select tests.authenticate_as('00000000-0000-0000-0000-0000000a0002', 'aal2'); -- physician A
select throws_ok($$ select public.clara_future_internal('00000000-0000-0000-0000-0000000a1001') $$,
  '42501', null, 'authenticated: real call of new SECURITY DEFINER clara_future_internal() is refused');
select throws_ok($$ select public.clara_future_invoker('00000000-0000-0000-0000-0000000a1001') $$,
  '42501', null, 'authenticated: real call of new invoker function is refused');
select throws_ok($$ select public.normalise_link_code('abcd-efgh') $$,
  '42501', null, 'authenticated: real call of an existing internal helper is refused');
select lives_ok($$ select public.current_org_id() $$,
  'authenticated: an allowlisted RLS helper still runs');
reset role;
select tests.authenticate_as_service_role();
select is(public.clara_future_internal('00000000-0000-0000-0000-0000000a1001'),
  '00000000-0000-0000-0000-0000000a1001'::uuid,
  'service_role can still call the new function (probe is not vacuous)');
reset role;

select * from finish();
rollback;
