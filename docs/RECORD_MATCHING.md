# Record matching: app account ↔ telehealth / clinic record

Owner: Leo (design + impl) | Reviewer: Clara | Accept: Henry
Card: TC-012 | Status: **APPROVED by Clara (27 Oct); matching RPCs + Edge request-link landed (Leo). PSU-TO-16 closed; pgTAP 650 covers TO-01..15.**
Date: 27 Oct 2026, Asia/Calcutta (IST)
Sources: TC-012.md, TEST_PLAN_PATIENT_SIGNUP.md (PSU-TO-*, PSU-DUP-*), Ava patient-auth handoff (README + copy-deck, updated 27 Oct), Henry rulings 27 Oct (incl. link/unlink notice via clinic messages **and** account email), Clara REVIEW_RECORD_MATCHING.md.

Fictional / test data only until BAA + Compliance sign-off. Live telehealth API is phase 2.

---

## 1. Goal

A patient can create a Zyndio app account (email + password, verified) and later **link** that account to an existing telehealth / clinic record so they can see their care data in the app.

Linking must never let an attacker attach someone else's clinic record to their own app account (record takeover). Ambiguous cases go to a staff review queue and show **no clinic data** to the patient until resolved.

---

## 2. Non-negotiable rules

1. **Never auto-link** on email, name, date of birth, phone, or any combination of those alone.
2. Linking requires a **second proof the patient controls**, one of:
   - **Telehealth message code:** 6-digit one-time code sent to the patient's inbox on the telehealth platform ("your clinic's patient messages" until Brett names the platform). TTL **10 minutes**, single-use. **Bound to the requesting app account** (see §4 / §5.1).
   - **Clinic code:** patient-specific code issued by the clinic. Format **8 characters** from `A–Z` and `2–9`, **excluding look-alikes** `0 O 1 I L`, shown as `XXXX-XXXX`. TTL **72 hours**, single-use. Normalisation: strip spaces/dashes, uppercase before compare. Stored as **HMAC-SHA256 with a server-side pepper** (see §4).
3. **Unlinked accounts see no clinical data** (profiles, labs, files, consents). Self sign-up creates **no** org-scoped `patients` row until bind; patient-read RLS requires an **active link** (see §4).
4. **One active binding** per telehealth record and per app account.
5. **Ambiguous / duplicate matches → review state.** Staff resolution **never** binds directly: staff verify identity and **issue a clinic code**; the patient redeems it (see §5.3).
6. **Enumeration-safe errors.** Wrong / expired / already-used / wrong-account codes return the same client-visible shape and similar timing. **"Send me a code"** returns the **identical** response for 0 / 1 / many matches (see §5.1).
7. **Patients only.** Staff/admin stay invite-only with two-step login.
8. **Notice on every link and unlink** via **both** channels (Henry, 27 Oct): (a) the clinic patient-messages connector stub, and (b) email to the app account's address. Copy includes "not you? contact your clinic". Email delivery goes live with the telehealth API; until then both paths write the same stub/outbox. OTP messages include "not you? ignore" (see §5.5).

---

## 3. Threat notes (maps to Clara's PSU-TO-* / PSU-DUP-* + additions)

