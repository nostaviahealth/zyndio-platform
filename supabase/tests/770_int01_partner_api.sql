-- INT-01 / INT-02 / INT-03 / PP-03: partner API schema, RLS, RPCs, triggers,
-- webhook delivery state machine. Fictional data only. Everything below is
-- rolled back.
begin;
set local search_path = public, extensions, pg_catalog;
select no_plan();

reset role;
select set_config('request.jwt.claims', '', true);

-- Fixture actors (000_fixtures): org admin A a0001, physician A a0002, org
-- admin B is absent so clinic B is probed with physician B b0001. Org A ...0a,
-- org B ...0b.
--
-- API clients for org A (sandbox + production) and org B (sandbox), with
-- known secrets so token issuing can be exercised.
insert into public.api_clients (id, org_id, environment, client_id, secret_hash, secret_hint, name, scopes) values
  ('00000000-0000-0000-0000-000000760c01', '00000000-0000-0000-0000-00000000000a', 'sandbox',
   'zyc_test_aaaaaaaaaaaaaaaaaaaaaaaa', encode(digest('zys_0000000000000000000000000000000000000000000000000000000000000001', 'sha256'), 'hex'), 'cret',
   'Fictional sandbox', array['patients:read', 'patients:write', 'webhooks:manage']),
  ('00000000-0000-0000-0000-000000760c02', '00000000-0000-0000-0000-00000000000a', 'production',
   'zyc_live_aaaaaaaaaaaaaaaaaaaaaaaa', encode(digest('zys_0000000000000000000000000000000000000000000000000000000000000002', 'sha256'), 'hex'), 'cret',
   'Fictional production', array['patients:read']),
  ('00000000-0000-0000-0000-000000760c03', '00000000-0000-0000-0000-00000000000b', 'sandbox',
   'zyc_test_bbbbbbbbbbbbbbbbbbbbbbbb', encode(digest('zys_0000000000000000000000000000000000000000000000000000000000000003', 'sha256'), 'hex'), 'cret',
   'Fictional clinic B', array['patients:read', 'patients:write']);

-- Scratch space shared by every role this file switches to.
create temp table int01_j (k text primary key, j jsonb);
grant all on int01_j to authenticated, service_role;
create temp table int01_d (id uuid, n int);
grant all on int01_d to authenticated, service_role;

-- Fresh auth accounts the Edge Function would have minted with admin.createUser.
insert into auth.users (id, email, email_confirmed_at, aud, role) values
  ('00000000-0000-0000-0000-000000760a01', 'int01-patient-one@example.test', now(), 'authenticated', 'authenticated'),
  ('00000000-0000-0000-0000-000000760a02', 'int01-patient-two@example.test', now(), 'authenticated', 'authenticated'),
  ('00000000-0000-0000-0000-000000760a03', 'int01-patient-three@example.test', now(), 'authenticated', 'authenticated');

-- ---------------------------------------------------------------------------
-- 1. Shape: tables exist, forced RLS, no client writes, no secret columns
-- ---------------------------------------------------------------------------
select ok((select relrowsecurity and relforcerowsecurity from pg_class where oid = t::regclass),
          t || ' has forced RLS')
  from unnest(array['public.api_clients', 'public.api_access_tokens', 'public.api_idempotency_keys',
                    'public.zyndio_patient_links', 'public.webhook_endpoints', 'public.webhook_events',
                    'public.webhook_deliveries', 'public.webhook_delivery_attempts']) t;

select ok(not has_table_privilege(r, t, p), format('%s has no %s on %s', r, p, t))
  from unnest(array['public.api_clients', 'public.api_access_tokens', 'public.api_idempotency_keys',
                    'public.zyndio_patient_links', 'public.webhook_endpoints', 'public.webhook_events',
                    'public.webhook_deliveries', 'public.webhook_delivery_attempts']) t,
       unnest(array['anon', 'authenticated']) r,
       unnest(array['INSERT', 'UPDATE', 'DELETE']) p;

select ok(not has_table_privilege('anon', t, 'SELECT'), 'anon cannot read ' || t)
  from unnest(array['public.api_clients', 'public.webhook_endpoints', 'public.webhook_events',
                    'public.webhook_deliveries', 'public.webhook_delivery_attempts']) t;
select ok(not has_table_privilege('authenticated', t, 'SELECT'), 'authenticated has no SELECT on ' || t)
  from unnest(array['public.api_access_tokens', 'public.api_idempotency_keys', 'public.zyndio_patient_links']) t;
select ok(not has_column_privilege('authenticated', 'public.api_clients', 'secret_hash', 'SELECT'),
  'authenticated cannot read api_clients.secret_hash');
select ok(not has_column_privilege('authenticated', 'public.webhook_endpoints', 'secret', 'SELECT'),
  'authenticated cannot read webhook_endpoints.secret');
select ok(not has_column_privilege('authenticated', 'public.webhook_endpoints', 'previous_secret', 'SELECT'),
  'authenticated cannot read webhook_endpoints.previous_secret');
select ok(not has_column_privilege('authenticated', 'public.webhook_events', 'data', 'SELECT'),
  'authenticated cannot read webhook_events.data (event payloads)');

