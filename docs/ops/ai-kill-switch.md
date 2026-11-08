# AI feature kill switch

Each AI route checks `public.ai_feature_switches` before a model call. The feature is the URL the request hit. A JSON `feature` field is not read.

The production behaviour of a missing row is not decided. This fictional candidate fails closed: a feature runs only when an explicit enabled row exists for it, and an applicable `*` row with `enabled = false` turns it off. Lookup errors return 503 and do not call a model.

Audit rows use `audit_log.event_type` and `audit_log.org_id`.

Operators with a database role that can write the table can insert or update a row. `anon` and `authenticated` cannot. Example, one clinic:

```sql
insert into public.ai_feature_switches (org_id, feature, enabled, reason)
values ('<clinic-uuid>', 'food_analysis', false, 'Clinic pause on meal analysis');
```
