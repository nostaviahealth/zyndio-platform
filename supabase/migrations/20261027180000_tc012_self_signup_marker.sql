-- TC-012 first matching migration (Clara Approve condition / PSU-TO-16).
-- Self-signup accounts must not receive a clinic patients row via
-- create_patient_record (the org_id grandfather would otherwise treat them
-- as "linked"). Marker is written only by patient-signup (service_role).

create table public.patient_self_signups (
  user_id uuid primary key references auth.users (id) on delete cascade,
  created_at timestamptz not null default now()
);

alter table public.patient_self_signups enable row level security;
alter table public.patient_self_signups force row level security;
revoke all on public.patient_self_signups from anon, authenticated;
-- service_role retains access for Edge Functions; no client policies.

create or replace function public.is_patient_self_signup(p_user_id uuid)
returns boolean
language sql
stable
security definer
set search_path = pg_catalog, public
as $$
  select exists (
    select 1 from public.patient_self_signups s where s.user_id = p_user_id
  );
$$;

revoke all on function public.is_patient_self_signup(uuid) from public;
grant execute on function public.is_patient_self_signup(uuid) to authenticated, service_role;

create or replace function public.create_patient_record(
  p_user_id uuid,
  p_display_name text default null,
  p_mrn text default null
)
returns void
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
declare
  v_org_id uuid;
begin
  if not public.has_aal2() or public.current_role() not in ('physician', 'care_coordinator') then
    raise exception 'not authorized' using errcode = '42501';
  end if;

  v_org_id := public.current_org_id();

  if not exists (select 1 from auth.users where id = p_user_id) then
    raise exception 'account not found' using errcode = 'P0002';
  end if;

  if exists (select 1 from public.org_members where user_id = p_user_id) then
    raise exception 'cannot bind a patient record to a staff account' using errcode = '42501';
  end if;

  if exists (select 1 from public.platform_admins where user_id = p_user_id) then
    raise exception 'cannot bind a patient record to a platform admin account' using errcode = '42501';
  end if;

  -- Clara Approve condition / PSU-TO-16: refuse self-signup accounts.
  if public.is_patient_self_signup(p_user_id) then
    raise exception 'cannot create a clinic patient record for a self-signup account' using errcode = '42501';
  end if;

  if exists (select 1 from public.patients where id = p_user_id) then
    raise exception 'account already has a patient record' using errcode = '42501';
  end if;

  insert into public.patients (id, org_id, display_name, mrn)
    values (p_user_id, v_org_id, p_display_name, p_mrn);

  perform public._audit_log_insert(
    'patient_created', auth.uid(), p_user_id, v_org_id, '{}'::jsonb
  );
end;
$$;

revoke all on function public.create_patient_record(uuid, text, text) from public;
grant execute on function public.create_patient_record(uuid, text, text) to authenticated;

comment on table public.patient_self_signups is
  'Marker set by patient-signup Edge Function. create_patient_record refuses these ids (PSU-TO-16).';
