-- Clara M16: full_name lives on org_members (server-written only). Users can
-- edit auth.users.raw_user_meta_data themselves, so list_org_members must not
-- read the display name from there.
--
-- 1. org_members.full_name column
-- 2. Backfill from existing user_metadata / invites where present
-- 3. list_org_members reads m.full_name
alter table public.org_members
  add column if not exists full_name text;

-- Prefer the name captured on the live (or most recent) invite; fall back to
-- whatever was stored in user_metadata at invite time.
update public.org_members m
set full_name = src.name
from (
  select distinct on (m2.user_id)
    m2.user_id,
    nullif(btrim(coalesce(
      i.full_name,
      u.raw_user_meta_data->>'full_name',
      ''
    )), '') as name
  from public.org_members m2
  join auth.users u on u.id = m2.user_id
  left join public.invites i
    on i.user_id = m2.user_id
   and i.org_id = m2.org_id
  order by m2.user_id, i.created_at desc nulls last
) src
where m.user_id = src.user_id
  and m.full_name is null
  and src.name is not null;

drop function if exists public.list_org_members();
create function public.list_org_members()
returns table (
  user_id uuid,
  email text,
  full_name text,
  role public.app_role,
  status text,
  created_at timestamptz,
  updated_at timestamptz
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
      m.updated_at
    from public.org_members m
    join auth.users u on u.id = m.user_id
    where m.org_id = public.current_org_id()
    order by m.created_at asc;
end;
$$;

revoke all on function public.list_org_members() from public;
grant execute on function public.list_org_members() to authenticated;
