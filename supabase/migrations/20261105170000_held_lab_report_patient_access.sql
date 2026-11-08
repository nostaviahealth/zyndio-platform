-- Held lab reports are hidden from the patient on the server.
--
-- Before this, identity_hold was enforced for staff trends (lab_report_held)
-- and by a client filter (.eq identity_hold false). The patient SELECT
-- policies on lab_reports, lab_results, and storage.objects did not look at
-- the flag, so a modified client could read a held row and sign its file.
--
-- Patients: a held row is not visible, its lab_results are not visible, and
-- the object cannot be selected (storage-api signs only after that SELECT).
-- An unfiled object in the patient's own folder stays readable so an upload
-- can finish. Staff policies are not changed: a physician or care coordinator
-- in the same clinic, at aal2, can still open a held file for review.
--
-- own_lab_report_released / own_lab_file_released are SECURITY DEFINER so the
-- check is not hidden by the patient policy it protects (a subquery on
-- lab_reports would otherwise miss the held row and treat it as released).
-- Both return false for any row that is not this patient's released report.
-- They return a boolean, not lab values. Authenticated may execute them
-- because RLS runs as the caller; anon may not. Pinned in tests 747 and 743.

create function public.own_lab_report_released(p_lab_report_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
      from public.lab_reports r
     where r.id = p_lab_report_id
       and r.patient_id = (select auth.uid())
       and r.identity_hold = false
  );
$$;

create function public.own_lab_file_released(p_object_name text)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select split_part(p_object_name, '/', 1) = (select auth.uid())::text
     and not exists (
       select 1
         from public.lab_reports r
        where r.pdf_path = p_object_name
          and r.identity_hold
     );
$$;

revoke all on function public.own_lab_report_released(uuid) from public, anon, authenticated;
revoke all on function public.own_lab_file_released(text) from public, anon, authenticated;
grant execute on function public.own_lab_report_released(uuid) to authenticated;
grant execute on function public.own_lab_file_released(text) to authenticated;

drop policy if exists lab_reports_self_select on public.lab_reports;
create policy lab_reports_self_select on public.lab_reports
  for select to authenticated
  using (
    patient_id = (select auth.uid())
    and identity_hold = false
    and public.current_email_confirmed()
    and public.current_patient_linked()
  );

drop policy if exists lab_results_self_select on public.lab_results;
create policy lab_results_self_select on public.lab_results
  for select to authenticated
  using (
    patient_id = (select auth.uid())
    and public.own_lab_report_released(lab_report_id)
  );

drop policy if exists lab_reports_objects_self_select on storage.objects;
create policy lab_reports_objects_self_select on storage.objects
  for select to authenticated
  using (
    bucket_id = 'lab-reports'
    and split_part(objects.name, '/', 1) = (select auth.uid())::text
    and public.current_email_confirmed()
    and public.current_patient_linked()
    and public.own_lab_file_released(objects.name)
  );
