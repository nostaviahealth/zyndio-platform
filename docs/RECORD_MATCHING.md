# Record matching: app account ↔ telehealth / clinic record

Owner: Leo (design + impl) | Reviewer: Clara | Accept: Henry
Card: TC-012 | Status: **DESIGN — awaiting Clara's check before any matching code**
Date: 27 Oct 2026, Asia/Calcutta (IST)
Sources: TC-012.md, TEST_PLAN_PATIENT_SIGNUP.md (PSU-TO-*, PSU-DUP-*), Ava patient-auth handoff, Henry rulings 27 Oct.

Fictional / test data only until BAA + Compliance sign-off. Live telehealth API is phase 2.

---

## 1. Goal

A patient can create a Zyndio app account (email + password, verified) and later **link** that account to an existing telehealth / clinic record so they can see their care data in the app.

Linking must never let an attacker attach someone else's clinic record to their own app account (record takeover). Ambiguous cases go to a staff review queue and show **no clinic data** to the patient until resolved.

## 2. Non-negotiable rules

1. **Never auto-link** on email, name, date of birth, phone, or any combination of those alone.
2. Linking requires a **second proof the patient controls**, one of:
   - **Telehealth message code:** 6-digit one-time code sent to the patient's inbox on the telehealth platform ("your clinic's patient messages" until Brett names the platform). TTL **10 minutes**, single-use.
   - **Clinic code:** patient-specific code issued by the clinic. Format **8 characters** from `A–Z` and `2–9`, **excluding look-alikes** `0 O 1 I L`, shown as `XXXX-XXXX`. TTL **72 hours**, single-use. Normalisation: strip spaces/dashes, uppercase before compare.
3. **Unlinked accounts see no clinical data** (profiles, labs, files, consents tied to a clinic record).
4. **One active binding** per telehealth record and per app account. A second claimant with a fresh valid code is rejected while the first binding is active (unique constraints + RPC).
5. **Ambiguous / duplicate matches → review state.** The patient sees Ava's `13-link-record/review` copy and **zero** clinic fields. Staff resolve in a queue (phase 2 UI may be minimal stub; the row + audit exist in release 1).
6. **Enumeration-safe errors.** Wrong / expired / already-used / wrong-account codes return the same client-visible shape and similar timing. Never confirm that a telehealth patient with that email/name/DOB exists.
7. **Patients only.** This flow is for patient self-serve accounts. Staff/admin stay invite-only with two-step login (unchanged).

## 3. Threat notes (maps to Clara's PSU-TO-* / PSU-DUP-*)

| Threat | Design control | Tests |
|---|---|---|
| Email-only takeover | No link path accepts email as binding factor | PSU-TO-01 |
| Name-only / DOB-only | Same; demographic fields never call `bind` | PSU-TO-02, 03 |
| Replay used code | Codes marked `used_at` atomically; second use fails | PSU-TO-04 |
| Brute-force codes | 5 wrong → 15 min lockout per account (+ IP rate limit) | PSU-TO-05, PSU-RL-06 |
| Cross-patient code use | Code row is bound to `telehealth_patient_id` at issue; RPC checks caller cannot rebind to another record | PSU-TO-06 |
| Same record → two apps | Partial unique index on active `telehealth_patient_id` | PSU-TO-07 |
| Re-link after delete | Deletion clears binding; old codes dead; new code required | PSU-TO-08, PSU-DEL-04 |
| RLS cross-patient read | Clinical tables gated on verified + linked patient id | PSU-TO-09 |
| Concurrent double-bind | Unique index + single transactional RPC | PSU-TO-10 |
| Clinic code as universal key | Clinic codes are **patient-scoped** at issue (one code → one telehealth patient). Entering a clinic code never takes email/name/DOB as a selector | PSU-TO-11 |
| Test connector hits prod | Launch config only loads `FakeTelehealthAdapter` seeded fixtures; misconfig fails closed | PSU-TO-12 |
| Duplicate sign-up / case / whitespace | Email normalised (trim + lower); uniqueness on normalised form | PSU-DUP-01..05 |

