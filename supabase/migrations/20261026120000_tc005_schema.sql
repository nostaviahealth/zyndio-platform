-- TC-005: organizations/roles/clinical-stub schema + audit/invite/mfa support tables.
-- This is a clean baseline. It does not build on, reference, or migrate data from
-- supabase/_legacy/ (see supabase/_legacy/README.md).

create extension if not exists pgcrypto with schema extensions;

-- ---------------------------------------------------------------------------
-- organizations + roles
-- ---------------------------------------------------------------------------

create table public.organizations (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  created_at timestamptz not null default now()
);

create type public.app_role as enum ('org_admin', 'physician', 'care_coordinator', 'read_only');

-- One row per person: user_id is the primary key, so a person has exactly one
-- org and one role (Henry: one role per person).
create table public.org_members (
  user_id uuid primary key references auth.users (id) on delete cascade,
  org_id uuid not null references public.organizations (id) on delete cascade,
  role public.app_role not null,
  status text not null default 'invited' check (status in ('invited', 'active', 'deactivated')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index org_members_org_id_idx on public.org_members (org_id);

-- ---------------------------------------------------------------------------
-- minimal clinical stubs (each carries org_id directly to avoid join-time
-- derivation recursion - see supabase/_legacy/README.md for the bug class
-- this avoids)
-- ---------------------------------------------------------------------------

create table public.patients (
  id uuid primary key references auth.users (id) on delete cascade,
  org_id uuid not null references public.organizations (id) on delete cascade,
  display_name text,
  mrn text,
  created_at timestamptz not null default now()
);

create index patients_org_id_idx on public.patients (org_id);

create table public.patient_profiles (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null references public.organizations (id) on delete cascade,
  patient_id uuid not null references public.patients (id) on delete cascade,
  data jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index patient_profiles_org_id_idx on public.patient_profiles (org_id);
create index patient_profiles_patient_id_idx on public.patient_profiles (patient_id);

create table public.lab_reports (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null references public.organizations (id) on delete cascade,
  patient_id uuid not null references public.patients (id) on delete cascade,
  report_type text not null,
  data jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create index lab_reports_org_id_idx on public.lab_reports (org_id);
create index lab_reports_patient_id_idx on public.lab_reports (patient_id);

create table public.consents (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null references public.organizations (id) on delete cascade,
  patient_id uuid not null references public.patients (id) on delete cascade,
  consent_type text not null,
  granted boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index consents_org_id_idx on public.consents (org_id);
create index consents_patient_id_idx on public.consents (patient_id);

-- ---------------------------------------------------------------------------
-- MFA / lockout / audit / invite support
-- ---------------------------------------------------------------------------

-- factor_id is a plain uuid (not a FK into auth.mfa_factors): a cross-schema
-- FK into GoTrue's own tables isn't safe to depend on.
create table public.mfa_recovery_codes (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  factor_id uuid not null,
  code_hash text not null,
  used_at timestamptz,
  created_at timestamptz not null default now()
);

create index mfa_recovery_codes_user_id_idx on public.mfa_recovery_codes (user_id);

-- Shared wrong-count + lockout + password-verified window, keyed by user.
-- Touched only by SECURITY DEFINER functions and auth hooks (TC-005 step 2).
create table public.auth_attempt_state (
  user_id uuid primary key references auth.users (id) on delete cascade,
  wrong_count int not null default 0,
  locked_until timestamptz,
  password_verified_at timestamptz,
  updated_at timestamptz not null default now()
);

-- Append-only. No UPDATE/DELETE grants to any role, ever. Inserts only via
-- write_audit_log().
create table public.audit_log (
  id bigint generated always as identity primary key,
  actor_user_id uuid,
  target_user_id uuid,
  org_id uuid,
  event_type text not null,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create index audit_log_org_id_idx on public.audit_log (org_id);
create index audit_log_target_user_id_idx on public.audit_log (target_user_id);

create table public.notification_outbox (
  id uuid primary key default gen_random_uuid(),
  user_id uuid,
  org_id uuid,
  type text not null,
  status text not null default 'pending' check (status in ('pending', 'sent', 'failed')),
  payload jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create table public.invites (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null references public.organizations (id) on delete cascade,
  email text not null,
  role public.app_role not null,
  token_hash text not null,
  invited_by uuid references auth.users (id),
  created_at timestamptz not null default now(),
  expires_at timestamptz not null default (now() + interval '7 days'),
  accepted_at timestamptz,
  revoked_at timestamptz
);

-- Allows re-inviting the same email after a prior invite expired or was
-- revoked, while forbidding two simultaneously-live invites for one email.
create unique index invites_org_email_pending_idx
  on public.invites (org_id, lower(email))
  where accepted_at is null and revoked_at is null;

-- ---------------------------------------------------------------------------
-- Helper functions (STABLE, SECURITY DEFINER, pinned search_path to close off
-- the search_path-hijack / recursive-policy bug class documented in
-- supabase/_legacy/README.md).
-- ---------------------------------------------------------------------------

create function public.current_org_id()
returns uuid
language sql
stable
security definer
set search_path = pg_catalog, public
as $$
  select org_id from public.org_members where user_id = auth.uid();
$$;

create function public.current_role()
returns public.app_role
language sql
stable
security definer
set search_path = pg_catalog, public
as $$
  select role from public.org_members where user_id = auth.uid();
$$;

create function public.is_org_admin()
returns boolean
language sql
stable
security definer
set search_path = pg_catalog, public
as $$
  select coalesce(public.current_role() = 'org_admin', false);
$$;

-- Reads the GoTrue AAL claim at its documented top-level `aal` path. A live
-- probe against local GoTrue (sign in, decode the access token) was blocked
-- by this environment's sandboxed network policy during this step - see
-- step1-summary.md for the open item. Fails safe either way: a wrong claim
-- path reads as null, so has_aal2() returns false and every staff policy
-- stays closed rather than silently open.
create function public.has_aal2()
returns boolean
language sql
stable
security definer
set search_path = pg_catalog, public
as $$
  select coalesce((auth.jwt() ->> 'aal') = 'aal2', false);
$$;

create function public.write_audit_log(
  p_event_type text,
  p_actor_user_id uuid,
  p_target_user_id uuid,
  p_org_id uuid,
  p_metadata jsonb default '{}'::jsonb
)
returns void
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
begin
  insert into public.audit_log (actor_user_id, target_user_id, org_id, event_type, metadata)
  values (p_actor_user_id, p_target_user_id, p_org_id, p_event_type, p_metadata);
end;
$$;

-- "Last admin can't be demoted/deactivated" needs visibility across rows, so
-- it's a trigger invariant rather than a row-level RLS policy.
create function public.enforce_last_admin()
returns trigger
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
declare
  remaining_admins int;
begin
  if TG_OP = 'DELETE' then
    if OLD.role = 'org_admin' and OLD.status = 'active' then
      select count(*) into remaining_admins
        from public.org_members
        where org_id = OLD.org_id and role = 'org_admin' and status = 'active' and user_id <> OLD.user_id;
      if remaining_admins = 0 then
        raise exception 'cannot remove the last active org admin' using errcode = 'P0001';
      end if;
    end if;
    return OLD;
  elsif TG_OP = 'UPDATE' then
    if OLD.role = 'org_admin' and OLD.status = 'active'
       and (NEW.role <> 'org_admin' or NEW.status <> 'active') then
      select count(*) into remaining_admins
        from public.org_members
        where org_id = OLD.org_id and role = 'org_admin' and status = 'active' and user_id <> OLD.user_id;
      if remaining_admins = 0 then
        raise exception 'cannot demote or deactivate the last active org admin' using errcode = 'P0001';
      end if;
    end if;
    return NEW;
  end if;
  return null;
end;
$$;

create trigger trg_enforce_last_admin
  before update or delete on public.org_members
  for each row execute function public.enforce_last_admin();

-- org_members has no direct UPDATE grant for role changes via the client;
-- this RPC is the only sanctioned path, so every role change is audited and
-- re-checks aal2 + org_admin server-side (never trusts a client-asserted role).
create function public.change_member_role(p_target_user_id uuid, p_new_role public.app_role)
returns void
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
declare
  v_org_id uuid;
  v_old_role public.app_role;
begin
  if not public.is_org_admin() or not public.has_aal2() then
    raise exception 'not authorized' using errcode = '42501';
  end if;

  select org_id into v_org_id from public.org_members where user_id = auth.uid();

  select role into v_old_role
    from public.org_members
    where user_id = p_target_user_id and org_id = v_org_id;

  if v_old_role is null then
    raise exception 'member not found in your organization' using errcode = 'P0002';
  end if;

  update public.org_members
    set role = p_new_role, updated_at = now()
    where user_id = p_target_user_id and org_id = v_org_id;

  perform public.write_audit_log(
    'role_changed', auth.uid(), p_target_user_id, v_org_id,
    jsonb_build_object('from', v_old_role, 'to', p_new_role)
  );
end;
$$;

revoke all on function public.change_member_role(uuid, public.app_role) from public;
grant execute on function public.change_member_role(uuid, public.app_role) to authenticated;
