-- Clara L22: _bind_patient_record's `insert ... on conflict (id) do nothing`
-- silently kept a stale patients.org_id when re-linking to a different
-- clinic after unlink (unlink revokes the link but keeps the patients row).
-- Per docs/RECORD_MATCHING.md, cross-clinic re-bind is refused outright
-- rather than silently keeping or rewriting org tenancy; same-org re-link
-- after unlink is unaffected.

create or replace function public._bind_patient_record(
  p_app_user_id uuid,
  p_org_id uuid,
  p_telehealth_patient_id text,
  p_proof_method text
)
returns void
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
declare
  v_existing_org uuid;
begin
  if exists (select 1 from public.org_members where user_id = p_app_user_id) then
    raise exception 'cannot bind a patient record to a staff account' using errcode = '42501';
  end if;

  if exists (select 1 from public.platform_admins where user_id = p_app_user_id) then
    raise exception 'cannot bind a patient record to a platform admin account'
      using errcode = '42501';
  end if;

  if exists (
    select 1 from public.patient_record_links
    where app_user_id = p_app_user_id and status = 'active'
  ) then
    raise exception 'already linked' using errcode = '23505';
  end if;

  if exists (
    select 1 from public.patient_record_links
    where telehealth_patient_id = p_telehealth_patient_id and status = 'active'
  ) then
    raise exception 'record already linked' using errcode = '23505';
  end if;

  select org_id into v_existing_org from public.patients where id = p_app_user_id;

  -- L22: refuse rather than silently keep/rewrite tenancy across clinics.
  -- Distinct errcode (not 42501) so redeem paths can tell this apart from
  -- the staff/platform-admin refusals above, which must keep propagating
  -- as real exceptions (H-M3).
  if v_existing_org is not null and v_existing_org <> p_org_id then
    raise exception 'patient record belongs to another clinic' using errcode = 'P0003';
  end if;

  insert into public.patients (id, org_id)
  values (p_app_user_id, p_org_id)
  on conflict (id) do nothing;

  insert into public.patient_record_links (
    app_user_id, org_id, telehealth_patient_id, status, linked_at, proof_method
  ) values (
    p_app_user_id, p_org_id, p_telehealth_patient_id, 'active', now(), p_proof_method
  );

  perform public._enqueue_link_notices(
    p_app_user_id, p_org_id, p_telehealth_patient_id, 'linked'
  );

  perform public._audit_log_insert(
    'patient_record_linked',
    p_app_user_id,
    p_app_user_id,
    p_org_id,
    jsonb_build_object(
      'telehealth_patient_id', p_telehealth_patient_id,
      'proof_method', p_proof_method
    )
  );
end;
$$;

comment on function public._bind_patient_record(uuid, uuid, text, text) is
  'Binds app_user_id to a telehealth record. Refuses cross-clinic re-bind when '
  'an existing patients.org_id differs from the target org (Clara L22) — '
  'same-org re-link after unlink is unaffected.';

-- Both redeem paths must translate the new P0003 "another clinic" refusal
-- into the same enumeration-safe shape as a wrong code (never a raw
-- exception to the client).

create or replace function public.redeem_telehealth_link_code(p_code text)
returns jsonb
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
declare
  v_uid uuid := auth.uid();
  v_mac text;
  v_row public.patient_link_codes%rowtype;