-- partner_* / webhook_* are service_role only
select ok(not has_function_privilege(r, f, 'EXECUTE'), format('%s cannot execute %s', r, f))
  from unnest(array[
    'public.partner_issue_token(text, text, text[], text)',
    'public.partner_authenticate(text)',
    'public.partner_enrol_patient(uuid, uuid, text, text, text, text)',
    'public.partner_get_patient(uuid, text)',
    'public.partner_patient_summary(uuid, text)',
    'public.webhook_claim_due(int)',
    'public.webhook_record_attempt(uuid, text, int, int, text)',
    'public._emit_integration_event(uuid, text, text, jsonb)',
    'public._partner_patient_json(uuid)']) f,
       unnest(array['anon', 'authenticated']) r;
select ok(has_function_privilege('service_role', 'public.partner_enrol_patient(uuid, uuid, text, text, text, text)', 'EXECUTE'),
  'service_role can execute partner_enrol_patient');

-- ---------------------------------------------------------------------------
-- 2. PP-03 portal RPCs: org_admin + aal2, own org
-- ---------------------------------------------------------------------------
select tests.authenticate_as('00000000-0000-0000-0000-0000000a0002', 'aal2');
select throws_ok($$ select public.integration_admin_create_api_client('x', 'sandbox', array['patients:read']) $$,
  '42501', null, 'a physician cannot create an API client');
select tests.authenticate_as('00000000-0000-0000-0000-0000000a0001', 'aal1');
select throws_ok($$ select public.integration_admin_create_api_client('x', 'sandbox', array['patients:read']) $$,
  '42501', null, 'an org admin at aal1 cannot create an API client');
select is((select count(*)::int from public.api_clients), 0, 'an org admin at aal1 sees no API clients');

select tests.authenticate_as('00000000-0000-0000-0000-0000000a0001', 'aal2');
insert into int01_j select 'int01_created', public.integration_admin_create_api_client('  Fictional portal client ', 'production',
                                                    array['patients:write', 'patients:read', 'patients:read']);

select matches((select j ->> 'client_id' from (select j from int01_j where k = 'int01_created') int01_created), '^zyc_live_[0-9a-f]{24}$', 'production client id is zyc_live_*');
select matches((select j ->> 'client_secret' from (select j from int01_j where k = 'int01_created') int01_created), '^zys_[0-9a-f]{64}$', 'client secret is returned once, 256 bits');
select is((select j -> 'scopes' from (select j from int01_j where k = 'int01_created') int01_created), '["patients:read", "patients:write"]'::jsonb, 'scopes de-duplicated and sorted');
select is((select name from public.api_clients where client_id = (select j ->> 'client_id' from (select j from int01_j where k = 'int01_created') int01_created)),
  'Fictional portal client', 'name trimmed');
select is((select count(*)::int from public.api_clients), 3, 'org admin A at aal2 sees only clinic A clients');
select throws_ok($$ select secret_hash from public.api_clients $$, '42501', null,
  'org admin cannot select secret_hash');
select throws_ok($$ select public.integration_admin_create_api_client('x', 'staging', array['patients:read']) $$,
  '22023', null, 'unknown environment refused');
select throws_ok($$ select public.integration_admin_create_api_client('x', 'sandbox', array['admin:all']) $$,
  '22023', null, 'unknown scope refused');
select throws_ok($$ select public.integration_admin_revoke_api_client('00000000-0000-0000-0000-000000760c03') $$,
  'PT404', null, 'clinic A admin cannot revoke a clinic B client (looks like not found)');

reset role;
select is((select secret_hash from public.api_clients where client_id = (select j ->> 'client_id' from (select j from int01_j where k = 'int01_created') int01_created)),
  encode(digest((select j ->> 'client_secret' from (select j from int01_j where k = 'int01_created') int01_created), 'sha256'), 'hex'),
  'only sha256(secret) is stored');
select is((select count(*)::int from public.audit_log where event_type = 'api_client_created'
            and org_id = '00000000-0000-0000-0000-00000000000a'
            and actor_user_id = '00000000-0000-0000-0000-0000000a0001'), 1, 'api_client_created audited');

select tests.authenticate_as('00000000-0000-0000-0000-0000000b0001', 'aal2');
select is((select count(*)::int from public.api_clients), 0, 'a clinic B physician sees no API clients');

-- ---------------------------------------------------------------------------
-- 3. OAuth client credentials
-- ---------------------------------------------------------------------------
select tests.authenticate_as_service_role();
select is(public.partner_issue_token('zyc_test_aaaaaaaaaaaaaaaaaaaaaaaa', encode(digest('wrong', 'sha256'), 'hex'),
                                     null, repeat('1', 64)) ->> 'error', 'invalid_client', 'wrong secret -> invalid_client');
select is(public.partner_issue_token('zyc_test_nope', encode(digest('zys_0000000000000000000000000000000000000000000000000000000000000001', 'sha256'), 'hex'),
                                     null, repeat('1', 64)) ->> 'error', 'invalid_client', 'unknown client -> invalid_client');
select is(public.partner_issue_token('zyc_live_aaaaaaaaaaaaaaaaaaaaaaaa', encode(digest('zys_0000000000000000000000000000000000000000000000000000000000000002', 'sha256'), 'hex'),
                                     array['patients:write'], repeat('1', 64)) ->> 'error', 'invalid_scope',
  'scope the client does not have -> invalid_scope');
select is(public.partner_issue_token('zyc_test_aaaaaaaaaaaaaaaaaaaaaaaa', encode(digest('zys_0000000000000000000000000000000000000000000000000000000000000001', 'sha256'), 'hex'),
                                     array['patients:read'], repeat('a', 64)),
  '{"scopes": ["patients:read"], "expires_in": 900, "environment": "sandbox"}'::jsonb, 'narrowed scope granted');
