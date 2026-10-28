-- Clara review of ecff0d3:
-- M10: never leave an unmarked self-signup account (trigger + ensure helper)
-- M11: idempotent backfill of markers
-- L17: revoke is_patient_self_signup from authenticated

-- ---------------------------------------------------------------------------
-- L17
-- ---------------------------------------------------------------------------
revoke all on function public.is_patient_self_signup(uuid) from public, anon, authenticated;
grant execute on function public.is_patient_self_signup(uuid) to service_role;

-- ---------------------------------------------------------------------------
-- M10 trigger: same DB step as auth.users insert
-- ---------------------------------------------------------------------------
create or replace function public.trg_auth_users_mark_patient_self_signup()
returns trigger
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
begin
  if coalesce(NEW.raw_user_meta_data->>'role', '') = 'patient'
     and not exists (select 1 from public.org_members om where om.user_id = NEW.id)
     and not exists (select 1 from public.platform_admins pa where pa.user_id = NEW.id)
     and not exists (select 1 from public.patients p where p.id = NEW.id)
  then
    insert into public.patient_self_signups (user_id)
    values (NEW.id)
    on conflict (user_id) do nothing;
  end if;
  return NEW;
end;
$$;

drop trigger if exists auth_users_mark_patient_self_signup on auth.users;
create trigger auth_users_mark_patient_self_signup
  after insert on auth.users
  for each row
  execute function public.trg_auth_users_mark_patient_self_signup();

revoke all on function public.trg_auth_users_mark_patient_self_signup() from public, anon, authenticated;

-- L18: test-only fail trigger lives in supabase/tests/660_clara_m10_m11_l17.sql
-- (created inside the pgTAP transaction). Production must not ship test hooks.
drop trigger if exists patient_self_signups_test_fail on public.patient_self_signups;
drop function if exists public.trg_patient_self_signups_test_fail();

-- Edge helper: marker or delete account (never fail-open).
-- Returns 'ok' | 'removed'. Must NOT re-raise after delete — a re-raise
-- rolls back the delete in the same transaction (Clara M10).
create or replace function public.ensure_patient_self_signup_marker(p_user_id uuid)
returns text
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
declare
  v_still boolean;
begin
  if auth.role() is distinct from 'service_role' then
    raise exception 'not authorized' using errcode = '42501';
  end if;

  begin
    insert into public.patient_self_signups (user_id)
    values (p_user_id)
    on conflict (user_id) do nothing;
  exception
    when others then
      delete from auth.users where id = p_user_id;
      select exists(select 1 from auth.users where id = p_user_id) into v_still;
      if v_still then
        raise exception 'marker insert failed and user delete failed' using errcode = 'P0001';
      end if;
      return 'removed';
  end;

  if exists (select 1 from public.patient_self_signups where user_id = p_user_id) then
    return 'ok';
  end if;

  delete from auth.users where id = p_user_id;
  select exists(select 1 from auth.users where id = p_user_id) into v_still;
  if v_still then
    raise exception 'marker missing and user delete failed' using errcode = 'P0001';
  end if;
  return 'removed';
end;
$$;

revoke all on function public.ensure_patient_self_signup_marker(uuid) from public, anon, authenticated;
grant execute on function public.ensure_patient_self_signup_marker(uuid) to service_role;

-- ---------------------------------------------------------------------------
-- M11 backfill (idempotent function + one call)
-- ---------------------------------------------------------------------------
create or replace function public.backfill_patient_self_signups()
returns int
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
declare
  v_count int;
begin
  insert into public.patient_self_signups (user_id)
  select u.id
  from auth.users u
  where coalesce(u.raw_user_meta_data->>'role', '') = 'patient'
    and not exists (select 1 from public.org_members om where om.user_id = u.id)
    and not exists (select 1 from public.platform_admins pa where pa.user_id = u.id)
    and not exists (select 1 from public.patients p where p.id = u.id)
  on conflict (user_id) do nothing;
  get diagnostics v_count = row_count;
  return v_count;
end;
$$;

revoke all on function public.backfill_patient_self_signups() from public, anon, authenticated;
grant execute on function public.backfill_patient_self_signups() to service_role;

select public.backfill_patient_self_signups();
