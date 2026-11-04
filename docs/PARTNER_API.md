# Partner API (zyndio.com integration) — v1 reference

Server-to-server API the zyndio.com backend uses to enrol patients, read their status and
summary, and receive webhooks. PRD: INT-01, INT-02, INT-03 (plus PP-03 for the portal page).

- **Base URL:** `https://platform.zyndio.com/v1` once the Zyndio hostname proxies to the
  `partner-api` Edge Function. Until then, call the function directly at
  `https://<project>.supabase.co/functions/v1/partner-api/v1`. Both paths route the same way.
- **Implementation:** `supabase/functions/partner-api/` (HTTP layer),
  `supabase/functions/deliver-webhooks/` (delivery worker),
  `supabase/migrations/20261104170000_int01_*` … `20261104170200_int02_*` (tables, RPCs, cron).
- **Environments:** each API client is either **sandbox** (`zyc_test_…`) or **production**
  (`zyc_live_…`). Patients and webhook endpoints belong to the environment of the client that
  created them, so sandbox and production never see each other's data, even when they use the
  same `zyndio_patient_id`.

All examples use fictional data.

## Conventions

| | |
|---|---|
| Format | JSON, `snake_case` fields, `Content-Type: application/json` |
| Timestamps | ISO 8601 UTC with milliseconds, e.g. `2026-11-04T15:00:00.000Z` |
| Patient id | `zyndio_patient_id` only: 1–128 chars, `[A-Za-z0-9][A-Za-z0-9_.:-]*`. The platform's internal patient id never appears in a response. |
| Other ids | `evt_…` (event), `whe_…` (webhook endpoint), `req_…` (request) |
| Request id | Every response has `X-Request-Id: req_…`, which matches `error.request_id`. |
| Body size | 16 KB max (`413 payload_too_large`) |
| Caching | `Cache-Control: no-store` on every response |

### Idempotency

Every `POST` (except `/oauth/token`) **must** send `Idempotency-Key` (1–255 printable ASCII
characters, for example a UUID). Missing key: `400 idempotency_key_required`.

- Same key + same method, path and body within **7 days**: the original status and body are
  returned unchanged, with `Idempotent-Replayed: true`. This includes 4xx results.
- Same key with a different request: `422 idempotency_key_reused`.
- Same key while the first request is still running: `409 idempotency_key_in_use`.
- 5xx results are **not** stored, so retry with the same key.

Keys are scoped per API client.

### Pagination

List endpoints take `limit` (1–100, default 25) and `cursor`. Responses look like this:

```json
{ "object": "list", "data": [ ... ], "has_more": true, "next_cursor": "eyJzIjoi..." }
```

Pass `next_cursor` back unchanged as `cursor`. Treat it as opaque.

### Errors

One shape for every error:

```json
{ "error": { "code": "patient_already_exists", "message": "A patient with this zyndio_patient_id is already enrolled.", "request_id": "req_5f0c2a9e41b3d6a8c7e1f204" } }
```

`code` is stable; `message` is for humans and may change.

| Status | Code | When |
|---|---|---|
| 400 | `invalid_request` | Bad field, unknown field, bad cursor/limit, malformed JSON |
| 400 | `invalid_webhook_url` | Not https, IP address, localhost/internal host, credentials in URL |
| 400 | `idempotency_key_required` | POST without `Idempotency-Key` |
| 400 | `unsupported_grant_type` | `grant_type` is not `client_credentials` |
| 400 | `invalid_scope` | Unknown scope, or one the client is not allowed |
| 401 | `invalid_client` | Wrong client id/secret, or the client was revoked |
| 401 | `unauthorized` | Missing, unknown or expired bearer token |
| 403 | `insufficient_scope` | Token lacks the scope this route needs |
| 404 | `not_found` | Unknown route, patient or endpoint (including ones in the other environment) |
| 405 | `method_not_allowed` | See the `Allow` header |
| 409 | `patient_already_exists` | `zyndio_patient_id` already enrolled in this environment |
| 409 | `email_unavailable` | Email can't be used for this patient (already has an account) |
| 409 | `email_change_not_allowed` | Patient has signed in; only they can change their sign-in email |
| 409 | `patient_deactivated` | Action not possible on a deactivated patient |
| 409 | `patient_already_active` | Invite requested for a patient who has already signed in |
| 409 | `idempotency_key_in_use` | See Idempotency |
| 409 | `limit_reached` | More than 10 webhook endpoints in one environment |
| 413 | `payload_too_large` | Body over 16 KB |
| 415 | `unsupported_media_type` | Wrong `Content-Type` |
| 422 | `idempotency_key_reused` | See Idempotency |
| 429 | `rate_limited` | Invite resent less than 60 s after the previous one |
| 500 | `internal_error` | Retry with the same `Idempotency-Key` |

