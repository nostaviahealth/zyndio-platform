# Zyndio Compliance, Security & Operations Pack

**Document Ref:** PRD Phase 0.3 / Clauses 6.6, 8, 9 & Schedule C  
**Last Updated:** 10 November 2026  

This pack consolidates the technical compliance, security architecture, clinical safety controls, and operational runbooks required by **Zyndio Build: PRD and Technical Plan**.

---

## 1. Architecture & Data Flow Map (Phase 0.3)

### 1.1 System Components
| Component | Codebase Location | Technology | Data Classification |
|---|---|---|---|
| **Patient App (iOS / Android)** | `flutter_app/` | Flutter 3, `flutter_secure_storage` (iOS Keychain / Android EncryptedSharedPreferences) | ePHI (authenticated session only; neutral push notifications) |
| **Physician & Partner Portal** | `pages/`, `components/`, `lib/` | React 19 + TypeScript + Vite | ePHI & Operational Audit Data (AAL2 MFA enforced for clinical roles) |
| **Reverse Proxy & Edge Gateway** | `supabase/proxy-worker.js` | Cloudflare Worker (`platform.zyndio.com`) | TLS 1.2+ pass-through; IP header sanitization (`CF-Connecting-IP`); `R-AUTH-M8` guard |
| **Core Database & Auth** | `supabase/migrations/` | PostgreSQL 15 + GoTrue + Row-Level Security (RLS) + Vault | AES-256 encrypted at rest; organization-scoped RLS |
| **Serverless Edge Functions** | `supabase/functions/` | Deno Edge Runtime | Stateless API handlers, HMAC-SHA256 webhooks, AI safety boundaries |
| **Object Storage** | Supabase Storage (`lab-uploads`, `food-photos`) | S3-compatible encrypted buckets | Private buckets; signed URLs only (`<= 15 min` expiry) |

### 1.2 Data Flow & Trust Boundaries
1. **Enrolment & Identity (`INT-01`, `APP-01`):**
   - `zyndio.com` calls `POST /functions/v1/partner-api/v1/patients` using a per-partner API key (`zynd_live_...` hashed with SHA-256 in `public.partner_api_keys`).
   - Patient signs in via one-time enrolment code (`auth-send-code` / `auth-verify-code`) and completes versioned consent (`APP-02`) + optional revocable partner outcomes consent (`APP-03`).
2. **Clinical & Wearable Ingestion (`APP-05`–`APP-08`, `INT-04`, `INT-05`):**
   - Wearables sync daily summaries to `public.wearable_daily`.
   - Lab PDFs/images upload to private `lab-uploads` storage; extracted markers (`lab-ocr`) require patient identity match (name/DOB verification) before committing to `public.biomarker_results`.
   - DEXASCAN payloads arrive via `POST /functions/v1/partner-api/v1/measurements` (`INT-05`). High-confidence matches bind to the patient; ambiguous records route to `public.unmatched_partner_records` (`POR-10`) for manual review.
3. **Clinical Review & Outcomes Loop (`POR-01`–`POR-10`, `INT-06`, Schedule C):**
   - Physicians (authenticated at `aal2` MFA) review roster flags (`POR-02`), timeline (`POR-03`), pre-visit brief (`POR-04`), and reference ranges (`POR-05`).
   - Outcomes engine computes longitudinal deltas at baseline / Day 90 / Day 180 / Day 365 (`public.outcome_records`), enforces `partner_outcome_authorisations`, queues records for clinical sign-off (`POR-09`), and delivers signed webhooks via `deliver-webhooks` (`INT-06`).

---

## 2. Sub-Processor Register & BAA Gating Matrix (Clause 8)

> **CRITICAL RULE:** No real patient data (ePHI) may be ingested into any environment until the corresponding Business Associate Agreement (BAA) is counter-signed and recorded by Zyndio.

| Sub-Processor | Purpose | PHI Exposure | Required Control / Feature Flag |
|---|---|---|---|
| **Supabase (AWS US Region)** | Primary Postgres DB, Auth, Edge Functions, Storage | Full ePHI (encrypted AES-256 at rest, TLS 1.2+ in transit) | HIPAA Plan + Signed BAA required before production launch |
| **Cloudflare** | DNS & Reverse Proxy (`supabase/proxy-worker.js`) | In-transit TLS termination | Zero payload caching; `TRUSTED_PROXY_HOPS=1` |
| **Google Cloud / Gemini API** | AI Lab OCR (`lab-ocr`), Food Photo Analysis (`analyze-food`), AI Companion (`ai-chat`) | Lab PDFs, meal photos, chat prompts | Gated by `LAB_AI_EXTRACTION_ENABLED` and `public.ai_feature_switches` (`Clause 9.2`). **Default OFF** until BAA is signed |
| **Firebase / APNs** | Push Notification Transport (`send-push`) | **Zero PHI** (`APP-10`) | Payload text is strictly hardcoded to neutral text (`"You have a new update in Zyndio."`) |
| **RevenueCat** | Subscription & Entitlement Webhook (`revenuecat-webhook`) | Pseudonymous User UUID only | HMAC / Secret header validation + idempotent event ordering (`public.apply_revenuecat_event`) |

---

## 3. Access Control, MFA & Encryption Controls (Clause 8.1–8.7)

1. **Multi-Factor Authentication (`POR-01`):**
   - Every clinical portal role (`physician`, `care_coordinator`, `org_admin`, `read_only`) is enforced at two independent layers:
     - **Frontend Gate:** `MfaGate.tsx` blocks access to `/admin/*` unless the session JWT carries `aal = 'aal2'`.
     - **Database RLS Gate:** Clinical RLS policies invoke `public.is_aal2()` (`coalesce(auth.jwt()->>'aal', 'aal1') = 'aal2'`), preventing direct PostgREST access with an `aal1` token.
