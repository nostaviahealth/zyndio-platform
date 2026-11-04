-- INT-01 / INT-02 / INT-03 / PP-03: functions for the partner API.
-- Runs after APP-01 (20261104160000): enrolment invites go through its
-- issue_patient_invite() / patient_invites, not a password link.
--
--   * internal helpers (_iso_utc, _integration_public_id, _emit_integration_event,
--     _partner_patient_json, ...): no client grant, called only from the
--     SECURITY DEFINER functions below.
--   * partner_* / webhook_*: service_role only. Called by the partner-api and
--     deliver-webhooks Edge Functions after they have authenticated the
--     partner's bearer token. Business errors come back as {"error": "<code>"}
--     so the Edge Function can map them to the API's stable error codes.
--   * integration_admin_*: the PP-03 portal page (supabase.rpc with the
--     org admin's own session). org_admin + aal2 + own org, re-checked here,
--     every change audited. Allowlisted for authenticated in test 747.
--   * triggers: patient.activated on the first sign-in (auth.users) and
--     consent.updated on any consents change, whatever the consent
--     workstream does to that table's columns (rows are read via to_jsonb).
--   * integration_wearable_summary / integration_connected_sources: stubs
--     returning empty data until wearable_daily lands (data-pipeline branch
--     replaces them with create or replace, same signature).

-- ---------------------------------------------------------------------------
-- Internal helpers
-- ---------------------------------------------------------------------------

-- ISO 8601, UTC, millisecond precision, 'Z' suffix - the API's one timestamp format.
create function public._iso_utc(p_ts timestamptz)
returns text
language sql
stable
set search_path = pg_catalog
as $$
  select to_char(p_ts at time zone 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS.MS"Z"');
$$;

-- Neutral public ids: evt_ / whe_ + 24 hex chars (96 random bits).
create function public._integration_public_id(p_prefix text)
returns text
language sql
volatile
set search_path = pg_catalog, extensions
as $$
  select p_prefix || '_' || encode(extensions.gen_random_bytes(12), 'hex');
$$;

-- Retry schedule after failed attempt n (1-based): 1m, 5m, 30m, 2h, 6h, 12h,
-- 24h. null => no more retries (dead letter after the 8th attempt).
create function public._webhook_retry_delay(p_attempt int)
returns interval
language sql
immutable
set search_path = pg_catalog
as $$
  select (array[
    interval '1 minute', interval '5 minutes', interval '30 minutes', interval '2 hours',
    interval '6 hours', interval '12 hours', interval '24 hours'
  ])[p_attempt];
$$;

-- An API client that is still live: (org_id, environment). Raises for a
-- missing or revoked client so no partner_* RPC can act for one.
create function public._partner_client(p_api_client_id uuid, out org_id uuid, out environment text, out client_id text)
language plpgsql
stable
security definer
set search_path = pg_catalog, public
as $$
begin
  select c.org_id, c.environment, c.client_id into org_id, environment, client_id
    from public.api_clients c
   where c.id = p_api_client_id and c.revoked_at is null;
  if not found then
    raise exception 'api client not found or revoked' using errcode = '42501';
  end if;
end;
$$;

-- Records an event and fans it out to every enabled endpoint of the same org
-- and environment that subscribes to its type. Same transaction as the change
-- that caused it, so an event is never lost (at-least-once starts here).
create function public._emit_integration_event(
  p_org_id uuid,
  p_environment text,
  p_event_type text,
  p_data jsonb
)
returns text
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
declare
  v_event_id uuid;
  v_public_id text := public._integration_public_id('evt');
begin
  insert into public.webhook_events (public_id, org_id, environment, event_type, data)
    values (v_public_id, p_org_id, p_environment, p_event_type, p_data)
    returning id into v_event_id;

  insert into public.webhook_deliveries (event_id, endpoint_id, org_id)
    select v_event_id, e.id, e.org_id
      from public.webhook_endpoints e
     where e.org_id = p_org_id
       and e.environment = p_environment
       and e.disabled_at is null
       and p_event_type = any (e.event_types);

  return v_public_id;
end;
$$;

-- INT-03 hooks for the data-pipeline branch: empty until wearable_daily
-- exists. Replace with create or replace (same signature, same grants).
create function public.integration_wearable_summary(p_patient_id uuid)
returns jsonb
language sql
stable
security definer
set search_path = pg_catalog, public
as $$
  select jsonb_build_object('sources', '[]'::jsonb, 'daily', '[]'::jsonb);
$$;

create function public.integration_connected_sources(p_patient_id uuid)
returns jsonb
language sql
stable
security definer
set search_path = pg_catalog, public
as $$
  select '[]'::jsonb;
$$;

-- The API's patient object. Never includes patients.id / auth.users.id.
-- Consents are read through to_jsonb() so a column change by the consent
-- workstream degrades a field to null instead of breaking the API.
create function public._partner_patient_json(p_link_id uuid)
returns jsonb
language sql
stable
security definer
set search_path = pg_catalog, public
as $$
  select jsonb_build_object(
    'object', 'patient',
    'zyndio_patient_id', l.zyndio_patient_id,
    'environment', l.environment,
    'status', case
      when l.deactivated_at is not null then 'deactivated'
      when coalesce(l.activated_at, u.last_sign_in_at) is not null then 'active'
      else 'invited'
    end,
    'email', u.email,
    'given_name', l.given_name,
    'family_name', l.family_name,
    'phone', l.phone,
    'enrolled_at', public._iso_utc(l.enrolled_at),
    'activated_at', public._iso_utc(coalesce(l.activated_at, u.last_sign_in_at)),
    'deactivated_at', public._iso_utc(l.deactivated_at),
    'last_invited_at', public._iso_utc(l.last_invited_at),
    'consents', coalesce((
      select jsonb_agg(jsonb_build_object(
               'consent_type', c.j ->> 'consent_type',
               'granted', c.j -> 'granted',
               'version', c.j ->> 'version',
               'updated_at', public._iso_utc((c.j ->> 'updated_at')::timestamptz)
             ) order by c.j ->> 'consent_type')
        from (
          select distinct on (to_jsonb(cr) ->> 'consent_type') to_jsonb(cr) as j
            from public.consents cr
           where cr.patient_id = l.patient_id
           order by to_jsonb(cr) ->> 'consent_type', to_jsonb(cr) ->> 'updated_at' desc nulls last
        ) c
    ), '[]'::jsonb),
    'connected_sources', public.integration_connected_sources(l.patient_id)
  )
  from public.zyndio_patient_links l
  join auth.users u on u.id = l.patient_id
  where l.id = p_link_id;
$$;

-- New invite for a partner-enrolled patient through the one patient-invite
-- path (APP-01, 20261104160000): issue_patient_invite() records it in
-- patient_invites (revoking any earlier open invite) and the email is a
-- credential-free 'patient_invite' outbox row - the same row
-- _shared/patientInvite.ts sendPatientInvite() queues for create-patient. The
-- patient then signs in with an emailed one-time code; their first sign-in
-- accepts the invite. Done in SQL (not via the TS helper) so enrolment, link,
-- invite and event commit or roll back together.
create function public._partner_issue_invite(p_link_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
declare
  v_link public.zyndio_patient_links%rowtype;
  v_invite jsonb;
begin
  select * into v_link from public.zyndio_patient_links where id = p_link_id;

  v_invite := public.issue_patient_invite(v_link.patient_id, null, 'api');

  insert into public.notification_outbox (user_id, org_id, type, payload)
    values (v_link.patient_id, v_link.org_id, 'patient_invite',
            jsonb_build_object('email', v_invite ->> 'email', 'invite_id', v_invite ->> 'invite_id'));

  update public.zyndio_patient_links
     set last_invited_at = now(), invite_count = invite_count + 1, updated_at = now()
   where id = p_link_id;

  return jsonb_build_object(
    'object', 'invite',
    'zyndio_patient_id', v_link.zyndio_patient_id,
    'sent_at', public._iso_utc(now())
  );
end;
$$;

-- ---------------------------------------------------------------------------
-- Webhook endpoint core (shared by the partner API and the portal)
-- ---------------------------------------------------------------------------

-- null when the URL is acceptable, else an error code. HTTPS only; hostnames
-- only (no IP literals, no userinfo); no localhost / .local / .internal. A
-- local receiver (http or https on localhost / 127.0.0.1) is allowed only for
-- sandbox and only when app.webhooks_allow_local_receivers = 'on' (local dev
-- and tests). The delivery worker also refuses redirects. DNS that resolves a
-- public hostname to a private address is not covered here (see docs).
create function public._webhook_url_error(p_url text, p_environment text)
returns text
language plpgsql
stable
set search_path = pg_catalog
as $$
declare
  v_scheme text;
  v_host text;
  v_local boolean;
begin
  if p_url is null or char_length(p_url) > 2048 or p_url ~ '[[:space:][:cntrl:]]' then
    return 'invalid_url';
  end if;
  v_scheme := lower(substring(p_url from '^([A-Za-z][A-Za-z0-9+.-]*)://'));
  if v_scheme is null then
    return 'invalid_url';
  end if;
  if p_url ~ '^[A-Za-z][A-Za-z0-9+.-]*://[^/?#]*@' then
    return 'invalid_url';
  end if;
  v_host := lower(substring(p_url from '^[A-Za-z][A-Za-z0-9+.-]*://(\[[^]]*\]|[^/:?#]+)'));
  if v_host is null or v_host = '' then
    return 'invalid_url';
  end if;
  v_host := rtrim(v_host, '.');

  v_local := v_host in ('localhost', '127.0.0.1');
  if v_local
     and p_environment = 'sandbox'
     and coalesce(current_setting('app.webhooks_allow_local_receivers', true), '') = 'on'
     and v_scheme in ('http', 'https') then
    return null;
  end if;

  if v_host = 'localhost'
     or v_host like '%.localhost'
     or v_host like '%.local'
     or v_host like '%.internal'
     or v_host like '[%'
     or v_host ~ '^[0-9.]+$'
     or v_host ~ '^0x[0-9a-f.x]+$'
     or v_host !~ '\.' then
    return 'url_not_allowed';
  end if;
  if v_scheme <> 'https' then
    return 'https_required';
  end if;
  return null;
end;
$$;

create function public._webhook_endpoint_json(p_endpoint_id uuid, p_include_secret boolean)
returns jsonb
language sql
stable
security definer
set search_path = pg_catalog, public
as $$
  select jsonb_build_object(
    'object', 'webhook_endpoint',
    'id', e.public_id,
    'environment', e.environment,
    'url', e.url,
    'description', e.description,
    'event_types', to_jsonb(e.event_types),
    'status', case when e.disabled_at is null then 'enabled' else 'disabled' end,
    'created_at', public._iso_utc(e.created_at),
    'secret_rotated_at', public._iso_utc(e.secret_rotated_at)
  ) || case when p_include_secret then jsonb_build_object('secret', e.secret) else '{}'::jsonb end
  from public.webhook_endpoints e
  where e.id = p_endpoint_id;
$$;

create function public._webhook_endpoint_create(
  p_org_id uuid,
  p_environment text,
  p_url text,
  p_description text,
  p_event_types text[],
  p_api_client_id uuid,
  p_user_id uuid
)
returns jsonb
language plpgsql
security definer
set search_path = pg_catalog, public, extensions
as $$
declare
  v_url_error text := public._webhook_url_error(p_url, p_environment);
  v_types text[];
  v_id uuid;
begin
  if v_url_error is not null then
    return jsonb_build_object('error', v_url_error);
  end if;
  if p_description is not null and char_length(p_description) > 200 then
    return jsonb_build_object('error', 'invalid_request');
  end if;
  v_types := coalesce(p_event_types,
    array['patient.enrolled', 'patient.activated', 'patient.deactivated', 'consent.updated']);
  if cardinality(v_types) = 0
     or not v_types <@ array['patient.enrolled', 'patient.activated', 'patient.deactivated', 'consent.updated'] then
    return jsonb_build_object('error', 'invalid_event_types');
  end if;
  select array_agg(distinct t order by t) into v_types from unnest(v_types) t;

  -- serialise creates per org + environment so the 10-endpoint cap holds
  perform pg_advisory_xact_lock(hashtextextended('webhook_endpoints:' || p_org_id::text || ':' || p_environment, 0));
  if (select count(*) from public.webhook_endpoints
       where org_id = p_org_id and environment = p_environment and disabled_at is null) >= 10 then
    return jsonb_build_object('error', 'endpoint_limit_reached');
  end if;

  insert into public.webhook_endpoints (
    public_id, org_id, environment, url, description, event_types, secret,
    created_by_client, created_by_user
  ) values (
    public._integration_public_id('whe'), p_org_id, p_environment, p_url,
    nullif(btrim(p_description), ''), v_types,
    'whsec_' || encode(extensions.gen_random_bytes(24), 'hex'),
    p_api_client_id, p_user_id
  ) returning id into v_id;

  perform public._audit_log_insert('webhook_endpoint_created', p_user_id, null, p_org_id,
    jsonb_build_object('endpoint_id', v_id, 'environment', p_environment, 'url', p_url,
                       'via', case when p_api_client_id is null then 'portal' else 'api' end));

  return public._webhook_endpoint_json(v_id, true);
end;
$$;

create function public._webhook_endpoint_rotate(p_endpoint_id uuid, p_user_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = pg_catalog, public, extensions
as $$
declare
  v_org uuid;
begin
  update public.webhook_endpoints
     set previous_secret = secret,
         previous_secret_expires_at = now() + interval '24 hours',
         secret = 'whsec_' || encode(extensions.gen_random_bytes(24), 'hex'),
         secret_rotated_at = now()
   where id = p_endpoint_id and disabled_at is null
   returning org_id into v_org;
  if not found then
    return jsonb_build_object('error', 'not_found');
  end if;
  perform public._audit_log_insert('webhook_endpoint_secret_rotated', p_user_id, null, v_org,
    jsonb_build_object('endpoint_id', p_endpoint_id));
  return public._webhook_endpoint_json(p_endpoint_id, true);
end;
$$;

-- Disabling cancels the endpoint's pending deliveries; delivered / dead-letter
-- history stays for the log.
create function public._webhook_endpoint_disable(p_endpoint_id uuid, p_user_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
declare
  v_org uuid;
begin
  update public.webhook_endpoints
     set disabled_at = now(), previous_secret = null, previous_secret_expires_at = null
   where id = p_endpoint_id and disabled_at is null
   returning org_id into v_org;
  if not found then
    return jsonb_build_object('error', 'not_found');
  end if;
  update public.webhook_deliveries
     set status = 'cancelled', completed_at = now(), locked_until = null
   where endpoint_id = p_endpoint_id and status = 'pending';
  perform public._audit_log_insert('webhook_endpoint_disabled', p_user_id, null, v_org,
    jsonb_build_object('endpoint_id', p_endpoint_id));
  return public._webhook_endpoint_json(p_endpoint_id, false);
end;
$$;

-- ---------------------------------------------------------------------------
-- partner_* : OAuth, idempotency (service_role only)
-- ---------------------------------------------------------------------------

-- client_credentials grant. p_secret_hash is sha256(client_secret) computed by
-- the Edge Function; comparing hashes here leaks nothing useful about the
-- secret. Requested scopes must be a subset of the client's.
create function public.partner_issue_token(
  p_client_id text,
  p_secret_hash text,
  p_requested_scopes text[],
  p_token_hash text
)
returns jsonb
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
declare
  v_client public.api_clients%rowtype;
  v_scopes text[];
begin
  select * into v_client from public.api_clients where client_id = p_client_id;
  if not found or v_client.revoked_at is not null or v_client.secret_hash <> p_secret_hash then
    return jsonb_build_object('error', 'invalid_client');
  end if;

  if p_requested_scopes is null then
    v_scopes := v_client.scopes;
  elsif cardinality(p_requested_scopes) = 0 or not p_requested_scopes <@ v_client.scopes then
    return jsonb_build_object('error', 'invalid_scope');
  else
    v_scopes := p_requested_scopes;
  end if;
  select array_agg(distinct s order by s) into v_scopes from unnest(v_scopes) s;

  insert into public.api_access_tokens (api_client_id, token_hash, scopes, expires_at)
    values (v_client.id, p_token_hash, v_scopes, now() + interval '15 minutes');
  update public.api_clients set last_used_at = now() where id = v_client.id;

  return jsonb_build_object('scopes', to_jsonb(v_scopes), 'expires_in', 900, 'environment', v_client.environment);
end;
$$;

-- Bearer token -> principal, or null. A revoked client's tokens die with it.
create function public.partner_authenticate(p_token_hash text)
returns jsonb
language sql
stable
security definer
set search_path = pg_catalog, public
as $$
  select jsonb_build_object(
    'api_client_id', c.id,
    'client_id', c.client_id,
    'environment', c.environment,
    'scopes', to_jsonb(t.scopes)
  )
  from public.api_access_tokens t
  join public.api_clients c on c.id = t.api_client_id
  where t.token_hash = p_token_hash
    and t.expires_at > now()
    and c.revoked_at is null;
$$;

-- Reserve an Idempotency-Key. state:
--   new         -> run the request, then partner_idempotency_complete / _abandon
--   replay      -> return response_status / response_body as-is
--   in_progress -> a request with this key is still running (409)
--   mismatch    -> key reused with a different method / path / body (422)
-- Keys expire after 7 days. A reservation left in_progress for 5 minutes
-- (crashed worker) can be taken over.
create function public.partner_idempotency_begin(
  p_api_client_id uuid,
  p_key text,
  p_method text,
  p_path text,
  p_request_hash text
)
returns jsonb
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
declare
  v_row public.api_idempotency_keys%rowtype;
begin
  perform public._partner_client(p_api_client_id);

  delete from public.api_idempotency_keys
   where api_client_id = p_api_client_id and idempotency_key = p_key and expires_at <= now();

  insert into public.api_idempotency_keys (api_client_id, idempotency_key, request_method, request_path, request_hash)
    values (p_api_client_id, p_key, p_method, p_path, p_request_hash)
    on conflict (api_client_id, idempotency_key) do nothing;
  if found then
    return jsonb_build_object('state', 'new');
  end if;

  select * into v_row from public.api_idempotency_keys
   where api_client_id = p_api_client_id and idempotency_key = p_key
   for update;

  if v_row.request_method <> p_method or v_row.request_path <> p_path or v_row.request_hash <> p_request_hash then
    return jsonb_build_object('state', 'mismatch');
  end if;
  if v_row.completed_at is null then
    if v_row.created_at < now() - interval '5 minutes' then
      update public.api_idempotency_keys set created_at = now() where id = v_row.id;
      return jsonb_build_object('state', 'new');
    end if;
    return jsonb_build_object('state', 'in_progress');
  end if;
  return jsonb_build_object('state', 'replay', 'response_status', v_row.response_status,
                            'response_body', v_row.response_body);
end;
$$;

create function public.partner_idempotency_complete(
  p_api_client_id uuid,
  p_key text,
  p_response_status int,
  p_response_body jsonb
)
returns void
language sql
security definer
set search_path = pg_catalog, public
as $$
  update public.api_idempotency_keys
     set response_status = p_response_status, response_body = p_response_body, completed_at = now()
   where api_client_id = p_api_client_id and idempotency_key = p_key and completed_at is null;
$$;

-- 5xx outcomes are not stored: the partner retries with the same key.
create function public.partner_idempotency_abandon(p_api_client_id uuid, p_key text)
returns void
language sql
security definer
set search_path = pg_catalog, public
as $$
  delete from public.api_idempotency_keys
   where api_client_id = p_api_client_id and idempotency_key = p_key and completed_at is null;
$$;

-- ---------------------------------------------------------------------------
-- partner_* : patients (INT-01, INT-03)
-- ---------------------------------------------------------------------------

-- Internal ids the Edge Function needs for GoTrue calls. Never returned to
-- the partner.
create function public.partner_resolve_patient(p_api_client_id uuid, p_zyndio_patient_id text)
returns jsonb
language sql
stable
security definer
set search_path = pg_catalog, public
as $$
  select jsonb_build_object(
    'user_id', l.patient_id,
    'activated', coalesce(l.activated_at, u.last_sign_in_at) is not null,
    'deactivated', l.deactivated_at is not null
  )
  from public._partner_client(p_api_client_id) c
  join public.zyndio_patient_links l
    on l.org_id = c.org_id and l.environment = c.environment and l.zyndio_patient_id = p_zyndio_patient_id
  join auth.users u on u.id = l.patient_id;
$$;

create function public.partner_get_patient(p_api_client_id uuid, p_zyndio_patient_id text)
returns jsonb
language sql
stable
security definer
set search_path = pg_catalog, public
as $$
  select public._partner_patient_json(l.id)
  from public._partner_client(p_api_client_id) c
  join public.zyndio_patient_links l
    on l.org_id = c.org_id and l.environment = c.environment and l.zyndio_patient_id = p_zyndio_patient_id;
$$;

-- Keyset page ordered by (enrolled_at, zyndio_patient_id). Each item carries
-- _sort (full-precision enrolled_at) for the next cursor; the Edge Function
-- strips it. p_limit rows are returned (the caller asks for limit + 1).
create function public.partner_list_patients(
  p_api_client_id uuid,
  p_after_sort text,
  p_after_id text,
  p_limit int
)
returns jsonb
language sql
stable
security definer
set search_path = pg_catalog, public
as $$
  select coalesce(jsonb_agg(public._partner_patient_json(p.id)
                            || jsonb_build_object('_sort', p.enrolled_at::text)
                            order by p.enrolled_at, p.zyndio_patient_id), '[]'::jsonb)
  from (
    select l.id, l.enrolled_at, l.zyndio_patient_id
      from public._partner_client(p_api_client_id) c
      join public.zyndio_patient_links l on l.org_id = c.org_id and l.environment = c.environment
     where p_after_sort is null
        or (l.enrolled_at, l.zyndio_patient_id) > (p_after_sort::timestamptz, p_after_id)
     order by l.enrolled_at, l.zyndio_patient_id
     limit greatest(1, least(p_limit, 101))
  ) p;
$$;

-- POST /v1/patients. p_user_id is the auth.users row the Edge Function just
-- minted (same admin.createUser pattern as create-patient). Mirrors
-- create_patient_record()'s refusals (20261102161000) - never bind a patient
-- record to a staff, platform-admin, self-signup or existing-patient account
-- - but runs as the API client's org instead of a care_coordinator session,
-- then adds the external id link, the invite, the patient.enrolled event and
-- the audit row in the same transaction.
create function public.partner_enrol_patient(
  p_api_client_id uuid,
  p_user_id uuid,
  p_zyndio_patient_id text,
  p_given_name text,
  p_family_name text,
  p_phone text
)
returns jsonb
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
declare
  v_client record;
  v_link_id uuid;
begin
  select * into v_client from public._partner_client(p_api_client_id);

  if exists (select 1 from public.zyndio_patient_links
              where org_id = v_client.org_id and environment = v_client.environment
                and zyndio_patient_id = p_zyndio_patient_id) then
    return jsonb_build_object('error', 'patient_already_exists');
  end if;

  if not exists (select 1 from auth.users where id = p_user_id) then
    raise exception 'account not found' using errcode = 'P0002';
  end if;
  if exists (select 1 from public.org_members where user_id = p_user_id)
     or exists (select 1 from public.platform_admins where user_id = p_user_id)
     or public.is_patient_self_signup(p_user_id)
     or exists (select 1 from public.patients where id = p_user_id) then
    return jsonb_build_object('error', 'email_unavailable');
  end if;

  insert into public.patients (id, org_id, display_name, mrn)
    values (p_user_id, v_client.org_id,
            nullif(btrim(concat_ws(' ', p_given_name, p_family_name)), ''), null);

  insert into public.patient_record_links (
    app_user_id, org_id, telehealth_patient_id, status, linked_at, proof_method
  ) values (
    p_user_id, v_client.org_id, 'clinic:' || p_user_id::text, 'active', now(), 'clinic_provisioned'
  );

  insert into public.zyndio_patient_links (
    org_id, environment, zyndio_patient_id, patient_id, given_name, family_name, phone, enrolled_by_client
  ) values (
    v_client.org_id, v_client.environment, p_zyndio_patient_id, p_user_id,
    p_given_name, p_family_name, p_phone, p_api_client_id
  ) returning id into v_link_id;

  perform public._partner_issue_invite(v_link_id);

  perform public._emit_integration_event(v_client.org_id, v_client.environment, 'patient.enrolled',
    jsonb_build_object('zyndio_patient_id', p_zyndio_patient_id, 'status', 'invited',
                       'enrolled_at', public._iso_utc(now())));

  perform public._audit_log_insert('partner_patient_enrolled', null, p_user_id, v_client.org_id,
    jsonb_build_object('api_client', v_client.client_id, 'environment', v_client.environment));

  return public._partner_patient_json(v_link_id);
exception
  when unique_violation then
    return jsonb_build_object('error', 'patient_already_exists');
  when check_violation then
    return jsonb_build_object('error', 'invalid_request');
end;
$$;

-- POST /v1/patients/{id}/invites. Only for a patient who has not signed in
-- yet; at most one per minute unless p_bypass_throttle (used after an email
-- change, where the old link went to the old address).
create function public.partner_send_invite(
  p_api_client_id uuid,
  p_zyndio_patient_id text,
  p_bypass_throttle boolean default false
)
returns jsonb
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
declare
  v_client record;
  v_link public.zyndio_patient_links%rowtype;
  v_result jsonb;
begin
  select * into v_client from public._partner_client(p_api_client_id);
  select * into v_link from public.zyndio_patient_links
   where org_id = v_client.org_id and environment = v_client.environment
     and zyndio_patient_id = p_zyndio_patient_id
   for update;
  if not found then
    return jsonb_build_object('error', 'not_found');
  end if;
  if v_link.deactivated_at is not null then
    return jsonb_build_object('error', 'patient_deactivated');
  end if;
  if v_link.activated_at is not null
     or exists (select 1 from auth.users where id = v_link.patient_id and last_sign_in_at is not null)
     or exists (select 1 from public.patient_invites where patient_id = v_link.patient_id and accepted_at is not null) then
    return jsonb_build_object('error', 'patient_already_active');
  end if;
  if not coalesce(p_bypass_throttle, false)
     and v_link.last_invited_at is not null
     and v_link.last_invited_at > now() - interval '60 seconds' then
    return jsonb_build_object('error', 'rate_limited');
  end if;

  v_result := public._partner_issue_invite(v_link.id);
  perform public._audit_log_insert('partner_patient_invite_sent', null, v_link.patient_id, v_client.org_id,
    jsonb_build_object('api_client', v_client.client_id));
  return v_result;
end;
$$;

-- PATCH /v1/patients/{id}: contact fields (absent = unchanged, null = clear)
-- and/or {"status": "deactivated"}. Email changes are applied to auth.users by
-- the Edge Function before this runs. Deactivation is one-way via the API:
-- the open invite is revoked, sessions end (force_sign_out), patient.deactivated
-- fires; the Edge Function then bans the auth user, which also makes them
-- ineligible for code sign-in (_patient_code_signin_eligible).
create function public.partner_update_patient(
  p_api_client_id uuid,
  p_zyndio_patient_id text,
  p_patch jsonb
)
returns jsonb
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
declare
  v_client record;
  v_link public.zyndio_patient_links%rowtype;
  v_fields text[];
begin
  select * into v_client from public._partner_client(p_api_client_id);
  select * into v_link from public.zyndio_patient_links
   where org_id = v_client.org_id and environment = v_client.environment
     and zyndio_patient_id = p_zyndio_patient_id
   for update;
  if not found then
    return jsonb_build_object('error', 'not_found');
  end if;

  select array_agg(k order by k) into v_fields
    from jsonb_object_keys(p_patch) k
   where k in ('given_name', 'family_name', 'phone', 'email');

  if p_patch ?| array['given_name', 'family_name', 'phone'] then
    update public.zyndio_patient_links
       set given_name = case when p_patch ? 'given_name' then nullif(btrim(p_patch ->> 'given_name'), '') else given_name end,
           family_name = case when p_patch ? 'family_name' then nullif(btrim(p_patch ->> 'family_name'), '') else family_name end,
           phone = case when p_patch ? 'phone' then nullif(btrim(p_patch ->> 'phone'), '') else phone end,
           updated_at = now()
     where id = v_link.id
     returning * into v_link;
    update public.patients
       set display_name = nullif(btrim(concat_ws(' ', v_link.given_name, v_link.family_name)), '')
     where id = v_link.patient_id;
  end if;

  if v_fields is not null then
    perform public._audit_log_insert('partner_patient_updated', null, v_link.patient_id, v_client.org_id,
      jsonb_build_object('api_client', v_client.client_id, 'fields', to_jsonb(v_fields)));
  end if;

  if p_patch ->> 'status' = 'deactivated' and v_link.deactivated_at is null then
    update public.zyndio_patient_links
       set deactivated_at = now(), updated_at = now()
     where id = v_link.id;
    update public.patient_invites
       set revoked_at = now()
     where patient_id = v_link.patient_id and accepted_at is null and revoked_at is null;
    perform public.force_sign_out(v_link.patient_id);
    perform public._emit_integration_event(v_client.org_id, v_client.environment, 'patient.deactivated',
      jsonb_build_object('zyndio_patient_id', v_link.zyndio_patient_id,
                         'deactivated_at', public._iso_utc(now())));
    perform public._audit_log_insert('partner_patient_deactivated', null, v_link.patient_id, v_client.org_id,
      jsonb_build_object('api_client', v_client.client_id));
  end if;

  return public._partner_patient_json(v_link.id);
exception
  when check_violation then
    return jsonb_build_object('error', 'invalid_request');
end;
$$;

-- GET /v1/patients/{id}/summary (INT-03). Latest biomarkers use exactly the
-- rules of patient_latest_results() (20261029150000): identity-held reports
-- excluded, latest per analyte with the (taken_at, id) tie-break. Open flags:
-- reports awaiting review, reports on identity hold, and latest values that
-- are outside range or need review.
create function public.partner_patient_summary(p_api_client_id uuid, p_zyndio_patient_id text)
returns jsonb
language plpgsql
stable
security definer
set search_path = pg_catalog, public
as $$
declare
  v_client record;
  v_link public.zyndio_patient_links%rowtype;
  v_latest jsonb;
  v_flags jsonb;
begin
  select * into v_client from public._partner_client(p_api_client_id);
  select * into v_link from public.zyndio_patient_links
   where org_id = v_client.org_id and environment = v_client.environment
     and zyndio_patient_id = p_zyndio_patient_id;
  if not found then
    return jsonb_build_object('error', 'not_found');
  end if;

  select coalesce(jsonb_agg(jsonb_build_object(
           'analyte_key', x.analyte_key,
           'label', x.analyte_label,
           'value', x.value,
           'unit', x.unit,
           'status', x.status,
           'range_low', x.range_low,
           'range_high', x.range_high,
           'range_mapped', not x.is_unmapped,
           'taken_at', public._iso_utc(x.taken_at)
         ) order by x.analyte_key), '[]'::jsonb)
    into v_latest
    from (
      select distinct on (lr.analyte_key) lr.*
        from public.lab_results lr
       where lr.patient_id = v_link.patient_id
         and not public.lab_report_held_unscoped(lr.lab_report_id)
         and lr.original_value is null
       order by lr.analyte_key, lr.taken_at desc, lr.id desc
    ) x;

  select coalesce(jsonb_agg(f order by f ->> 'raised_at' desc nulls last, f ->> 'type'), '[]'::jsonb)
    into v_flags
    from (
      select jsonb_build_object('type', 'lab_report_needs_review', 'report_type', r.report_type,
                                'raised_at', public._iso_utc(coalesce(r.flagged_at, r.created_at))) as f
        from public.lab_reports r
       where r.patient_id = v_link.patient_id and r.needs_review
      union all
      select jsonb_build_object('type', 'lab_report_identity_hold', 'report_type', r.report_type,
                                'raised_at', public._iso_utc(r.created_at))
        from public.lab_reports r
       where r.patient_id = v_link.patient_id and r.identity_hold
      union all
      select jsonb_build_object('type', 'biomarker_' || (b ->> 'status'), 'analyte_key', b ->> 'analyte_key',
                                'raised_at', b ->> 'taken_at')
        from jsonb_array_elements(v_latest) b
       where b ->> 'status' in ('outside_range', 'needs_review')
    ) flags;

  return jsonb_build_object(
    'object', 'patient_summary',
    'zyndio_patient_id', v_link.zyndio_patient_id,
    'generated_at', public._iso_utc(now()),
    'biomarkers', v_latest,
    'wearables', public.integration_wearable_summary(v_link.patient_id),
    'open_flags', v_flags
  );
end;
$$;

-- ---------------------------------------------------------------------------
-- partner_* : webhook endpoints (INT-02)
-- ---------------------------------------------------------------------------

create function public.partner_list_webhook_endpoints(
  p_api_client_id uuid,
  p_after_sort text,
  p_after_id text,
  p_limit int
)
returns jsonb
language sql
stable
security definer
set search_path = pg_catalog, public
as $$
  select coalesce(jsonb_agg(public._webhook_endpoint_json(e.id, false)
                            || jsonb_build_object('_sort', e.created_at::text)
                            order by e.created_at, e.public_id), '[]'::jsonb)
  from (
    select w.id, w.created_at, w.public_id
      from public._partner_client(p_api_client_id) c
      join public.webhook_endpoints w on w.org_id = c.org_id and w.environment = c.environment
     where w.disabled_at is null
       and (p_after_sort is null or (w.created_at, w.public_id) > (p_after_sort::timestamptz, p_after_id))
     order by w.created_at, w.public_id
     limit greatest(1, least(p_limit, 101))
  ) e;
$$;

create function public.partner_create_webhook_endpoint(
  p_api_client_id uuid,
  p_url text,
  p_description text,
  p_event_types text[]
)
returns jsonb
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
declare
  v_client record;
begin
  select * into v_client from public._partner_client(p_api_client_id);
  return public._webhook_endpoint_create(v_client.org_id, v_client.environment, p_url, p_description,
                                         p_event_types, p_api_client_id, null);
end;
$$;

create function public.partner_delete_webhook_endpoint(p_api_client_id uuid, p_endpoint_public_id text)
returns jsonb
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
declare
  v_client record;
  v_id uuid;
begin
  select * into v_client from public._partner_client(p_api_client_id);
  select id into v_id from public.webhook_endpoints
   where public_id = p_endpoint_public_id and org_id = v_client.org_id
     and environment = v_client.environment and disabled_at is null;
  if v_id is null then
    return jsonb_build_object('error', 'not_found');
  end if;
  return public._webhook_endpoint_disable(v_id, null);
end;
$$;

create function public.partner_rotate_webhook_secret(p_api_client_id uuid, p_endpoint_public_id text)
returns jsonb
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
declare
  v_client record;
  v_id uuid;
begin
  select * into v_client from public._partner_client(p_api_client_id);
  select id into v_id from public.webhook_endpoints
   where public_id = p_endpoint_public_id and org_id = v_client.org_id
     and environment = v_client.environment and disabled_at is null;
  if v_id is null then
    return jsonb_build_object('error', 'not_found');
  end if;
  return public._webhook_endpoint_rotate(v_id, null);
end;
$$;

-- ---------------------------------------------------------------------------
-- webhook_* : delivery worker (service_role only)
-- ---------------------------------------------------------------------------

-- Claims up to p_limit due deliveries for 2 minutes (skip locked, so parallel
-- workers never double-send inside one claim window). Returns everything the
-- worker needs to sign and send: url, signing secrets (current first, plus the
-- previous one during a rotation overlap) and the envelope.
create function public.webhook_claim_due(p_limit int default 25)
returns jsonb
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
declare
  v_result jsonb;
begin
  with due as (
    select d.id
      from public.webhook_deliveries d
      join public.webhook_endpoints e on e.id = d.endpoint_id
     where d.status = 'pending'
       and d.next_attempt_at <= now()
       and (d.locked_until is null or d.locked_until < now())
       and e.disabled_at is null
     order by d.next_attempt_at
     limit greatest(1, least(coalesce(p_limit, 25), 100))
     for update of d skip locked
  ), claimed as (
    update public.webhook_deliveries d
       set locked_until = now() + interval '2 minutes'
      from due
     where d.id = due.id
    returning d.id, d.event_id, d.endpoint_id, d.attempt_count
  )
  select coalesce(jsonb_agg(jsonb_build_object(
           'delivery_id', c.id,
           'attempt_number', c.attempt_count + 1,
           'url', e.url,
           'secrets', case
             when e.previous_secret is not null and e.previous_secret_expires_at > now()
               then jsonb_build_array(e.secret, e.previous_secret)
             else jsonb_build_array(e.secret)
           end,
           'envelope', jsonb_build_object(
             'event_id', ev.public_id,
             'event_type', ev.event_type,
             'created_at', public._iso_utc(ev.created_at),
             'schema_version', ev.schema_version,
             'data', ev.data
           )
         )), '[]'::jsonb)
    into v_result
    from claimed c
    join public.webhook_endpoints e on e.id = c.endpoint_id
    join public.webhook_events ev on ev.id = c.event_id;
  return v_result;
end;
$$;

-- Logs one attempt and moves the delivery on: 2xx -> succeeded; otherwise
-- the next retry per _webhook_retry_delay, or dead_letter after the last.
create function public.webhook_record_attempt(
  p_delivery_id uuid,
  p_payload_sha256 text,
  p_response_status int,
  p_duration_ms int,
  p_error text
)
returns text
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
declare
  v_delivery public.webhook_deliveries%rowtype;
  v_attempt int;
  v_outcome text;
  v_delay interval;
begin
  select * into v_delivery from public.webhook_deliveries where id = p_delivery_id for update;
  if not found then
    raise exception 'delivery not found' using errcode = 'P0002';
  end if;
  if v_delivery.status <> 'pending' then
    return v_delivery.status;
  end if;

  v_attempt := v_delivery.attempt_count + 1;
  if p_response_status between 200 and 299 then
    v_outcome := 'succeeded';
    update public.webhook_deliveries
       set status = 'succeeded', attempt_count = v_attempt, completed_at = now(), locked_until = null,
           last_response_status = p_response_status, last_error = null
     where id = p_delivery_id;
  else
    v_delay := public._webhook_retry_delay(v_attempt);
    if v_delay is null then
      v_outcome := 'dead_letter';
      update public.webhook_deliveries
         set status = 'dead_letter', attempt_count = v_attempt, completed_at = now(), locked_until = null,
             last_response_status = p_response_status, last_error = left(p_error, 200)
       where id = p_delivery_id;
    else
      v_outcome := 'retry_scheduled';
      update public.webhook_deliveries
         set attempt_count = v_attempt, next_attempt_at = now() + v_delay, locked_until = null,
             last_response_status = p_response_status, last_error = left(p_error, 200)
       where id = p_delivery_id;
    end if;
  end if;

  insert into public.webhook_delivery_attempts (
    delivery_id, org_id, attempt_number, payload_sha256, response_status, duration_ms, error, outcome
  ) values (
    p_delivery_id, v_delivery.org_id, v_attempt, p_payload_sha256, p_response_status,
    greatest(coalesce(p_duration_ms, 0), 0), left(p_error, 200), v_outcome
  );
  return v_outcome;
end;
$$;

-- ---------------------------------------------------------------------------
-- integration_admin_* : PP-03 portal (org_admin + aal2, own org)
-- ---------------------------------------------------------------------------

create function public._require_integration_admin()
returns uuid
language plpgsql
stable
security definer
set search_path = pg_catalog, public
as $$
begin
  if not public.is_org_admin() or not public.has_aal2() or public.current_org_id() is null then
    raise exception 'not authorized' using errcode = '42501';
  end if;
  return public.current_org_id();
end;
$$;

-- Returns the client secret exactly once; only its sha256 is stored.
create function public.integration_admin_create_api_client(
  p_name text,
  p_environment text,
  p_scopes text[]
)
returns jsonb
language plpgsql
security definer
set search_path = pg_catalog, public, extensions
as $$
declare
  v_org uuid := public._require_integration_admin();
  v_secret text := 'zys_' || encode(extensions.gen_random_bytes(32), 'hex');
  v_client_id text;
  v_id uuid;
  v_scopes text[];
begin
  if p_environment not in ('sandbox', 'production') then
    raise exception 'invalid environment' using errcode = '22023';
  end if;
  if p_name is null or char_length(btrim(p_name)) not between 1 and 100 then
    raise exception 'invalid name' using errcode = '22023';
  end if;
  if p_scopes is null or cardinality(p_scopes) = 0
     or not p_scopes <@ array['patients:write', 'patients:read', 'webhooks:manage'] then
    raise exception 'invalid scopes' using errcode = '22023';
  end if;
  select array_agg(distinct s order by s) into v_scopes from unnest(p_scopes) s;

  v_client_id := case p_environment when 'sandbox' then 'zyc_test_' else 'zyc_live_' end
                 || encode(extensions.gen_random_bytes(12), 'hex');

  insert into public.api_clients (org_id, environment, client_id, secret_hash, secret_hint, name, scopes, created_by)
    values (v_org, p_environment, v_client_id, encode(extensions.digest(v_secret, 'sha256'), 'hex'),
            right(v_secret, 4), btrim(p_name), v_scopes, auth.uid())
    returning id into v_id;

  perform public._audit_log_insert('api_client_created', auth.uid(), null, v_org,
    jsonb_build_object('api_client', v_client_id, 'environment', p_environment, 'scopes', to_jsonb(v_scopes)));

  return jsonb_build_object('id', v_id, 'client_id', v_client_id, 'client_secret', v_secret,
                            'environment', p_environment, 'scopes', to_jsonb(v_scopes), 'name', btrim(p_name));
end;
$$;

create function public.integration_admin_revoke_api_client(p_id uuid)
returns void
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
declare
  v_org uuid := public._require_integration_admin();
  v_client_id text;
begin
  update public.api_clients
     set revoked_at = now(), revoked_by = auth.uid()
   where id = p_id and org_id = v_org and revoked_at is null
   returning client_id into v_client_id;
  if not found then
    raise exception 'api client not found' using errcode = 'PT404';
  end if;
  delete from public.api_access_tokens where api_client_id = p_id;
  perform public._audit_log_insert('api_client_revoked', auth.uid(), null, v_org,
    jsonb_build_object('api_client', v_client_id));
end;
$$;

create function public.integration_admin_create_webhook_endpoint(
  p_environment text,
  p_url text,
  p_description text,
  p_event_types text[]
)
returns jsonb
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
declare
  v_org uuid := public._require_integration_admin();
begin
  if p_environment not in ('sandbox', 'production') then
    raise exception 'invalid environment' using errcode = '22023';
  end if;
  return public._webhook_endpoint_create(v_org, p_environment, p_url, p_description, p_event_types,
                                         null, auth.uid());
end;
$$;

create function public.integration_admin_rotate_webhook_secret(p_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
declare
  v_org uuid := public._require_integration_admin();
begin
  if not exists (select 1 from public.webhook_endpoints where id = p_id and org_id = v_org) then
    raise exception 'webhook endpoint not found' using errcode = 'PT404';
  end if;
  return public._webhook_endpoint_rotate(p_id, auth.uid());
end;
$$;

create function public.integration_admin_disable_webhook_endpoint(p_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
declare
  v_org uuid := public._require_integration_admin();
begin
  if not exists (select 1 from public.webhook_endpoints where id = p_id and org_id = v_org) then
    raise exception 'webhook endpoint not found' using errcode = 'PT404';
  end if;
  return public._webhook_endpoint_disable(p_id, auth.uid());
end;
$$;

-- ---------------------------------------------------------------------------
-- Event triggers
-- ---------------------------------------------------------------------------

-- patient.activated: the first sign-in of a partner-enrolled patient. Never
-- blocks the sign-in itself: a failure here is logged as a warning (the
-- patient object still reports "active" from auth.users.last_sign_in_at).
create function public._trg_auth_users_partner_activation()
returns trigger
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
declare
  v_link public.zyndio_patient_links%rowtype;
begin
  if OLD.last_sign_in_at is null and NEW.last_sign_in_at is not null then
    begin
      update public.zyndio_patient_links
         set activated_at = NEW.last_sign_in_at, updated_at = now()
       where patient_id = NEW.id and activated_at is null and deactivated_at is null
       returning * into v_link;
      if found then
        perform public._emit_integration_event(v_link.org_id, v_link.environment, 'patient.activated',
          jsonb_build_object('zyndio_patient_id', v_link.zyndio_patient_id,
                             'activated_at', public._iso_utc(NEW.last_sign_in_at)));
      end if;
    exception when others then
      raise warning 'partner activation event failed for a patient account: %', sqlerrm;
    end;
  end if;
  return NEW;
end;
$$;

create trigger auth_users_partner_activation
  after update of last_sign_in_at on auth.users
  for each row
  execute function public._trg_auth_users_partner_activation();

-- consent.updated: any insert / update / delete on consents for a
-- partner-enrolled patient. Columns are read via to_jsonb() so the consent
-- workstream can add or change columns without breaking this trigger; an
-- update that only touches updated_at is not an event.
create function public._trg_consents_partner_event()
returns trigger
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
declare
  v_row jsonb := case when TG_OP = 'DELETE' then to_jsonb(OLD) else to_jsonb(NEW) end;
  v_link public.zyndio_patient_links%rowtype;
begin
  if TG_OP = 'UPDATE' and (to_jsonb(OLD) - 'updated_at') = (to_jsonb(NEW) - 'updated_at') then
    return null;
  end if;

  select * into v_link from public.zyndio_patient_links
   where patient_id = (v_row ->> 'patient_id')::uuid;
  if not found then
    return null;
  end if;

  perform public._emit_integration_event(v_link.org_id, v_link.environment, 'consent.updated',
    jsonb_build_object(
      'zyndio_patient_id', v_link.zyndio_patient_id,
      'consent_type', v_row ->> 'consent_type',
      'granted', case when TG_OP = 'DELETE' then 'false'::jsonb else coalesce(v_row -> 'granted', 'null'::jsonb) end,
      'document', v_row ->> 'document',
      'version', v_row ->> 'version',
      'revoked_at', public._iso_utc((v_row ->> 'revoked_at')::timestamptz),
      'change', case TG_OP when 'INSERT' then 'created' when 'UPDATE' then 'updated' else 'deleted' end,
      'updated_at', public._iso_utc(coalesce((v_row ->> 'updated_at')::timestamptz, now()))
    ));
  return null;
end;
$$;

create trigger consents_partner_event
  after insert or update or delete on public.consents
  for each row
  execute function public._trg_consents_partner_event();

-- ---------------------------------------------------------------------------
-- Grants. TC-040 already closed default EXECUTE; be explicit anyway.
-- ---------------------------------------------------------------------------

do $$
declare
  f regprocedure;
begin
  foreach f in array array[
    'public._iso_utc(timestamptz)',
    'public._integration_public_id(text)',
    'public._webhook_retry_delay(int)',
    'public._partner_client(uuid)',
    'public._emit_integration_event(uuid, text, text, jsonb)',
    'public.integration_wearable_summary(uuid)',
    'public.integration_connected_sources(uuid)',
    'public._partner_patient_json(uuid)',
    'public._partner_issue_invite(uuid)',
    'public._webhook_url_error(text, text)',
    'public._webhook_endpoint_json(uuid, boolean)',
    'public._webhook_endpoint_create(uuid, text, text, text, text[], uuid, uuid)',
    'public._webhook_endpoint_rotate(uuid, uuid)',
    'public._webhook_endpoint_disable(uuid, uuid)',
    'public._require_integration_admin()',
    'public._trg_auth_users_partner_activation()',
    'public._trg_consents_partner_event()'
  ]::regprocedure[] loop
    execute format('revoke all on function %s from public, anon, authenticated, service_role', f);
  end loop;

  foreach f in array array[
    'public.partner_issue_token(text, text, text[], text)',
    'public.partner_authenticate(text)',
    'public.partner_idempotency_begin(uuid, text, text, text, text)',
    'public.partner_idempotency_complete(uuid, text, int, jsonb)',
    'public.partner_idempotency_abandon(uuid, text)',
    'public.partner_resolve_patient(uuid, text)',
    'public.partner_get_patient(uuid, text)',
    'public.partner_list_patients(uuid, text, text, int)',
    'public.partner_enrol_patient(uuid, uuid, text, text, text, text)',
    'public.partner_send_invite(uuid, text, boolean)',
    'public.partner_update_patient(uuid, text, jsonb)',
    'public.partner_patient_summary(uuid, text)',
    'public.partner_list_webhook_endpoints(uuid, text, text, int)',
    'public.partner_create_webhook_endpoint(uuid, text, text, text[])',
    'public.partner_delete_webhook_endpoint(uuid, text)',
    'public.partner_rotate_webhook_secret(uuid, text)',
    'public.webhook_claim_due(int)',
    'public.webhook_record_attempt(uuid, text, int, int, text)'
  ]::regprocedure[] loop
    execute format('revoke all on function %s from public, anon, authenticated', f);
    execute format('grant execute on function %s to service_role', f);
  end loop;

  foreach f in array array[
    'public.integration_admin_create_api_client(text, text, text[])',
    'public.integration_admin_revoke_api_client(uuid)',
    'public.integration_admin_create_webhook_endpoint(text, text, text, text[])',
    'public.integration_admin_rotate_webhook_secret(uuid)',
    'public.integration_admin_disable_webhook_endpoint(uuid)'
  ]::regprocedure[] loop
    execute format('revoke all on function %s from public, anon', f);
    execute format('grant execute on function %s to authenticated', f);
  end loop;
end
$$;