select is(public.partner_issue_token('zyc_test_aaaaaaaaaaaaaaaaaaaaaaaa', encode(digest('zys_0000000000000000000000000000000000000000000000000000000000000001', 'sha256'), 'hex'),
                                     null, repeat('b', 64)) -> 'scopes',
  '["patients:read", "patients:write", "webhooks:manage"]'::jsonb, 'no scope requested -> all client scopes');

reset role;
select is((select expires_at - created_at from public.api_access_tokens where token_hash = repeat('a', 64)),
  interval '15 minutes', 'token lives 15 minutes');
select throws_ok($$ insert into public.api_access_tokens (api_client_id, token_hash, scopes, expires_at)
  values ('00000000-0000-0000-0000-000000760c01', repeat('9', 64), array['patients:read'], now() + interval '1 hour') $$,
  '23514', null, 'a token can never be minted for longer than 15 minutes');
select tests.authenticate_as_service_role();

select is(public.partner_authenticate(repeat('b', 64)) ->> 'api_client_id', '00000000-0000-0000-0000-000000760c01',
  'valid token -> principal');
select is(public.partner_authenticate(repeat('c', 64)), null, 'unknown token -> null');
reset role;
update public.api_access_tokens set expires_at = now() - interval '5 minutes', created_at = now() - interval '20 minutes'
 where token_hash = repeat('a', 64);
select tests.authenticate_as_service_role();
select is(public.partner_authenticate(repeat('a', 64)), null, 'expired token -> null');

-- ---------------------------------------------------------------------------
-- 4. Idempotency keys
-- ---------------------------------------------------------------------------
select is(public.partner_idempotency_begin('00000000-0000-0000-0000-000000760c01', 'key-1', 'POST', 'patients', repeat('d', 64)) ->> 'state',
  'new', 'first use of a key -> new');
select is(public.partner_idempotency_begin('00000000-0000-0000-0000-000000760c01', 'key-1', 'POST', 'patients', repeat('d', 64)) ->> 'state',
  'in_progress', 'same key while running -> in_progress');
select is(public.partner_idempotency_begin('00000000-0000-0000-0000-000000760c01', 'key-1', 'POST', 'patients', repeat('e', 64)) ->> 'state',
  'mismatch', 'same key, different body -> mismatch');
select public.partner_idempotency_complete('00000000-0000-0000-0000-000000760c01', 'key-1', 201, '{"object":"patient"}');
select is(public.partner_idempotency_begin('00000000-0000-0000-0000-000000760c01', 'key-1', 'POST', 'patients', repeat('d', 64)),
  '{"state": "replay", "response_status": 201, "response_body": {"object": "patient"}}'::jsonb, 'completed key -> replay of the original');
select is(public.partner_idempotency_begin('00000000-0000-0000-0000-000000760c03', 'key-1', 'POST', 'patients', repeat('d', 64)) ->> 'state',
  'new', 'keys are scoped per API client');
select public.partner_idempotency_abandon('00000000-0000-0000-0000-000000760c03', 'key-1');
select is(public.partner_idempotency_begin('00000000-0000-0000-0000-000000760c03', 'key-1', 'POST', 'patients', repeat('d', 64)) ->> 'state',
  'new', 'an abandoned (5xx) key can be retried');
reset role;
update public.api_idempotency_keys set expires_at = now() - interval '1 second'
 where api_client_id = '00000000-0000-0000-0000-000000760c01' and idempotency_key = 'key-1';
select tests.authenticate_as_service_role();
select is(public.partner_idempotency_begin('00000000-0000-0000-0000-000000760c01', 'key-1', 'POST', 'patients', repeat('e', 64)) ->> 'state',
  'new', 'after 7 days the key is free again');
reset role;
select is((select expires_at - created_at from public.api_idempotency_keys
            where api_client_id = '00000000-0000-0000-0000-000000760c01' and idempotency_key = 'key-1'),
  interval '7 days', 'keys are kept 7 days');

-- ---------------------------------------------------------------------------
-- 5. Webhook endpoints (needed before events so fan-out can be checked)
-- ---------------------------------------------------------------------------
select tests.authenticate_as_service_role();
select is(public.partner_create_webhook_endpoint('00000000-0000-0000-0000-000000760c01', 'http://hooks.example.test/in', null, null) ->> 'error',
  'https_required', 'production-style http URL refused');
select is(public.partner_create_webhook_endpoint('00000000-0000-0000-0000-000000760c01', 'https://10.0.0.5/in', null, null) ->> 'error',
  'url_not_allowed', 'IP-literal URL refused');
select is(public.partner_create_webhook_endpoint('00000000-0000-0000-0000-000000760c01', 'https://localhost/in', null, null) ->> 'error',
  'url_not_allowed', 'localhost refused by default');
select is(public.partner_create_webhook_endpoint('00000000-0000-0000-0000-000000760c01', 'https://user:pw@hooks.example.test/in', null, null) ->> 'error',
  'invalid_url', 'URL with credentials refused');
select is(public.partner_create_webhook_endpoint('00000000-0000-0000-0000-000000760c01', 'https://metadata.internal/in', null, null) ->> 'error',
  'url_not_allowed', '.internal host refused');
select is(public.partner_create_webhook_endpoint('00000000-0000-0000-0000-000000760c01', 'https://hooks.example.test/in', null,
                                                 array['patient.exploded']) ->> 'error',
  'invalid_event_types', 'unknown event type refused');

