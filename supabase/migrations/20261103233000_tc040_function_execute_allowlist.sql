-- TC-040 (Clara #34 M1): functions in public are no longer executable by
-- anon/authenticated by default; only an explicit allowlist is.
--
-- Why: PostgreSQL gives every new function EXECUTE to PUBLIC, and Supabase's
-- default privileges in schema public also grant it to anon and authenticated.
-- So any new SECURITY DEFINER helper is callable over /rest/v1/rpc the moment
-- it ships unless its migration remembers to revoke (the TC-040 High). This
-- migration flips the default to closed and re-grants only what clients call.
--
-- 1. Default privileges, for every role that runs our migrations / owns our
--    functions. Our migrations run as postgres (all 80+ functions in public
--    are owned by postgres; locally and in CI postgres is not a superuser and
--    is not a member of supabase_admin). supabase_admin also has Supabase's
--    grant-to-anon/authenticated default in public; it is covered here when
--    the migrating role is allowed to change it (a superuser run), otherwise
--    a NOTICE says so and test 747 still fails on any supabase_admin-owned
--    function that anon/authenticated could execute.
--    Note: the PUBLIC revoke is global (all schemas) for that role, so any
--    future function another role must call (auth hooks, test helpers) needs
--    an explicit GRANT, as the auth hooks already have.
-- 2. Existing functions: revoke EXECUTE from PUBLIC, anon and authenticated on
--    every function in public, then grant authenticated back only the
--    allowlist below (anon gets nothing). service_role grants are untouched.
-- 3. test 747 pins the allowlist and the default privileges.

-- 1a. The role running this migration (postgres in CI, local and hosted).
alter default privileges revoke execute on functions from public;
alter default privileges in schema public revoke execute on functions from anon, authenticated;

-- 1b. Every known migration / function-owning role, by name.
do $$
declare
  r text;
begin
  foreach r in array array['postgres', 'supabase_admin'] loop
    if not exists (select 1 from pg_roles where rolname = r) then
      raise notice 'TC-040: role % does not exist here; nothing to change', r;
    elsif pg_has_role(current_user, r, 'MEMBER') then
      execute format('alter default privileges for role %I revoke execute on functions from public', r);
      execute format('alter default privileges for role %I in schema public revoke execute on functions from anon, authenticated', r);
    else
      raise notice 'TC-040: % may not change default privileges of %; it owns no function in public (test 747 guards this)', current_user, r;
    end if;
  end loop;
end
$$;

-- 2. Existing functions: closed by default ...
revoke execute on all functions in schema public from public, anon, authenticated;

-- ... and the allowlist (authenticated only; see the PR body inventory).
-- RLS helpers called by policies that apply to authenticated (tables and
-- storage.objects); a policy's function needs EXECUTE for the caller's role.
grant execute on function public.current_org_id() to authenticated;
grant execute on function public."current_role"() to authenticated;
grant execute on function public.has_aal2() to authenticated;
grant execute on function public.is_org_admin() to authenticated;
grant execute on function public.current_email_confirmed() to authenticated;
grant execute on function public.current_patient_linked() to authenticated;
-- Web admin/physician app (supabase.rpc with the signed-in session).
grant execute on function public.change_member_role(uuid, public.app_role) to authenticated;
grant execute on function public.consume_recovery_code(text) to authenticated;
grant execute on function public.generate_recovery_codes() to authenticated;
grant execute on function public.flag_lab_report_needs_review(uuid) to authenticated;
grant execute on function public.is_zyndio_admin() to authenticated;
grant execute on function public.list_org_members() to authenticated;
grant execute on function public.request_mfa_reset(uuid, text) to authenticated;
grant execute on function public.physician_patient_roster(text, text, text, integer, integer) to authenticated;
grant execute on function public.physician_roster_chip_counts() to authenticated;
grant execute on function public.open_patient_detail(uuid) to authenticated;
grant execute on function public.patient_trend(uuid, text, text) to authenticated;
grant execute on function public.patient_latest_results(uuid) to authenticated;
-- Flutter patient app (client.rpc with the signed-in session).
grant execute on function public.redeem_telehealth_link_code(text) to authenticated;
grant execute on function public.redeem_clinic_link_code(text) to authenticated;
grant execute on function public.unlink_patient_record() to authenticated;
grant execute on function public.patient_leaderboard_top10() to authenticated;
-- Edge function create-patient calls this with the caller's JWT (not service role).
grant execute on function public.create_patient_record(uuid, text, text) to authenticated;
-- Called from inside allowlisted SECURITY INVOKER functions, so the caller needs it:
-- physician_patient_roster / physician_roster_chip_counts -> physician_roster_base,
-- patient_trend / patient_latest_results -> lab_report_held,
-- open_patient_detail -> write_audit_log.
grant execute on function public.physician_roster_base() to authenticated;
grant execute on function public.lab_report_held(uuid) to authenticated;
grant execute on function public.write_audit_log(text, uuid, uuid, uuid, jsonb) to authenticated;