| Threat | Design control | Tests |
|---|---|---|
| Email-only takeover | No link path accepts email as binding factor | PSU-TO-01 |
| Name-only / DOB-only | Same; demographic fields never call `bind` | PSU-TO-02, 03 |
| Replay used code | Codes marked `used_at` atomically; second use fails | PSU-TO-04 |
| Brute-force codes | Telehealth OTP: 5 wrong tries **kills that code**; plus per-account/per-IP limits. Clinic codes: same per-account/per-IP **plus global failed-attempt circuit breaker + alert** | PSU-TO-05, PSU-RL-06 |
| Cross-patient / cross-account OTP use | Telehealth OTP rows carry `issued_to_app_user_id NOT NULL`; redeem looks up **only** `(issued_to_app_user_id = auth.uid(), method, unused, unexpired)` — never a global 6-digit lookup | PSU-TO-06, **PSU-TO-13** |
| Same record → two apps | Partial unique index on active `telehealth_patient_id` | PSU-TO-07 |
| Re-link after delete | Deletion clears binding; old codes dead; new code required | PSU-TO-08, PSU-DEL-04 |
| RLS cross-patient / unlinked read | Clinical tables require verified email **and** an active `patient_record_links` row (legacy clinic-provisioned patients with `patients.org_id IS NOT NULL` grandfathered until links backfill) | PSU-TO-09, **PSU-TO-15** |
| Concurrent double-bind | Unique index + single transactional RPC | PSU-TO-10 |
| Clinic code as universal key | Clinic codes are patient-scoped at issue; redeem never takes email/name/DOB as a selector; stored as keyed HMAC so a DB leak is not offline-bruteforceable | PSU-TO-11 |
| Test connector hits prod | Launch config only loads `FakeTelehealthAdapter`; misconfig fails closed | PSU-TO-12 |
| Match-count enumeration on "send code" | 0 / 1 / many matches return the **same** client response; review UI only after redeem or later in-app | **PSU-TO-14** |
| Staff "approve link" without second proof | Review resolution = issue clinic code only; no bind RPC from staff | §5.3 |
| Silent takeover | Bind and unlink both notify clinic patient messages **and** the account email with "not you? contact your clinic" | §5.5 |
| Duplicate sign-up / case / whitespace | Email normalised (trim + lower); uniqueness on normalised form | PSU-DUP-01..05 |
| Plus-addressing | Distinct accounts allowed (`user+tag@` ≠ `user@`); active-link unique index blocks two aliases binding the same telehealth record (PSU-TO-07) | PSU-DUP-04 |

---

## 4. Data model (proposed)

### 4.1 App account vs clinic patient (Clara #5)

- **Self sign-up** (TC-012 `patient-signup` Edge Function) creates an `auth.users` row with `user_metadata.role = 'patient'` and **does not** insert `public.patients` (and therefore no `org_id`). The account can verify email, reset password, and manage account settings only.
- **Clinic / telehealth identity** is a separate external id. An org-scoped `public.patients` row (with `org_id`) is created **only at successful bind** (or by the existing staff invite / care-portal provisioning path).
- **Patient-read RLS** on clinical tables (`patient_profiles`, `lab_reports`, `consents`, storage) requires:
  1. `email_confirmed_at` set, and
  2. an **active** `patient_record_links` row for `auth.uid()`  
  **Transitional grandfather:** until every clinic-provisioned account has a link row, `exists (select 1 from patients where id = auth.uid() and org_id is not null)` also satisfies (2) for staff-provisioned patients. **Clara Approve condition:** that grandfather **did** open a hole — a physician/coordinator could call `create_patient_record` on a self-signup `auth.users` id and mint an org-scoped `patients` row without a second-proof link. **Closed:** `patient-signup` writes a `patient_self_signups` marker; `create_patient_record` refuses those accounts (pgTAP **PSU-TO-16**). Clinic-scoped rows for self-signup accounts are created only at successful bind.
- **pgTAP (PSU-TO-15):** a verified self-signup user with no `patients` row and no link reads **zero** rows from every clinical table and storage path. Planned before matching RPCs land; partial coverage lands with the TC-012 backend hardening.

### 4.2 Tables

