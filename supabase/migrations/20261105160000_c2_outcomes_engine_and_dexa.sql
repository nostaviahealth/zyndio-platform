-- Phase 2 (C2): Outcomes Engine, DEXASCAN Body Composition Ingestion,
-- Outcomes Review Queue (POR-09), and Unmatched Partner Scans Queue (POR-10).
-- PRD pages 14-25, 35-36, 40-43.

-- ---------------------------------------------------------------------------
-- 1. public.body_composition_scans (INT-05 / POR-10 / APP-13)
-- ---------------------------------------------------------------------------

create table public.body_composition_scans (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null references public.organizations(id) on delete cascade,
  patient_id uuid references public.patients(id) on delete set null,
  zyndio_patient_id text,
  partner_patient_id text not null,
  partner_scan_id text not null,
  partner_scan_version int not null default 1,
  scan_date date not null,
  site_id text,
  device_vendor text not null,
  device_model text not null,
  software_version text not null,
  measures jsonb not null,
  binding_status text not null check (binding_status in ('bound', 'unmatched', 'rejected')),
  created_at timestamptz not null default now(),
  unique (org_id, partner_scan_id, partner_scan_version)
);

create index body_composition_scans_org_binding_idx
  on public.body_composition_scans (org_id, binding_status, created_at desc);

create index body_composition_scans_patient_date_idx
  on public.body_composition_scans (patient_id, scan_date desc);

alter table public.body_composition_scans enable row level security;
alter table public.body_composition_scans force row level security;

revoke insert, update, delete on public.body_composition_scans from anon, authenticated;

create policy body_composition_scans_staff_select on public.body_composition_scans
  for select to authenticated
  using (
    public.has_aal2()
    and public.current_role() in ('physician', 'care_coordinator')
    and org_id = public.current_org_id()
  );

create policy body_composition_scans_patient_select on public.body_composition_scans
  for select to authenticated
  using (
    patient_id = auth.uid()
    and binding_status = 'bound'
    and public.current_email_confirmed()
    and public.current_patient_linked()
  );

-- ---------------------------------------------------------------------------
-- 2. public.outcome_records (Schedule C / INT-06 / POR-09)
-- ---------------------------------------------------------------------------

create table public.outcome_records (
  id uuid primary key default gen_random_uuid(),
  record_id text not null unique,
  org_id uuid not null references public.organizations(id) on delete cascade,
  patient_id uuid not null references public.patients(id) on delete cascade,
  milestone text not null check (milestone in ('baseline', 'd90', 'd180', 'd365', 'adhoc')),
  record_version int not null default 1,
  rules_version text not null default 'v1.0',
  state text not null check (state in ('computed', 'in_review', 'approved', 'held', 'sent_back', 'delivered', 'withdrawn')) default 'in_review',
  lean_mass_flag text not null check (lean_mass_flag in ('none', 'watch', 'flagged')) default 'none',
  clinical_context_flag boolean not null default false,
  clinical_flag_cleared_by uuid,
  clinical_flag_cleared_reason text,
  clinician_summary text not null,
  payload jsonb not null,
  approved_by uuid,
  approved_at timestamptz,
  sent_back_reason text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (patient_id, milestone, record_version)
);

create index outcome_records_org_state_idx
  on public.outcome_records (org_id, state, updated_at desc);

create index outcome_records_patient_milestone_idx
  on public.outcome_records (patient_id, milestone, record_version desc);

alter table public.outcome_records enable row level security;
alter table public.outcome_records force row level security;

revoke insert, update, delete on public.outcome_records from anon, authenticated;

create policy outcome_records_staff_select on public.outcome_records
  for select to authenticated
  using (
    public.has_aal2()
    and public.current_role() in ('physician', 'care_coordinator', 'read_only')
    and org_id = public.current_org_id()
  );

-- ---------------------------------------------------------------------------
-- 3. Trigger enforcing immutability of delivered outcome records
-- ---------------------------------------------------------------------------

create function public.enforce_delivered_outcome_immutability()
returns trigger
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
begin
  if OLD.state = 'delivered' then
    if NEW.payload is distinct from OLD.payload
       or NEW.clinician_summary is distinct from OLD.clinician_summary
       or NEW.record_version is distinct from OLD.record_version
       or NEW.milestone is distinct from OLD.milestone
       or NEW.patient_id is distinct from OLD.patient_id
       or NEW.org_id is distinct from OLD.org_id
       or NEW.record_id is distinct from OLD.record_id
       or NEW.lean_mass_flag is distinct from OLD.lean_mass_flag
       or NEW.clinical_context_flag is distinct from OLD.clinical_context_flag then
      raise exception 'delivered outcome records are immutable; insert record_version + 1 to issue a correction'
        using errcode = 'P0001';
    end if;
  end if;
  return NEW;
end;
$$;

revoke all on function public.enforce_delivered_outcome_immutability() from public, anon, authenticated;

create trigger trg_enforce_delivered_outcome_immutability
  before update on public.outcome_records
  for each row execute function public.enforce_delivered_outcome_immutability();