begin
  if v_uid is null then
    raise exception 'not authenticated' using errcode = '42501';
  end if;

  if public._patient_link_locked(v_uid) then
    return jsonb_build_object('ok', false, 'error', 'locked');
  end if;

  v_mac := public.link_code_mac(p_code);

  -- Scoped lookup ONLY (PSU-TO-13): never global by code digits.
  select * into v_row
  from public.patient_link_codes c
  where c.issued_to_app_user_id = v_uid
    and c.method = 'telehealth_otp'
    and c.used_at is null
    and c.killed_at is null
    and c.superseded_at is null
    and c.expires_at > now()
    and c.code_mac = v_mac
  for update;

  if not found then
    -- Wrong try against any open OTP for this user (if present).
    update public.patient_link_codes
      set wrong_try_count = wrong_try_count + 1,
          killed_at = case when wrong_try_count + 1 >= 5 then now() else killed_at end
      where issued_to_app_user_id = v_uid
        and method = 'telehealth_otp'
        and used_at is null
        and killed_at is null
        and superseded_at is null
        and expires_at > now();

    perform public._patient_link_register_wrong(v_uid);
    perform public._audit_log_insert(
      'patient_link_otp_rejected',
      v_uid, v_uid, null,
      jsonb_build_object('reason', 'mismatch_or_absent')
    );
    return jsonb_build_object('ok', false, 'error', 'invalid_code');
  end if;

  begin
    perform public._bind_patient_record(
      v_uid, v_row.org_id, v_row.telehealth_patient_id, 'telehealth_otp'
    );
  exception
    when unique_violation then
      perform public._audit_log_insert(
        'patient_link_otp_conflict',
        v_uid, v_uid, null,
        jsonb_build_object('reason', 'unique_violation')
      );
      return jsonb_build_object('ok', false, 'error', 'conflict');
    when others then
      if sqlstate = 'P0003' then
        perform public._audit_log_insert(
          'patient_link_otp_rejected',
          v_uid, v_uid, null,
          jsonb_build_object('reason', 'org_mismatch')
        );
        return jsonb_build_object('ok', false, 'error', 'invalid_code');
      end if;
      raise;
  end;

  update public.patient_link_codes
    set used_at = now()
    where id = v_row.id;
  perform public._patient_link_clear_attempts(v_uid);

  return jsonb_build_object(
    'ok', true,
    'telehealth_patient_id', v_row.telehealth_patient_id,
    'org_id', v_row.org_id
  );
end;
$$;

create or replace function public.redeem_clinic_link_code(p_code text)
returns jsonb
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
declare
  v_uid uuid := auth.uid();
  v_mac text;
  v_row public.patient_link_codes%rowtype;
begin
  if v_uid is null then
    raise exception 'not authenticated' using errcode = '42501';
  end if;

  if public._patient_link_locked(v_uid) then
    return jsonb_build_object('ok', false, 'error', 'locked');
  end if;

  if public._clinic_code_breaker_tripped() then
    return jsonb_build_object('ok', false, 'error', 'unavailable');
  end if;

  -- Clinic redeem never takes email/name/DOB (PSU-TO-01..03, TO-11).
  v_mac := public.link_code_mac(p_code);

  select * into v_row
  from public.patient_link_codes c
  where c.method = 'clinic_code'
    and c.code_mac = v_mac
    and c.used_at is null
    and c.killed_at is null
    and c.expires_at > now()
  for update;

  if not found then
    perform public._clinic_code_breaker_bump();
    perform public._patient_link_register_wrong(v_uid);
    perform public._audit_log_insert(
      'patient_clinic_code_rejected',
      v_uid, v_uid, null,
      jsonb_build_object('reason', 'mismatch')
    );
    return jsonb_build_object('ok', false, 'error', 'invalid_code');
  end if;

  begin
    perform public._bind_patient_record(
      v_uid, v_row.org_id, v_row.telehealth_patient_id, 'clinic_code'
    );
  exception
    when unique_violation then
      perform public.enqueue_patient_link_review(
        v_uid, v_row.org_id, 'duplicate_claim',
        jsonb_build_object('telehealth_patient_id', v_row.telehealth_patient_id)
      );
      return jsonb_build_object('ok', false, 'error', 'conflict');
    when others then
      if sqlstate = 'P0003' then
        perform public._audit_log_insert(
          'patient_clinic_code_rejected',
          v_uid, v_uid, null,
          jsonb_build_object('reason', 'org_mismatch')
        );
        return jsonb_build_object('ok', false, 'error', 'invalid_code');
      end if;
      raise;
  end;

  update public.patient_link_codes set used_at = now() where id = v_row.id;
  perform public._patient_link_clear_attempts(v_uid);
  return jsonb_build_object(
    'ok', true,
    'telehealth_patient_id', v_row.telehealth_patient_id,
    'org_id', v_row.org_id
  );
end;
$$;