## Authentication: OAuth 2.0 client credentials

An org admin creates API clients in the care portal (**Integrations → New API client**). The
client secret is shown **once**; only its SHA-256 hash is stored. Revoking a client kills its
live tokens immediately.

```http
POST /v1/oauth/token
Authorization: Basic base64(client_id:client_secret)
Content-Type: application/x-www-form-urlencoded

grant_type=client_credentials&scope=patients:read%20patients:write
```

Credentials may instead be sent as `client_id` / `client_secret` form fields (not both), and
`application/json` bodies are accepted too. Omit `scope` to get every scope the client has.

```json
{ "access_token": "zyat_…", "token_type": "Bearer", "expires_in": 900, "scope": "patients:read patients:write" }
```

Tokens are opaque and last **15 minutes**; fetch a new one when they expire (there is no
refresh token). Send them as `Authorization: Bearer zyat_…`.

| Scope | Allows |
|---|---|
| `patients:write` | `POST /patients`, `PATCH /patients/{id}`, `POST /patients/{id}/invites` |
| `patients:read` | `GET /patients`, `GET /patients/{id}`, `GET /patients/{id}/summary` |
| `webhooks:manage` | `/webhook-endpoints` (all) |

## Patients (INT-01)

### The patient object

```json
{
  "object": "patient",
  "zyndio_patient_id": "zp-10042",
  "environment": "sandbox",
  "status": "invited",
  "email": "jordan.example@example.test",
  "given_name": "Jordan",
  "family_name": "Example",
  "phone": "+15555550123",
  "enrolled_at": "2026-11-04T15:00:00.000Z",
  "activated_at": null,
  "deactivated_at": null,
  "last_invited_at": "2026-11-04T15:00:00.000Z",
  "consents": [
    { "consent_type": "health_data", "granted": true, "version": "0.1", "updated_at": "2026-11-04T15:10:00.000Z" }
  ],
  "connected_sources": []
}
```

`status` is one of these:
- `invited`: enrolled, hasn't signed in yet.
- `active`: has signed in at least once.
- `deactivated`: deactivated through the API.

`consents` holds the latest row per consent type (APP-02 versioned consents: a revoke shows as `granted: false`). `connected_sources` stays empty until wearable
connections land.

### `POST /v1/patients` — enrol (`patients:write`)

```json
{ "zyndio_patient_id": "zp-10042", "email": "jordan.example@example.test", "given_name": "Jordan", "family_name": "Example", "phone": "+15555550123" }
```

`zyndio_patient_id` and `email` are required. Names can be 1–100 characters and `phone` must be E.164.
This call does four things:
- Creates the patient account in the API client's clinic.
- Sends the Zyndio invite email. It carries no link or password: the patient opens the app and signs in with a one-time code emailed to that address (APP-01). Their first sign-in accepts the invite.
- Fires `patient.enrolled`.
- Returns `201` with the patient object.

Unknown fields are rejected.

### `GET /v1/patients/{zyndio_patient_id}` (`patients:read`)

Returns account status, consent state and connected sources. Returns `404` if the patient isn't
enrolled in this environment.

### `GET /v1/patients` (`patients:read`)

A paginated list of patients, ordered by enrolment time.

### `PATCH /v1/patients/{zyndio_patient_id}` (`patients:write`)

