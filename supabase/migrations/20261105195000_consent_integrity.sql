-- Consent integrity (PR #41 review).
--
-- Timestamps on consents are server-owned for every role. A client cannot
-- backdate a grant, including by inserting an inactive row and then setting
-- granted_at. A revoked row cannot be cleared back to active; granting again
-- inserts a new row. Withdrawal always succeeds, including a grant that was
-- stored in the future before this rule existed.
--
-- Placeholder consent documents do not unlock health data. Patient reads and
-- writes of lab reports, results and report files require the current
-- health_data document to be a non-placeholder version the patient has granted.
-- Staff policies are unchanged.
--
-- Date of birth is checked on every profile write. Existing nulls are left
-- null. Login-code reissue keeps the in-progress attempt count.

create or replace function public._consents_versioning()
returns trigger
language plpgsql
set search_path = pg_catalog, public
as $$
declare
  v_client_granted_at timestamptz;
  v_client_revoked_at timestamptz;
  v_versioned boolean;
begin
  v_versioned := new.consent_type in ('terms', 'privacy', 'health_data', 'partner_disclosure');

  if tg_op = 'INSERT' then
    new.document := coalesce(new.document, new.consent_type);
    if new.granted or new.granted_at is not null then
      new.granted_at := now();
    else
      new.granted_at := null;
    end if;
    new.revoked_at := null;
    new.granted := new.granted_at is not null and new.revoked_at is null;
    return new;
  end if;

  if new.consent_type is distinct from old.consent_type
     or new.document is distinct from old.document
     or new.version is distinct from old.version then
    raise exception 'consent document and version are immutable; insert a new row'
      using errcode = '42501';
  end if;

  v_client_granted_at := new.granted_at;
  v_client_revoked_at := new.revoked_at;
  new.granted_at := old.granted_at;
  new.revoked_at := old.revoked_at;

  if v_client_revoked_at is null and old.revoked_at is not null then
    raise exception 'a revoked consent cannot be restored; grant it again'
      using errcode = '42501';
  end if;
  if new.granted is true and old.granted is false and old.revoked_at is not null then
    raise exception 'a revoked consent cannot be restored; grant it again'
      using errcode = '42501';
  end if;

  if v_versioned and old.granted_at is null and v_client_granted_at is distinct from old.granted_at then
    raise exception 'granted_at is server-owned' using errcode = '42501';
  end if;
  if v_versioned and old.granted_at is null and new.granted is true and old.granted is false then
    raise exception 'grant by inserting a new row' using errcode = '42501';
  end if;

  if (new.granted is false and old.granted is true)
     or (v_client_revoked_at is not null and old.revoked_at is null) then
    if new.granted_at is null then
      new.granted_at := now();
    end if;
    new.revoked_at := greatest(now(), new.granted_at);
  elsif old.granted_at is null and old.revoked_at is null
        and new.granted is true and old.granted is false then
    new.granted_at := now();
  end if;

  new.granted := new.granted_at is not null and new.revoked_at is null;
  new.updated_at := now();
  return new;
end;
$$;

revoke all on function public._consents_versioning() from public, anon, authenticated;

create or replace function public.patient_onboarding_status()
returns jsonb
language plpgsql
stable
security definer
set search_path = pg_catalog, public
as $$
declare
  v_uid uuid := auth.uid();
  v_linked boolean;
  v_ready boolean;
begin
  if v_uid is null then
    raise exception 'not authorized' using errcode = '42501';
  end if;

  v_linked := public.current_email_confirmed()
    and public.current_patient_linked()
    and exists (select 1 from public.patients p where p.id = v_uid);

  if not v_linked then
    return jsonb_build_object(
      'linked', false,
      'missing_consents', '[]'::jsonb,
      'profile_complete', false,
      'documents_ready', false
    );
  end if;

  select coalesce(bool_and(not d.is_placeholder), false) into v_ready
    from public.current_consent_documents d
   where d.required;

  return jsonb_build_object(
    'linked', true,
    'documents_ready', v_ready,
    'missing_consents', coalesce((
      select jsonb_agg(jsonb_build_object(
          'consent_type', d.consent_type,
          'version', d.version,
          'document', d.document,
          'title', d.title,
          'summary', d.summary,
          'body', d.body,
          'is_placeholder', d.is_placeholder
        ) order by array_position(array['terms', 'privacy', 'health_data'], d.consent_type))
      from public.current_consent_documents d
      where d.required
        and not exists (
          select 1 from public.consents c
          where c.patient_id = v_uid
            and c.consent_type = d.consent_type
            and c.version = d.version
            and c.granted_at is not null
            and c.revoked_at is null
        )
    ), '[]'::jsonb),
    'profile_complete', public._patient_profile_complete(v_uid)
  );
end;
$$;

-- Placeholder wording is not something the app can collect as the gate.
-- The patient still reads it from consent_documents. documents_ready stays
-- false until every required current document is a real (non-placeholder)
-- version. missing_consents lists only those real documents.

create or replace function public.grant_patient_consents(p_items jsonb)
returns int
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
declare
  v_uid uuid := auth.uid();
  v_org_id uuid;
  v_item jsonb;
  v_type text;
  v_version text;
  v_doc public.consent_documents%rowtype;
  v_count int := 0;
begin
  if v_uid is null
     or not public.current_email_confirmed()
     or not public.current_patient_linked() then
    raise exception 'not authorized' using errcode = '42501';
  end if;

  select p.org_id into v_org_id from public.patients p where p.id = v_uid;
  if v_org_id is null then
    raise exception 'not authorized' using errcode = '42501';
  end if;

  if jsonb_typeof(p_items) <> 'array' or jsonb_array_length(p_items) not between 1 and 10 then
    raise exception 'invalid consent list' using errcode = '22023';
  end if;

  for v_item in select * from jsonb_array_elements(p_items) loop
    v_type := v_item ->> 'consent_type';
    v_version := v_item ->> 'version';
    if v_type not in ('terms', 'privacy', 'health_data', 'partner_disclosure')
       or v_version is null
       or v_version !~ '^[0-9A-Za-z._-]{1,32}$' then
      raise exception 'unknown consent type' using errcode = '22023';
    end if;

    select * into v_doc from public.current_consent_documents d where d.consent_type = v_type;
    if not found then
      raise exception 'unknown consent type' using errcode = '22023';
    end if;
    if v_version is distinct from v_doc.version then
      raise exception 'consent_version_stale' using errcode = '22023';
    end if;

    if not exists (
      select 1 from public.consents c
      where c.patient_id = v_uid
        and c.consent_type = v_type
        and c.version = v_doc.version
        and c.granted_at is not null
        and c.revoked_at is null
    ) then
      insert into public.consents (org_id, patient_id, consent_type, document, version, granted, granted_at)
        values (v_org_id, v_uid, v_type, v_doc.document, v_doc.version, true, now());
      v_count := v_count + 1;
    end if;
  end loop;

  return v_count;
end;
$$;

-- Health data access. False while the current health_data document is missing
-- or still a placeholder, and false after withdrawal.
create function public.patient_health_data_access_granted(p_patient_id uuid)
returns boolean
language sql
stable
security definer
set search_path = pg_catalog, public
as $$
  select exists (
    select 1
      from public.current_consent_documents d
      join public.consents c
        on c.consent_type = d.consent_type
       and c.version = d.version
       and c.patient_id = p_patient_id
       and c.granted_at is not null
       and c.revoked_at is null
     where d.consent_type = 'health_data'
       and d.is_placeholder = false
  );
$$;

revoke all on function public.patient_health_data_access_granted(uuid) from public, anon, authenticated;
grant execute on function public.patient_health_data_access_granted(uuid) to authenticated;

drop policy if exists lab_reports_self_select on public.lab_reports;
create policy lab_reports_self_select on public.lab_reports
  for select to authenticated
  using (
    patient_id = (select auth.uid())
    and identity_hold = false
    and public.current_email_confirmed()
    and public.current_patient_linked()
    and public.patient_health_data_access_granted((select auth.uid()))
  );

drop policy if exists lab_reports_self_insert on public.lab_reports;
create policy lab_reports_self_insert on public.lab_reports
  for insert to authenticated
  with check (
    patient_id = (select auth.uid())
    and public.current_email_confirmed()
    and public.current_patient_linked()
    and org_id = (select org_id from public.patients where id = (select auth.uid()))
    and public.patient_health_data_access_granted((select auth.uid()))
  );

drop policy if exists lab_results_self_select on public.lab_results;
create policy lab_results_self_select on public.lab_results
  for select to authenticated
  using (
    patient_id = (select auth.uid())
    and public.own_lab_report_released(lab_report_id)
    and public.patient_health_data_access_granted((select auth.uid()))
  );

drop policy if exists lab_reports_objects_self_select on storage.objects;
create policy lab_reports_objects_self_select on storage.objects
  for select to authenticated
  using (
    bucket_id = 'lab-reports'
    and split_part(objects.name, '/', 1) = (select auth.uid())::text
    and public.current_email_confirmed()
    and public.current_patient_linked()
    and public.own_lab_file_released(objects.name)
    and public.patient_health_data_access_granted((select auth.uid()))
  );

drop policy if exists lab_reports_objects_self_insert on storage.objects;
create policy lab_reports_objects_self_insert on storage.objects
  for insert to authenticated
  with check (
    bucket_id = 'lab-reports'
    and name ~ ('^' || (select auth.uid())::text
                || '/[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\.(pdf|jpg|jpeg|png|heic|webp)$')
    and public.current_email_confirmed()
    and public.current_patient_linked()
    and public.patient_health_data_access_granted((select auth.uid()))
  );

create or replace function public._patient_profile_dob_guard()
returns trigger
language plpgsql
set search_path = pg_catalog, public
as $$
begin
  if tg_op = 'UPDATE' and new.date_of_birth is not distinct from old.date_of_birth then
    return new;
  end if;
  if new.date_of_birth is null then
    return new;
  end if;
  if new.date_of_birth < date '1900-01-01'
     or new.date_of_birth > (current_date - interval '18 years')::date then
    raise exception 'invalid_date_of_birth' using errcode = '22023';
  end if;
  return new;
end;
$$;

drop trigger if exists patient_profiles_dob_guard on public.patient_profiles;
create trigger patient_profiles_dob_guard
  before insert or update on public.patient_profiles
  for each row execute function public._patient_profile_dob_guard();

revoke all on function public._patient_profile_dob_guard() from public, anon, authenticated;

create or replace function public.issue_patient_login_code(
  p_email text,
  p_code text,
  p_ttl_seconds int default 600
)
returns uuid
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
declare
  v_user_id uuid;
  v_hash text;
begin
  if p_code !~ '^[0-9]{6}$' then
    raise exception 'code must be 6 digits' using errcode = '22023';
  end if;

  v_hash := public._patient_email_hash(p_email);

  select u.id into v_user_id
    from auth.users u
    where lower(u.email) = lower(btrim(p_email))
    limit 1;

  if not public._patient_code_signin_eligible(v_user_id) then
    v_user_id := null;
  end if;

  insert into public.patient_login_codes (email_hash, user_id, code_hash, expires_at)
    values (
      v_hash,
      v_user_id,
      extensions.crypt(p_code, extensions.gen_salt('bf', 8)),
      now() + make_interval(secs => p_ttl_seconds)
    )
  on conflict (email_hash) do update
    set user_id = excluded.user_id,
        code_hash = case
          when public.patient_login_codes.locked_until > now() then public.patient_login_codes.code_hash
          else excluded.code_hash
        end,
        expires_at = case
          when public.patient_login_codes.locked_until > now() then public.patient_login_codes.expires_at
          else excluded.expires_at
        end,
        attempts = case
          when public.patient_login_codes.locked_until is not null
           and public.patient_login_codes.locked_until <= now() then 0
          else public.patient_login_codes.attempts
        end,
        used_at = case
          when public.patient_login_codes.locked_until > now() then public.patient_login_codes.used_at
          else null
        end,
        locked_until = case
          when public.patient_login_codes.locked_until > now() then public.patient_login_codes.locked_until
          else null
        end,
        created_at = case
          when public.patient_login_codes.locked_until > now() then public.patient_login_codes.created_at
          else now()
        end;

  return v_user_id;
end;
$$;

revoke all on function public.issue_patient_login_code(text, text, int) from public, anon, authenticated;
grant execute on function public.issue_patient_login_code(text, text, int) to service_role;