2. **Tenant & Role Isolation:**
   - Every multi-tenant table carries `org_id` with restrictive RLS policies (`supabase/tests/200_cross_org_isolation.sql`, `210_in_org_role_matrix.sql`).
   - Last-admin guard (`public.enforce_last_admin`) prevents accidental lockout of an organization's final active `org_admin`.
3. **Immutable Audit Logging (`POR-08`):**
   - `public.audit_log` records every privileged action (`patient_enrolled`, `consent_recorded`, `treatment_event_recorded`, `reference_range_approved`, `outcome_approved`, `patient_export_generated`, `patient_deletion_completed`, `security_incident_logged`).
   - `UPDATE` and `DELETE` on `public.audit_log` are blocked by database trigger for non-service roles.
4. **Secret & Key Management:**
   - Partner API keys and webhook signing secrets use high-entropy prefixes (`zynd_live_`, `whsec_`) with dual-key grace-window rotation (`public.rotate_webhook_secret`, `PP-03`).
   - Pseudonymization (`patient_ref = pat_...`) uses HMAC-SHA256 with a secret pepper stored in `vault.decrypted_secrets` (`outcomes_pseudonym_pepper`).

---

## 4. Clinical Decision Support & AI Safety Boundaries (Clause 9.1 & 9.2)

1. **Decision Support Only (Clause 9.1):**
   - Reference ranges (`public.reference_ranges`, `POR-05`) are versioned and require explicit `physician` approval (`approved_by`, `approved_at`) before activation.
   - Patient-facing biomarker views (`APP-06`) use bounded, non-diagnostic language (`"Outside reference range — discuss with your care team"`).
   - Treatment context (`public.treatment_events`, `POR-07`, `INT-04`) strips `dose`, `dose_unit`, and `frequency` from all patient-facing projections (`public.patient_visible_treatment_events` and RLS column guards). **Dosing is never shown to the patient.**
2. **AI Companion Escalation & Boundaries (`APP-09`):**
   - `supabase/functions/ai-chat/index.ts` enforces deterministic pre-LLM classifiers:
     - **Emergency keywords** (chest pain, shortness of breath, suicidal ideation, severe allergic reaction, stroke symptoms) immediately return emergency guidance (`911` / emergency services) and insert an urgent alert into `public.escalation_events`.
     - **Clinical / dosing / diagnostic requests** refuse autonomous medical advice and route the inquiry to the care team.
3. **Per-Feature AI Kill Switches (Clause 9.2):**
   - Controlled via `public.ai_feature_switches` (`lab_ocr`, `ai_companion`, `food_photo_analysis`, `previsit_brief_summary`).
   - Any `org_admin` or platform operator can disable an AI feature immediately without redeploying code.

---

## 5. Operational Runbooks (Clause 6.6, Clause 8.8 & Schedule C)

### 5.1 Clause 6.6 — 30-Day Termination Export (`OPS-01`)
- **UI Path:** Partner Portal → `Operations & Billing` (`/admin/operations`) → **Termination Data Export**.
- **RPC:** `public.ops_generate_org_termination_export(p_org_id, p_reason)`
- **Behaviour:** Generates a complete JSON bundle of all organization patients, demographics, consents, lab reports, biomarker results, wearable summaries, DEXA scans, treatment events, and outcome records within the 30-day post-termination window, and writes `org_termination_export_generated` to `public.audit_log`.

### 5.2 Clause 6.6 — 72-Hour Patient Deletion & Legal Hold (`OPS-02`)
- **UI Path:** Partner Portal → `Operations & Billing` (`/admin/operations`) → **Patient Deletion Queue & Legal Holds**.
- **RPCs:**
  - Place/Release Hold: `public.ops_set_legal_hold(p_patient_id, p_active, p_reason)`
  - Execute Scrub: `public.ops_execute_patient_deletion(p_request_id, p_written_confirmation)`
- **Behaviour:**
  - If `legal_hold = true`, deletion is blocked with an explicit error and logged.
  - Otherwise, clinical rows and private storage objects (`lab-uploads`, `food-photos`) are purged within the 72-hour SLA, statutory audit/consent metadata is retained per APP-11, and a signed confirmation receipt (`del_conf_...`) is recorded.

### 5.3 Clause 8.8 — 72-Hour Security Incident Notification (`OPS-03`)
- **UI Path:** Partner Portal → `Operations & Billing` (`/admin/operations`) → **Security Incidents (72h SLA)**.
- **RPCs:** `public.ops_report_security_incident(...)` and `public.ops_mark_incident_notified(p_incident_id, p_notification_ref)`
- **Behaviour:** Tracks discovery timestamp (`discovered_at`), computes the mandatory `notify_deadline_at = discovered_at + interval '72 hours'`, records affected patient count, containment summary, and partner notification confirmation.

### 5.4 Schedule C — 35-Field Outcomes & DEXASCAN Loop (`C1`–`C3`)
- **Schema & Engine:** `supabase/migrations/20261105160000_c2_outcomes_engine_and_dexa.sql`
- **Capabilities:**
  - Computes all 35 Schedule C fields across 7 sections (`record_metadata`, `patient_cohort`, `programme_adherence`, `biomarker_outcomes`, `body_composition_outcomes`, `wearable_outcomes`, `treatment_context`).
  - Enforces revocable partner consent (`public.partner_outcome_authorisations`) both at queue generation and right before webhook dispatch (`deliver-webhooks`).
  - Sandbox testing endpoint available at `/functions/v1/outcomes-sandbox`.
