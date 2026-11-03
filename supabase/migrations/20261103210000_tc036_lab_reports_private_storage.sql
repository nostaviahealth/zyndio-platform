-- TC-036: lab-report files live in a PRIVATE bucket, reachable only through
-- storage.objects RLS, and lab_reports stores the object PATH, never a URL.
--
-- Before this, nothing in the repo created the `lab-reports` bucket or any
-- storage policy, and the patient app saved getPublicUrl() links (which only
-- open if the bucket is public). Idempotent: safe to re-run, and safe on a
-- database where the bucket was created by hand (it is forced private).
--
-- Path layout: <patient_id>/<uuid>.<ext>. The first folder is the patient's
-- auth user id (= public.patients.id = lab_reports.patient_id).
--
-- Who can reach an object (all policies are `to authenticated`; anon has none):
--   * the patient whose folder it is: read; upload new uuid-named files; delete
--     a file ONLY while no lab_reports row points at it (orphan cleanup after a
--     failed insert). No update: an upload never overwrites (upsert off), and a
--     filed report's PDF is as immutable as the report row.
--     Same email-confirmed + linked gates as lab_reports_self_*.
--   * clinic staff: read only, and only a file that a lab_reports row THEY CAN
--     ALREADY READ points at. That inherits lab_reports RLS exactly
--     (lab_reports_staff_write_select: physician/care_coordinator, own clinic,
--     aal2), so read_only (H2: no raw reports), org_admin ("admins manage users
--     only"), other clinics and unfiled uploads get nothing. The role/aal2 gate
--     is repeated here so the policy stays closed if a lab_reports policy is
--     ever widened.
--   * service_role (Edge Functions) bypasses RLS, as before.
--
-- Data: new column lab_reports.pdf_path. The real schema never had a pdf_url
-- column (the old app insert failed on it), so the only place a saved link can
-- exist is the `data` payload (data->>'pdf_url'). Links that parse safely to
-- this patient's own folder in this bucket become pdf_path; anything else is
-- moved to a locked quarantine table for manual review. Either way the URL is
-- removed from `data`, so no URL stays readable by any client.

-- ---------------------------------------------------------------------------
-- 1. The bucket, private. storage-api adds public/file_size_limit/
--    allowed_mime_types; a database without storage-api (CI runs
--    `supabase start -x storage`) has only id/name, so set them when present.
-- ---------------------------------------------------------------------------
do $$
declare
  has_public boolean;
  has_limits boolean;
begin
  select exists (select 1 from information_schema.columns
                  where table_schema = 'storage' and table_name = 'buckets' and column_name = 'public')
    into has_public;
  select exists (select 1 from information_schema.columns
                  where table_schema = 'storage' and table_name = 'buckets' and column_name = 'allowed_mime_types')
    into has_limits;

  insert into storage.buckets (id, name) values ('lab-reports', 'lab-reports')
  on conflict (id) do nothing;

  if has_public then
    execute $q$update storage.buckets set public = false where id = 'lab-reports'$q$;
  end if;
  if has_limits then
    execute $q$update storage.buckets
                  set file_size_limit = 52428800,
                      allowed_mime_types = array['application/pdf', 'image/jpeg', 'image/png', 'image/heic', 'image/webp']
                where id = 'lab-reports'$q$;
  end if;
end;
$$;

-- ---------------------------------------------------------------------------
-- 2. lab_reports.pdf_path: the object path inside lab-reports, always inside
--    the report's own patient folder, one path segment, never a URL.
-- ---------------------------------------------------------------------------
alter table public.lab_reports add column if not exists pdf_path text;

alter table public.lab_reports drop constraint if exists lab_reports_pdf_path_own_folder;
alter table public.lab_reports add constraint lab_reports_pdf_path_own_folder check (
  pdf_path is null
  or pdf_path ~ ('^' || patient_id::text || '/[A-Za-z0-9_][A-Za-z0-9._-]{0,199}$')
);

create index if not exists lab_reports_pdf_path_idx
  on public.lab_reports (pdf_path) where pdf_path is not null;

-- ---------------------------------------------------------------------------
-- 3. Storage policies on storage.objects for this bucket.
-- ---------------------------------------------------------------------------
drop policy if exists lab_reports_objects_self_select on storage.objects;
create policy lab_reports_objects_self_select on storage.objects
  for select to authenticated
  using (
    bucket_id = 'lab-reports'
    and (storage.foldername(name))[1] = auth.uid()::text
    and public.current_email_confirmed()
    and public.current_patient_linked()
  );

drop policy if exists lab_reports_objects_self_insert on storage.objects;
create policy lab_reports_objects_self_insert on storage.objects
  for insert to authenticated
  with check (
    bucket_id = 'lab-reports'
    and name ~ ('^' || auth.uid()::text
                || '/[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}\.(pdf|jpg|jpeg|png|heic|webp)$')
    and public.current_email_confirmed()
    and public.current_patient_linked()
  );

drop policy if exists lab_reports_objects_self_delete_unfiled on storage.objects;
create policy lab_reports_objects_self_delete_unfiled on storage.objects
  for delete to authenticated
  using (
    bucket_id = 'lab-reports'
    and (storage.foldername(name))[1] = auth.uid()::text
    and public.current_email_confirmed()
    and public.current_patient_linked()
    -- Only the patient's own rows can point into their folder (check
    -- constraint above), and lab_reports_self_select shows them all, so this
    -- sees every reference.
    and not exists (select 1 from public.lab_reports r where r.pdf_path = objects.name)
  );

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
  );