select set_config('app.webhooks_allow_local_receivers', 'on', true);
select is(public.partner_create_webhook_endpoint('00000000-0000-0000-0000-000000760c02', 'http://127.0.0.1:9999/in', null, null) ->> 'error',
  'url_not_allowed', 'local receivers are never allowed for production, even with the dev setting on');
insert into int01_j select 'int01_local', public.partner_create_webhook_endpoint('00000000-0000-0000-0000-000000760c01', 'http://127.0.0.1:9999/in', 'local dev', null);
select set_config('app.webhooks_allow_local_receivers', '', true);
select is((select j ->> 'status' from (select j from int01_j where k = 'int01_local') int01_local), 'enabled', 'sandbox local receiver allowed with the dev setting');

insert into int01_j select 'int01_ep', public.partner_create_webhook_endpoint('00000000-0000-0000-0000-000000760c01', 'https://hooks.example.test/in',
                                               'Fictional receiver', null);
select matches((select j ->> 'id' from (select j from int01_j where k = 'int01_ep') int01_ep), '^whe_[0-9a-f]{24}$', 'endpoint id is whe_*');
select matches((select j ->> 'secret' from (select j from int01_j where k = 'int01_ep') int01_ep), '^whsec_[0-9a-f]{48}$', 'secret returned on create');
select is((select j -> 'event_types' from (select j from int01_j where k = 'int01_ep') int01_ep),
  '["consent.updated", "patient.activated", "patient.deactivated", "patient.enrolled"]'::jsonb, 'defaults to every event type');

insert into int01_j select 'int01_ep_consent_only', public.partner_create_webhook_endpoint('00000000-0000-0000-0000-000000760c01', 'https://consents.example.test/in',
                                               null, array['consent.updated']);
insert into int01_j select 'int01_ep_prod', public.partner_create_webhook_endpoint('00000000-0000-0000-0000-000000760c02', 'https://prod.example.test/in', null, null);

select is(jsonb_array_length(public.partner_list_webhook_endpoints('00000000-0000-0000-0000-000000760c01', null, null, 100)), 3,
  'sandbox client lists its 3 sandbox endpoints');
select is(jsonb_array_length(public.partner_list_webhook_endpoints('00000000-0000-0000-0000-000000760c02', null, null, 100)), 1,
  'production client lists only the production endpoint');
select is(public.partner_list_webhook_endpoints('00000000-0000-0000-0000-000000760c01', null, null, 100) -> 0 -> 'secret', null,
  'list never includes the secret');
select is(public.partner_delete_webhook_endpoint('00000000-0000-0000-0000-000000760c03', (select j ->> 'id' from (select j from int01_j where k = 'int01_ep') int01_ep)) ->> 'error',
  'not_found', 'clinic B cannot delete clinic A endpoint');
select is(public.partner_rotate_webhook_secret('00000000-0000-0000-0000-000000760c02', (select j ->> 'id' from (select j from int01_j where k = 'int01_ep') int01_ep)) ->> 'error',
  'not_found', 'production client cannot touch a sandbox endpoint');

-- ---------------------------------------------------------------------------
-- 6. Enrolment (INT-01) + patient.enrolled
-- ---------------------------------------------------------------------------
insert into int01_j select 'int01_enrol', public.partner_enrol_patient('00000000-0000-0000-0000-000000760c01', '00000000-0000-0000-0000-000000760a01',
           'zp-fictional-001', 'Fictional', 'Person', '+15555550101');
reset role;

select is((select j ->> 'zyndio_patient_id' from (select j from int01_j where k = 'int01_enrol') int01_enrol), 'zp-fictional-001', 'enrol returns the patient object');
select is((select j ->> 'status' from (select j from int01_j where k = 'int01_enrol') int01_enrol), 'invited', 'new patient is invited');
select is((select j ->> 'email' from (select j from int01_j where k = 'int01_enrol') int01_enrol), 'int01-patient-one@example.test', 'email from the auth account');
select matches((select j ->> 'enrolled_at' from (select j from int01_j where k = 'int01_enrol') int01_enrol), '^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\.\d{3}Z$',
  'timestamps are ISO 8601 UTC');
select is(position('00000000-0000-0000-0000-000000760a01' in (select j::text from (select j from int01_j where k = 'int01_enrol') int01_enrol)), 0,
  'the internal patient uuid never appears in the response');
select is((select org_id from public.patients where id = '00000000-0000-0000-0000-000000760a01'),
  '00000000-0000-0000-0000-00000000000a'::uuid, 'patients row in the client''s org');
select is((select display_name from public.patients where id = '00000000-0000-0000-0000-000000760a01'),
  'Fictional Person', 'display name from given + family');
select is((select proof_method from public.patient_record_links where app_user_id = '00000000-0000-0000-0000-000000760a01' and status = 'active'),
  'clinic_provisioned', 'active clinic_provisioned record link, as create_patient_record makes');
select is((select source from public.patient_invites
            where patient_id = '00000000-0000-0000-0000-000000760a01' and accepted_at is null and revoked_at is null),
  'api', 'APP-01 invite recorded with source api');
select is((select payload - 'invite_id' from public.notification_outbox
            where user_id = '00000000-0000-0000-0000-000000760a01' and type = 'patient_invite'),
  '{"email": "int01-patient-one@example.test"}'::jsonb, 'patient_invite email queued, carrying no credential');
