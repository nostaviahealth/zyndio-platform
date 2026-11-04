-- APP-02: Zyndio terms, privacy notice and health-data consent are stored
-- as consents rows with document, version, granted_at and revoked_at, and
-- the app is gated on onboarding until the required ones are given.
--
-- Shape (kept as plain rows on purpose: another branch adds an AFTER
-- trigger on consents that sends consent.updated webhooks):
--   * a grant is an INSERT of a new row (granted_at = server clock);
--   * a revoke is an UPDATE that sets revoked_at (one-way for the patient);
--   * granting again, or agreeing to a newer version, inserts a new row.
-- The legacy `granted` boolean stays, kept in sync by the BEFORE trigger
-- below (granted = granted_at is not null and revoked_at is null), so every
-- existing reader/writer of `granted` keeps working: flipping granted to
-- false is recorded as a revoke.
--
-- consent_documents holds the text the patient agreed to, per type and
-- version. The 0.1 rows seeded here are PLACEHOLDER wording, clearly marked
-- as such, until Zyndio supplies the real documents. Publishing a new
-- version is an insert with a later published_at; every patient is then
-- asked again for that type.

-- ---------------------------------------------------------------------------
-- documents
-- ---------------------------------------------------------------------------

create table public.consent_documents (
  consent_type text not null
    check (consent_type in ('terms', 'privacy', 'health_data', 'partner_disclosure')),
  version text not null check (char_length(version) between 1 and 32),
  document text not null check (char_length(document) between 1 and 100),
  title text not null check (char_length(title) between 1 and 200),
  summary text not null default '' check (char_length(summary) <= 500),
  body text not null check (char_length(body) <= 100000),
  required boolean not null,
  is_placeholder boolean not null default false,
  published_at timestamptz not null default now(),
  primary key (consent_type, version)
);

alter table public.consent_documents enable row level security;
alter table public.consent_documents force row level security;
revoke all on public.consent_documents from anon, authenticated;
grant select on public.consent_documents to authenticated;

-- Document text is not patient data: any signed-in user may read it.
create policy consent_documents_read on public.consent_documents
  for select to authenticated
  using (true);

-- The version in force for each type: latest already-published row.
create or replace view public.current_consent_documents
with (security_invoker = true) as
  select distinct on (d.consent_type) d.*
  from public.consent_documents d
  where d.published_at <= now()
  order by d.consent_type, d.published_at desc;

revoke all on public.current_consent_documents from anon, authenticated;
grant select on public.current_consent_documents to authenticated;

insert into public.consent_documents
  (consent_type, version, document, title, summary, body, required, is_placeholder)
values
  ('terms', '0.1', 'zyndio_terms_of_service', 'Terms of Service',
   'Version 0.1 · placeholder text',
   'PLACEHOLDER - NOT THE FINAL TERMS. Zyndio and its counsel will supply the real Terms of Service before launch. '
   'This placeholder exists so the app can record which version a patient agreed to and when.',
   true, true),
  ('privacy', '0.1', 'zyndio_privacy_notice', 'Privacy Notice',
   'Version 0.1 · placeholder text',
   'PLACEHOLDER - NOT THE FINAL PRIVACY NOTICE. Zyndio and its counsel will supply the real Privacy Notice before launch. '
   'This placeholder exists so the app can record which version a patient agreed to and when.',
   true, true),
  ('health_data', '0.1', 'zyndio_health_data_consent', 'Consent to use my health data',
   'Version 0.1 · placeholder text',
   'PLACEHOLDER - NOT THE FINAL CONSENT WORDING. Zyndio and its counsel will supply the real consent to use health data '
   'for your care before launch. This placeholder exists so the app can record which version a patient agreed to and when.',
   true, true),
  ('partner_disclosure', '0.1', 'zyndio_partner_disclosure', 'Share progress with a partner',
   'Version 0.1 · placeholder text · optional',
   'PLACEHOLDER - NOT THE FINAL DISCLOSURE WORDING. Optional consent to share clinician-reviewed progress with a partner. '
   'Zyndio will supply the real text; the app does not ask for this consent yet.',
   false, true);

-- ---------------------------------------------------------------------------
-- consents: new columns + backfill
-- ---------------------------------------------------------------------------

alter table public.consents
  add column if not exists document text,
  add column if not exists version text,
  add column if not exists granted_at timestamptz,
  add column if not exists revoked_at timestamptz;

update public.consents
  set document = coalesce(document, consent_type),
      granted_at = case when granted then coalesce(granted_at, created_at) end,
      revoked_at = case when granted then null else revoked_at end;

