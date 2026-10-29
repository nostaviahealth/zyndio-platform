-- TC-015 fix round (Leo review of C3): refresh_roster_summary(uuid) and
-- refresh_roster_summary_all() are SECURITY DEFINER maintenance functions for
-- the triggers and service_role only. 20261028160000 revoked them from public
-- and anon, but Supabase default privileges also grant EXECUTE to
-- authenticated. Revoke that too. Triggers run as the function owner, so the
-- maintenance path is unaffected. Covered by 721_tc015_roster_summary_privs.
revoke execute on function public.refresh_roster_summary(uuid) from authenticated;
revoke execute on function public.refresh_roster_summary_all() from authenticated;
