-- APP-02: versioned consents.
--   * placeholder documents for terms / privacy / health_data (required)
--     and partner_disclosure (optional, schema only), clearly marked;
--   * grant_patient_consents writes one row per document with document,
--     version and a server-clock granted_at; stale versions are refused;
--   * revoke is one-way for the patient and keeps the row;
--   * the legacy `granted` flag stays in sync with granted_at/revoked_at;
--   * patient_onboarding_status lists exactly the missing required ones,
--     and a new document version asks again;
--   * RLS: own rows only, documents readable by any signed-in user.
begin;
select no_plan();

-- ---------------------------------------------------------------------------
-- documents
-- ---------------------------------------------------------------------------
select is(
  (select array_agg(consent_type order by consent_type) from public.current_consent_documents where required),
  array['health_data', 'privacy', 'terms'],
  'terms, privacy and health_data are the required documents');
select is(
  (select required from public.current_consent_documents where consent_type = 'partner_disclosure'),
  false, 'partner_disclosure exists in the schema and is optional');
select ok(
  (select bool_and(is_placeholder and body like 'PLACEHOLDER%') from public.consent_documents),
  'every seeded document is clearly marked placeholder');
select throws_ok(
  $$ insert into public.consent_documents (consent_type, version, document, title, body, required)
     values ('marketing', '1', 'x', 'x', 'x', false) $$,
  '23514', null, 'only the four Zyndio consent types exist');

select tests.authenticate_as('00000000-0000-0000-0000-0000000a1001', 'aal1'); -- patient_a1
select is((select count(*)::int from public.current_consent_documents), 4,
  'a signed-in patient can read the current documents');
select throws_ok($$ insert into public.consent_documents (consent_type, version, document, title, body, required)
                   values ('terms', '9.9', 'x', 'x', 'x', true) $$,
  '42501', null, 'a patient cannot publish a document');
reset role;

select tests.authenticate_as_anon();
select throws_ok($$ select count(*) from public.consent_documents $$, '42501', null,
  'anon cannot read consent documents');
reset role;

-- ---------------------------------------------------------------------------
-- onboarding status before consent
-- ---------------------------------------------------------------------------
select tests.authenticate_as('00000000-0000-0000-0000-0000000a1001', 'aal1');
select is((public.patient_onboarding_status() ->> 'linked')::boolean, true, 'patient_a1 is linked');
select is(
  (select array_agg(e ->> 'consent_type') from jsonb_array_elements(public.patient_onboarding_status() -> 'missing_consents') e),
  array['terms', 'privacy', 'health_data'],
  'a new patient is missing all three required consents, in display order');
select ok(
  (select bool_and((e ->> 'is_placeholder')::boolean and e ->> 'body' like 'PLACEHOLDER%')
     from jsonb_array_elements(public.patient_onboarding_status() -> 'missing_consents') e),
  'the gate hands the app the placeholder text to show');

-- ---------------------------------------------------------------------------
-- grant
-- ---------------------------------------------------------------------------
select throws_ok(
  $$ select public.grant_patient_consents('[{"consent_type":"terms","version":"0.0"}]'::jsonb) $$,
  '22023', 'consent_version_stale', 'agreeing to a version that is not current is refused');
select throws_ok(
  $$ select public.grant_patient_consents('[{"consent_type":"marketing","version":"0.1"}]'::jsonb) $$,
  '22023', null, 'an unknown consent type is refused');
select throws_ok(
  $$ select public.grant_patient_consents('[]'::jsonb) $$,
  '22023', null, 'an empty list is refused');

select is(public.grant_patient_consents(
  '[{"consent_type":"terms","version":"0.1"},{"consent_type":"privacy","version":"0.1"}]'::jsonb), 2,
  'granting two documents writes two rows');
select is(
  (select array_agg(e ->> 'consent_type') from jsonb_array_elements(public.patient_onboarding_status() -> 'missing_consents') e),
  array['health_data'], 'only health_data is still missing');
select is(public.grant_patient_consents('[{"consent_type":"terms","version":"0.1"}]'::jsonb), 0,
  'granting the same version again is a no-op (idempotent)');
select is(public.grant_patient_consents('[{"consent_type":"health_data","version":"0.1"}]'::jsonb), 1,
  'grant health_data');
