-- TC-036 r1 (Clara M1 on PR #33): clinic staff may read a lab-report FILE only
-- when the patient folder in the object path is a patient of THEIR OWN clinic.
--
-- Before this, lab_reports_objects_staff_select only required that some
-- lab_reports row in the caller's clinic had pdf_path = the object name. Staff
-- can write lab_reports rows for another clinic's patient (lab_reports insert
-- checks only org_id; a physician can re-point patient_id; root cause is card
-- TC-040), and the pdf_path CHECK only ties the path to the row's own
-- patient_id. So a clinic-B physician could file a clinic-B row naming
-- clinic-A patient A1 and A1's object, then sign and download A1's PDF.
--
-- Now BOTH must hold (plus the unchanged role/aal2 gate):
--   1. a lab_reports row in the caller's clinic points at the object
--      (unfiled uploads stay patient-only), and
--   2. the object's first path segment, compared as an exact segment
--      (split_part, never a LIKE prefix), is the id of a patient whose
--      org_id is the caller's clinic.
-- The row being forged no longer matters for file access: a foreign patient's
-- folder never matches (2). Same policy name, so the TC-036 guard list and
-- pgTAP 744's policy-set check are unchanged. New migration rather than an
-- edit: 20261103210000 is already pushed on PR #33.
--
-- Correction to 20261103210000's comment (Clara Low 7): CI does run storage-api.
-- `supabase start -x studio,storage,inbucket` ignores "storage" (not a valid
-- exclude name; the valid one is storage-api), so CI starts storage-api
-- v1.84.19. The bucket-column guard there is still right for databases
-- without storage-api's columns; only the "(CI runs -x storage)" aside is wrong.
drop policy if exists lab_reports_objects_staff_select on storage.objects;
create policy lab_reports_objects_staff_select on storage.objects
  for select to authenticated
  using (
    bucket_id = 'lab-reports'
    and public.has_aal2()
    and public.current_role() in ('physician', 'care_coordinator')
    and exists (
      select 1 from public.lab_reports r
       where r.pdf_path = objects.name
         and r.org_id = public.current_org_id()
    )
    and exists (
      select 1 from public.patients p
       where p.id::text = split_part(objects.name, '/', 1)
         and p.org_id = public.current_org_id()
    )
  );