-- ---------------------------------------------------------------------------
-- 4. POR-09 RPCs: list_outcomes_review_queue & review_outcome_record
-- ---------------------------------------------------------------------------

create function public.list_outcomes_review_queue()
returns table (
  id uuid,
  record_id text,
  org_id uuid,
  patient_id uuid,
  patient_display_name text,
  patient_mrn text,
  milestone text,
  record_version int,
  rules_version text,
  state text,
  lean_mass_flag text,
  clinical_context_flag boolean,
  clinical_flag_cleared_by uuid,
  clinical_flag_cleared_reason text,
  clinician_summary text,
  payload jsonb,
  approved_by uuid,
  approved_at timestamptz,
  sent_back_reason text,
  has_partner_disclosure_consent boolean,
  created_at timestamptz,
  updated_at timestamptz
)
language plpgsql
stable
security definer
set search_path = pg_catalog, public
as $$
declare
  v_org_id uuid;
begin
  if auth.uid() is null
     or not public.has_aal2()
     or public.current_role() not in ('physician', 'care_coordinator', 'read_only') then
    raise exception 'not authorized' using errcode = '42501';
  end if;

  v_org_id := public.current_org_id();

  return query
    select
      o.id,
      o.record_id,
      o.org_id,
      o.patient_id,
      coalesce(p.display_name, '') as patient_display_name,
      coalesce(p.mrn, '') as patient_mrn,
      o.milestone,
      o.record_version,
      o.rules_version,
      o.state,
      o.lean_mass_flag,
      o.clinical_context_flag,
      o.clinical_flag_cleared_by,
      o.clinical_flag_cleared_reason,
      o.clinician_summary,
      o.payload,
      o.approved_by,
      o.approved_at,
      o.sent_back_reason,
      exists (
        select 1
        from public.consents c
        where c.patient_id = o.patient_id
          and c.org_id = o.org_id
          and c.consent_type in ('data_sharing', 'partner_disclosure', 'outcomes_disclosure')
          and c.granted = true
      ) as has_partner_disclosure_consent,
      o.created_at,
      o.updated_at
    from public.outcome_records o
    join public.patients p on p.id = o.patient_id and p.org_id = o.org_id
    where o.org_id = v_org_id
    order by o.updated_at desc, o.created_at desc;
end;
$$;

revoke all on function public.list_outcomes_review_queue() from public, anon;
grant execute on function public.list_outcomes_review_queue() to authenticated;

create function public.review_outcome_record(
  p_record_id text,
  p_decision text,
  p_clinician_summary text default null,
  p_clear_clinical_flag boolean default false,
  p_note text default null
)
returns jsonb
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
declare
  v_org_id uuid;
  v_rec public.outcome_records;
  v_target_state text;
  v_flag_after boolean;
  v_cleared_by uuid;
  v_cleared_reason text;
  v_summary text;
  v_has_consent boolean;
begin
  -- POR-09: Only an active physician at AAL2 can approve, hold, or send back an outcome record.
  if auth.uid() is null
     or not public.has_aal2()
     or public.current_role() is distinct from 'physician' then
    raise exception 'not authorized' using errcode = '42501';
  end if;

  v_org_id := public.current_org_id();

  select * into v_rec
    from public.outcome_records
    where record_id = p_record_id and org_id = v_org_id
    for update;

  if v_rec.id is null then
    raise exception 'outcome record not found' using errcode = 'P0002';
  end if;

  if v_rec.state = 'delivered' then
    raise exception 'delivered outcome records are immutable; insert record_version + 1 to issue a correction'
      using errcode = 'P0001';
  end if;

  case lower(btrim(coalesce(p_decision, '')))
    when 'approve', 'approved' then
      v_target_state := 'approved';
    when 'hold', 'held' then
      v_target_state := 'held';
    when 'send_back', 'sent_back' then
      v_target_state := 'sent_back';
    else
      raise exception 'invalid review decision: must be approve, hold, or send_back'
        using errcode = '22023';
  end case;

  if coalesce(p_clear_clinical_flag, false) then
    v_flag_after := false;
    v_cleared_by := auth.uid();
    v_cleared_reason := coalesce(nullif(btrim(p_note), ''), 'Cleared by reviewing physician');
  else
    v_flag_after := v_rec.clinical_context_flag;
    v_cleared_by := v_rec.clinical_flag_cleared_by;
    v_cleared_reason := v_rec.clinical_flag_cleared_reason;
  end if;

  if v_target_state = 'approved' then
    if v_flag_after then
      raise exception 'clinical context flag must be cleared by a physician before approving an outcome record'
        using errcode = 'P0001';
    end if;

    select exists (
      select 1
      from public.consents c
      where c.patient_id = v_rec.patient_id
        and c.org_id = v_org_id
        and c.consent_type in ('data_sharing', 'partner_disclosure', 'outcomes_disclosure')
        and c.granted = true
    ) into v_has_consent;

    if not coalesce(v_has_consent, false) then
      raise exception 'partner disclosure consent is required before approving an outcome record'
        using errcode = 'P0001';
    end if;
  end if;

  v_summary := coalesce(nullif(btrim(p_clinician_summary), ''), v_rec.clinician_summary);

  update public.outcome_records
    set state = v_target_state,
        clinician_summary = v_summary,
        clinical_context_flag = v_flag_after,
        clinical_flag_cleared_by = v_cleared_by,
        clinical_flag_cleared_reason = v_cleared_reason,
        approved_by = case when v_target_state = 'approved' then auth.uid() else approved_by end,
        approved_at = case when v_target_state = 'approved' then now() else approved_at end,
        sent_back_reason = case when v_target_state = 'sent_back' then coalesce(nullif(btrim(p_note), ''), 'Sent back for review') else sent_back_reason end,
        updated_at = now()
    where id = v_rec.id;

  perform public._audit_log_insert(
    'outcome_record_reviewed',
    auth.uid(),
    v_rec.patient_id,
    v_org_id,
    jsonb_build_object(
      'record_id', v_rec.record_id,
      'milestone', v_rec.milestone,
      'record_version', v_rec.record_version,
      'decision', v_target_state,
      'cleared_clinical_flag', coalesce(p_clear_clinical_flag, false)
    )
  );

  return jsonb_build_object(
    'record_id', v_rec.record_id,
    'state', v_target_state,
    'clinical_context_flag', v_flag_after,
    'clinical_flag_cleared_by', v_cleared_by,
    'clinician_summary', v_summary,
    'approved_by', case when v_target_state = 'approved' then auth.uid() else v_rec.approved_by end
  );