alter table public.consents
  add constraint consents_document_length check (document is null or char_length(document) <= 100),
  add constraint consents_version_length check (version is null or char_length(version) <= 32),
  add constraint consents_revoked_after_granted
    check (revoked_at is null or (granted_at is not null and revoked_at >= granted_at)),
  -- Zyndio's own document types must say exactly which version was agreed.
  add constraint consents_zyndio_types_versioned
    check (
      consent_type not in ('terms', 'privacy', 'health_data', 'partner_disclosure')
      or (document is not null and version is not null)
    ),
  -- MATCH SIMPLE: legacy rows with no version aren't checked.
  add constraint consents_document_version_fkey
    foreign key (consent_type, version)
    references public.consent_documents (consent_type, version);

create unique index consents_one_active_grant_per_version
  on public.consents (patient_id, consent_type, version)
  where granted_at is not null and revoked_at is null and version is not null;

create index consents_patient_type_idx on public.consents (patient_id, consent_type);

-- ---------------------------------------------------------------------------
-- BEFORE trigger: server-side clock, one-way revoke, granted kept in sync.
-- ---------------------------------------------------------------------------

create or replace function public._consents_versioning()
returns trigger
language plpgsql
set search_path = pg_catalog, public
as $$
declare
  -- A signed-in client (patient or staff) gets the server clock and the
  -- immutability rules; the table owner / service_role (migrations, seeds,
  -- trusted back-office jobs) can still correct history.
  v_client boolean := coalesce(auth.role(), '') in ('authenticated', 'anon');
  v_is_patient boolean := auth.uid() is not null and auth.uid() = new.patient_id;
begin
  if tg_op = 'INSERT' then
    new.document := coalesce(new.document, new.consent_type);
    if v_client then
      new.granted_at := case when new.granted or new.granted_at is not null then now() end;
      new.revoked_at := null;
    else
      if new.granted and new.granted_at is null then
        new.granted_at := now();
      end if;
    end if;
    new.granted := new.granted_at is not null and new.revoked_at is null;
    return new;
  end if;

  -- UPDATE
  if new.consent_type is distinct from old.consent_type
     or new.document is distinct from old.document
     or new.version is distinct from old.version then
    raise exception 'consent document and version are immutable; insert a new row'
      using errcode = '42501';
  end if;

  if new.granted is distinct from old.granted
     and new.revoked_at is not distinct from old.revoked_at
     and new.granted_at is not distinct from old.granted_at then
    -- Legacy writer flipped the boolean only.
    if new.granted then
      new.granted_at := coalesce(old.granted_at, now());
      new.revoked_at := null;
    else
      new.revoked_at := now();
      new.granted_at := coalesce(old.granted_at, now());
    end if;
  end if;

  if v_client then
    if new.granted_at is distinct from old.granted_at and old.granted_at is not null then
      raise exception 'granted_at is immutable' using errcode = '42501';
    end if;
    if new.revoked_at is distinct from old.revoked_at then
      if new.revoked_at is null then
        if v_is_patient then
          raise exception 'a revoked consent cannot be restored; grant it again'
            using errcode = '42501';
        end if;
      else
        new.revoked_at := now();
      end if;
    end if;
  end if;

  new.granted := new.granted_at is not null and new.revoked_at is null;
  new.updated_at := now();
  return new;
end;
$$;

revoke all on function public._consents_versioning() from public, anon, authenticated;

create trigger consents_versioning
  before insert or update on public.consents
  for each row execute function public._consents_versioning();

-- ---------------------------------------------------------------------------
-- Patient RPCs
-- ---------------------------------------------------------------------------

-- Grants the CURRENT version of each listed type for the caller. p_items is
-- [{"consent_type": "...", "version": "..."}]: the version the app showed.
-- A stale version (a newer one was published meanwhile) is refused with
-- consent_version_stale so the app reloads the text rather than recording
-- agreement to words the patient never saw. Idempotent per version.
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

revoke all on function public.grant_patient_consents(jsonb) from public, anon, authenticated;
grant execute on function public.grant_patient_consents(jsonb) to authenticated;

-- Revokes every active grant of one type for the caller. Revoking a required
-- type sends the patient back through the onboarding gate.
create or replace function public.revoke_patient_consent(p_consent_type text)
returns int
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
declare
  v_uid uuid := auth.uid();
  v_count int;
begin
  if v_uid is null
     or not public.current_email_confirmed()
     or not public.current_patient_linked() then
    raise exception 'not authorized' using errcode = '42501';
  end if;

  update public.consents
    set revoked_at = now()
    where patient_id = v_uid
      and consent_type = p_consent_type
      and granted_at is not null
      and revoked_at is null;
  get diagnostics v_count = row_count;
  return v_count;
end;
$$;

revoke all on function public.revoke_patient_consent(text) from public, anon, authenticated;
grant execute on function public.revoke_patient_consent(text) to authenticated;