Any of `given_name`, `family_name`, `phone` (`null` clears a field), `email`, and
`"status": "deactivated"`. Fields you leave out are not changed.

- `email` can only change **before** the patient's first sign-in. A fresh invite goes to the new
  address and the earlier invite is revoked. After first sign-in it returns
  `409 email_change_not_allowed`.
- `"status": "deactivated"` does the following:
  - Ends the patient's sessions.
  - Revokes any open invite.
  - Blocks sign-in.
  - Fires `patient.deactivated`.

  It is one-way through the API and safe to repeat (repeats return the same result and fire no
  second event).

### `POST /v1/patients/{zyndio_patient_id}/invites` (`patients:write`)

Resends the invite email. Any earlier open invite is revoked. Returns `202`:

```json
{ "object": "invite", "zyndio_patient_id": "zp-10042", "sent_at": "2026-11-04T15:00:00.000Z" }
```

These errors can come back:
- `409 patient_already_active`: the patient has signed in.
- `409 patient_deactivated`: the patient is deactivated.
- `429 rate_limited`: another invite went out less than 60 s ago.

## Summary (INT-03)

### `GET /v1/patients/{zyndio_patient_id}/summary` (`patients:read`)

```json
{
  "object": "patient_summary",
  "zyndio_patient_id": "zp-10042",
  "generated_at": "2026-11-04T15:00:00.000Z",
  "biomarkers": [
    { "analyte_key": "hba1c", "label": "HbA1c", "value": 6.1, "unit": "%", "status": "outside_range",
      "range_low": 4.0, "range_high": 5.6, "range_mapped": true, "taken_at": "2026-11-03T09:00:00.000Z" }
  ],
  "wearables": { "sources": [], "daily": [] },
  "open_flags": [
    { "type": "lab_report_needs_review", "report_type": "basic_panel", "raised_at": "2026-11-03T10:00:00.000Z" },
    { "type": "biomarker_outside_range", "analyte_key": "hba1c", "raised_at": "2026-11-03T09:00:00.000Z" }
  ]
}
```

- `biomarkers` is the latest value per analyte, using the same rules as the physician portal.
  Reports on identity hold are excluded.
- `wearables` is empty until the wearable data pipeline lands. Its shape is set by
  `public.integration_wearable_summary()`.
- `open_flags` types are `lab_report_needs_review`, `lab_report_identity_hold`,
  `biomarker_outside_range` and `biomarker_needs_review`.

## Webhooks (INT-02)

### Events

| `event_type` | Fires when | `data` |
|---|---|---|
| `patient.enrolled` | `POST /patients` succeeds | `zyndio_patient_id`, `status`, `enrolled_at` |
| `patient.activated` | The patient's first sign-in | `zyndio_patient_id`, `activated_at` |
| `patient.deactivated` | `PATCH … {"status":"deactivated"}` | `zyndio_patient_id`, `deactivated_at` |
| `consent.updated` | Any consent row for the patient is created, changed (including revoked) or deleted | `zyndio_patient_id`, `consent_type`, `document`, `version`, `granted`, `revoked_at`, `change` (`created`/`updated`/`deleted`), `updated_at` |

Events only fire for patients enrolled through this API, and only to endpoints in the same
environment.

### Envelope

```json
{
  "event_id": "evt_3b9f1c0a7d2e4f5a6b8c9d0e",
  "event_type": "consent.updated",
  "created_at": "2026-11-04T15:10:00.000Z",
  "schema_version": 1,
  "data": { "zyndio_patient_id": "zp-10042", "consent_type": "health_data", "document": "zyndio_health_data", "version": "0.1", "granted": true, "revoked_at": null, "change": "created", "updated_at": "2026-11-04T15:10:00.000Z" }
}
```

Every delivery is a `POST` with these headers:
- `Content-Type: application/json`
- `X-Signature`
- `X-Event-Id`
- `X-Event-Type`
- `X-Delivery-Attempt`

### Verifying `X-Signature`

```
X-Signature: t=1793804400,v1=5257a869e7ecebeda32affa62cdca3fa51cad7e77a0e56ff536d0ce8e108d8bd
```