```
auth.users  (self-signup: no public.patients yet)
     │
     │ 0..1 active link (after bind)
     ▼
public.patient_record_links
  - id uuid PK
  - app_user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE
  - org_id uuid NOT NULL
  - telehealth_patient_id text NOT NULL   -- opaque external id
  - status text NOT NULL CHECK (status IN ('active','revoked','pending_review'))
  - linked_at timestamptz
  - revoked_at timestamptz
  - proof_method text NOT NULL CHECK (proof_method IN ('telehealth_otp','clinic_code'))
  - created_at timestamptz

  UNIQUE (app_user_id) WHERE status = 'active'
  UNIQUE (telehealth_patient_id) WHERE status = 'active'

  -- ON DELETE CASCADE on app_user_id is OK because audit_log retains
  -- bind/revoke history with opaque ids (Clara Low confirmed).

public.patient_link_codes
  - id uuid PK
  - telehealth_patient_id text NOT NULL
  - org_id uuid NOT NULL
  - method text NOT NULL CHECK (method IN ('telehealth_otp','clinic_code'))
  - issued_to_app_user_id uuid NULL
      -- NOT NULL when method = 'telehealth_otp' (Clara #1 HIGH).
      -- NULL when method = 'clinic_code' (global redeem by HMAC, patient-scoped at issue).
  - code_mac text NOT NULL
      -- HMAC-SHA256(pepper, normalised_code) for clinic codes (Clara #2).
      -- For telehealth OTP: HMAC or salted hash of the 6-digit code; never plaintext.
  - expires_at timestamptz NOT NULL
  - used_at timestamptz
  - killed_at timestamptz          -- set after 5 wrong tries (OTP) or admin void
  - wrong_try_count int NOT NULL DEFAULT 0
  - created_at timestamptz
  - created_by text                -- 'connector' | 'clinic_staff' | 'system'
  - superseded_at timestamptz      -- prior OTP voided when a new request is made

  CHECK (method <> 'telehealth_otp' OR issued_to_app_user_id IS NOT NULL)

public.patient_link_attempts       -- per-account lockout helper
  - app_user_id uuid PK REFERENCES auth.users(id)
  - wrong_count int NOT NULL DEFAULT 0
  - locked_until timestamptz
  - updated_at timestamptz

public.patient_link_global_failures  -- Clara #2 clinic-code circuit breaker
  - window_start timestamptz NOT NULL
  - fail_count int NOT NULL DEFAULT 0
  -- When fail_count crosses threshold → reject all clinic-code redeems in-window
  -- and write an alert (outbox / ops). Per-account and per-IP limits still apply.

public.patient_link_review_queue
  - id uuid PK
  - app_user_id uuid NOT NULL
  - org_id uuid NOT NULL
  - reason text NOT NULL             -- 'ambiguous_match' | 'duplicate_claim' | …
  - payload jsonb NOT NULL DEFAULT '{}'  -- NO PHI: opaque ids only
  - status text NOT NULL DEFAULT 'open'
  - created_at timestamptz
```

Pepper for HMAC lives in Edge / Vault (`LINK_CODE_PEPPER`), never in the database row and never in the client.

**Audit:** every issue / redeem / reject / kill / lockout / bind / revoke / review-enqueue / notice-send writes `audit_log` with opaque ids only (no email, name, DOB, code plaintext).

---

## 5. Flows

### 5.1 Link via telehealth message code (Clara #1, #3)

1. Verified patient opens **Link your record** (Ava `13-link-record`).
2. Chooses "Send a code to your clinic's patient messages".
3. App calls `request_telehealth_link_code`. Server:
   - Rate-limits per user + IP.
   - Asks `TelehealthConnector.locateForCodeRequest(appUser)` — **must not** return clinical fields to the client.
   - **Regardless of 0, 1, or many matches**, the client receives the **same** success shape and Ava copy: **"If your details match a clinic record, we've sent a 6-digit code to your clinic's patient messages."** Timing padded. **PSU-TO-14.**
   - Server-side only:
     - **0 matches:** send nothing; optional no-op audit.
     - **1 match:** void any earlier unused OTP for this `issued_to_app_user_id` (`superseded_at`); issue new code with `issued_to_app_user_id = auth.uid()`, TTL 10 min; deliver via `sendPatientMessage` including "not you? ignore this message".
     - **Many matches:** enqueue review with opaque ids; send nothing; do **not** change the client response.
4. Patient enters code. `redeem_link_code` (telehealth path):
   - Looks up **only** rows where `issued_to_app_user_id = auth.uid()`, `method = telehealth_otp`, `used_at IS NULL`, `killed_at IS NULL`, `superseded_at IS NULL`, `expires_at > now()`.
   - **Never** a global lookup by 6-digit code alone (**PSU-TO-13**).
   - Wrong try: increment `wrong_try_count`; at **5** set `killed_at` (code dies). Same generic error shape every time.
   - Success: bind atomically; audit; send link notice (§5.5).

### 5.2 Link via clinic code (Clara #2)

1. Patient chooses "I have a clinic code".
2. Enters `XXXX-XXXX` (dashes optional).
3. `redeem_clinic_code`:
   - Normalise; check per-account, per-IP, and **global failure** circuit breaker.
   - Compute `HMAC-SHA256(pepper, normalised_code)` and look up `code_mac` (not a plain hash).
   - On hit: bind if that `telehealth_patient_id` is free; else conflict → review enqueue or reject (deterministic, enumeration-safe client shape).
   - On miss: increment global + per-account/IP failure counters; generic wrong-code error.
   - Threshold breach on global counter → alert ops and refuse further clinic-code redeems in the window.