select is((select count(*)::int from public.patient_password_resets where user_id = '00000000-0000-0000-0000-000000760a01'), 0,
  'no password link is issued (patients sign in with a code)');
select is((select count(*)::int from public.webhook_events
            where event_type = 'patient.enrolled' and data ->> 'zyndio_patient_id' = 'zp-fictional-001'), 1,
  'patient.enrolled event recorded');
select is((select count(*)::int from public.webhook_deliveries d join public.webhook_events e on e.id = d.event_id
            where e.event_type = 'patient.enrolled'), 2,
  'fanned out to the two sandbox endpoints that subscribe to it (not consent-only, not production)');
select is((select count(*)::int from public.audit_log where event_type = 'partner_patient_enrolled'
            and target_user_id = '00000000-0000-0000-0000-000000760a01'), 1, 'enrolment audited');

select tests.authenticate_as_service_role();
select is(public.partner_enrol_patient('00000000-0000-0000-0000-000000760c01', '00000000-0000-0000-0000-000000760a02',
           'zp-fictional-001', null, null, null) ->> 'error',
  'patient_already_exists', 'same zyndio_patient_id twice -> patient_already_exists');
select is(public.partner_enrol_patient('00000000-0000-0000-0000-000000760c01', '00000000-0000-0000-0000-0000000a0002',
           'zp-staff', null, null, null) ->> 'error',
  'email_unavailable', 'a staff account can never become a partner patient');
select is(public.partner_enrol_patient('00000000-0000-0000-0000-000000760c01', '00000000-0000-0000-0000-0000000a1001',
           'zp-existing', null, null, null) ->> 'error',
  'email_unavailable', 'an existing patient account is not re-bound');
select is(public.partner_enrol_patient('00000000-0000-0000-0000-000000760c01', '00000000-0000-0000-0000-000000760a02',
           'zp-bad-phone', null, null, '555-0102') ->> 'error',
  'invalid_request', 'non-E.164 phone refused by the table check');

-- the same zyndio_patient_id may exist in production separately from sandbox
select is(public.partner_get_patient('00000000-0000-0000-0000-000000760c02', 'zp-fictional-001'), null,
  'a production client cannot see a sandbox patient');
select is(public.partner_get_patient('00000000-0000-0000-0000-000000760c03', 'zp-fictional-001'), null,
  'clinic B cannot see clinic A''s patient');
select is(public.partner_get_patient('00000000-0000-0000-0000-000000760c01', 'zp-fictional-001') ->> 'status', 'invited',
  'GET returns the patient');
select is(public.partner_resolve_patient('00000000-0000-0000-0000-000000760c01', 'zp-fictional-001') ->> 'user_id',
  '00000000-0000-0000-0000-000000760a01', 'resolve gives the Edge Function the internal id (never sent to the partner)');

select ok(public.partner_enrol_patient('00000000-0000-0000-0000-000000760c01', '00000000-0000-0000-0000-000000760a02',
           'zp-fictional-002', 'Second', null, null) ? 'zyndio_patient_id', 'second enrolment');
select is(jsonb_array_length(public.partner_list_patients('00000000-0000-0000-0000-000000760c01', null, null, 1)), 1,
  'list honours the limit');
select is(public.partner_list_patients('00000000-0000-0000-0000-000000760c01',
           public.partner_list_patients('00000000-0000-0000-0000-000000760c01', null, null, 1) -> 0 ->> '_sort',
           'zp-fictional-001', 10) -> 0 ->> 'zyndio_patient_id',
  'zp-fictional-002', 'keyset cursor continues after the last item');

-- revoked clients can do nothing
reset role;
update public.api_clients set revoked_at = now() where id = '00000000-0000-0000-0000-000000760c03';
select tests.authenticate_as_service_role();
select throws_ok($$ select public.partner_get_patient('00000000-0000-0000-0000-000000760c03', 'x') $$,
  '42501', null, 'a revoked client is refused by every partner RPC');
select is(public.partner_issue_token('zyc_test_bbbbbbbbbbbbbbbbbbbbbbbb', encode(digest('zys_0000000000000000000000000000000000000000000000000000000000000003', 'sha256'), 'hex'),
                                     null, repeat('7', 64)) ->> 'error', 'invalid_client', 'a revoked client gets no token');

-- ---------------------------------------------------------------------------
-- 7. Invites
-- ---------------------------------------------------------------------------
select is(public.partner_send_invite('00000000-0000-0000-0000-000000760c01', 'zp-fictional-001') ->> 'error',
  'rate_limited', 'a second invite inside a minute is throttled');
select is(public.partner_send_invite('00000000-0000-0000-0000-000000760c01', 'zp-fictional-001', true) ->> 'object',
  'invite', 'bypass (after an email change) sends');
reset role;
select is((select count(*)::int from public.patient_invites
            where patient_id = '00000000-0000-0000-0000-000000760a01' and accepted_at is null and revoked_at is null), 1,
  'only the newest invite is open');
select is((select count(*)::int from public.patient_invites where patient_id = '00000000-0000-0000-0000-000000760a01'), 2,
  'the earlier invite is kept, revoked');
select tests.authenticate_as_service_role();
select is(public.partner_send_invite('00000000-0000-0000-0000-000000760c01', 'zp-unknown') ->> 'error',
  'not_found', 'unknown patient -> not_found');

