-- TC-005 step 3: deactivate-user and reset-mfa must sign the target out
-- globally. supabase-js's admin.signOut(jwt, scope) only accepts a live
-- session's own JWT (it POSTs /logout with that JWT as the bearer), which a
-- service-role-only Edge Function calling on someone else's behalf never
-- has. Deleting the target's own auth.sessions rows (and their dependent
-- refresh tokens) is the server-side equivalent: the next refresh attempt
-- from an already-open tab fails and it is redirected to
-- 05-session/ended-by-admin, same as the plan's intent.
create function public.force_sign_out(p_user_id uuid)
returns void
language plpgsql
security definer
set search_path = pg_catalog, public, auth
as $$
begin
  delete from auth.refresh_tokens
    where session_id in (select id from auth.sessions where user_id = p_user_id);
  delete from auth.sessions where user_id = p_user_id;
end;
$$;

revoke all on function public.force_sign_out(uuid) from public, anon, authenticated;
grant execute on function public.force_sign_out(uuid) to service_role;
