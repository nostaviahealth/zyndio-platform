-- P1 Operations, Metering, and Compliance (PP-02, OPS-01, OPS-02, OPS-03):
--   * PP-02: Active Patients monthly metering (public.usage_months) + Schedule B
--     tiered overage calculation (1-1,000 included; 1,001-2,500 @ $0.50;
--     2,501-10,000 @ $0.35; 10,001+ @ $0.25).
--   * OPS-01: Clause 6.6 patient data export within 30 days of termination
--     request (public.org_termination_exports + deterministic manifest with
--     SHA-256 integrity hash and 60-day read-only window).
--   * OPS-02: Patient data deletion with legal holds (public.patient_legal_holds)
--     and written deletion confirmation certificates
--     (public.patient_deletion_confirmations).
--   * OPS-03: Clause 8.8 72-hour confirmed security incident notification
--     workflow (public.security_incidents + notification_outbox queueing).

-- ===========================================================================
-- 1. PP-02: Active Patients Metering (UsageMonth)
-- ===========================================================================

create table public.usage_months (
  id uuid primary key default extensions.gen_random_uuid(),
  org_id uuid not null references public.organizations (id) on delete cascade,
  month date not null check (month = pg_catalog.date_trunc('month', month)::date),
  patient_id uuid not null references public.patients (id) on delete cascade,
  qualifying_reason text not null check (qualifying_reason in ('sign_in', 'data_processed')),
  first_qualified_at timestamptz not null default pg_catalog.now(),
  unique (org_id, month, patient_id)
);

create index usage_months_org_month_idx on public.usage_months (org_id, month);
create index usage_months_patient_id_idx on public.usage_months (patient_id);

alter table public.usage_months enable row level security;
alter table public.usage_months force row level security;

revoke all on public.usage_months from anon;
revoke insert, update, delete on public.usage_months from authenticated;

create policy usage_months_admin_select on public.usage_months
  for select
  to authenticated
  using (
    org_id = public.current_org_id()
    and public.is_org_admin()
    and public.has_aal2()
  );

