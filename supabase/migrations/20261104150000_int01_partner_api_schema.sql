-- INT-01 / INT-02 / INT-03 / PP-03: server-to-server partner API for the
-- zyndio.com backend - schema, RLS and grants.
--
-- Tables (all owned by this workstream):
--   api_clients               OAuth 2.0 client-credentials clients, per org and
--                             per environment (sandbox / production). Only a
--                             SHA-256 hash of the client secret is stored; the
--                             secret itself is shown once at creation.
--   api_access_tokens         15-minute opaque bearer tokens (hash only).
--   api_idempotency_keys      Idempotency-Key -> original response, 7 days.
--   zyndio_patient_links      external id link: zyndio_patient_id <-> patient.
--                             The internal patient uuid never leaves the
--                             server; the API speaks zyndio_patient_id only.
--   webhook_endpoints         partner-registered receivers + signing secret.
--   webhook_events            immutable event log (evt_ ids).
--   webhook_deliveries        one row per (event, endpoint): at-least-once state.
--   webhook_delivery_attempts every attempt: payload sha256, status, timing.
--
-- Access model: every table has forced RLS and no anon/authenticated grants,
-- except read-only column grants for the org-admin portal page (PP-03) on the
-- client / endpoint / delivery-log tables, gated by the usual
-- org_id = current_org_id() AND is_org_admin() AND has_aal2() policy. Secret
-- columns (secret_hash, secret, previous_secret) and event payloads are never
-- granted to a client role. The partner-api / deliver-webhooks Edge Functions
-- use the service role through the SECURITY DEFINER RPCs in the next
-- migration.

-- ---------------------------------------------------------------------------
-- api_clients
-- ---------------------------------------------------------------------------

create table public.api_clients (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null references public.organizations (id) on delete cascade,
  environment text not null check (environment in ('sandbox', 'production')),
  -- zyc_test_* for sandbox, zyc_live_* for production: a sandbox credential
  -- can never be mistaken for (or used as) a production one.
  client_id text not null unique check (client_id ~ '^zyc_(test|live)_[0-9a-f]{24}$'),
  secret_hash text not null check (secret_hash ~ '^[0-9a-f]{64}$'),
  -- last 4 characters of the secret, for recognising it in the portal.
  secret_hint text not null check (char_length(secret_hint) = 4),
  name text not null check (char_length(btrim(name)) between 1 and 100),
  scopes text[] not null check (
    cardinality(scopes) > 0
    and scopes <@ array['patients:write', 'patients:read', 'webhooks:manage']::text[]
  ),
  created_by uuid references auth.users (id) on delete set null,
  created_at timestamptz not null default now(),
  last_used_at timestamptz,
  revoked_at timestamptz,
  revoked_by uuid references auth.users (id) on delete set null,
  constraint api_clients_environment_prefix check (
    (environment = 'sandbox') = (left(client_id, 9) = 'zyc_test_')
  )
);

create index api_clients_org_id_idx on public.api_clients (org_id);

-- ---------------------------------------------------------------------------
-- api_access_tokens (opaque, hashed, 15 minutes)
-- ---------------------------------------------------------------------------

create table public.api_access_tokens (
  id uuid primary key default gen_random_uuid(),
  api_client_id uuid not null references public.api_clients (id) on delete cascade,
  token_hash text not null unique check (token_hash ~ '^[0-9a-f]{64}$'),
  scopes text[] not null,
  expires_at timestamptz not null,
  created_at timestamptz not null default now(),
  check (expires_at <= created_at + interval '15 minutes')
);

create index api_access_tokens_client_idx on public.api_access_tokens (api_client_id);
create index api_access_tokens_expires_idx on public.api_access_tokens (expires_at);

-- ---------------------------------------------------------------------------
-- api_idempotency_keys
-- ---------------------------------------------------------------------------

create table public.api_idempotency_keys (
  id uuid primary key default gen_random_uuid(),
  api_client_id uuid not null references public.api_clients (id) on delete cascade,
  idempotency_key text not null check (char_length(idempotency_key) between 1 and 255),
  request_method text not null,
  request_path text not null,
  request_hash text not null check (request_hash ~ '^[0-9a-f]{64}$'),
  response_status int,
  response_body jsonb,
  created_at timestamptz not null default now(),
  completed_at timestamptz,
  expires_at timestamptz not null default (now() + interval '7 days'),
  unique (api_client_id, idempotency_key)
);

create index api_idempotency_keys_expires_idx on public.api_idempotency_keys (expires_at);

