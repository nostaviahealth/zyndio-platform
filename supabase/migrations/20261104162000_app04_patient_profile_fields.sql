-- APP-04: the patient profile the clinical side needs - name, date of birth,
-- sex at birth (drives lab reference ranges), height (drives BMI) and the
-- patient's unit preference. Collected in onboarding, editable in Settings.
--
-- Name stays on patients.display_name (what staff see on the roster). The
-- rest are typed columns on patient_profiles rather than keys in its `data`
-- jsonb, so reference-range and BMI code can rely on their type and range.
-- Height is always stored in centimetres; unit_system only changes display.
--
-- Writes go through update_patient_profile() so the age rule (18+, the
-- program is adult-only) and the org pinning live in one place. The existing
-- patient_profiles RLS (self select/update, staff in own clinic) is
-- unchanged, so staff see the new columns wherever they already see the row.

alter table public.patient_profiles
  add column if not exists date_of_birth date,
  add column if not exists sex_at_birth text,
  add column if not exists height_cm numeric(5, 1),
  add column if not exists unit_system text;

alter table public.patient_profiles
  add constraint patient_profiles_sex_at_birth_check
    check (sex_at_birth is null or sex_at_birth in ('female', 'male', 'intersex')),
  add constraint patient_profiles_height_cm_check
    check (height_cm is null or height_cm between 50 and 272),
  add constraint patient_profiles_unit_system_check
    check (unit_system is null or unit_system in ('imperial', 'metric')),
  add constraint patient_profiles_date_of_birth_check
    check (date_of_birth is null or date_of_birth >= date '1900-01-01');

-- Latest profile row for a patient. patient_id isn't unique on this table
-- (fixtures and staff tools may have created more than one), so every
-- reader/writer here agrees on "most recently updated".
create or replace function public._latest_patient_profile_id(p_patient_id uuid)
returns uuid
language sql
stable
security definer
set search_path = pg_catalog, public
as $$
  select pp.id
  from public.patient_profiles pp
  where pp.patient_id = p_patient_id
  order by pp.updated_at desc, pp.created_at desc
  limit 1;
$$;

revoke all on function public._latest_patient_profile_id(uuid) from public, anon, authenticated;

create or replace function public._patient_profile_json(p_patient_id uuid)
returns jsonb
language sql
stable
security definer
set search_path = pg_catalog, public
as $$
  select jsonb_build_object(
    'display_name', p.display_name,
    'date_of_birth', pp.date_of_birth,
    'sex_at_birth', pp.sex_at_birth,
    'height_cm', pp.height_cm,
    'unit_system', pp.unit_system
  )
  from public.patients p
  left join public.patient_profiles pp
    on pp.id = public._latest_patient_profile_id(p.id)
  where p.id = p_patient_id;
$$;

revoke all on function public._patient_profile_json(uuid) from public, anon, authenticated;

create or replace function public._patient_profile_complete(p_patient_id uuid)
returns boolean
language sql
stable
security definer
set search_path = pg_catalog, public
as $$
  select coalesce((
    select nullif(btrim(coalesce(j ->> 'display_name', '')), '') is not null
       and j ->> 'date_of_birth' is not null
       and j ->> 'sex_at_birth' is not null
       and j ->> 'height_cm' is not null
       and j ->> 'unit_system' is not null
    from (select public._patient_profile_json(p_patient_id) as j) s
  ), false);
$$;

revoke all on function public._patient_profile_complete(uuid) from public, anon, authenticated;

create or replace function public.my_patient_profile()
returns jsonb
language plpgsql
stable
security definer
set search_path = pg_catalog, public
as $$
begin
  if auth.uid() is null
     or not public.current_email_confirmed()
     or not public.current_patient_linked() then
    raise exception 'not authorized' using errcode = '42501';
  end if;
  return public._patient_profile_json(auth.uid());
end;
$$;

revoke all on function public.my_patient_profile() from public, anon, authenticated;
grant execute on function public.my_patient_profile() to authenticated;

create or replace function public.update_patient_profile(
  p_display_name text,
  p_date_of_birth date,
  p_sex_at_birth text,
  p_height_cm numeric,
  p_unit_system text
)
returns jsonb
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
declare
  v_uid uuid := auth.uid();
  v_org_id uuid;
  v_name text := nullif(btrim(coalesce(p_display_name, '')), '');
  v_profile_id uuid;
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

  if v_name is null or char_length(v_name) > 80 then
    raise exception 'invalid_display_name' using errcode = '22023';
  end if;
  if p_date_of_birth is null
     or p_date_of_birth < date '1900-01-01'
     or p_date_of_birth > (current_date - interval '18 years')::date then
    raise exception 'invalid_date_of_birth' using errcode = '22023';
  end if;
  if p_sex_at_birth is null or p_sex_at_birth not in ('female', 'male', 'intersex') then
    raise exception 'invalid_sex_at_birth' using errcode = '22023';
  end if;
  if p_height_cm is null or p_height_cm < 50 or p_height_cm > 272 then
    raise exception 'invalid_height' using errcode = '22023';
  end if;
  if p_unit_system is null or p_unit_system not in ('imperial', 'metric') then
    raise exception 'invalid_unit_system' using errcode = '22023';
  end if;

  update public.patients set display_name = v_name where id = v_uid;

  v_profile_id := public._latest_patient_profile_id(v_uid);
  if v_profile_id is null then
    insert into public.patient_profiles
      (org_id, patient_id, date_of_birth, sex_at_birth, height_cm, unit_system)
      values (v_org_id, v_uid, p_date_of_birth, p_sex_at_birth, round(p_height_cm, 1), p_unit_system);
  else
    update public.patient_profiles
      set date_of_birth = p_date_of_birth,
          sex_at_birth = p_sex_at_birth,
          height_cm = round(p_height_cm, 1),
          unit_system = p_unit_system,
          updated_at = now()
      where id = v_profile_id;
  end if;

  return public._patient_profile_json(v_uid);
end;
$$;

revoke all on function public.update_patient_profile(text, date, text, numeric, text) from public, anon, authenticated;
grant execute on function public.update_patient_profile(text, date, text, numeric, text) to authenticated;

-- ---------------------------------------------------------------------------
-- Onboarding gate (APP-02 + APP-04): one call the app makes after sign-in.
--   linked            - false for an unlinked self-signup account (no
--                       patients row yet): the app sends it to link-record.
--   missing_consents  - required current documents the patient hasn't
--                       actively granted at that version, with their text.
--   profile_complete  - name, DOB, sex at birth, height, units all set.
-- ---------------------------------------------------------------------------

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
      'profile_complete', false
    );
  end if;

  return jsonb_build_object(
    'linked', true,
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

revoke all on function public.patient_onboarding_status() from public, anon, authenticated;
grant execute on function public.patient_onboarding_status() to authenticated;
