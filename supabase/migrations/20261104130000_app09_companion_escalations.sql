-- APP-09 / POR-02: the AI companion hands clinical questions to the care team
-- and raises an alert on emergency language, instead of only answering in the
-- chat. Until now the roster's "question waiting" flag read
-- patient_roster_meta.open_questions, which nothing ever wrote.
--
--   * public.companion_escalations: one row per handed-off message, kind
--     'clinical_question' or 'emergency', status open -> answered / closed.
--     The patient files and reads their own; own-clinic physicians and care
--     coordinators (aal2) read them and may change only the status.
--   * patient_roster_meta.open_questions is kept equal to the patient's open
--     escalations by trigger, so the existing roster flag lights up.
--   * an emergency queues a notification_outbox row for each of the clinic's
--     escalation contacts (org_members.is_escalation_contact), or for every
--     active physician when none is set, so an emergency is never silent.
--     The payload carries only the escalation id: no message text, no health
--     information (same rule as push text, APP-10).
--
-- Trigger functions are not callable by clients (TC-040 allowlist unchanged).

-- ---------------------------------------------------------------------------
-- 1. Escalation contacts
-- ---------------------------------------------------------------------------
alter table public.org_members
  add column if not exists is_escalation_contact boolean not null default false;

comment on column public.org_members.is_escalation_contact is
  'APP-09: receives companion emergency alerts. When no active member of the clinic has it, every active physician is alerted.';

-- ---------------------------------------------------------------------------
-- 2. Table
-- ---------------------------------------------------------------------------
create table if not exists public.companion_escalations (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null references public.organizations (id) on delete cascade,
  patient_id uuid not null references public.patients (id) on delete cascade,
  kind text not null check (kind in ('clinical_question', 'emergency')),
  question text not null check (char_length(question) between 1 and 4000),
  status text not null default 'open' check (status in ('open', 'answered', 'closed')),
  created_at timestamptz not null default now(),
  resolved_at timestamptz,
  resolved_by uuid references auth.users (id) on delete set null
);

create index if not exists companion_escalations_patient_open_idx
  on public.companion_escalations (patient_id) where status = 'open';
create index if not exists companion_escalations_org_created_idx
  on public.companion_escalations (org_id, created_at desc);

-- org_id from the patient (security invoker: the patient can read their own
-- patients row); a new escalation always starts open and unresolved.
create or replace function public.companion_escalations_before_insert()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.org_id := (select p.org_id from public.patients p where p.id = new.patient_id);
  if new.org_id is null then
    raise exception 'companion_escalations: unknown patient' using errcode = '23503';
  end if;
  new.status := 'open';
  new.resolved_at := null;
  new.resolved_by := null;
  new.created_at := now();
  return new;
end;
$$;

drop trigger if exists companion_escalations_before_insert on public.companion_escalations;
create trigger companion_escalations_before_insert
  before insert on public.companion_escalations
  for each row execute function public.companion_escalations_before_insert();

-- Staff close the loop: stamp who and when, and audit it.
create or replace function public.companion_escalations_before_update()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if new.status is distinct from old.status then
    if new.status = 'open' then
      new.resolved_at := null;
      new.resolved_by := null;
    else
      new.resolved_at := now();
      new.resolved_by := auth.uid();
    end if;
    perform public.write_audit_log(
      'companion_escalation_status_changed', auth.uid(), new.patient_id, new.org_id,
      jsonb_build_object('escalation_id', new.id, 'from', old.status, 'to', new.status)
    );
  end if;
  return new;
end;
$$;

drop trigger if exists companion_escalations_before_update on public.companion_escalations;
create trigger companion_escalations_before_update
  before update on public.companion_escalations
  for each row execute function public.companion_escalations_before_update();

-- Keep the roster's open-question count true (definer: patients cannot write
-- patient_roster_meta).
create or replace function public.companion_escalations_sync_roster()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_patient uuid := coalesce(new.patient_id, old.patient_id);
  v_org uuid := coalesce(new.org_id, old.org_id);
  v_open int;