-- A hand-made policy elsewhere on storage.objects that mentions this bucket
-- would be OR-ed with the ones above and could reopen it. Fail the migration
-- loudly instead of guessing which to drop.
do $$
declare
  foreign_policies text;
begin
  select string_agg(policyname, ', ') into foreign_policies
    from pg_policies
   where schemaname = 'storage' and tablename = 'objects'
     and policyname not in ('lab_reports_objects_self_select', 'lab_reports_objects_self_insert',
                            'lab_reports_objects_self_delete_unfiled', 'lab_reports_objects_staff_select')
     and (coalesce(qual, '') || coalesce(with_check, '')) like '%lab-reports%';
  if foreign_policies is not null then
    raise exception 'TC-036: unreviewed storage.objects policies mention lab-reports: %', foreign_policies;
  end if;
end;
$$;

-- ---------------------------------------------------------------------------
-- 4. Saved links -> object paths.
-- ---------------------------------------------------------------------------
create table if not exists public.lab_report_pdf_url_quarantine (
  lab_report_id uuid primary key references public.lab_reports (id) on delete cascade,
  raw_value text not null,
  quarantined_at timestamptz not null default now()
);
alter table public.lab_report_pdf_url_quarantine enable row level security;
alter table public.lab_report_pdf_url_quarantine force row level security;
revoke all on public.lab_report_pdf_url_quarantine from public, anon, authenticated;

-- Returns the object path for a saved lab-reports link or bare path, or NULL
-- when it can't be read safely as an object in THIS patient's folder of THIS
-- bucket (other bucket or folder, extra segments, encoded or odd characters,
-- not a storage URL). Accepts public, signed and authenticated object URLs
-- from any host; query strings (e.g. a signed token) are dropped.
create or replace function public.lab_report_path_from_saved_url(p_value text, p_patient_id uuid)
returns text
language sql
immutable
set search_path = ''
as $$
  select case
    when candidate ~ ('^' || p_patient_id::text || '/[A-Za-z0-9_][A-Za-z0-9._-]{0,199}$') then candidate
    else null
  end
  from (
    select case
      when btrim(p_value) ~ '^https?://[^/?#]+/storage/v1/object/(public|sign|authenticated)/lab-reports/[^?#]+([?#].*)?$'
        then substring(btrim(p_value) from '^https?://[^/?#]+/storage/v1/object/(?:public|sign|authenticated)/lab-reports/([^?#]+)')
      when btrim(p_value) ~ '^lab-reports/[^:?#]+$' then substring(btrim(p_value) from 13)
      when btrim(p_value) !~ '[:?#]' then btrim(p_value)
      else null
    end as candidate
  ) c;
$$;

revoke all on function public.lab_report_path_from_saved_url(text, uuid) from public, anon, authenticated;

-- Converts every saved link, then strips it from the payload. Rows already
-- carrying a pdf_path keep it. Re-running is a no-op (no data->'pdf_url'
-- remains). Not client-callable; the migration runs it once below, and the
-- pgTAP suite runs it on fictional rows.
create or replace function public.lab_reports_convert_saved_pdf_urls(
  out converted integer, out quarantined integer)
language plpgsql
set search_path = ''
as $$
begin
  insert into public.lab_report_pdf_url_quarantine (lab_report_id, raw_value)
  select r.id, r.data ->> 'pdf_url'
    from public.lab_reports r
   where r.data ? 'pdf_url'
     and coalesce(r.data ->> 'pdf_url', '') <> ''
     and r.pdf_path is null
     and public.lab_report_path_from_saved_url(r.data ->> 'pdf_url', r.patient_id) is null
  on conflict (lab_report_id) do nothing;
  get diagnostics quarantined = row_count;

  select count(*)::int into converted
    from public.lab_reports r
   where r.data ? 'pdf_url'
     and r.pdf_path is null
     and public.lab_report_path_from_saved_url(r.data ->> 'pdf_url', r.patient_id) is not null;

  update public.lab_reports r
     set pdf_path = coalesce(r.pdf_path, public.lab_report_path_from_saved_url(r.data ->> 'pdf_url', r.patient_id)),
         data = r.data - 'pdf_url'
   where r.data ? 'pdf_url';
end;
$$;

revoke all on function public.lab_reports_convert_saved_pdf_urls() from public, anon, authenticated;

select * from public.lab_reports_convert_saved_pdf_urls();
