-- TC-005 step 1b policy fix (found by the in-org role matrix): the helper
-- functions behind every staff policy read org_members WITHOUT checking
-- status, so an 'invited' or 'deactivated' member kept full staff access
-- until their token expired. Only ACTIVE members get an org / role.
-- Self-row visibility on org_members uses auth.uid() directly, so a
-- deactivated person can still read their own status (needed for the
-- "ended by admin" screen) but nothing else.

create or replace function public.current_org_id()
returns uuid
language sql
stable
security definer
set search_path = pg_catalog, public
as $$
  select org_id from public.org_members
  where user_id = auth.uid() and status = 'active';
$$;

create or replace function public.current_role()
returns public.app_role
language sql
stable
security definer
set search_path = pg_catalog, public
as $$
  select role from public.org_members
  where user_id = auth.uid() and status = 'active';
$$;