begin
  select count(*)::int into v_open
    from public.companion_escalations e
   where e.patient_id = v_patient and e.status = 'open';

  insert into public.patient_roster_meta (patient_id, org_id, open_questions)
  values (v_patient, v_org, v_open)
  on conflict (patient_id) do update set open_questions = excluded.open_questions;
  return null;
end;
$$;

drop trigger if exists companion_escalations_sync_roster on public.companion_escalations;
create trigger companion_escalations_sync_roster
  after insert or update of status or delete on public.companion_escalations
  for each row execute function public.companion_escalations_sync_roster();

-- Emergency alert: ids only in the payload.
create or replace function public.companion_escalations_alert_emergency()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_contact uuid;
  v_any boolean := false;
begin
  for v_contact in
    select m.user_id from public.org_members m
     where m.org_id = new.org_id and m.status = 'active' and m.is_escalation_contact
  loop
    v_any := true;
    insert into public.notification_outbox (user_id, org_id, type, payload)
    values (v_contact, new.org_id, 'companion_emergency', jsonb_build_object('escalation_id', new.id));
  end loop;

  if not v_any then
    for v_contact in
      select m.user_id from public.org_members m
       where m.org_id = new.org_id and m.status = 'active' and m.role = 'physician'
    loop
      insert into public.notification_outbox (user_id, org_id, type, payload)
      values (v_contact, new.org_id, 'companion_emergency', jsonb_build_object('escalation_id', new.id));
    end loop;
  end if;
  return null;
end;
$$;

drop trigger if exists companion_escalations_alert_emergency on public.companion_escalations;
create trigger companion_escalations_alert_emergency
  after insert on public.companion_escalations
  for each row when (new.kind = 'emergency')
  execute function public.companion_escalations_alert_emergency();

revoke execute on function public.companion_escalations_before_insert() from public, anon, authenticated;
revoke execute on function public.companion_escalations_before_update() from public, anon, authenticated;
revoke execute on function public.companion_escalations_sync_roster() from public, anon, authenticated;
revoke execute on function public.companion_escalations_alert_emergency() from public, anon, authenticated;

-- ---------------------------------------------------------------------------
-- 3. Row level security
-- ---------------------------------------------------------------------------
alter table public.companion_escalations enable row level security;
alter table public.companion_escalations force row level security;

revoke all on public.companion_escalations from anon, authenticated;
grant select, insert on public.companion_escalations to authenticated;
-- Staff may change the status only; resolved_at / resolved_by come from the
-- trigger, and nobody can rewrite the question.
grant update (status) on public.companion_escalations to authenticated;

drop policy if exists companion_escalations_self_select on public.companion_escalations;
create policy companion_escalations_self_select on public.companion_escalations
  for select to authenticated
  using (
    patient_id = auth.uid()
    and public.current_email_confirmed()
    and public.current_patient_linked()
  );

drop policy if exists companion_escalations_self_insert on public.companion_escalations;
create policy companion_escalations_self_insert on public.companion_escalations
  for insert to authenticated
  with check (
    patient_id = auth.uid()
    and public.current_email_confirmed()
    and public.current_patient_linked()
  );

drop policy if exists companion_escalations_staff_select on public.companion_escalations;
create policy companion_escalations_staff_select on public.companion_escalations
  for select to authenticated
  using (
    org_id = public.current_org_id()
    and public.has_aal2()
    and public.current_role() in ('physician', 'care_coordinator')
  );

drop policy if exists companion_escalations_staff_update on public.companion_escalations;
create policy companion_escalations_staff_update on public.companion_escalations
  for update to authenticated
  using (
    org_id = public.current_org_id()
    and public.has_aal2()
    and public.current_role() in ('physician', 'care_coordinator')
  )
  with check (
    org_id = public.current_org_id()
    and public.has_aal2()
    and public.current_role() in ('physician', 'care_coordinator')
  );
