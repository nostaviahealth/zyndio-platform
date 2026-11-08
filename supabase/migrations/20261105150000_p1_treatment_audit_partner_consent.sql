-- P1 Clinical & Governance (APP-03, POR-07, POR-08, INT-04):
--   1. APP-03: Separate, revocable authorisation to share clinician-reviewed
--      milestone outcomes with the body composition partner (DEXASCAN).
--   2. POR-07 & INT-04: GLP-1 treatment context and chronological treatment
--      events (courses + events, idempotency key per org, clinic staff only;
--      patients can NEVER write treatment/dose rows per Clause 9.1).
--   3. POR-08: Org-scoped audit log view RPC for active org_admin at AAL2.

-- ===========================================================================
-- 1. APP-03: partner_outcome_authorisations
-- ===========================================================================

create table public.partner_outcome_authorisations (
  patient_id uuid primary key references auth.users (id) on delete cascade,
  org_id uuid references public.organizations (id) on delete cascade,
  partner_code text not null default 'DEXASCAN'
    check (char_length(partner_code) between 1 and 64),
  consent_version text not null
    check (char_length(consent_version) between 1 and 32),
  consent_text_sha256 text not null
    check (char_length(consent_text_sha256) = 64),
  authorized boolean not null default false,
  granted_at timestamptz,
  revoked_at timestamptz,
  updated_at timestamptz not null default now()
);

create index partner_outcome_authorisations_org_id_idx
  on public.partner_outcome_authorisations (org_id);

alter table public.partner_outcome_authorisations enable row level security;
alter table public.partner_outcome_authorisations force row level security;

revoke all on public.partner_outcome_authorisations from anon, authenticated;
grant select on public.partner_outcome_authorisations to authenticated;

create policy partner_outcome_authorisations_self_select
  on public.partner_outcome_authorisations
  for select
  to authenticated
  using (patient_id = auth.uid());

create policy partner_outcome_authorisations_staff_select
  on public.partner_outcome_authorisations
  for select
  to authenticated
  using (
    org_id = public.current_org_id()
    and public.has_aal2()
    and public.current_role() in ('physician', 'care_coordinator', 'read_only')
  );

-- The current partner_disclosure document is the APP-03 statement. The
-- setter stores that version and a hash of that body. A client cannot
-- substitute a different sentence. Synthetic wording only; not a legal policy.
insert into public.consent_documents
  (consent_type, version, document, title, summary, body, required, is_placeholder)
values (
  'partner_disclosure',
  'v1.0',
  'zyndio_partner_disclosure',
  'Share clinician-reviewed outcomes with DEXASCAN',
  'Synthetic APP-03 statement for the fictional test candidate. Not a legal policy.',
  'I authorise Zyndio to share my clinician-reviewed milestone outcomes with DEXASCAN.',
  false,
  false
);

