-- TC-005 step 3: resolving "this email already has an auth.users row" back
-- to a user id needs a lookup that doesn't go through GoTrue's Admin API
-- listUsers/list-by-filter endpoints - observed live, those 500 ("Database
-- error finding users" / NULL confirmation_token scan error) the moment any
-- account in the instance was created via admin.createUser(), which is
-- exactly the invite-user/admin-bootstrap code path. A plain SQL lookup
-- against auth.users sidesteps that Go-side bug entirely. service_role only
-- (Edge Functions and the admin bootstrap script), never exposed to a
-- client role.
create or replace function public.find_user_id_by_email(p_email text)
returns uuid
language sql
stable
security definer
set search_path = pg_catalog, public, auth
as $$
  select id from auth.users where lower(email) = lower(p_email) limit 1;
$$;

revoke all on function public.find_user_id_by_email(text) from public, anon, authenticated;
grant execute on function public.find_user_id_by_email(text) to service_role;