## 4. Data model (proposed)

Current `public.patients.id` is `auth.users(id)` (TC-005). Release 1 keeps that: the app account **is** the patient row once email is verified. Clinic / telehealth identity is a **separate** external id, bound only after second proof.

```
auth.users  1──1  public.patients (id = auth.users.id, org_id, …)
                      │
                      │ 0..1 active
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

            public.patient_link_codes
              - id uuid PK
              - telehealth_patient_id text NOT NULL
              - org_id uuid NOT NULL
              - code_hash text NOT NULL          -- never store plaintext
              - method text NOT NULL CHECK (method IN ('telehealth_otp','clinic_code'))
              - expires_at timestamptz NOT NULL
              - used_at timestamptz
              - created_at timestamptz
              - created_by text                  -- 'connector' | 'clinic_staff' | system

            public.patient_link_attempts          -- lockout + audit helper
              - app_user_id uuid PK REFERENCES auth.users(id)
              - wrong_count int NOT NULL DEFAULT 0
              - locked_until timestamptz
              - updated_at timestamptz

            public.patient_link_review_queue
              - id uuid PK
              - app_user_id uuid NOT NULL
              - org_id uuid NOT NULL
              - reason text NOT NULL             -- 'ambiguous_match' | 'duplicate_claim' | …
              - payload jsonb NOT NULL DEFAULT '{}'  -- NO PHI: opaque ids only
              - status text NOT NULL DEFAULT 'open'
              - created_at timestamptz
```

**RLS:** clinical tables (`patient_profiles`, `lab_reports`, `consents`, storage paths) readable by the patient JWT only when `email_confirmed_at` is set **and** an `active` `patient_record_links` row exists for `auth.uid()`. Unlinked verified users may manage account settings only.

**Audit:** every issue / redeem / reject / lockout / bind / revoke / review-enqueue writes `audit_log` with opaque ids only (no email, name, DOB, code plaintext).

## 5. Flows

### 5.1 Link via telehealth message code

1. Verified patient opens **Link your record** (Ava `13-link-record`).
2. Chooses "Send a code to your clinic's patient messages".
3. App calls `request_telehealth_link_code` (Edge / RPC). Server:
   - Rate-limits per user + IP.
   - Asks `TelehealthConnector.locateForCodeRequest(appUser)` — **must not** return clinical fields. Launch fake adapter: looks up seeded test records by a server-side allowlist keyed only after the user has already proven mailbox ownership (verified email). If 0 matches → still return generic "If we find a match we'll send a code" (enumeration-safe). If >1 → enqueue review, return review state, send nothing. If exactly 1 → issue hashed 6-digit code, TTL 10 min, deliver via connector `sendPatientMessage`.
4. Patient enters code. `redeem_link_code` verifies hash, expiry, unused, method, lockout; binds atomically; audits.

### 5.2 Link via clinic code

1. Patient chooses "I have a clinic code".
2. Enters `XXXX-XXXX` (dashes optional).
3. `redeem_clinic_code` normalises, rate-limits, looks up hash. On hit: bind to that code's `telehealth_patient_id` if free; else conflict → review or reject (deterministic). On miss: generic wrong-code error (no existence leak).

### 5.3 Review state

Triggered when connector reports ambiguous candidates, or bind hits a uniqueness conflict that isn't a simple "already linked to you" idempotent success. Patient UI: Ava `review` — no clinic summary. Staff queue row created with opaque ids.

### 5.4 Unlink / account deletion

- **Unlink** (Ava "Not you? Unlink"): sets link `revoked`, audits, clinical reads stop immediately.
- **Account deletion** (TC-012 / Apple 5.1.1(v)): re-auth → consequences → delete/anonymise app data, revoke sessions, clear link, kill outstanding codes. Clinic records stay with the clinic (copy). Confirmation email.

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

