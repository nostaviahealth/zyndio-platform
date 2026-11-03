-- TC-040 item 6 (Clara #33 r2 L1, performance): the clinic-staff read rule on
-- lab-report files compares the patient folder to patients.id as a UUID, so
-- each signed link is one patients_pkey lookup instead of a scan of every
-- patient in the clinic.
--
-- 20261103220000 compared `p.id::text = split_part(objects.name, '/', 1)`.
-- Casting the column to text hides it from patients_pkey, so the planner
-- hashed every patient of the caller's clinic (patients_org_id_idx) for each
-- request: ~189 ms per sign at 10,000 patients per clinic. Budget (Henry,
-- 3 Nov 22:46 IST): under 5 ms per signed link at 10,000 patients per clinic.
--
-- Same meaning as before, only faster:
--   * the first path segment is turned into a uuid ONLY when it is exactly the
--     canonical lowercase form uuid::text produces (8-4-4-4-12 hex). Anything
--     else (no folder, upper case, braces, no hyphens, '..', '%2F', a longer
--     "sibling" segment, garbage) becomes NULL, which matches no patient. So
--     the set of folders that match is identical to the old text compare,
--     and a non-uuid segment can never raise an "invalid input syntax for
--     type uuid" error that would break listing or signing for everyone.
--     CASE evaluates its THEN branch only when the WHEN test is true, so the
--     cast never sees a non-matching segment.
--   * everything else is unchanged: bucket, aal2, physician/care_coordinator,
--     a lab_reports row in the caller's clinic points at the object, and the
--     folder's patient is in the caller's clinic.
-- Same policy name, so the TC-036 guard and pgTAP 744's policy-set check hold.
-- Forward-only: 20261103210000 and 20261103220000 are on PR #33 already.
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
       where p.id = (
               case
                 when split_part(objects.name, '/', 1)
                      ~ '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$'
                 then split_part(objects.name, '/', 1)::uuid
               end)
         and p.org_id = public.current_org_id()
    )
  );