-- ---------------------------------------------------------------------------
-- zyndio_patient_links (external id)
-- ---------------------------------------------------------------------------

create table public.zyndio_patient_links (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null references public.organizations (id) on delete cascade,
  environment text not null check (environment in ('sandbox', 'production')),
  zyndio_patient_id text not null check (zyndio_patient_id ~ '^[A-Za-z0-9][A-Za-z0-9_.:-]{0,127}$'),
  patient_id uuid not null unique references public.patients (id) on delete cascade,
  given_name text check (char_length(given_name) between 1 and 100),
  family_name text check (char_length(family_name) between 1 and 100),
  -- E.164
  phone text check (phone ~ '^\+[1-9][0-9]{6,14}$'),
  enrolled_by_client uuid references public.api_clients (id) on delete set null,
  enrolled_at timestamptz not null default now(),
  activated_at timestamptz,
  deactivated_at timestamptz,
  last_invited_at timestamptz,
  invite_count int not null default 0,
  updated_at timestamptz not null default now(),
  unique (org_id, environment, zyndio_patient_id)
);

-- cursor pagination for GET /v1/patients
create index zyndio_patient_links_page_idx
  on public.zyndio_patient_links (org_id, environment, enrolled_at, zyndio_patient_id);

-- ---------------------------------------------------------------------------
-- webhook_endpoints
-- ---------------------------------------------------------------------------

create table public.webhook_endpoints (
  id uuid primary key default gen_random_uuid(),
  public_id text not null unique check (public_id ~ '^whe_[0-9a-f]{24}$'),
  org_id uuid not null references public.organizations (id) on delete cascade,
  environment text not null check (environment in ('sandbox', 'production')),
  url text not null check (char_length(url) <= 2048 and url ~ '^https?://[^[:space:]]+$'),
  description text check (char_length(description) <= 200),
  event_types text[] not null check (
    cardinality(event_types) > 0
    and event_types <@ array['patient.enrolled', 'patient.activated', 'patient.deactivated', 'consent.updated']::text[]
  ),
  -- HMAC signing secret. Must be readable by the delivery worker, so it is
  -- not hashed; it is never granted to anon/authenticated (column grants
  -- below) and is returned to the partner only on create / rotate.
  secret text not null check (secret ~ '^whsec_[0-9a-f]{48}$'),
  -- After a rotation the old secret keeps signing (second v1=) for 24h.
  previous_secret text check (previous_secret ~ '^whsec_[0-9a-f]{48}$'),
  previous_secret_expires_at timestamptz,
  created_by_client uuid references public.api_clients (id) on delete set null,
  created_by_user uuid references auth.users (id) on delete set null,
  created_at timestamptz not null default now(),
  secret_rotated_at timestamptz,
  disabled_at timestamptz
);

create index webhook_endpoints_org_env_idx on public.webhook_endpoints (org_id, environment, created_at, public_id);

-- ---------------------------------------------------------------------------
-- webhook_events / deliveries / attempts
-- ---------------------------------------------------------------------------

create table public.webhook_events (
  id uuid primary key default gen_random_uuid(),
  public_id text not null unique check (public_id ~ '^evt_[0-9a-f]{24}$'),
  org_id uuid not null references public.organizations (id) on delete cascade,
  environment text not null check (environment in ('sandbox', 'production')),
  event_type text not null check (
    event_type in ('patient.enrolled', 'patient.activated', 'patient.deactivated', 'consent.updated')
  ),
  schema_version int not null default 1,
  data jsonb not null,
  created_at timestamptz not null default now()
);

create index webhook_events_org_idx on public.webhook_events (org_id, created_at);

create table public.webhook_deliveries (
  id uuid primary key default gen_random_uuid(),
  event_id uuid not null references public.webhook_events (id) on delete cascade,
  endpoint_id uuid not null references public.webhook_endpoints (id) on delete cascade,
  org_id uuid not null references public.organizations (id) on delete cascade,
  status text not null default 'pending'
    check (status in ('pending', 'succeeded', 'dead_letter', 'cancelled')),
  attempt_count int not null default 0,
  next_attempt_at timestamptz not null default now(),
  locked_until timestamptz,
  last_response_status int,
  last_error text,
  created_at timestamptz not null default now(),
  completed_at timestamptz,
  unique (event_id, endpoint_id)
);

create index webhook_deliveries_due_idx
  on public.webhook_deliveries (next_attempt_at) where status = 'pending';
create index webhook_deliveries_org_idx on public.webhook_deliveries (org_id, created_at desc);
create index webhook_deliveries_endpoint_idx on public.webhook_deliveries (endpoint_id);

