-- DELIVERY-NOV9-C2. Outcomes release blockers on the integrated branch.
--
-- A delivered row stays delivered: cycling the state does not reopen the
-- payload. Partnership disclosure is the latest partner_disclosure consent
-- only. data_sharing does not substitute. The APP-03 authorisation table is
-- not created here; it arrives with bold-cerf and must be reconciled then.
-- Binding an unmatched scan requires the MRN and the partner patient id.
-- anon and authenticated cannot TRUNCATE the outcomes tables.

alter table public.outcome_records
  add column if not exists delivered_at timestamptz;

update public.outcome_records
  set delivered_at = coalesce(updated_at, now())
  where state = 'delivered' and delivered_at is null;

create or replace function public.enforce_delivered_outcome_immutability()
returns trigger
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
begin
  if old.state = 'delivered' or old.delivered_at is not null then
    if new.state not in ('delivered', 'withdrawn')
       or new.payload is distinct from old.payload
       or new.clinician_summary is distinct from old.clinician_summary
       or new.record_version is distinct from old.record_version
       or new.milestone is distinct from old.milestone
       or new.patient_id is distinct from old.patient_id
       or new.org_id is distinct from old.org_id
       or new.record_id is distinct from old.record_id
       or new.lean_mass_flag is distinct from old.lean_mass_flag
       or new.clinical_context_flag is distinct from old.clinical_context_flag
       or new.delivered_at is distinct from old.delivered_at
    then
      raise exception 'delivered outcome records are immutable; insert record_version + 1 to issue a correction'
        using errcode = 'P0001';
    end if;
    return new;
  end if;

  if new.state = 'delivered' then
    if new.payload is distinct from old.payload
       or new.clinician_summary is distinct from old.clinician_summary
       or new.record_version is distinct from old.record_version
       or new.milestone is distinct from old.milestone
       or new.patient_id is distinct from old.patient_id
       or new.org_id is distinct from old.org_id
       or new.record_id is distinct from old.record_id
       or new.lean_mass_flag is distinct from old.lean_mass_flag
       or new.clinical_context_flag is distinct from old.clinical_context_flag
    then
      raise exception 'delivered outcome records are immutable; insert record_version + 1 to issue a correction'
        using errcode = 'P0001';
    end if;
    new.delivered_at := now();
  end if;
  return new;
end;
$$;

revoke all on function public.enforce_delivered_outcome_immutability() from public, anon, authenticated;

revoke truncate on public.body_composition_scans from public, anon, authenticated;
revoke truncate on public.outcome_records from public, anon, authenticated;

-- Latest partner_disclosure row only. A historical grant, and any
-- data_sharing row, do not authorise partnership disclosure.
create function public.partner_disclosure_currently_granted(p_patient_id uuid, p_org_id uuid)
returns boolean
language sql
stable
security definer
set search_path = pg_catalog, public
as $$
  select coalesce((
    select c.granted and c.revoked_at is null
    from public.consents c
    where c.patient_id = p_patient_id
      and c.org_id = p_org_id
      and c.consent_type = 'partner_disclosure'
    order by c.granted_at desc nulls last, c.created_at desc
    limit 1
  ), false);
$$;

revoke all on function public.partner_disclosure_currently_granted(uuid, uuid) from public, anon, authenticated;
grant execute on function public.partner_disclosure_currently_granted(uuid, uuid) to current_user;

create or replace function public.list_outcomes_review_queue()
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
      public.partner_disclosure_currently_granted(o.patient_id, o.org_id) as has_partner_disclosure_consent,
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

create or replace function public.review_outcome_record(
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
begin
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

  if v_rec.state = 'delivered' or v_rec.delivered_at is not null then
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

    if not public.partner_disclosure_currently_granted(v_rec.patient_id, v_org_id) then
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

drop function public.bind_unmatched_partner_scan(uuid, uuid);

create function public.bind_unmatched_partner_scan(
  p_scan_id uuid,
  p_patient_id uuid,
  p_confirm_mrn text,
  p_confirm_partner_patient_id text
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

  if nullif(btrim(coalesce(p_confirm_mrn, '')), '') is null
     or btrim(coalesce(v_patient.mrn, '')) is distinct from btrim(p_confirm_mrn) then
    raise exception 'patient identity does not match the confirmed MRN' using errcode = 'P0001';
  end if;

  if nullif(btrim(coalesce(p_confirm_partner_patient_id, '')), '') is null
     or btrim(coalesce(v_scan.partner_patient_id, '')) is distinct from btrim(p_confirm_partner_patient_id) then
    raise exception 'partner patient id does not match this scan' using errcode = 'P0001';
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
      'partner_patient_id', v_scan.partner_patient_id,
      'confirmed_mrn', true
    )
  );

  return jsonb_build_object(
    'scan_id', p_scan_id,
    'patient_id', p_patient_id,
    'binding_status', 'bound'
  );
end;
$$;

revoke all on function public.bind_unmatched_partner_scan(uuid, uuid, text, text) from public, anon;
grant execute on function public.bind_unmatched_partner_scan(uuid, uuid, text, text) to authenticated;

create function public.reject_unmatched_partner_scan(p_scan_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
declare
  v_org_id uuid;
  v_scan public.body_composition_scans;
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

  update public.body_composition_scans
    set patient_id = null,
        binding_status = 'rejected'
    where id = p_scan_id;

  perform public._audit_log_insert(
    'partner_scan_rejected',
    auth.uid(),
    null,
    v_org_id,
    jsonb_build_object(
      'scan_id', p_scan_id,
      'partner_scan_id', v_scan.partner_scan_id,
      'partner_patient_id', v_scan.partner_patient_id
    )
  );

  return jsonb_build_object(
    'scan_id', p_scan_id,
    'patient_id', null,
    'binding_status', 'rejected'
  );
end;
$$;

revoke all on function public.reject_unmatched_partner_scan(uuid) from public, anon;
grant execute on function public.reject_unmatched_partner_scan(uuid) to authenticated;

create function public.record_partner_scan_autobind(
  p_org_id uuid,
  p_patient_id uuid,
  p_partner_scan_id text,
  p_partner_patient_id text
)
returns void
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
begin
  perform public._audit_log_insert(
    'partner_scan_autobound',
    null,
    p_patient_id,
    p_org_id,
    jsonb_build_object(
      'partner_scan_id', p_partner_scan_id,
      'partner_patient_id', p_partner_patient_id
    )
  );
end;
$$;

revoke all on function public.record_partner_scan_autobind(uuid, uuid, text, text) from public, anon, authenticated;
grant execute on function public.record_partner_scan_autobind(uuid, uuid, text, text) to service_role;