`v1` is the hex HMAC-SHA256 of `"<t>.<raw request body>"`, keyed with the endpoint's signing
secret (the full `whsec_…` string, UTF-8). To verify a delivery:
1. Recompute the HMAC over the **raw** body bytes.
2. Compare it in constant time against **every** `v1` value. After a rotation the header carries
   one `v1` for the new secret and one for the old secret, for 24 hours.
3. Reject the delivery if `t` is more than 5 minutes from your clock.

`supabase/functions/_shared/webhookSignature.ts` (`verifySignatureHeader`) is the reference
implementation.

### Delivery and retries

Delivery is **at-least-once**, so dedupe on `event_id`. Ordering is not guaranteed.

- **Success:** any 2xx within 10 s. Redirects are not followed and count as failures.
- **Retry schedule:** after a failure the platform retries after **1 min, 5 min, 30 min, 2 h,
  6 h, 12 h and 24 h**. That makes 8 attempts in total. Failed deliveries then move to the
  **dead letter**, which is visible in the portal delivery log.
- **Logging:** every attempt is logged with the payload SHA-256, response status (or
  `timeout`/`network_error`) and duration. Response bodies are never stored.
- **Scheduling:** a worker runs every minute (pg_cron → `deliver-webhooks`). Delays are therefore
  "at least" the schedule above, plus up to about a minute.

### Endpoint management (`webhooks:manage`)

| | |
|---|---|
| `GET /v1/webhook-endpoints` | Paginated list of enabled endpoints in this environment (never includes secrets) |
| `POST /v1/webhook-endpoints` | `{ "url": "https://…", "description": "…", "event_types": [ … ] }`. `event_types` defaults to all four. Returns `201` with `secret` **once**. |
| `POST /v1/webhook-endpoints/{id}/rotate-secret` | New `secret`, returned once. The old one keeps signing for 24 h. |
| `DELETE /v1/webhook-endpoints/{id}` | Disables the endpoint and cancels its pending deliveries. History is kept. |

Endpoint URLs must use `https` with a public hostname. IP literals, `localhost`, `*.local`,
`*.internal` and URLs with credentials are refused. Each environment allows at most 10 enabled
endpoints. Org admins can do the same things in the portal (**Integrations**).

## Deploy checklist

1. Deploy `partner-api` with gateway JWT verification off
   (`supabase/config.toml` `[functions.partner-api] verify_jwt = false`). Partners use this API's
   own tokens, which the function verifies on every request. Every other function keeps
   `verify_jwt` on.
2. Deploy `deliver-webhooks` with `verify_jwt` on. It also checks for the `service_role` claim
   itself.
3. Per environment, create two Vault secrets. Never commit their values.
   - `webhook_worker_url`: the `deliver-webhooks` function URL.
   - `webhook_worker_service_key`: the service-role key.

   Without them the cron job does nothing and deliveries wait in `pending`.
4. Point `platform.zyndio.com/v1/*` at `…/functions/v1/partner-api/v1/*`.
5. Local dev only:
   - Database setting `app.webhooks_allow_local_receivers = 'on'` lets **sandbox** endpoints use
     `http(s)://localhost` / `127.0.0.1`.
   - Env `WEBHOOKS_ALLOW_LOCAL_RECEIVERS=true` lets the worker deliver to them.

   Never set either in a deployed environment.

## Known limits / follow-ups

- **DNS-based SSRF:** registration refuses IP literals and internal names, and the worker refuses
  redirects. A public hostname that **resolves** to a private address is not blocked yet. That
  needs egress controls or resolve-then-connect pinning.
- **Sandbox invites:** sandbox enrolments create real (sandbox-tagged) accounts and queue real
  invite emails. Use test addresses.
- **Email error leaks account existence:** `email_unavailable` tells an authenticated partner
  that an email already has an account on the platform.
- **No consent gate on the summary:** the summary isn't gated on a specific consent type yet. The
  consent workstream owns consent types.
- **No redelivery API:** there is no endpoint to redeliver a dead-letter event and no
  `GET /v1/events` for reconciliation yet.