select is(jsonb_array_length(public.patient_onboarding_status() -> 'missing_consents'), 0,
  'all required consents given: nothing missing');

select results_eq(
  $$ select consent_type, document, version, granted, granted_at is not null, revoked_at is null
       from public.consents
      where patient_id = '00000000-0000-0000-0000-0000000a1001' and version is not null
      order by consent_type $$,
  $$ values ('health_data', 'zyndio_health_data_consent', '0.1', true, true, true),
            ('privacy', 'zyndio_privacy_notice', '0.1', true, true, true),
            ('terms', 'zyndio_terms_of_service', '0.1', true, true, true) $$,
  'each consent is its own row with document, version, granted_at and no revoked_at');
select ok(
  (select bool_and(granted_at between now() - interval '1 minute' and now() + interval '1 minute')
     from public.consents where patient_id = '00000000-0000-0000-0000-0000000a1001' and version is not null),
  'granted_at is the server clock');

-- A patient writing directly can't backdate granted_at.
insert into public.consents (org_id, patient_id, consent_type, document, version, granted, granted_at)
  values ('00000000-0000-0000-0000-00000000000a', '00000000-0000-0000-0000-0000000a1001',
          'partner_disclosure', 'zyndio_partner_disclosure', '0.1', true, '2001-01-01');
select ok(
  (select granted_at > now() - interval '1 minute' from public.consents
    where patient_id = '00000000-0000-0000-0000-0000000a1001' and consent_type = 'partner_disclosure'),
  'a client-supplied granted_at is replaced by the server clock');
select throws_ok(
  $$ insert into public.consents (org_id, patient_id, consent_type, granted)
     values ('00000000-0000-0000-0000-00000000000a', '00000000-0000-0000-0000-0000000a1001', 'terms', true) $$,
  '23514', null, 'a Zyndio consent type without a version is refused');
select throws_ok(
  $$ insert into public.consents (org_id, patient_id, consent_type, document, version, granted)
     values ('00000000-0000-0000-0000-00000000000a', '00000000-0000-0000-0000-0000000a1001', 'terms', 'x', '7.0', true) $$,
  '23503', null, 'a version that was never published is refused');

-- ---------------------------------------------------------------------------
-- revoke: one-way, row kept, gate re-opens
-- ---------------------------------------------------------------------------
select throws_ok(
  $$ update public.consents set version = '0.2' where patient_id = '00000000-0000-0000-0000-0000000a1001' and consent_type = 'terms' $$,
  '42501', null, 'the version of a recorded consent cannot be changed');
select is(public.revoke_patient_consent('partner_disclosure'), 1, 'the patient can revoke an optional consent');
select ok(
  (select revoked_at is not null and not granted from public.consents
    where patient_id = '00000000-0000-0000-0000-0000000a1001' and consent_type = 'partner_disclosure'),
  'revoking sets revoked_at and flips granted to false; the row is kept');
select throws_ok(
  $$ update public.consents set revoked_at = null
      where patient_id = '00000000-0000-0000-0000-0000000a1001' and consent_type = 'partner_disclosure' $$,
  '42501', null, 'a patient cannot un-revoke; they must grant again');
select throws_ok(
  $$ update public.consents set granted = true
      where patient_id = '00000000-0000-0000-0000-0000000a1001' and consent_type = 'partner_disclosure' $$,
  '42501', null, 'nor un-revoke through the legacy granted flag');

-- Legacy flag: setting granted = false records a revoke.
update public.consents set granted = false
  where patient_id = '00000000-0000-0000-0000-0000000a1001' and consent_type = 'privacy';
select ok(
  (select revoked_at is not null from public.consents
    where patient_id = '00000000-0000-0000-0000-0000000a1001' and consent_type = 'privacy'),
  'setting the legacy granted flag to false is recorded as a revoke');
select is(
  (select array_agg(e ->> 'consent_type') from jsonb_array_elements(public.patient_onboarding_status() -> 'missing_consents') e),
  array['privacy'], 'revoking a required consent sends the patient back through the gate');
select is(public.grant_patient_consents('[{"consent_type":"privacy","version":"0.1"}]'::jsonb), 1,
  'granting again after a revoke inserts a new row');
