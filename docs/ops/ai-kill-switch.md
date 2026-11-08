# AI Feature Kill Switch Runbook (PRD Clause 9.2)

Every AI-assisted feature in Zyndio sits behind its own kill switch in `public.ai_feature_switches`, so if a regulator or clinic objects to a specific capability we can switch it off for one clinic (or globally across all clinics) within minutes — **without an app release or redeploy**.

## Supported Feature Keys

| `feature` value | What it governs | Edge Functions enforcing it |
| :--- | :--- | :--- |
| `'companion'` | Conversational AI companion chat & tool calls (also the fallback for any unlabelled request) | `intelligence` |
| `'food_analysis'` | Photo & text meal analysis (`LensScreen`, transcript refinement) | `intelligence` |
| `'lab_extraction'` | AI biomarker extraction from lab report PDFs/images | `intelligence`, `analyze-lab-report` |
| `'coaching'` | Daily rhythm optimization, blueprint generation, nutrition goal calculations, contextual/reward nudges | `intelligence` |
| `'memory'` | Long-term conversation summary embedding and semantic memory search | `embed-memory`, `search-memory`, `intelligence` |
| `'*'` | **All AI features** for the target clinic (or globally when `org_id IS NULL`) | All AI Edge Functions |

## Precedence & Fail-Closed Rules

1. **Default On**: If no row matches `(org_id, feature)` or `(NULL, feature)` or `(org_id, '*')` or `(NULL, '*')`, the feature is enabled.
2. **Per-Clinic vs. All-Clinics**: For a given `feature`, a clinic's own row (`org_id = <clinic_uuid>`) overrides the all-clinics row (`org_id IS NULL`).
3. **Wildcard (`'*'`)**: Any applicable `enabled = false` row for `'*'` disables **all** AI features for that scope, even if a specific feature row has `enabled = true`.
4. **Fail Closed (`503`)**: If the Edge Function cannot read `public.ai_feature_switches` or `public.patients`, it returns `503` and **never** calls the AI model provider.
5. **Audit Trail**: Every `INSERT`, `UPDATE`, or `DELETE` on `public.ai_feature_switches` triggers `public.ai_feature_switches_audit()`, writing an append-only row (`ai_feature_switch_insert`, `ai_feature_switch_update`, `ai_feature_switch_delete`) to `public.audit_log`.

## Operator SQL Commands

Run these commands using a privileged database role (`postgres` / `service_role`). Client roles (`anon`, `authenticated`) have zero table privileges on `public.ai_feature_switches`.

### 1. Disable a specific AI feature for one clinic
```sql
insert into public.ai_feature_switches (org_id, feature, enabled, reason)
values (
  '<clinic-org-uuid>',
  'companion',
  false,
  'Clinic requested companion pause pending medical director review'
)
on conflict ((coalesce(org_id, '00000000-0000-0000-0000-000000000000'::uuid)), feature)
do update set
  enabled = excluded.enabled,
  reason = excluded.reason;
```

### 2. Disable ALL AI features for one clinic
```sql
insert into public.ai_feature_switches (org_id, feature, enabled, reason)
values (
  '<clinic-org-uuid>',
  '*',
  false,
  'Regulatory hold on all AI features for this clinic'
)
on conflict ((coalesce(org_id, '00000000-0000-0000-0000-000000000000'::uuid)), feature)
do update set
  enabled = excluded.enabled,
  reason = excluded.reason;
```

### 3. Disable an AI feature globally across all clinics
```sql
insert into public.ai_feature_switches (org_id, feature, enabled, reason)
values (
  null,
  'food_analysis',
  false,
  'Global pause on food_analysis feature'
)
on conflict ((coalesce(org_id, '00000000-0000-0000-0000-000000000000'::uuid)), feature)
do update set
  enabled = excluded.enabled,
  reason = excluded.reason;
```

### 4. Re-enable a switched-off feature
```sql
update public.ai_feature_switches
set enabled = true,
    reason = 'Cleared by compliance review'
where org_id = '<clinic-org-uuid>'
  and feature = 'companion';
```

### 5. Inspect active switches and audit history
```sql
select org_id, feature, enabled, reason, changed_at
from public.ai_feature_switches
order by changed_at desc;

select action, target_org_id, metadata, created_at
from public.audit_log
where action like 'ai_feature_switch_%'
order by created_at desc;
```