create table public.webhook_delivery_attempts (
  id bigint generated always as identity primary key,
  delivery_id uuid not null references public.webhook_deliveries (id) on delete cascade,
  org_id uuid not null references public.organizations (id) on delete cascade,
  attempt_number int not null check (attempt_number >= 1),
  attempted_at timestamptz not null default now(),
  payload_sha256 text not null check (payload_sha256 ~ '^[0-9a-f]{64}$'),
  -- null when no HTTP response came back (timeout / network error)
  response_status int,
  duration_ms int not null check (duration_ms >= 0),
  error text check (char_length(error) <= 200),
  outcome text not null check (outcome in ('succeeded', 'retry_scheduled', 'dead_letter'))
);

create index webhook_delivery_attempts_delivery_idx on public.webhook_delivery_attempts (delivery_id, attempt_number);

-- ---------------------------------------------------------------------------
-- RLS: forced everywhere, closed by default
-- ---------------------------------------------------------------------------

alter table public.api_clients enable row level security;
alter table public.api_clients force row level security;
alter table public.api_access_tokens enable row level security;
alter table public.api_access_tokens force row level security;
alter table public.api_idempotency_keys enable row level security;
alter table public.api_idempotency_keys force row level security;
alter table public.zyndio_patient_links enable row level security;
alter table public.zyndio_patient_links force row level security;
alter table public.webhook_endpoints enable row level security;
alter table public.webhook_endpoints force row level security;
alter table public.webhook_events enable row level security;
alter table public.webhook_events force row level security;
alter table public.webhook_deliveries enable row level security;
alter table public.webhook_deliveries force row level security;
alter table public.webhook_delivery_attempts enable row level security;
alter table public.webhook_delivery_attempts force row level security;

revoke all on public.api_clients from anon, authenticated;
revoke all on public.api_access_tokens from anon, authenticated;
revoke all on public.api_idempotency_keys from anon, authenticated;
revoke all on public.zyndio_patient_links from anon, authenticated;
revoke all on public.webhook_endpoints from anon, authenticated;
revoke all on public.webhook_events from anon, authenticated;
revoke all on public.webhook_deliveries from anon, authenticated;
revoke all on public.webhook_delivery_attempts from anon, authenticated;

-- PP-03 portal reads: column grants (no secret / hash / payload column), and
-- an org-admin + aal2 + own-org policy on each. No write grant at all: every
-- change goes through the integration_admin_* RPCs (audited).
grant select (id, org_id, environment, client_id, secret_hint, name, scopes,
              created_by, created_at, last_used_at, revoked_at, revoked_by)
  on public.api_clients to authenticated;
grant select (id, public_id, org_id, environment, url, description, event_types,
              created_by_client, created_by_user, created_at, secret_rotated_at,
              previous_secret_expires_at, disabled_at)
  on public.webhook_endpoints to authenticated;
grant select (id, public_id, org_id, environment, event_type, schema_version, created_at)
  on public.webhook_events to authenticated;
grant select (id, event_id, endpoint_id, org_id, status, attempt_count, next_attempt_at,
              last_response_status, last_error, created_at, completed_at)
  on public.webhook_deliveries to authenticated;
grant select (id, delivery_id, org_id, attempt_number, attempted_at, payload_sha256,
              response_status, duration_ms, error, outcome)
  on public.webhook_delivery_attempts to authenticated;

create policy api_clients_org_admin_select on public.api_clients
  for select to authenticated
  using (org_id = public.current_org_id() and public.is_org_admin() and public.has_aal2());

create policy webhook_endpoints_org_admin_select on public.webhook_endpoints
  for select to authenticated
  using (org_id = public.current_org_id() and public.is_org_admin() and public.has_aal2());

create policy webhook_events_org_admin_select on public.webhook_events
  for select to authenticated
  using (org_id = public.current_org_id() and public.is_org_admin() and public.has_aal2());

create policy webhook_deliveries_org_admin_select on public.webhook_deliveries
  for select to authenticated
  using (org_id = public.current_org_id() and public.is_org_admin() and public.has_aal2());

create policy webhook_delivery_attempts_org_admin_select on public.webhook_delivery_attempts
  for select to authenticated
  using (org_id = public.current_org_id() and public.is_org_admin() and public.has_aal2());

comment on table public.zyndio_patient_links is
  'INT-01: zyndio_patient_id <-> patients.id. Service role only; the partner API never returns patient_id.';
comment on table public.webhook_endpoints is
  'INT-02: partner webhook receivers. secret/previous_secret are service-role only.';