-- Patient-callable RPC to grant or revoke DEXASCAN outcome sharing.
-- Records grant/revocation timestamp, SHA-256 of consent text, audit_log row,
-- and enqueues a consent.updated event in public.notification_outbox.
create or replace function public.set_partner_outcome_authorisation(
  p_authorized boolean,
  p_consent_version text default 'v1.0',
  p_consent_text text default 'I authorise Zyndio to share my clinician-reviewed milestone outcomes with DEXASCAN.'
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
  v_org_id uuid;
  v_version text := pg_catalog.btrim(coalesce(p_consent_version, ''));
  v_text text := pg_catalog.btrim(coalesce(p_consent_text, ''));
  v_sha256 text;
  v_now timestamptz := pg_catalog.now();
  v_event_type text;
  v_row public.partner_outcome_authorisations;
begin
  if v_uid is null then
    raise exception 'not authenticated' using errcode = '42501';
  end if;

  -- Clinic staff who are not patient accounts cannot toggle patient consent.
  if exists (
    select 1 from public.org_members m
    where m.user_id = v_uid
  ) and not exists (
    select 1 from public.patients p
    where p.id = v_uid
  ) then
    raise exception 'not authorized' using errcode = '42501';
  end if;

  if p_authorized is null then
    raise exception 'p_authorized is required' using errcode = '22023';
  end if;

  select d.version, pg_catalog.btrim(d.body)
    into v_version, v_text
  from public.current_consent_documents d
  where d.consent_type = 'partner_disclosure';

  if v_version is null or v_text is null then
    raise exception 'partner disclosure document is not published' using errcode = 'P0001';
  end if;

  if pg_catalog.btrim(coalesce(p_consent_version, '')) <> ''
     and pg_catalog.btrim(p_consent_version) is distinct from v_version then
    raise exception 'consent_version does not match the current document' using errcode = '22023';
  end if;

  if pg_catalog.btrim(coalesce(p_consent_text, '')) <> ''
     and pg_catalog.btrim(p_consent_text) is distinct from v_text then
    raise exception 'consent_text does not match the current document' using errcode = '22023';
  end if;

  v_sha256 := pg_catalog.encode(
    extensions.digest(pg_catalog.convert_to(v_text, 'UTF8'), 'sha256'),
    'hex'
  );

  select p.org_id into v_org_id
  from public.patients p
  where p.id = v_uid;

  if v_org_id is null then
    raise exception 'not authorized' using errcode = '42501';
  end if;

  insert into public.partner_outcome_authorisations as poa (
    patient_id,
    org_id,
    partner_code,
    consent_version,
    consent_text_sha256,
    authorized,
    granted_at,
    revoked_at,
    updated_at
  )
  values (
    v_uid,
    v_org_id,
    'DEXASCAN',
    v_version,
    v_sha256,
    p_authorized,
    case when p_authorized then v_now else null end,
    case when p_authorized then null else v_now end,
    v_now
  )
  on conflict (patient_id) do update set
    org_id              = coalesce(excluded.org_id, poa.org_id),
    partner_code        = excluded.partner_code,
    consent_version     = excluded.consent_version,
    consent_text_sha256 = excluded.consent_text_sha256,
    authorized          = excluded.authorized,
    granted_at          = case when p_authorized then v_now else poa.granted_at end,
    revoked_at          = case when p_authorized then null else v_now end,
    updated_at          = v_now
  returning * into v_row;

  if p_authorized then
    insert into public.consents (org_id, patient_id, consent_type, granted, document, version)
    values (v_org_id, v_uid, 'partner_disclosure', true, 'zyndio_partner_disclosure', v_version);
  else
    update public.consents
      set granted = false
      where patient_id = v_uid
        and org_id = v_org_id
        and consent_type = 'partner_disclosure'
        and revoked_at is null;
  end if;

  v_event_type := case
    when p_authorized then 'partner_outcome_consent_granted'
    else 'partner_outcome_consent_revoked'
  end;

  perform public._audit_log_insert(
    v_event_type,
    v_uid,
    v_uid,
    v_org_id,
    pg_catalog.jsonb_build_object(
      'partner_code', v_row.partner_code,
      'authorized', v_row.authorized,
      'consent_version', v_row.consent_version,
      'consent_text_sha256', v_row.consent_text_sha256
    )
  );

  insert into public.notification_outbox (user_id, org_id, type, status, payload)
  values (
    v_uid,
    v_org_id,
    'consent.updated',
    'pending',
    pg_catalog.jsonb_build_object(
      'event_type', 'consent.updated',
      'patient_id', v_uid,
      'partner_code', v_row.partner_code,
      'authorized', v_row.authorized,
      'consent_version', v_row.consent_version,
      'consent_text_sha256', v_row.consent_text_sha256,
      'occurred_at', v_now
    )
  );

  return pg_catalog.jsonb_build_object(
    'patient_id', v_row.patient_id,
    'org_id', v_row.org_id,
    'partner_code', v_row.partner_code,
    'authorized', v_row.authorized,
    'consent_version', v_row.consent_version,
    'consent_text_sha256', v_row.consent_text_sha256,
    'granted_at', v_row.granted_at,
    'revoked_at', v_row.revoked_at,
    'updated_at', v_row.updated_at
  );
end;
$$;

-- Checked at both outcome compute time and delivery time (PRD p. 15 & 20).
-- Returns true ONLY when authorized = true AND revoked_at IS NULL.
create or replace function public.is_partner_outcome_authorised(p_patient_id uuid)
returns boolean
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_uid uuid := auth.uid();
  v_role text := coalesce(auth.role(), '');
begin
  if p_patient_id is null then
    return false;
  end if;

  -- When called by an authenticated session (not service_role or superuser),
  -- enforce own-patient or own-clinic staff visibility.
  if v_role = 'authenticated' and v_uid is not null and v_uid <> p_patient_id then
    if not (
      public.has_aal2()
      and public.current_role() in ('physician', 'care_coordinator', 'read_only')
      and exists (
        select 1 from public.patients p
        where p.id = p_patient_id and p.org_id = public.current_org_id()
      )
    ) then
      return false;
    end if;
  end if;

  return exists (
    select 1
    from public.partner_outcome_authorisations poa
    join public.current_consent_documents d
      on d.consent_type = 'partner_disclosure'
    where poa.patient_id = p_patient_id
      and poa.authorized = true
      and poa.revoked_at is null
      and poa.org_id is not null
      and poa.consent_version = d.version
      and poa.consent_text_sha256 = pg_catalog.encode(
        extensions.digest(pg_catalog.convert_to(pg_catalog.btrim(d.body), 'UTF8'), 'sha256'),
        'hex'
      )
      and public.partner_disclosure_currently_granted(poa.patient_id, poa.org_id)
  );
end;
$$;

revoke all on function public.set_partner_outcome_authorisation(boolean, text, text) from public, anon;
grant execute on function public.set_partner_outcome_authorisation(boolean, text, text) to authenticated, service_role;

revoke all on function public.is_partner_outcome_authorised(uuid) from public, anon;
grant execute on function public.is_partner_outcome_authorised(uuid) to authenticated, service_role;

-- ===========================================================================
-- 2. POR-07 & INT-04: treatment_courses & treatment_events
--    (Clause 9.1 No-Dose-Suggestion Rule: recorded clinician/partner context
--     only; patients can NEVER write treatment or dose rows)
-- ===========================================================================

create table public.treatment_courses (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null references public.organizations (id) on delete cascade,
  patient_id uuid not null references public.patients (id) on delete cascade,
  medication text not null check (char_length(medication) between 1 and 120),
  formulation text not null default '' check (char_length(formulation) <= 120),
  current_dose_value numeric check (current_dose_value is null or current_dose_value > 0),
  current_dose_unit text check (current_dose_unit is null or char_length(current_dose_unit) <= 32),
  start_date date not null,
  status text not null default 'active'
    check (status in ('active', 'paused', 'discontinued', 'completed')),
  created_by uuid,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index treatment_courses_patient_id_idx
  on public.treatment_courses (patient_id, created_at desc);
create index treatment_courses_org_id_idx
  on public.treatment_courses (org_id);

create table public.treatment_events (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null references public.organizations (id) on delete cascade,
  patient_id uuid not null references public.patients (id) on delete cascade,
  course_id uuid not null references public.treatment_courses (id) on delete cascade,
  event_type text not null
    check (event_type in ('medication_start', 'dose_change', 'status_change', 'tolerability_note', 'clinician_change')),
  dose_value numeric check (dose_value is null or dose_value > 0),
  dose_unit text check (dose_unit is null or char_length(dose_unit) <= 32),
  status_value text
    check (status_value is null or status_value in ('active', 'paused', 'discontinued', 'completed')),
  note text check (note is null or char_length(note) <= 500),
  effective_at timestamptz not null default now(),
  entered_by uuid,
  source text not null default 'portal'
    check (source in ('portal', 'api')),
  idempotency_key text,
  created_at timestamptz not null default now(),
  unique (org_id, idempotency_key)
);

create index treatment_events_patient_effective_idx
  on public.treatment_events (patient_id, effective_at desc, created_at desc);
create index treatment_events_course_id_idx
  on public.treatment_events (course_id);
create index treatment_events_org_id_idx
  on public.treatment_events (org_id);

alter table public.treatment_courses enable row level security;
alter table public.treatment_courses force row level security;
alter table public.treatment_events enable row level security;
alter table public.treatment_events force row level security;

-- No direct INSERT/UPDATE/DELETE for anon or authenticated; all writes go
-- through record_patient_treatment_event() (clinic staff) or service_role
-- (INT-04 partner API). Patients have zero write path and zero read policy
-- on treatment_courses/treatment_events.
revoke all on public.treatment_courses from anon, authenticated;
revoke all on public.treatment_events from anon, authenticated;
grant select on public.treatment_courses to authenticated;
grant select on public.treatment_events to authenticated;

create policy treatment_courses_staff_select
  on public.treatment_courses
  for select
  to authenticated
  using (
    org_id = public.current_org_id()
    and public.has_aal2()
    and public.current_role() in ('physician', 'care_coordinator', 'read_only')
  );

create policy treatment_events_staff_select
  on public.treatment_events
  for select
  to authenticated
  using (
    org_id = public.current_org_id()
    and public.has_aal2()
    and public.current_role() in ('physician', 'care_coordinator', 'read_only')
  );

-- Record a GLP-1 treatment event from the Physician Portal (physician or
-- care_coordinator at AAL2, own clinic only; patients and read_only are
-- strictly refused with 42501).
create or replace function public.record_patient_treatment_event(
  p_patient_id uuid,
  p_event_type text,
  p_medication text default null,
  p_formulation text default '',
  p_dose_value numeric default null,
  p_dose_unit text default null,
  p_status_value text default null,
  p_note text default null,
  p_effective_at timestamptz default now(),
  p_idempotency_key text default null
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor uuid := auth.uid();
  v_org_id uuid := public.current_org_id();
  v_patient public.patients;
  v_course public.treatment_courses;
  v_event public.treatment_events;
  v_idem text := nullif(pg_catalog.btrim(coalesce(p_idempotency_key, '')), '');
  v_med text := nullif(pg_catalog.btrim(coalesce(p_medication, '')), '');
  v_form text := pg_catalog.btrim(coalesce(p_formulation, ''));
  v_unit text := nullif(pg_catalog.btrim(coalesce(p_dose_unit, '')), '');
  v_note text := nullif(pg_catalog.btrim(coalesce(p_note, '')), '');
  v_eff timestamptz := coalesce(p_effective_at, pg_catalog.now());
begin
  if v_actor is null
     or v_org_id is null
     or not public.has_aal2()
     or public.current_role() not in ('physician', 'care_coordinator') then
    raise exception 'not authorized' using errcode = '42501';
  end if;

  select * into v_patient
  from public.patients p
  where p.id = p_patient_id and p.org_id = v_org_id;

  if v_patient.id is null then
    raise exception 'patient not found' using errcode = 'P0002';
  end if;

  if p_event_type is null or p_event_type not in (
    'medication_start', 'dose_change', 'status_change', 'tolerability_note', 'clinician_change'
  ) then
    raise exception 'invalid event_type' using errcode = '22023';
  end if;

  if p_dose_value is not null and p_dose_value <= 0 then
    raise exception 'dose_value must be positive' using errcode = '22023';
  end if;

  if v_unit is not null and pg_catalog.char_length(v_unit) > 32 then
    raise exception 'dose_unit too long' using errcode = '22023';
  end if;

  if p_status_value is not null and p_status_value not in ('active', 'paused', 'discontinued', 'completed') then
    raise exception 'invalid status_value' using errcode = '22023';
  end if;

  if v_note is not null and pg_catalog.char_length(v_note) > 500 then
    raise exception 'note exceeds 500 characters' using errcode = '22023';
  end if;

  if p_event_type = 'dose_change' and (p_dose_value is null or v_unit is null) then
    raise exception 'dose is required for dose_change' using errcode = '22023';
  end if;

  -- Idempotent replay within 7 days per (org_id, idempotency_key).
  -- The HTTP handler uses the same window. A key older than 7 days conflicts
  -- instead of replaying the old dose forever.
  if v_idem is not null then
    select * into v_event
    from public.treatment_events te
    where te.org_id = v_org_id
      and te.idempotency_key = v_idem;

    if v_event.id is not null then
      if v_event.patient_id <> p_patient_id
         or v_event.created_at < pg_catalog.now() - interval '7 days' then
        raise exception 'idempotency_key conflict' using errcode = '23505';
      end if;
      select * into v_course
      from public.treatment_courses tc
      where tc.id = v_event.course_id;

      return pg_catalog.jsonb_build_object(
        'replayed', true,
        'course', pg_catalog.jsonb_build_object(
          'id', v_course.id,
          'org_id', v_course.org_id,
          'patient_id', v_course.patient_id,
          'medication', v_course.medication,
          'formulation', v_course.formulation,
          'current_dose_value', v_course.current_dose_value,
          'current_dose_unit', v_course.current_dose_unit,
          'start_date', v_course.start_date,
          'status', v_course.status,
          'updated_at', v_course.updated_at
        ),
        'event', pg_catalog.jsonb_build_object(
          'id', v_event.id,
          'course_id', v_event.course_id,
          'patient_id', v_event.patient_id,
          'event_type', v_event.event_type,
          'dose_value', v_event.dose_value,
          'dose_unit', v_event.dose_unit,
          'status_value', v_event.status_value,
          'note', v_event.note,
          'effective_at', v_event.effective_at,
          'entered_by', v_event.entered_by,
          'source', v_event.source,
          'idempotency_key', v_event.idempotency_key,
          'created_at', v_event.created_at
        )
      );
    end if;
  end if;

  -- A new medication starts its own course and leaves a different active
  -- medication active. The same medication reuses its active course so a
  -- second start does not fork that drug. Events below attach to v_course only.
  if p_event_type = 'medication_start' and v_med is not null then
    select * into v_course
    from public.treatment_courses tc
    where tc.patient_id = p_patient_id
      and tc.org_id = v_org_id
      and tc.status = 'active'
      and pg_catalog.lower(pg_catalog.btrim(tc.medication)) = pg_catalog.lower(v_med)
    order by tc.created_at desc, tc.id desc
    limit 1;
  elsif v_med is not null then
    select * into v_course
    from public.treatment_courses tc
    where tc.patient_id = p_patient_id
      and tc.org_id = v_org_id
      and tc.status = 'active'
      and pg_catalog.lower(pg_catalog.btrim(tc.medication)) = pg_catalog.lower(v_med)
    order by tc.created_at desc, tc.id desc
    limit 1;
  end if;

  if v_course.id is null and p_event_type <> 'medication_start' then
    select * into v_course
    from public.treatment_courses tc
    where tc.patient_id = p_patient_id
      and tc.org_id = v_org_id
      and tc.status = 'active'
    order by tc.created_at desc, tc.id desc
    limit 1;
  end if;

  if v_course.id is null then
    if v_med is null or pg_catalog.char_length(v_med) > 120 then
      raise exception 'medication is required (1..120 chars)' using errcode = '22023';
    end if;
    if pg_catalog.char_length(v_form) > 120 then
      raise exception 'formulation exceeds 120 characters' using errcode = '22023';
    end if;

    insert into public.treatment_courses (
      org_id,
      patient_id,
      medication,
      formulation,
      current_dose_value,
      current_dose_unit,
      start_date,
      status,
      created_by,
      created_at,
      updated_at
    )
    values (
      v_org_id,
      p_patient_id,
      v_med,
      v_form,
      p_dose_value,
      v_unit,
      (v_eff at time zone 'UTC')::date,
      coalesce(p_status_value, 'active'),
      v_actor,
      pg_catalog.now(),
      pg_catalog.now()
    )
    returning * into v_course;
  else
    update public.treatment_courses tc
    set
      medication         = coalesce(v_med, tc.medication),
      formulation        = case when v_form <> '' then v_form else tc.formulation end,
      current_dose_value = case when p_dose_value is not null then p_dose_value else tc.current_dose_value end,
      current_dose_unit  = case when v_unit is not null then v_unit else tc.current_dose_unit end,
      status             = coalesce(p_status_value, tc.status),
      updated_at         = pg_catalog.now()
    where tc.id = v_course.id
    returning * into v_course;
  end if;

  insert into public.treatment_events (
    org_id,
    patient_id,
    course_id,
    event_type,
    dose_value,
    dose_unit,
    status_value,
    note,
    effective_at,
    entered_by,
    source,
    idempotency_key
  )
  values (
    v_org_id,
    p_patient_id,
    v_course.id,
    p_event_type,
    p_dose_value,
    v_unit,
    coalesce(p_status_value, case when p_event_type = 'medication_start' then v_course.status else null end),
    v_note,
    v_eff,
    v_actor,
    'portal',
    v_idem
  )
  returning * into v_event;

  perform public._audit_log_insert(
    'treatment_event_recorded',
    v_actor,
    p_patient_id,
    v_org_id,
    pg_catalog.jsonb_build_object(
      'course_id', v_course.id,
      'event_id', v_event.id,
      'treatment_event_type', p_event_type,
      'source', 'portal'
    )
  );

  return pg_catalog.jsonb_build_object(
    'replayed', false,
    'course', pg_catalog.jsonb_build_object(
      'id', v_course.id,
      'org_id', v_course.org_id,
      'patient_id', v_course.patient_id,
      'medication', v_course.medication,
      'formulation', v_course.formulation,
      'current_dose_value', v_course.current_dose_value,
      'current_dose_unit', v_course.current_dose_unit,
      'start_date', v_course.start_date,
      'status', v_course.status,
      'updated_at', v_course.updated_at
    ),
    'event', pg_catalog.jsonb_build_object(
      'id', v_event.id,
      'course_id', v_event.course_id,
      'patient_id', v_event.patient_id,
      'event_type', v_event.event_type,
      'dose_value', v_event.dose_value,
      'dose_unit', v_event.dose_unit,
      'status_value', v_event.status_value,
      'note', v_event.note,
      'effective_at', v_event.effective_at,
      'entered_by', v_event.entered_by,
      'source', v_event.source,
      'idempotency_key', v_event.idempotency_key,
      'created_at', v_event.created_at
    )
  );
end;
$$;

-- Returns current treatment course + chronological event history for a patient
-- in the caller's clinic, and writes an audit_log entry ('treatment_context_viewed').
create or replace function public.get_patient_treatment_context(p_patient_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_actor uuid := auth.uid();
  v_org_id uuid := public.current_org_id();
  v_patient public.patients;
  v_course public.treatment_courses;
  v_events jsonb;
  v_courses jsonb;
begin
  if v_actor is null
     or v_org_id is null
     or not public.has_aal2()
     or public.current_role() not in ('physician', 'care_coordinator', 'read_only') then
    return null;
  end if;

  select * into v_patient
  from public.patients p
  where p.id = p_patient_id and p.org_id = v_org_id;

  if v_patient.id is null then
    return null;
  end if;

  select * into v_course
  from public.treatment_courses tc
  where tc.patient_id = p_patient_id and tc.org_id = v_org_id
  order by tc.created_at desc, tc.id desc
  limit 1;

  select coalesce(
    pg_catalog.jsonb_agg(
      pg_catalog.jsonb_build_object(
        'id', te.id,
        'course_id', te.course_id,
        'patient_id', te.patient_id,
        'event_type', te.event_type,
        'dose_value', te.dose_value,
        'dose_unit', te.dose_unit,
        'status_value', te.status_value,
        'note', te.note,
        'effective_at', te.effective_at,
        'entered_by', te.entered_by,
        'source', te.source,
        'idempotency_key', te.idempotency_key,
        'created_at', te.created_at
      )
      order by te.effective_at desc, te.created_at desc, te.id desc
    ),
    '[]'::jsonb
  )
  into v_events
  from public.treatment_events te
  where te.patient_id = p_patient_id
    and te.org_id = v_org_id
    and (v_course.id is null or te.course_id = v_course.id);

  select coalesce(
    pg_catalog.jsonb_agg(
      pg_catalog.jsonb_build_object(
        'id', tc.id,
        'medication', tc.medication,
        'formulation', tc.formulation,
        'status', tc.status,
        'current_dose_value', tc.current_dose_value,
        'current_dose_unit', tc.current_dose_unit,
        'start_date', tc.start_date
      )
      order by tc.created_at desc, tc.id desc
    ),
    '[]'::jsonb
  )
  into v_courses
  from public.treatment_courses tc
  where tc.patient_id = p_patient_id and tc.org_id = v_org_id;

  perform public._audit_log_insert(
    'treatment_context_viewed',
    v_actor,
    p_patient_id,
    v_org_id,
    '{}'::jsonb
  );

  return pg_catalog.jsonb_build_object(
    'patient_id', p_patient_id,
    'course', case when v_course.id is not null then
      pg_catalog.jsonb_build_object(
        'id', v_course.id,
        'org_id', v_course.org_id,
        'patient_id', v_course.patient_id,
        'medication', v_course.medication,
        'formulation', v_course.formulation,
        'current_dose_value', v_course.current_dose_value,
        'current_dose_unit', v_course.current_dose_unit,
        'start_date', v_course.start_date,
        'status', v_course.status,
        'updated_at', v_course.updated_at
      )
    else null end,
    'events', v_events,
    'courses', v_courses
  );
end;
$$;

revoke all on function public.record_patient_treatment_event(uuid, text, text, text, numeric, text, text, text, timestamptz, text) from public, anon;
grant execute on function public.record_patient_treatment_event(uuid, text, text, text, numeric, text, text, text, timestamptz, text) to authenticated, service_role;

revoke all on function public.get_patient_treatment_context(uuid) from public, anon;
grant execute on function public.get_patient_treatment_context(uuid) to authenticated, service_role;

-- ===========================================================================
-- 3. POR-08: list_org_audit_log (callable ONLY by active org_admin at AAL2)
-- ===========================================================================

create or replace function public.list_org_audit_log(
  p_limit int default 100,
  p_action_filter text default null
)
returns table (
  id bigint,
  action text,
  actor_id uuid,
  target_id uuid,
  created_at timestamptz,
  metadata jsonb
)
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_org_id uuid := public.current_org_id();
  v_filter text := nullif(pg_catalog.btrim(coalesce(p_action_filter, '')), '');
  v_cap int;
begin
  if not public.is_org_admin() or not public.has_aal2() or v_org_id is null then
    raise exception 'not authorized' using errcode = '42501';
  end if;

  -- greatest/least are SQL expressions. pg_catalog.greatest(int, int) does not exist.
  v_cap := least(greatest(coalesce(p_limit, 100), 1), 500);

  return query
  select
    a.id,
    a.event_type as action,
    a.actor_user_id as actor_id,
    a.target_user_id as target_id,
    a.created_at,
    (coalesce(a.metadata, '{}'::jsonb)
      - array['token', 'code', 'plain_code', 'otp', 'password', 'note', 'tolerability_note', 'email', 'full_name', 'display_name']) as metadata
  from public.audit_log a
  where a.org_id = v_org_id
    and (v_filter is null or a.event_type = v_filter)
  order by a.created_at desc, a.id desc
  limit v_cap;
end;
$$;

revoke all on function public.list_org_audit_log(int, text) from public, anon;
grant execute on function public.list_org_audit_log(int, text) to authenticated, service_role;

-- service_role UPDATE/DELETE on audit_log predates this branch. Legitimate
-- writers are the security-definer audit functions. This revoke is a migration,
-- not a live permission change on a hosted project.
revoke update, delete on public.audit_log from public, anon, authenticated, service_role;

-- Partner API write: patient, clinic, current APP-03 consent, course, event,
-- and audit commit together. A failed audit rolls the dose back with the function.
create or replace function public.record_partner_treatment_event(
  p_org_id uuid,
  p_patient_id uuid,
  p_event_type text,
  p_medication text,
  p_formulation text,
  p_dose_value numeric,
  p_dose_unit text,
  p_status_value text,
  p_note text,
  p_effective_at timestamptz,
  p_idempotency_key text,
  p_request_id text
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_course public.treatment_courses;
  v_event public.treatment_events;
  v_med text := nullif(pg_catalog.btrim(coalesce(p_medication, '')), '');
  v_form text := pg_catalog.btrim(coalesce(p_formulation, ''));
  v_unit text := nullif(pg_catalog.btrim(coalesce(p_dose_unit, '')), '');
  v_note text := nullif(pg_catalog.btrim(coalesce(p_note, '')), '');
  v_idem text := nullif(pg_catalog.btrim(coalesce(p_idempotency_key, '')), '');
  v_eff timestamptz := coalesce(p_effective_at, pg_catalog.now());
begin
  if p_org_id is null or not exists (
    select 1 from public.patients p where p.id = p_patient_id and p.org_id = p_org_id
  ) then
    raise exception 'patient not found' using errcode = 'P0002';
  end if;

  if not public.is_partner_outcome_authorised(p_patient_id) then
    raise exception 'partner disclosure consent is required' using errcode = '42501';
  end if;

  if p_event_type is null or p_event_type not in (
    'medication_start', 'dose_change', 'status_change', 'tolerability_note', 'clinician_change'
  ) then
    raise exception 'invalid event_type' using errcode = '22023';
  end if;

  if p_event_type = 'dose_change' and (p_dose_value is null or v_unit is null or p_dose_value <= 0) then
    raise exception 'dose is required for dose_change' using errcode = '22023';
  end if;

  if v_idem is not null then
    select * into v_event
    from public.treatment_events te
    where te.org_id = p_org_id and te.idempotency_key = v_idem;
    if v_event.id is not null then
      if v_event.patient_id <> p_patient_id
         or v_event.created_at < pg_catalog.now() - interval '7 days' then
        raise exception 'idempotency_key conflict' using errcode = '23505';
      end if;
      select * into v_course from public.treatment_courses tc where tc.id = v_event.course_id;
      return pg_catalog.jsonb_build_object('replayed', true, 'course', pg_catalog.to_jsonb(v_course), 'event', pg_catalog.to_jsonb(v_event));
    end if;
  end if;

  if p_event_type = 'medication_start' and v_med is not null then
    select * into v_course from public.treatment_courses tc
    where tc.patient_id = p_patient_id and tc.org_id = p_org_id and tc.status = 'active'
      and pg_catalog.lower(pg_catalog.btrim(tc.medication)) = pg_catalog.lower(v_med)
    order by tc.created_at desc, tc.id desc limit 1;
  elsif p_event_type <> 'medication_start' then
    select * into v_course from public.treatment_courses tc
    where tc.patient_id = p_patient_id and tc.org_id = p_org_id and tc.status = 'active'
      and (v_med is null or pg_catalog.lower(pg_catalog.btrim(tc.medication)) = pg_catalog.lower(v_med))
    order by tc.created_at desc, tc.id desc limit 1;
  end if;

  if v_course.id is null then
    if v_med is null then
      raise exception 'medication is required' using errcode = '22023';
    end if;
    insert into public.treatment_courses (
      org_id, patient_id, medication, formulation, current_dose_value, current_dose_unit,
      start_date, status, created_by, created_at, updated_at
    ) values (
      p_org_id, p_patient_id, v_med, v_form, p_dose_value, v_unit,
      (v_eff at time zone 'UTC')::date, coalesce(p_status_value, 'active'), null, pg_catalog.now(), pg_catalog.now()
    ) returning * into v_course;
  else
    update public.treatment_courses tc
      set medication = coalesce(v_med, tc.medication),
          formulation = case when v_form <> '' then v_form else tc.formulation end,
          current_dose_value = case when p_dose_value is not null then p_dose_value else tc.current_dose_value end,
          current_dose_unit = case when v_unit is not null then v_unit else tc.current_dose_unit end,
          status = coalesce(p_status_value, tc.status),
          updated_at = pg_catalog.now()
      where tc.id = v_course.id
      returning * into v_course;
  end if;

  insert into public.treatment_events (
    org_id, patient_id, course_id, event_type, dose_value, dose_unit, status_value,
    note, effective_at, entered_by, source, idempotency_key
  ) values (
    p_org_id, p_patient_id, v_course.id, p_event_type, p_dose_value, v_unit, p_status_value,
    v_note, v_eff, null, 'api', v_idem
  ) returning * into v_event;

  perform public._audit_log_insert(
    'treatment_event_recorded',
    null,
    p_patient_id,
    p_org_id,
    pg_catalog.jsonb_build_object(
      'course_id', v_course.id,
      'event_id', v_event.id,
      'treatment_event_type', p_event_type,
      'source', 'api',
      'request_id', p_request_id
    )
  );

  return pg_catalog.jsonb_build_object('replayed', false, 'course', pg_catalog.to_jsonb(v_course), 'event', pg_catalog.to_jsonb(v_event));
end;
$$;

revoke all on function public.record_partner_treatment_event(uuid, uuid, text, text, text, numeric, text, text, text, timestamptz, text, text) from public, anon, authenticated;
grant execute on function public.record_partner_treatment_event(uuid, uuid, text, text, text, numeric, text, text, text, timestamptz, text, text) to service_role;

create trigger trg_treatment_courses_termination_readonly
  before insert or update or delete on public.treatment_courses
  for each row execute function public.enforce_org_termination_readonly();
create trigger trg_treatment_events_termination_readonly
  before insert or update or delete on public.treatment_events
  for each row execute function public.enforce_org_termination_readonly();
