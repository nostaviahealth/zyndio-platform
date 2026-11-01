-- TC-018 item 5 (L37): fill in the Two-factor and Last sign-in columns on
-- the admin users screen. list_org_members() gains two columns, still
-- guarded by is_org_admin()+has_aal2() and scoped to the caller's own org:
--   mfa_enrolled    - true iff the member has a verified auth.mfa_factors
--                     row (never exposes factor type/id/friendly_name).
--   last_sign_in_at - from auth.users, null if they have never signed in.

drop function if exists public.list_org_members();
create function public.list_org_members()
returns table (
  user_id uuid,
  email text,
  full_name text,
  role public.app_role,
  status text,
  created_at timestamptz,
  updated_at timestamptz,
  mfa_enrolled boolean,
  last_sign_in_at timestamptz
)
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
begin
  if not public.is_org_admin() or not public.has_aal2() then
    raise exception 'not authorized' using errcode = '42501';
  end if;

  return query
    select
      m.user_id,
      u.email::text,
      nullif(btrim(coalesce(m.full_name, '')), '')::text as full_name,
      m.role,
      m.status,
      m.created_at,
      m.updated_at,
      exists (
        select 1 from auth.mfa_factors f
        where f.user_id = m.user_id and f.status = 'verified'
      ) as mfa_enrolled,
      u.last_sign_in_at
    from public.org_members m
    join auth.users u on u.id = m.user_id
    where m.org_id = public.current_org_id()
    order by m.created_at asc;
end;
$$;

revoke all on function public.list_org_members() from public;
grant execute on function public.list_org_members() to authenticated;
