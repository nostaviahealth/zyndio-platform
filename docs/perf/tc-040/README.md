# TC-040 item 6: signed links on lab-report files at 10,000 patients per clinic

From Clara's #33 r2 review (L1) and Henry's note (3 Nov, 22:46 IST). The
budget is **every signed link under 5 ms at 10,000 patients per clinic**.

## What changed

`lab_reports_objects_staff_select` (storage.objects) checks that the file's
patient folder belongs to a patient of the caller's clinic. In PR #33
(`20261103220000`) that check was `p.id::text = split_part(name, '/', 1)`.
Casting the column to text hides it from `patients_pkey`. The planner then
read every patient of the clinic through `patients_org_id_idx` into a hash on
each request.

`20261103230000_tc040_lab_reports_staff_read_uuid.sql` compares on uuid instead:

```sql
p.id = case when split_part(objects.name, '/', 1)
                 ~ '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
            then split_part(objects.name, '/', 1)::uuid end
```

- Only the canonical lowercase form `uuid::text` produces is cast. Every other
  first segment becomes NULL and matches no patient, so the same folders match
  as before. That covers no folder, upper case, braces, no hyphens, sibling
  prefixes and garbage.
- A non-uuid segment can't raise `invalid input syntax for type uuid`, so it
  can't break listing or signing for real users.

## How to run the timing check (local only)

```bash
supabase start && supabase db reset         # or any local DB with the migrations
scripts/bench-lab-reports-sign.sh           # DB_URL=... to point at another LOCAL db
```

`sign_bench.sql` runs inside one transaction and then rolls it back. It creates
2 clinics × 10,000 fictional patients, each with one filed PDF, which gives
20,000 objects and 20,000 lab_reports rows. A physician of clinic X (aal2) then
"signs" 500 different own-clinic files. Before storage-api mints a signed URL,
it runs an RLS-checked `select` of the object as the caller. Each sample is
exactly that query, run through `EXECUTE` so it is planned per call, as a
request would be. The script exits 1 unless all 500 are allowed and the max is
under 5 ms.

## Results

These were run on the same box, using pg 15.19 (`supabase/postgres:15.19.0.007`)
with the storage schema from storage-api v1.84.19.

| schema | p50 | p95 | p99 | max | verdict | file |
|---|---|---|---|---|---|---|
| 4efb431 (PR #33, text compare) | 176.9 ms | 194.6 ms | 220.7 ms | 250.9 ms | FAIL | `sign-bench-before-4efb431.txt` |
| TC-040 (uuid compare) | 1.13 ms | 1.68 ms | 2.01 ms | 2.19 ms | PASS | `sign-bench-after-tc040.txt` |

Here is the plan for one sign, from `explain analyze` in the same files:

- before: `Index Scan using patients_org_id_idx on patients p (rows=10000)`,
  execution 167.9 ms
- after: `Index Scan using patients_pkey on patients p (rows=1)`, execution
  under 1 ms

pgTAP `745_tc040_lab_reports_staff_read_uuid.sql` pins the plan shape at the
same scale. The sign must use `patients_pkey`, with no `patients_org_id_idx`
and no seq scan on patients. A timer in CI would be flaky, so the deterministic
part is checked there and the timing lives here.

The samples include per-call planning (~1 ms). On a busy box I saw single
outliers up to ~4.9 ms in one of five repeat runs; the other four had a max of
1.6–3.3 ms. On a production-size instance that is still inside the budget,
but it's the number to watch if the box is loaded.

## Not covered (open)

Clara also measured a full staff **listing** of the bucket at 20,000 objects
(`count(*)`). It takes about 1 s with either rule, because it is a seq scan
over storage.objects. That cost is listing, not signing, and the app lists by
patient folder (prefix), not the whole bucket. It is left for a separate card
if a whole-bucket staff listing ever appears.