end;
$$;

revoke all on function public.review_outcome_record(text, text, text, boolean, text) from public, anon;
grant execute on function public.review_outcome_record(text, text, text, boolean, text) to authenticated;

-- ---------------------------------------------------------------------------
-- 5. POR-10 RPCs: list_unmatched_partner_scans & bind_unmatched_partner_scan
-- ---------------------------------------------------------------------------

create function public.list_unmatched_partner_scans()
returns table (
  id uuid,
  org_id uuid,
  patient_id uuid,
  zyndio_patient_id text,
  partner_patient_id text,
  partner_scan_id text,
  partner_scan_version int,
  scan_date date,
  site_id text,
  device_vendor text,
  device_model text,
  software_version text,
  measures jsonb,
  binding_status text,
  created_at timestamptz
)
language plpgsql
stable
security definer
set search_path = pg_catalog, public
as $$
declare
  v_org_id uuid;
begin
  if auth.uid() is null
     or not public.has_aal2()
     or public.current_role() not in ('physician', 'care_coordinator') then
    raise exception 'not authorized' using errcode = '42501';
  end if;

  v_org_id := public.current_org_id();

  return query
    select
      s.id,
      s.org_id,
      s.patient_id,
      s.zyndio_patient_id,
      s.partner_patient_id,
      s.partner_scan_id,
      s.partner_scan_version,
      s.scan_date,
      s.site_id,
      s.device_vendor,
      s.device_model,
      s.software_version,
      s.measures,
      s.binding_status,
      s.created_at
    from public.body_composition_scans s
    where s.org_id = v_org_id
      and s.binding_status = 'unmatched'
    order by s.created_at desc;
end;
$$;

revoke all on function public.list_unmatched_partner_scans() from public, anon;
grant execute on function public.list_unmatched_partner_scans() to authenticated;

create function public.bind_unmatched_partner_scan(
  p_scan_id uuid,
  p_patient_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
declare
  v_org_id uuid;
  v_scan public.body_composition_scans;
  v_patient public.patients;
begin
  if auth.uid() is null
     or not public.has_aal2()
     or public.current_role() not in ('physician', 'care_coordinator') then
    raise exception 'not authorized' using errcode = '42501';
  end if;

  v_org_id := public.current_org_id();

  select * into v_scan
    from public.body_composition_scans
    where id = p_scan_id and org_id = v_org_id
    for update;

  if v_scan.id is null then
    raise exception 'unmatched scan not found in organization' using errcode = 'P0002';
  end if;

  if v_scan.binding_status <> 'unmatched' then
    raise exception 'scan is already bound or rejected' using errcode = 'P0001';
  end if;

  select * into v_patient
    from public.patients
    where id = p_patient_id and org_id = v_org_id;

  if v_patient.id is null then
    raise exception 'target patient not found in organization' using errcode = 'P0002';
  end if;

  update public.body_composition_scans
    set patient_id = p_patient_id,
        binding_status = 'bound'
    where id = p_scan_id;

  perform public._audit_log_insert(
    'partner_scan_bound',
    auth.uid(),
    p_patient_id,
    v_org_id,
    jsonb_build_object(
      'scan_id', p_scan_id,
      'partner_scan_id', v_scan.partner_scan_id,
      'partner_scan_version', v_scan.partner_scan_version,
      'partner_patient_id', v_scan.partner_patient_id
    )
  );

  return jsonb_build_object(
    'scan_id', p_scan_id,
    'patient_id', p_patient_id,
    'binding_status', 'bound'
  );
end;
$$;

revoke all on function public.bind_unmatched_partner_scan(uuid, uuid) from public, anon;
grant execute on function public.bind_unmatched_partner_scan(uuid, uuid) to authenticated;