### 5.3 Review state (Clara #4)

Triggered when connector reports ambiguous candidates (server-side), or bind hits a uniqueness conflict that isn't idempotent "already linked to you".

- Patient UI: Ava `review` state titled **"No code yet?"** — explains codes usually arrive in a few minutes; if nothing comes, the clinic can confirm identity and give a **clinic code** instead. CTAs: "I have a clinic code" / "Send a new code". Footer: "Until your record is linked, no clinic data is shown in the app." **No clinic summary, no PHI.**
- Staff queue row: opaque ids only.
- **Resolution must never call bind.** Org admin / care coordinator (per Q2) verifies identity out-of-band, then **issues a new patient-scoped clinic code** (audited `created_by = clinic_staff`). The patient redeems that code through §5.2. There is **no** "Approve link" button or staff-side bind RPC.

### 5.4 Unlink / account deletion

- **Unlink** (Ava "Not you? Unlink"): sets link `revoked`, audits, clinical reads stop immediately, sends unlink notice (§5.5).
- **Account deletion** (TC-012 / Apple 5.1.1(v)): re-auth → consequences → delete/anonymise app data, revoke sessions, clear link, kill outstanding codes. Clinic records stay with the clinic. Confirmation email stub.

### 5.5 Notices on link / unlink (Clara #6 + Henry dual-channel)

On **every successful bind** and **every unlink**, send the notice on **both** channels (Henry, 27 Oct):

1. **Clinic patient messages** — `TelehealthConnector.sendPatientMessage` to that record's channel (launch: fake adapter → outbox; live with the telehealth API).
2. **Account email** — the verified app-account address (same outbox/email stub pattern as signup/reset; real delivery when the telehealth / mail stack goes live with the API).

Clinic-messages / email body equivalent to:

> Your record was linked to a Zyndio app account. Not you? Contact your clinic.

(Unlink variant: "A Zyndio app account was unlinked from your record. Not you? Contact your clinic.")

**Patient UI (Ava `linked` state):** after a successful bind, show **"We've also sent a notice to your email and your clinic's patient messages."** plus the "Not you? Unlink" escape.

OTP delivery messages (clinic channel only) include a "not you? ignore" line. Both notice paths are audited (opaque ids); failures retry via outbox — missing notice on either channel is a launch bug, not silent success.

---

## 6. Telehealth connector (interface + fake adapter)

```
interface TelehealthConnector {
  /** Launch: test fixtures only. Never call a live vendor API. */
  locateForCodeRequest(input: { appUserId: string; normalisedEmail: string }):
    Promise<{ kind: 'none' } | { kind: 'one'; telehealthPatientId: string } | { kind: 'ambiguous' }>;

  sendPatientMessage(input: { telehealthPatientId: string; body: string }): Promise<void>;

  /** Optional read AFTER active link only — not used in release-1 UI beyond stub. */
  fetchLinkedSummary?(telehealthPatientId: string): Promise<LinkedSummary>;
}
```

- `FakeTelehealthAdapter`: in-memory / DB-seeded fixtures (`th_test_jr_001`, …). Messages append to an outbox table for tests.
- Account-email notices (§5.5 channel 2) use the existing email/outbox stub, not the connector interface; both go live with the telehealth API.
- Live adapter: **not built** until Brett's platform, docs, and test access land. `TELEHEALTH_ADAPTER=fake|live` — default `fake`; `live` refuses to start without explicit allow + credentials.

---

## 7. Rate limits & lockouts (defaults)

| Endpoint | Per account | Per IP | Extra |
|---|---|---|---|
| Sign-up | 5 / 15 min (email hash) | 10 / 15 min | — |
| Login failures | 5 wrong → lock | **throttle (PSU-RL-03)** | 15 min account lock |
| Password reset | 5 / 15 min email | 10 / 15 min IP | — |
| Verify resend | 1 / 60 s UI; 5 / 15 min server | — | — |
| Telehealth OTP redeem | 5 wrong → **kill that code** | throttle | — |
| Request telehealth code | 3 / 15 min; new request voids prior OTP | 10 / 15 min | — |
| Clinic code redeem | 5 wrong → lock | throttle | **Global failure breaker + alert** |

Exact numbers are config-driven so Clara's tests can inject clocks and thresholds.

---