-- ---------------------------------------------------------------------------
-- 8. Triggers: consent.updated and patient.activated
-- ---------------------------------------------------------------------------
reset role;
insert into public.consents (id, org_id, patient_id, consent_type, granted) values
  ('00000000-0000-0000-0000-000000760d01', '00000000-0000-0000-0000-00000000000a', '00000000-0000-0000-0000-000000760a01', 'data_sharing', true);
select is((select data from public.webhook_events where event_type = 'consent.updated' order by created_at desc limit 1)
            - 'updated_at',
  '{"zyndio_patient_id": "zp-fictional-001", "consent_type": "data_sharing", "document": "data_sharing", "version": null,
    "revoked_at": null, "granted": true, "change": "created"}'::jsonb,
  'consent insert -> consent.updated');
select is((select count(*)::int from public.webhook_deliveries d join public.webhook_events e on e.id = d.event_id
            where e.event_type = 'consent.updated'), 3,
  'consent.updated reaches all three subscribed sandbox endpoints');
update public.consents set updated_at = now() + interval '1 minute' where id = '00000000-0000-0000-0000-000000760d01';
select is((select count(*)::int from public.webhook_events where event_type = 'consent.updated'), 1,
  'an updated_at-only touch is not an event');
update public.consents set granted = false where id = '00000000-0000-0000-0000-000000760d01';
select is((select data -> 'granted' from public.webhook_events where event_type = 'consent.updated'
            and data ->> 'change' = 'updated'), 'false'::jsonb, 'withdrawal -> consent.updated granted=false');
update public.consents set granted = false where id = '00000000-0000-0000-0000-0000000a4001';
select is((select count(*)::int from public.webhook_events where event_type = 'consent.updated'), 2,
  'consents of patients not enrolled via the API emit nothing');

select tests.authenticate_as_service_role();
select is(jsonb_array_length(public.partner_get_patient('00000000-0000-0000-0000-000000760c01', 'zp-fictional-001') -> 'consents'), 1,
  'GET shows current consent state');
reset role;

update auth.users set last_sign_in_at = now() where id = '00000000-0000-0000-0000-000000760a01';
select is((select count(*)::int from public.webhook_events where event_type = 'patient.activated'
            and data ->> 'zyndio_patient_id' = 'zp-fictional-001'), 1, 'first sign-in -> patient.activated');
select isnt((select activated_at from public.zyndio_patient_links where zyndio_patient_id = 'zp-fictional-001'), null,
  'activated_at stamped');
update auth.users set last_sign_in_at = now() + interval '1 hour' where id = '00000000-0000-0000-0000-000000760a01';
select is((select count(*)::int from public.webhook_events where event_type = 'patient.activated'), 1,
  'later sign-ins are not activations');
update auth.users set last_sign_in_at = now() where id = '00000000-0000-0000-0000-0000000a1001';
select is((select count(*)::int from public.webhook_events where event_type = 'patient.activated'), 1,
  'sign-ins of patients not enrolled via the API emit nothing');

select tests.authenticate_as_service_role();
select is(public.partner_get_patient('00000000-0000-0000-0000-000000760c01', 'zp-fictional-001') ->> 'status', 'active',
  'status active after first sign-in');
select is(public.partner_send_invite('00000000-0000-0000-0000-000000760c01', 'zp-fictional-001', true) ->> 'error',
  'patient_already_active', 'no invite once the patient has signed in');

-- ---------------------------------------------------------------------------
-- 9. PATCH: contact + deactivate
-- ---------------------------------------------------------------------------
select is(public.partner_update_patient('00000000-0000-0000-0000-000000760c01', 'zp-fictional-002',
           '{"family_name": "Example", "phone": "+15555550199"}') ->> 'phone', '+15555550199', 'phone updated');
select is(public.partner_update_patient('00000000-0000-0000-0000-000000760c01', 'zp-fictional-002', '{"phone": null}') -> 'phone',
  'null'::jsonb, 'null clears a field');
select is(public.partner_update_patient('00000000-0000-0000-0000-000000760c01', 'zp-fictional-002', '{"phone": "12"}') ->> 'error',
  'invalid_request', 'invalid phone refused');
reset role;
select is((select display_name from public.patients where id = '00000000-0000-0000-0000-000000760a02'),
  'Second Example', 'display name follows the contact update');
-- give the patient a live session to prove deactivation ends it
insert into auth.sessions (id, user_id) values ('00000000-0000-0000-0000-000000760e01', '00000000-0000-0000-0000-000000760a02');
select tests.authenticate_as_service_role();
select is(public.partner_update_patient('00000000-0000-0000-0000-000000760c01', 'zp-fictional-002', '{"status": "deactivated"}') ->> 'status',
  'deactivated', 'deactivated');
select is(public.partner_update_patient('00000000-0000-0000-0000-000000760c01', 'zp-fictional-002', '{"status": "deactivated"}') ->> 'status',
  'deactivated', 'deactivating twice is a no-op');
reset role;
select is((select count(*)::int from public.webhook_events where event_type = 'patient.deactivated'), 1,
  'exactly one patient.deactivated event');
select is((select count(*)::int from auth.sessions where user_id = '00000000-0000-0000-0000-000000760a02'), 0,
  'deactivation ends the patient''s sessions');
select is((select count(*)::int from public.patient_invites
            where patient_id = '00000000-0000-0000-0000-000000760a02' and accepted_at is null and revoked_at is null), 0,
  'deactivation revokes the open invite');
select tests.authenticate_as_service_role();
select is(public.partner_send_invite('00000000-0000-0000-0000-000000760c01', 'zp-fictional-002', true) ->> 'error',
  'patient_deactivated', 'no invite for a deactivated patient');