create or replace function public.record_patient_monthly_activity(
  p_patient_id uuid,
  p_reason text,
  p_occurred_at timestamptz default pg_catalog.now()
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_org_id uuid;
  v_month date;
  v_ts timestamptz;
  v_row public.usage_months;
begin
  if p_patient_id is null then
    raise exception 'patient_id_required' using errcode = '22023';
  end if;

  if p_reason is null or p_reason not in ('sign_in', 'data_processed') then
    raise exception 'invalid_qualifying_reason' using errcode = '22023';
  end if;

  select p.org_id into v_org_id
    from public.patients p
   where p.id = p_patient_id;

  if v_org_id is null then
    raise exception 'patient_not_found' using errcode = 'P0002';
  end if;

  if current_user not in ('postgres', 'service_role', 'supabase_admin')
     and coalesce(auth.role(), '') <> 'service_role'
  then
    if auth.uid() is null then
      raise exception 'not_authorized' using errcode = '42501';
    end if;

    if auth.uid() <> p_patient_id then
      if not public.has_aal2() or public.current_org_id() is distinct from v_org_id then
        raise exception 'not_authorized' using errcode = '42501';
      end if;
    end if;
  end if;

  v_ts := coalesce(p_occurred_at, pg_catalog.now());
  v_month := (pg_catalog.date_trunc('month', v_ts at time zone 'UTC'))::date;

  insert into public.usage_months (org_id, month, patient_id, qualifying_reason, first_qualified_at)
  values (v_org_id, v_month, p_patient_id, p_reason, v_ts)
  on conflict (org_id, month, patient_id) do nothing;

  select * into v_row
    from public.usage_months u
   where u.org_id = v_org_id
     and u.month = v_month
     and u.patient_id = p_patient_id;

  return pg_catalog.jsonb_build_object(
    'id', v_row.id,
    'org_id', v_row.org_id,
    'month', v_row.month,
    'patient_id', v_row.patient_id,
    'qualifying_reason', v_row.qualifying_reason,
    'first_qualified_at', v_row.first_qualified_at
  );
end;
$$;

revoke all on function public.record_patient_monthly_activity(uuid, text, timestamptz) from public, anon;
grant execute on function public.record_patient_monthly_activity(uuid, text, timestamptz) to authenticated, service_role;

create or replace function public.get_org_monthly_usage_summary(
  p_month date default pg_catalog.date_trunc('month', pg_catalog.now())::date
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_org_id uuid;
  v_month date;
  v_total integer := 0;
  v_sign_in_count integer := 0;
  v_data_processed_count integer := 0;
  v_included integer := 1000;
  v_overage integer := 0;
  v_tier1_patients integer := 0;
  v_tier1_cents integer := 0;
  v_tier2_patients integer := 0;
  v_tier2_cents integer := 0;
  v_tier3_patients integer := 0;
  v_tier3_cents integer := 0;
  v_overage_fee_cents integer := 0;
  v_overage_fee_usd numeric(12, 2) := 0.00;
begin
  v_org_id := public.current_org_id();
  if v_org_id is null or not public.is_org_admin() or not public.has_aal2() then
    raise exception 'not_authorized' using errcode = '42501';
  end if;

  v_month := pg_catalog.date_trunc('month', coalesce(p_month, (pg_catalog.now() at time zone 'UTC')::date))::date;

  select
    count(*)::int,
    count(*) filter (where u.qualifying_reason = 'sign_in')::int,
    count(*) filter (where u.qualifying_reason = 'data_processed')::int
  into v_total, v_sign_in_count, v_data_processed_count
  from public.usage_months u
  where u.org_id = v_org_id
    and u.month = v_month;

  v_overage := greatest(0, v_total - v_included);

  -- Schedule B tiered overage pricing:
  --   1 - 1,000:      Included in base subscription ($0.00)
  --   1,001 - 2,500:  $0.50 (50 cents) per active patient
  --   2,501 - 10,000: $0.35 (35 cents) per active patient
  --   10,001+:        $0.25 (25 cents) per active patient
  v_tier1_patients := greatest(0, least(v_total, 2500) - 1000);
  v_tier1_cents := v_tier1_patients * 50;

  v_tier2_patients := greatest(0, least(v_total, 10000) - 2500);
  v_tier2_cents := v_tier2_patients * 35;

  v_tier3_patients := greatest(0, v_total - 10000);
  v_tier3_cents := v_tier3_patients * 25;

  v_overage_fee_cents := v_tier1_cents + v_tier2_cents + v_tier3_cents;
  v_overage_fee_usd := round((v_overage_fee_cents::numeric / 100.0), 2);

  return pg_catalog.jsonb_build_object(
    'org_id', v_org_id,
    'month', v_month,
    'active_patients_total', v_total,
    'sign_in_count', v_sign_in_count,
    'data_processed_count', v_data_processed_count,
    'included_patients', v_included,
    'billable_overage_patients', v_overage,
    'overage_fee_cents', v_overage_fee_cents,
    'overage_fee_usd', v_overage_fee_usd,
    'tiers', pg_catalog.jsonb_build_object(
      'tier_1001_2500_patients', v_tier1_patients,
      'tier_1001_2500_cents', v_tier1_cents,
      'tier_2501_10000_patients', v_tier2_patients,
      'tier_2501_10000_cents', v_tier2_cents,
      'tier_10001_plus_patients', v_tier3_patients,
      'tier_10001_plus_cents', v_tier3_cents
    )
  );
end;
$$;

revoke all on function public.get_org_monthly_usage_summary(date) from public, anon;
grant execute on function public.get_org_monthly_usage_summary(date) to authenticated, service_role;

-- ===========================================================================
-- 2. OPS-01: Patient Data Export Within 30 Days of Termination Request (6.6)
-- ===========================================================================

create table public.org_termination_exports (
  id uuid primary key default extensions.gen_random_uuid(),
  org_id uuid not null references public.organizations (id) on delete cascade,
  requested_by uuid not null,
  requested_at timestamptz not null default pg_catalog.now(),
  due_at timestamptz not null default (pg_catalog.now() + interval '30 days'),
  readonly_until timestamptz not null default (pg_catalog.now() + interval '60 days'),
  status text not null default 'completed' check (status in ('pending', 'completed')),
  manifest jsonb not null
);

create index org_termination_exports_org_id_idx
  on public.org_termination_exports (org_id, requested_at desc);

alter table public.org_termination_exports enable row level security;
alter table public.org_termination_exports force row level security;

revoke all on public.org_termination_exports from anon;
revoke insert, update, delete on public.org_termination_exports from authenticated;

create policy org_termination_exports_admin_select on public.org_termination_exports
  for select
  to authenticated
  using (
    org_id = public.current_org_id()
    and public.is_org_admin()
    and public.has_aal2()
  );

-- Internal manifest builder (not directly executable by anon/authenticated so
-- TC-025 test 743's lab-reader function inventory stays closed).
create or replace function public._ops_build_export_manifest(p_org_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_patient_count integer := 0;
  v_report_count integer := 0;
  v_patients jsonb := '[]'::jsonb;
  v_documents jsonb := '[]'::jsonb;
  v_core jsonb;
  v_sha256 text;
begin
  select count(*)::int into v_patient_count
    from public.patients p
   where p.org_id = p_org_id;

  select count(*)::int into v_report_count
    from public.lab_reports r
   where r.org_id = p_org_id;

  select coalesce(
    pg_catalog.jsonb_agg(
      pg_catalog.jsonb_build_object(
        'patient_id', p.id,
        'patient_ref', 'PAT-' || pg_catalog.substr(pg_catalog.encode(extensions.digest(p.id::text, 'sha256'), 'hex'), 1, 16),
        'profile_count', (select count(*)::int from public.patient_profiles pp where pp.org_id = p_org_id and pp.patient_id = p.id),
        'lab_report_count', (select count(*)::int from public.lab_reports lr where lr.org_id = p_org_id and lr.patient_id = p.id),
        'consent_count', (select count(*)::int from public.consents c where c.org_id = p_org_id and c.patient_id = p.id)
      )
      order by p.id
    ),
    '[]'::jsonb
  )
  into v_patients
  from public.patients p
  where p.org_id = p_org_id;

  select coalesce(
    pg_catalog.jsonb_agg(
      pg_catalog.jsonb_build_object(
        'report_id', r.id,
        'patient_id', r.patient_id,
        'report_type', r.report_type,
        'storage_bucket', 'lab-reports',
        'storage_path', coalesce(r.pdf_path, r.patient_id::text || '/' || r.id::text || '.json'),
        'created_at', r.created_at
      )
      order by r.id
    ),
    '[]'::jsonb
  )
  into v_documents
  from public.lab_reports r
  where r.org_id = p_org_id;

  v_core := pg_catalog.jsonb_build_object(
    'schema_version', '1.0',
    'clause', '6.6',
    'org_id', p_org_id,
    'patient_count', v_patient_count,
    'lab_report_count', v_report_count,
    'patients', v_patients,
    'documents', v_documents
  );

  v_sha256 := pg_catalog.encode(extensions.digest(v_core::text, 'sha256'), 'hex');

  return v_core || pg_catalog.jsonb_build_object('sha256_manifest', v_sha256);
end;
$$;

revoke all on function public._ops_build_export_manifest(uuid) from public, anon, authenticated;
grant execute on function public._ops_build_export_manifest(uuid) to service_role;

create or replace function public.request_org_termination_export()
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_org_id uuid;
  v_now timestamptz := pg_catalog.now();
  v_manifest jsonb;
  v_row public.org_termination_exports;
begin
  v_org_id := public.current_org_id();
  if v_org_id is null or not public.is_org_admin() or not public.has_aal2() then
    raise exception 'not_authorized' using errcode = '42501';
  end if;

  v_manifest := public._ops_build_export_manifest(v_org_id);

  insert into public.org_termination_exports (
    org_id,
    requested_by,
    requested_at,
    due_at,
    readonly_until,
    status,
    manifest
  )
  values (
    v_org_id,
    auth.uid(),
    v_now,
    v_now + interval '30 days',
    v_now + interval '60 days',
    'completed',
    v_manifest
  )
  returning * into v_row;

  perform public._audit_log_insert(
    'org_termination_export_requested',
    auth.uid(),
    null,
    v_org_id,
    pg_catalog.jsonb_build_object(
      'export_id', v_row.id,
      'patient_count', v_manifest -> 'patient_count',
      'lab_report_count', v_manifest -> 'lab_report_count',
      'sha256_manifest', v_manifest ->> 'sha256_manifest',
      'due_at', v_row.due_at,
      'readonly_until', v_row.readonly_until
    )
  );

  return pg_catalog.to_jsonb(v_row);
end;
$$;

revoke all on function public.request_org_termination_export() from public, anon;
grant execute on function public.request_org_termination_export() to authenticated, service_role;

-- ===========================================================================
-- 3. OPS-02: Patient Data Deletion with Legal Holds & Written Confirmation
-- ===========================================================================

create table public.patient_legal_holds (
  patient_id uuid primary key references public.patients (id) on delete cascade,
  org_id uuid not null references public.organizations (id) on delete cascade,
  reason text not null check (pg_catalog.char_length(reason) between 3 and 500),
  placed_by uuid not null,
  placed_at timestamptz not null default pg_catalog.now()
);

create index patient_legal_holds_org_id_idx on public.patient_legal_holds (org_id);

alter table public.patient_legal_holds enable row level security;
alter table public.patient_legal_holds force row level security;

revoke all on public.patient_legal_holds from anon;
revoke insert, update, delete on public.patient_legal_holds from authenticated;

create policy patient_legal_holds_admin_select on public.patient_legal_holds
  for select
  to authenticated
  using (
    org_id = public.current_org_id()
    and public.is_org_admin()
    and public.has_aal2()
  );

create table public.patient_deletion_confirmations (
  id uuid primary key default extensions.gen_random_uuid(),
  org_id uuid not null references public.organizations (id) on delete cascade,
  patient_ref text not null,
  deleted_by uuid not null,
  deleted_at timestamptz not null default pg_catalog.now(),
  confirmation_code text not null unique,
  certificate_sha256 text not null,
  summary jsonb not null
);

create index patient_deletion_confirmations_org_id_idx
  on public.patient_deletion_confirmations (org_id, deleted_at desc);

alter table public.patient_deletion_confirmations enable row level security;
alter table public.patient_deletion_confirmations force row level security;

revoke all on public.patient_deletion_confirmations from anon;
revoke insert, update, delete on public.patient_deletion_confirmations from authenticated;

create policy patient_deletion_confirmations_admin_select on public.patient_deletion_confirmations
  for select
  to authenticated
  using (
    org_id = public.current_org_id()
    and public.is_org_admin()
    and public.has_aal2()
  );

create or replace function public.set_patient_legal_hold(
  p_patient_id uuid,
  p_hold boolean,
  p_reason text default null
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_org_id uuid;
  v_patient_org uuid;
  v_clean_reason text;
begin
  v_org_id := public.current_org_id();
  if v_org_id is null or not public.is_org_admin() or not public.has_aal2() then
    raise exception 'not_authorized' using errcode = '42501';
  end if;

  if p_patient_id is null or p_hold is null then
    raise exception 'invalid_legal_hold_input' using errcode = '22023';
  end if;

  select p.org_id into v_patient_org
    from public.patients p
   where p.id = p_patient_id;

  if v_patient_org is distinct from v_org_id then
    raise exception 'patient_not_found' using errcode = 'P0002';
  end if;

  if p_hold then
    v_clean_reason := pg_catalog.btrim(coalesce(p_reason, ''));
    if pg_catalog.char_length(v_clean_reason) < 3 or pg_catalog.char_length(v_clean_reason) > 500 then
      raise exception 'invalid_legal_hold_reason' using errcode = '22023';
    end if;

    insert into public.patient_legal_holds (patient_id, org_id, reason, placed_by, placed_at)
    values (p_patient_id, v_org_id, v_clean_reason, auth.uid(), pg_catalog.now())
    on conflict (patient_id) do update
      set reason = excluded.reason,
          placed_by = excluded.placed_by,
          placed_at = excluded.placed_at;

    perform public._audit_log_insert(
      'patient_legal_hold_placed',
      auth.uid(),
      p_patient_id,
      v_org_id,
      pg_catalog.jsonb_build_object('reason', v_clean_reason)
    );

    return pg_catalog.jsonb_build_object(
      'patient_id', p_patient_id,
      'org_id', v_org_id,
      'hold', true,
      'reason', v_clean_reason
    );
  else
    delete from public.patient_legal_holds h
     where h.patient_id = p_patient_id
       and h.org_id = v_org_id;

    perform public._audit_log_insert(
      'patient_legal_hold_released',
      auth.uid(),
      p_patient_id,
      v_org_id,
      '{}'::jsonb
    );

    return pg_catalog.jsonb_build_object(
      'patient_id', p_patient_id,
      'org_id', v_org_id,
      'hold', false,
      'reason', null
    );
  end if;
end;
$$;

revoke all on function public.set_patient_legal_hold(uuid, boolean, text) from public, anon;
grant execute on function public.set_patient_legal_hold(uuid, boolean, text) to authenticated, service_role;

-- Internal deletion worker (not directly executable by anon/authenticated so
-- TC-025 test 743's lab-reader function inventory stays closed).
create or replace function public._ops_delete_patient_clinical_rows(
  p_org_id uuid,
  p_patient_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_deleted_lab_reports integer := 0;
  v_deleted_profiles integer := 0;
  v_deleted_consents integer := 0;
begin
  delete from public.lab_reports r
   where r.org_id = p_org_id
     and r.patient_id = p_patient_id;
  get diagnostics v_deleted_lab_reports = row_count;

  delete from public.patient_profiles pp
   where pp.org_id = p_org_id
     and pp.patient_id = p_patient_id;
  get diagnostics v_deleted_profiles = row_count;

  delete from public.consents c
   where c.org_id = p_org_id
     and c.patient_id = p_patient_id;
  get diagnostics v_deleted_consents = row_count;

  update public.patients p
     set display_name = null,
         mrn = null
   where p.id = p_patient_id
     and p.org_id = p_org_id;

  return pg_catalog.jsonb_build_object(
    'deleted_lab_reports', v_deleted_lab_reports,
    'deleted_profiles', v_deleted_profiles,
    'deleted_consents', v_deleted_consents,
    'pii_scrubbed', true
  );
end;
$$;

revoke all on function public._ops_delete_patient_clinical_rows(uuid, uuid) from public, anon, authenticated;
grant execute on function public._ops_delete_patient_clinical_rows(uuid, uuid) to service_role;

create or replace function public.confirm_patient_data_deletion(p_patient_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_org_id uuid;
  v_patient_org uuid;
  v_now timestamptz := pg_catalog.now();
  v_patient_ref text;
  v_code text;
  v_summary jsonb;
  v_cert_sha256 text;
  v_row public.patient_deletion_confirmations;
begin
  v_org_id := public.current_org_id();
  if v_org_id is null or not public.is_org_admin() or not public.has_aal2() then
    raise exception 'not_authorized' using errcode = '42501';
  end if;

  if p_patient_id is null then
    raise exception 'patient_id_required' using errcode = '22023';
  end if;

  select p.org_id into v_patient_org
    from public.patients p
   where p.id = p_patient_id;

  if v_patient_org is distinct from v_org_id then
    raise exception 'patient_not_found' using errcode = 'P0002';
  end if;

  if exists (
    select 1
      from public.patient_legal_holds h
     where h.patient_id = p_patient_id
       and h.org_id = v_org_id
  ) then
    raise exception 'patient_under_legal_hold' using errcode = 'P0001';
  end if;

  v_summary := public._ops_delete_patient_clinical_rows(v_org_id, p_patient_id);

  v_patient_ref := 'PAT-' || pg_catalog.substr(
    pg_catalog.encode(extensions.digest(p_patient_id::text || ':' || v_org_id::text, 'sha256'), 'hex'),
    1,
    16
  );

  v_code := 'DEL-' || pg_catalog.upper(
    pg_catalog.substr(pg_catalog.replace(extensions.gen_random_uuid()::text, '-', ''), 1, 12)
  );

  v_cert_sha256 := pg_catalog.encode(
    extensions.digest(
      v_org_id::text || ':' || v_patient_ref || ':' || v_code || ':' || v_summary::text || ':' || v_now::text,
      'sha256'
    ),
    'hex'
  );

  insert into public.patient_deletion_confirmations (
    org_id,
    patient_ref,
    deleted_by,
    deleted_at,
    confirmation_code,
    certificate_sha256,
    summary
  )
  values (
    v_org_id,
    v_patient_ref,
    auth.uid(),
    v_now,
    v_code,
    v_cert_sha256,
    v_summary
  )
  returning * into v_row;

  perform public._audit_log_insert(
    'patient_deletion_confirmed',
    auth.uid(),
    null,
    v_org_id,
    pg_catalog.jsonb_build_object(
      'confirmation_id', v_row.id,
      'confirmation_code', v_row.confirmation_code,
      'patient_ref', v_row.patient_ref,
      'certificate_sha256', v_row.certificate_sha256,
      'summary', v_row.summary
    )
  );

  return pg_catalog.to_jsonb(v_row);
end;
$$;

revoke all on function public.confirm_patient_data_deletion(uuid) from public, anon;
grant execute on function public.confirm_patient_data_deletion(uuid) to authenticated, service_role;

-- ===========================================================================
-- 4. OPS-03: 72-Hour Security Incident Notification Workflow (Clause 8.8)
-- ===========================================================================

create table public.security_incidents (
  id uuid primary key default extensions.gen_random_uuid(),
  org_id uuid not null references public.organizations (id) on delete cascade,
  severity text not null check (severity in ('P1', 'P2', 'P3')),
  title text not null check (pg_catalog.char_length(title) between 3 and 200),
  summary text not null check (pg_catalog.char_length(summary) between 10 and 2000),
  confirmed_at timestamptz not null default pg_catalog.now(),
  notify_deadline_at timestamptz not null,
  notified_at timestamptz,
  status text not null default 'confirmed' check (status in ('confirmed', 'notified', 'resolved')),
  created_by uuid not null
);

create index security_incidents_org_id_idx
  on public.security_incidents (org_id, confirmed_at desc);

alter table public.security_incidents enable row level security;
alter table public.security_incidents force row level security;

revoke all on public.security_incidents from anon;
revoke insert, update, delete on public.security_incidents from authenticated;

create policy security_incidents_admin_select on public.security_incidents
  for select
  to authenticated
  using (
    org_id = public.current_org_id()
    and public.is_org_admin()
    and public.has_aal2()
  );

create or replace function public.report_security_incident(
  p_severity text,
  p_title text,
  p_summary text,
  p_notify_now boolean default true
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_org_id uuid;
  v_now timestamptz := pg_catalog.now();
  v_deadline timestamptz;
  v_notified_at timestamptz;
  v_status text;
  v_clean_title text;
  v_clean_summary text;
  v_row public.security_incidents;
  v_within_sla boolean;
begin
  v_org_id := public.current_org_id();
  if v_org_id is null or not public.is_org_admin() or not public.has_aal2() then
    raise exception 'not_authorized' using errcode = '42501';
  end if;

  v_clean_title := pg_catalog.btrim(coalesce(p_title, ''));
  v_clean_summary := pg_catalog.btrim(coalesce(p_summary, ''));

  if p_severity is null or p_severity not in ('P1', 'P2', 'P3')
     or pg_catalog.char_length(v_clean_title) < 3
     or pg_catalog.char_length(v_clean_title) > 200
     or pg_catalog.char_length(v_clean_summary) < 10
     or pg_catalog.char_length(v_clean_summary) > 2000
  then
    raise exception 'invalid_security_incident_input' using errcode = '22023';
  end if;

  v_deadline := v_now + interval '72 hours';
  if coalesce(p_notify_now, true) then
    v_notified_at := v_now;
    v_status := 'notified';
  else
    v_notified_at := null;
    v_status := 'confirmed';
  end if;

  insert into public.security_incidents (
    org_id,
    severity,
    title,
    summary,
    confirmed_at,
    notify_deadline_at,
    notified_at,
    status,
    created_by
  )
  values (
    v_org_id,
    p_severity,
    v_clean_title,
    v_clean_summary,
    v_now,
    v_deadline,
    v_notified_at,
    v_status,
    auth.uid()
  )
  returning * into v_row;

  v_within_sla := (v_row.notified_at is not null and v_row.notified_at <= v_row.notify_deadline_at);

  if coalesce(p_notify_now, true) then
    insert into public.notification_outbox (user_id, org_id, type, payload)
    values (
      auth.uid(),
      v_org_id,
      'security_incident_72h_notice',
      pg_catalog.jsonb_build_object(
        'event_type', 'security_incident_72h_notice',
        'incident_id', v_row.id,
        'org_id', v_org_id,
        'severity', v_row.severity,
        'title', v_row.title,
        'confirmed_at', v_row.confirmed_at,
        'notify_deadline_at', v_row.notify_deadline_at,
        'notified_at', v_row.notified_at,
        'within_72h_sla', v_within_sla,
        'clause', '8.8'
      )
    );
  end if;

  perform public._audit_log_insert(
    'security_incident_reported',
    auth.uid(),
    null,
    v_org_id,
    pg_catalog.jsonb_build_object(
      'incident_id', v_row.id,
      'severity', v_row.severity,
      'status', v_row.status,
      'notify_deadline_at', v_row.notify_deadline_at,
      'notified_at', v_row.notified_at,
      'within_72h_sla', v_within_sla
    )
  );

  return pg_catalog.to_jsonb(v_row) || pg_catalog.jsonb_build_object('within_72h_sla', v_within_sla);
end;
$$;

revoke all on function public.report_security_incident(text, text, text, boolean) from public, anon;
grant execute on function public.report_security_incident(text, text, text, boolean) to authenticated, service_role;
