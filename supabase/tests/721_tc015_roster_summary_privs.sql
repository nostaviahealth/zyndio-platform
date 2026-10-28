-- TC-015 fix round (Leo review of C3, 28 Oct): the roster-summary maintenance
-- functions are SECURITY DEFINER and meant for triggers / service_role only.
-- Supabase's default privileges grant EXECUTE on new public functions to
-- authenticated, so "revoke from public, anon" alone left any signed-in user
-- (patients included) able to call refresh_roster_summary_all() - a full
-- cross-org recompute - or refresh_roster_summary() on any patient uuid.
-- Neither leaks data (both return void) but they are not a client surface.
begin;
select plan(6);

select ok(not has_function_privilege('anon', 'public.refresh_roster_summary(uuid)', 'execute'),
  'anon cannot execute refresh_roster_summary(uuid)');
select ok(not has_function_privilege('authenticated', 'public.refresh_roster_summary(uuid)', 'execute'),
  'authenticated cannot execute refresh_roster_summary(uuid)');
select ok(not has_function_privilege('anon', 'public.refresh_roster_summary_all()', 'execute'),
  'anon cannot execute refresh_roster_summary_all()');
select ok(not has_function_privilege('authenticated', 'public.refresh_roster_summary_all()', 'execute'),
  'authenticated cannot execute refresh_roster_summary_all()');
select ok(has_function_privilege('service_role', 'public.refresh_roster_summary(uuid)', 'execute'),
  'service_role can execute refresh_roster_summary(uuid)');
select ok(has_function_privilege('service_role', 'public.refresh_roster_summary_all()', 'execute'),
  'service_role can execute refresh_roster_summary_all()');

select * from finish();
rollback;