-- ---------------------------------------------------------------------------
-- 10. Summary (INT-03)
-- ---------------------------------------------------------------------------
reset role;
-- as the flag RPC's owner would (L25/L28 trigger keeps the flag only on that path)
select set_config('app.lab_report_flag_rpc', 'on', true);
insert into public.lab_reports (id, org_id, patient_id, report_type, data, needs_review, flagged_at) values
  ('00000000-0000-0000-0000-000000760f01', '00000000-0000-0000-0000-00000000000a', '00000000-0000-0000-0000-000000760a01',
   'basic_panel', '{}', true, now());
insert into public.lab_results (org_id, patient_id, lab_report_id, analyte_key, analyte_label, value, unit, status, range_low, range_high, taken_at) values
  ('00000000-0000-0000-0000-00000000000a', '00000000-0000-0000-0000-000000760a01', '00000000-0000-0000-0000-000000760f01',
   'hba1c', 'HbA1c', 5.4, '%', 'within_range', 4.0, 5.6, now() - interval '30 days'),
  ('00000000-0000-0000-0000-00000000000a', '00000000-0000-0000-0000-000000760a01', '00000000-0000-0000-0000-000000760f01',
   'hba1c', 'HbA1c', 6.1, '%', 'outside_range', 4.0, 5.6, now() - interval '1 day');
select set_config('app.lab_report_flag_rpc', 'off', true);
select tests.authenticate_as_service_role();
insert into int01_j select 'int01_summary', public.partner_patient_summary('00000000-0000-0000-0000-000000760c01', 'zp-fictional-001');
select is((select jsonb_array_length(j -> 'biomarkers') from (select j from int01_j where k = 'int01_summary') int01_summary), 1, 'one latest value per analyte');
select is((select (j -> 'biomarkers' -> 0 ->> 'value')::numeric from (select j from int01_j where k = 'int01_summary') int01_summary), 6.1, 'the latest value wins');
select is((select j -> 'wearables' from (select j from int01_j where k = 'int01_summary') int01_summary), '{"sources": [], "daily": []}'::jsonb,
  'wearables empty until wearable_daily lands');
select ok((select j -> 'open_flags' @> '[{"type": "lab_report_needs_review"}, {"type": "biomarker_outside_range", "analyte_key": "hba1c"}]' from (select j from int01_j where k = 'int01_summary') int01_summary),
  'open flags: report awaiting review + latest out-of-range value');
select is(position('00000000-0000-0000-0000-000000760a01' in (select j::text from (select j from int01_j where k = 'int01_summary') int01_summary)), 0,
  'summary carries no internal uuid');
select is(public.partner_patient_summary('00000000-0000-0000-0000-000000760c02', 'zp-fictional-001') ->> 'error', 'not_found',
  'production client cannot read a sandbox summary');

-- ---------------------------------------------------------------------------
-- 11. Delivery state machine (INT-02)
-- ---------------------------------------------------------------------------
select is(public._webhook_retry_delay(n), d, format('retry after attempt %s is %s', n, d))
  from (values (1, interval '1 minute'), (2, interval '5 minutes'), (3, interval '30 minutes'),
               (4, interval '2 hours'), (5, interval '6 hours'), (6, interval '12 hours'),
               (7, interval '24 hours'), (8, null::interval)) v(n, d);

insert into int01_j select 'int01_claim', public.webhook_claim_due(100);
select ok((select jsonb_array_length(j) from (select j from int01_j where k = 'int01_claim') int01_claim) > 0, 'due deliveries are claimed');
select is((select count(*)::int from (select j from int01_j where k = 'int01_claim') int01_claim, jsonb_array_elements(j) c
            where c -> 'envelope' ?& array['event_id', 'event_type', 'created_at', 'schema_version', 'data']),
          (select jsonb_array_length(j) from (select j from int01_j where k = 'int01_claim') int01_claim), 'every claim carries the full envelope');
select is(jsonb_array_length(public.webhook_claim_due(100)), 0, 'claimed deliveries are locked against a second worker');

-- succeed one, fail one all the way to dead letter
insert into int01_d
  select (c ->> 'delivery_id')::uuid, row_number() over () from (select j from int01_j where k = 'int01_claim') int01_claim, jsonb_array_elements(j) c;
select is(public.webhook_record_attempt((select id from int01_d where n = 1), repeat('0', 64), 204, 120, null),
  'succeeded', '2xx -> succeeded');
select is(public.webhook_record_attempt((select id from int01_d where n = 2), repeat('0', 64), 500, 80, 'http_500'),
  'retry_scheduled', 'first failure -> retry');
reset role;
select ok((select next_attempt_at between now() + interval '59 seconds' and now() + interval '61 seconds'
             from public.webhook_deliveries where id = (select id from int01_d where n = 2)), 'first retry in 1 minute');
select tests.authenticate_as_service_role();
select public.webhook_record_attempt((select id from int01_d where n = 2), repeat('0', 64), null, 10000, 'timeout')
  from generate_series(2, 7);
select is(public.webhook_record_attempt((select id from int01_d where n = 2), repeat('0', 64), 410, 5, 'http_410'),
  'dead_letter', 'the 8th failed attempt moves the delivery to dead letter');
reset role;
select is((select status from public.webhook_deliveries where id = (select id from int01_d where n = 2)), 'dead_letter',
  'status dead_letter');