select is((select count(*)::int from public.consents
            where patient_id = '00000000-0000-0000-0000-0000000a1001' and consent_type = 'privacy'), 2,
  'both the revoked and the new grant are kept as history');
reset role;

-- ---------------------------------------------------------------------------
-- a new document version asks again
-- ---------------------------------------------------------------------------
insert into public.consent_documents (consent_type, version, document, title, body, required, is_placeholder, published_at)
  values ('terms', '0.2', 'zyndio_terms_of_service', 'Terms of Service', 'PLACEHOLDER v0.2', true, true, now() + interval '1 second');
select tests.authenticate_as('00000000-0000-0000-0000-0000000a1001', 'aal1');
select is(jsonb_array_length(public.patient_onboarding_status() -> 'missing_consents'), 0,
  'a version with a future published_at is not in force yet');
reset role;
update public.consent_documents set published_at = now() - interval '1 second'
  where consent_type = 'terms' and version = '0.2';
select tests.authenticate_as('00000000-0000-0000-0000-0000000a1001', 'aal1');
select is(
  (select array_agg((e ->> 'consent_type') || '@' || (e ->> 'version'))
     from jsonb_array_elements(public.patient_onboarding_status() -> 'missing_consents') e),
  array['terms@0.2'], 'publishing terms 0.2 asks the patient to agree again');
select throws_ok(
  $$ select public.grant_patient_consents('[{"consent_type":"terms","version":"0.1"}]'::jsonb) $$,
  '22023', 'consent_version_stale', 'agreeing to the old 0.1 text is now refused');
select is(public.grant_patient_consents('[{"consent_type":"terms","version":"0.2"}]'::jsonb), 1,
  'agreeing to 0.2 records a new row');
reset role;

-- ---------------------------------------------------------------------------
-- isolation and access
-- ---------------------------------------------------------------------------
select tests.authenticate_as('00000000-0000-0000-0000-0000000b1001', 'aal1'); -- patient_b1
select is((select count(*)::int from public.consents where patient_id = '00000000-0000-0000-0000-0000000a1001'), 0,
  'another patient cannot see patient_a1''s consents');
select is(public.revoke_patient_consent('terms'), 0, 'revoke only ever touches the caller''s own rows');
reset role;
select is((select count(*)::int from public.consents
            where patient_id = '00000000-0000-0000-0000-0000000a1001' and consent_type = 'terms' and revoked_at is null), 2,
  'patient_a1''s terms grants are untouched by patient_b1');

-- An unlinked account (no patients row) can't grant.
select tests.authenticate_as('00000000-0000-0000-0000-0000000a9001', 'aal1'); -- spare, no patients row
select throws_ok($$ select public.grant_patient_consents('[{"consent_type":"terms","version":"0.2"}]'::jsonb) $$,
  '42501', null, 'an unlinked account cannot record consent');
select is((public.patient_onboarding_status() ->> 'linked')::boolean, false,
  'the gate reports an unlinked account as not linked');
reset role;

select tests.authenticate_as_anon();
select throws_ok($$ select public.patient_onboarding_status() $$, '42501', null, 'anon has no onboarding status');
select throws_ok($$ select public.grant_patient_consents('[{"consent_type":"terms","version":"0.2"}]'::jsonb) $$,
  '42501', null, 'anon cannot grant');
reset role;

-- Staff in the patient's clinic can still revoke via the legacy flag (paper
-- withdrawal); the row records it.
select tests.authenticate_as('00000000-0000-0000-0000-0000000a0003', 'aal2'); -- care_coordinator_a
update public.consents set granted = false
  where patient_id = '00000000-0000-0000-0000-0000000a1001' and consent_type = 'health_data';
reset role;
select ok(
  (select revoked_at is not null from public.consents
    where patient_id = '00000000-0000-0000-0000-0000000a1001' and consent_type = 'health_data'),
  'a staff withdrawal is recorded as revoked_at');

-- Legacy data_sharing fixture row still reads granted and got a granted_at.
select ok(
  (select granted and granted_at is not null and document = 'data_sharing'
     from public.consents where id = '00000000-0000-0000-0000-0000000b4001'),
  'legacy rows keep granted and gain granted_at/document');

select * from finish();
rollback;