- `FakeTelehealthAdapter`: in-memory / DB-seeded fixtures (`th_test_jr_001`, `th_test_ac_002`, … per Clara's plan). Messages appended to an outbox table for tests.
- Live adapter: **not built** until Brett's platform name, docs, and test access land. Config flag `TELEHEALTH_ADAPTER=fake|live` — default `fake`; `live` refuses to start without explicit allow + credentials.

## 7. Rate limits & lockouts (defaults)

| Endpoint | Per account | Per IP | Lockout |
|---|---|---|---|
| Sign-up | 5 / 15 min (email hash) | 10 / 15 min | — |
| Login failures | 5 wrong → lock | throttle | 15 min |
| Password reset | 5 / 15 min email | 10 / 15 min IP | — |
| Verify resend | 1 / 60 s UI cooldown; 5 / 15 min server | — | — |
| Link code redeem | 5 wrong → lock | throttle | 15 min |
| Request telehealth code | 3 / 15 min | 10 / 15 min | — |

Exact numbers are config-driven (`app_settings` / env) so Clara's tests can inject clocks and thresholds.

## 8. Expiry & copy defaults (Henry, 27 Oct — config-driven)

| Item | Default | Config key (proposed) |
|---|---|---|
| Verify-email link | 24 h | `auth.verify_email_ttl_hours` |
| Reset-password link | 1 h | `auth.reset_password_ttl_hours` |
| Telehealth OTP | 10 min | `link.telehealth_otp_ttl_minutes` |
| Clinic code | 72 h | `link.clinic_code_ttl_hours` |
| Clinic code alphabet | A–Z, 2–9 minus 0/O/1/I/L, display `XXXX-XXXX` | `link.clinic_code_alphabet` |
| Channel name copy | "your clinic's patient messages" | `link.channel_display_name` (**pending Brett**) |

Mark any UI string that uses the channel name with a `// PENDING Ava/Henry: Brett platform name` comment so copy can swap in one place.

## 9. What release 1 does **not** include

- Live telehealth / EHR API.
- DEXASCAN, Jinfiniti, Apple Health, wearables.
- Staff UI beyond a minimal review-queue table (can be SQL + admin stub).
- Closing M8 (Supabase Pro leaked-password protection) — stays open in `docs/RISKS.md` as launch blocker; matching tests that depend on HIBP stay red and marked, never skipped.

## 10. Implementation order (after Clara checks this doc)

1. Migrations for tables + RLS + RPCs above (fail-first pgTAP for PSU-TO-* / unique / RLS).
2. `TelehealthConnector` + `FakeTelehealthAdapter` + Deno tests.
3. Edge / RPC rate limits + enumeration padding.
4. Flutter patient screens per Ava handoff (sign-up → verify → login → reset → delete → link), tests alongside.
5. Screenshots light+dark under `work/screenshots/tc-012/`.

**No matching code lands until Clara records a check on this document.** Sign-up / login / verify / reset / delete may proceed in parallel.

## 11. Open questions (tracked, not blocking the doc check)

| # | Question | Interim default | Owner |
|---|---|---|---|
| Q1 | Final telehealth platform name for patient-facing copy | "your clinic's patient messages" | Brett → Ava/Henry |
| Q2 | Who staffs the review queue at launch? | Org admin + care coordinator can list; resolve is org admin | Henry |
| Q3 | Plus-address email policy | Distinct accounts allowed; TO-07 still prevents two active links to one telehealth id | Henry (confirm) |
| Q4 | Email templates (confirm, "someone tried to sign up", deletion) | Ava offered to draw; stub subjects/bodies in outbox until then | Ava |

---

Clara: please check §2–§7 against TEST_PLAN_PATIENT_SIGNUP.md. Reply with Approve / Request changes (numbered). No matching code until then.