select is((select count(*)::int from public.webhook_delivery_attempts where delivery_id = (select id from int01_d where n = 2)), 8,
  'every attempt logged');
select is((select array_agg(response_status order by attempt_number)::text from public.webhook_delivery_attempts
            where delivery_id = (select id from int01_d where n = 2)), '{500,NULL,NULL,NULL,NULL,NULL,NULL,410}',
  'attempt log records response codes (null = no response)');
select tests.authenticate_as_service_role();
select is(public.webhook_record_attempt((select id from int01_d where n = 2), repeat('0', 64), 200, 5, null),
  'dead_letter', 'a finished delivery is not reopened by a late result');

-- rotation: the previous secret keeps signing for 24h
select ok(public.partner_rotate_webhook_secret('00000000-0000-0000-0000-000000760c01', (select j ->> 'id' from (select j from int01_j where k = 'int01_ep') int01_ep)) ->> 'secret'
            <> (select j ->> 'secret' from (select j from int01_j where k = 'int01_ep') int01_ep), 'rotate returns a new secret');
reset role;
update public.webhook_deliveries set locked_until = null, next_attempt_at = now() - interval '1 second'
 where status = 'pending';
select tests.authenticate_as_service_role();
select ok((select bool_and(jsonb_array_length(c -> 'secrets') = 2 and c -> 'secrets' ->> 1 = (select j ->> 'secret' from (select j from int01_j where k = 'int01_ep') int01_ep))
             from jsonb_array_elements(public.webhook_claim_due(100)) c
            where c ->> 'url' = 'https://hooks.example.test/in'),
  'after rotation deliveries are signed with the new and the previous secret');

-- disabling cancels pending deliveries
select is(public.partner_delete_webhook_endpoint('00000000-0000-0000-0000-000000760c01', (select j ->> 'id' from (select j from int01_j where k = 'int01_ep') int01_ep)) ->> 'status',
  'disabled', 'DELETE disables the endpoint');
reset role;
select is((select count(*)::int from public.webhook_deliveries d join public.webhook_endpoints e on e.id = d.endpoint_id
            where e.public_id = (select j ->> 'id' from (select j from int01_j where k = 'int01_ep') int01_ep) and d.status = 'pending'), 0,
  'pending deliveries to a disabled endpoint are cancelled');
select ok((select count(*) from public.webhook_deliveries d join public.webhook_endpoints e on e.id = d.endpoint_id
            where e.public_id = (select j ->> 'id' from (select j from int01_j where k = 'int01_ep') int01_ep)
              and d.status = 'cancelled') > 0,
  'cancelled deliveries are kept as history, not deleted');

-- endpoint cap
select tests.authenticate_as_service_role();
select public.partner_create_webhook_endpoint('00000000-0000-0000-0000-000000760c02', format('https://cap%s.example.test/in', g), null, null)
  from generate_series(1, 9) g;
select is(public.partner_create_webhook_endpoint('00000000-0000-0000-0000-000000760c02', 'https://cap10.example.test/in', null, null) ->> 'error',
  'endpoint_limit_reached', 'at most 10 enabled endpoints per environment');

-- ---------------------------------------------------------------------------
-- 12. Portal reads + portal endpoint management
-- ---------------------------------------------------------------------------
select tests.authenticate_as('00000000-0000-0000-0000-0000000a0001', 'aal2');
select ok((select count(*) from public.webhook_deliveries) > 0, 'org admin reads the delivery log');
select ok((select count(*) from public.webhook_delivery_attempts) > 0, 'org admin reads delivery attempts');
insert into int01_j select 'int01_portal_ep', public.integration_admin_create_webhook_endpoint('sandbox', 'https://portal.example.test/in', null, array['patient.enrolled']);
select matches((select j ->> 'secret' from (select j from int01_j where k = 'int01_portal_ep') int01_portal_ep), '^whsec_', 'portal create returns the secret once');
select is(public.integration_admin_disable_webhook_endpoint(
            (select id from public.webhook_endpoints where public_id = (select j ->> 'id' from (select j from int01_j where k = 'int01_portal_ep') int01_portal_ep))) ->> 'status',
  'disabled', 'portal disables an endpoint');
select tests.authenticate_as('00000000-0000-0000-0000-0000000a0002', 'aal2');
select is((select count(*)::int from public.webhook_deliveries), 0, 'a physician sees no delivery log');
select throws_ok($$ select public.integration_admin_rotate_webhook_secret(gen_random_uuid()) $$,
  '42501', null, 'a physician cannot rotate secrets');
select tests.authenticate_as('00000000-0000-0000-0000-0000000a0001', 'aal2');
select public.integration_admin_revoke_api_client('00000000-0000-0000-0000-000000760c01');
reset role;
select is((select count(*)::int from public.api_access_tokens where api_client_id = '00000000-0000-0000-0000-000000760c01'), 0,
  'revoking a client deletes its tokens');
select is((select count(*)::int from public.audit_log where event_type = 'api_client_revoked'), 1, 'revocation audited');

-- ---------------------------------------------------------------------------
-- 13. Scheduling
-- ---------------------------------------------------------------------------
select is((select count(*)::int from cron.job where jobname in ('int02_kick_webhook_worker', 'int01_partner_api_cleanup')), 2,
  'delivery kick + cleanup are scheduled');
select lives_ok($$ select public._cron_kick_webhook_worker() $$,
  'the worker kick is a no-op (notice only) when the Vault secrets are not configured');

select * from finish();
rollback;