## 8. Expiry & copy defaults (Henry, 27 Oct — config-driven)

| Item | Default | Config key (proposed) |
|---|---|---|
| Verify-email link | 24 h | `auth.verify_email_ttl_hours` |
| Reset-password link | 1 h | `auth.reset_password_ttl_hours` |
| Telehealth OTP | 10 min | `link.telehealth_otp_ttl_minutes` |
| Clinic code | 72 h | `link.clinic_code_ttl_hours` |
| Clinic code alphabet | A–Z, 2–9 minus 0/O/1/I/L, display `XXXX-XXXX` | `link.clinic_code_alphabet` |
| Channel name copy | "your clinic's patient messages" | `link.channel_display_name` (**pending Brett**) |
| Send-code client copy (0/1/many) | "If your details match a clinic record, we've sent a 6-digit code to your clinic's patient messages." | Ava copy-deck `13-link-record` / code·wrong·locked |
| Review UI title | "No code yet?" → clinic code path | Ava `13-link-record` / review |
| Linked notice line | "We've also sent a notice to your email and your clinic's patient messages." | Ava `13-link-record` / linked |

UI strings must match Ava's handoff `/workspace/design/team3/zyndio/handoff/patient-auth/` (README + copy-deck). Mark channel-name strings with `// PENDING Ava/Henry: Brett platform name`.

---

## 9. What release 1 does **not** include

- Live telehealth / EHR API.
- DEXASCAN, Jinfiniti, Apple Health, wearables.
- Staff UI beyond a minimal review-queue table (SQL + admin stub OK); resolution = issue clinic code only.
- Closing M8 (Supabase Pro leaked-password protection) — stays open in `docs/RISKS.md`.

---

## 10. Implementation order (after Clara re-checks this doc)

1. Migrations for tables + RLS (`current_patient_linked`) + RPCs (fail-first pgTAP for PSU-TO-* including **13/14/15**).
2. `TelehealthConnector` + `FakeTelehealthAdapter` + Deno tests.
3. Edge / RPC rate limits + enumeration padding + global clinic-code breaker.
4. Flutter patient screens per Ava handoff; link screens after matching RPCs.
5. Screenshots light+dark under `work/screenshots/tc-012/`.

**Clara APPROVED** this document (base `1f7168b`, amended `e236fe9`) on one condition: `create_patient_record` must refuse self-signup accounts (**PSU-TO-16**), addressed in the first matching migration. Matching redeem/bind/OTP implementation proceeds from that commit.

---

## 11. Open questions

| # | Question | Interim default | Owner |
|---|---|---|---|
| Q1 | Final telehealth platform name for patient-facing copy | "your clinic's patient messages" | Brett → Ava/Henry |
| Q2 | Who staffs the review queue at launch? | Org admin + care coordinator can **list**; resolve = issue clinic code (org admin) | Henry |
| Q3 | Plus-address email policy | Distinct accounts allowed; TO-07 still prevents two active links to one telehealth id | Henry (confirm) — Clara Low: acceptable |
| Q4 | Email templates | Ava offered to draw; stub subjects/bodies in outbox until then | Ava |
| Q5 | Global clinic-code failure threshold | 100 fails / 15 min → alert + trip (config) | Henry/Clara |

---

## 12. Clara review mapping (this revision)

| # | Clara finding | Where addressed |
|---|---|---|
| 1 High | OTP bound to requesting account; redeem scoped; new request voids old; 5 wrong kills | §2.2, §4.2 `issued_to_app_user_id`, §5.1, PSU-TO-13 |
| 2 Medium | Clinic codes as keyed HMAC + global breaker | §4.2 `code_mac` / pepper, §5.2, §7 |
| 3 Medium | Identical response for 0/1/many on send-code | §5.1, PSU-TO-14 |
| 4 Medium | Review never binds; staff issue clinic code | §5.3, Q2 |
| 5 Medium | No patients row before link; RLS needs active link; pgTAP | §4.1, PSU-TO-15 |
| 6 Medium | Notice on link/unlink (clinic messages **+ account email**, Henry) + OTP "not you?" + Ava linked copy | §5.5, §5.1, §8 |

Clara: please re-check against TEST_PLAN_PATIENT_SIGNUP.md (+ PSU-TO-13/14/15). Reply with Approve / Request changes (numbered). No matching redeem/bind code until Approve.
