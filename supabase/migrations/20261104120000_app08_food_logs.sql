-- APP-08: food logging by photo or text. The patient app has always written
-- meal logs to public.food_logs and meal photos to the `food-images` bucket,
-- but no migration created either, so every log failed silently and photos
-- were shown through getPublicUrl() links that only open on a public bucket.
-- This creates both, private, on the same model as lab reports (TC-012
-- patient gates, TC-036 storage):
--
--   * the patient: read, add, change and delete their own meal logs, once
--     their email is confirmed and their account is linked (same gates as
--     lab_reports_self_*). Photos live under <patient_id>/ in the bucket.
--   * clinic staff: read only, physician / care_coordinator, own clinic,
--     aal2 (the meal timeline, POR-03). Photos only when a meal log they can
--     already read points at them. read_only and org_admin get nothing, as
--     with raw lab reports.
--   * anon: nothing. service_role bypasses RLS, as before.
--
-- org_id is not sent by the app; a trigger copies it from the patient so a
-- row can never be filed under another clinic.

-- ---------------------------------------------------------------------------
-- 1. Table
-- ---------------------------------------------------------------------------
create table if not exists public.food_logs (
  id uuid primary key default gen_random_uuid(),
  org_id uuid not null references public.organizations (id) on delete cascade,
  patient_id uuid not null references public.patients (id) on delete cascade,
  -- Object path in food-images. Unique: the app upserts the fast analysis and
  -- then the deep analysis of the same photo onto one row.
  image_path text unique,
  analysis_json jsonb not null default '{}'::jsonb,
  meal_type text,
  logged_at timestamptz not null default now(),
  -- Post-meal heart-rate check written back by the app's meal watchdog.
  validation_insight text,
  validation_hr_delta numeric,
  validation_hrv_delta numeric,
  validation_checked_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint food_logs_image_path_own_folder check (
    image_path is null
    or image_path ~ ('^' || patient_id::text || '/[A-Za-z0-9_][A-Za-z0-9._-]{0,199}$')
  ),
  constraint food_logs_meal_type_length check (meal_type is null or char_length(meal_type) <= 40),
  constraint food_logs_insight_length check (validation_insight is null or char_length(validation_insight) <= 2000),
  constraint food_logs_analysis_size check (pg_column_size(analysis_json) <= 65536)
);

create index if not exists food_logs_patient_logged_at_idx on public.food_logs (patient_id, logged_at desc);
create index if not exists food_logs_org_id_idx on public.food_logs (org_id);

-- Security invoker: the patient can read their own patients row, and nobody
-- else writes here. Trigger functions need no EXECUTE grant (TC-040 allowlist
-- stays closed).
create or replace function public.food_logs_set_org()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.org_id := (select p.org_id from public.patients p where p.id = new.patient_id);
  if new.org_id is null then
    raise exception 'food_logs: unknown patient' using errcode = '23503';
  end if;
  new.updated_at := now();
  return new;
end;
$$;

drop trigger if exists food_logs_set_org on public.food_logs;
create trigger food_logs_set_org
  before insert or update of patient_id, org_id on public.food_logs
  for each row execute function public.food_logs_set_org();

drop trigger if exists food_logs_touch on public.food_logs;
create or replace function public.food_logs_touch()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.updated_at := now();
  return new;
end;
$$;
create trigger food_logs_touch
  before update on public.food_logs
  for each row execute function public.food_logs_touch();

revoke execute on function public.food_logs_set_org() from public, anon, authenticated;
revoke execute on function public.food_logs_touch() from public, anon, authenticated;

-- ---------------------------------------------------------------------------
-- 2. Row level security
-- ---------------------------------------------------------------------------
alter table public.food_logs enable row level security;
alter table public.food_logs force row level security;

revoke all on public.food_logs from anon;
grant select, insert, update, delete on public.food_logs to authenticated;

drop policy if exists food_logs_self_select on public.food_logs;
create policy food_logs_self_select on public.food_logs
  for select to authenticated
  using (
    patient_id = auth.uid()
    and public.current_email_confirmed()
    and public.current_patient_linked()
  );

drop policy if exists food_logs_self_insert on public.food_logs;
create policy food_logs_self_insert on public.food_logs
  for insert to authenticated
  with check (
    patient_id = auth.uid()
    and public.current_email_confirmed()
    and public.current_patient_linked()
  );

drop policy if exists food_logs_self_update on public.food_logs;
create policy food_logs_self_update on public.food_logs
  for update to authenticated
  using (
    patient_id = auth.uid()
    and public.current_email_confirmed()
    and public.current_patient_linked()
  )
  with check (
    patient_id = auth.uid()
    and public.current_email_confirmed()
    and public.current_patient_linked()
  );

drop policy if exists food_logs_self_delete on public.food_logs;
create policy food_logs_self_delete on public.food_logs
  for delete to authenticated
  using (
    patient_id = auth.uid()
    and public.current_email_confirmed()
    and public.current_patient_linked()
  );

drop policy if exists food_logs_staff_select on public.food_logs;
create policy food_logs_staff_select on public.food_logs
  for select to authenticated
  using (
    org_id = public.current_org_id()
    and public.has_aal2()
    and public.current_role() in ('physician', 'care_coordinator')
  );

-- ---------------------------------------------------------------------------
-- 3. The bucket, private (same storage-api column probing as TC-036).
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

  insert into storage.buckets (id, name) values ('food-images', 'food-images')
  on conflict (id) do nothing;

  if has_public then
    execute $q$update storage.buckets set public = false where id = 'food-images'$q$;
  end if;
  if has_limits then
    execute $q$update storage.buckets
                  set file_size_limit = 10485760,
                      allowed_mime_types = array['image/jpeg', 'image/png', 'image/heic', 'image/webp']
                where id = 'food-images'$q$;
  end if;
end;
$$;

-- ---------------------------------------------------------------------------
-- 4. storage.objects policies (split_part, not storage.foldername(): see
--    TC-036). No update policy: an upload never overwrites.
-- ---------------------------------------------------------------------------
drop policy if exists food_images_objects_self_select on storage.objects;
create policy food_images_objects_self_select on storage.objects
  for select to authenticated
  using (
    bucket_id = 'food-images'
    and split_part(objects.name, '/', 1) = auth.uid()::text
    and public.current_email_confirmed()
    and public.current_patient_linked()
  );

drop policy if exists food_images_objects_self_insert on storage.objects;
create policy food_images_objects_self_insert on storage.objects
  for insert to authenticated
  with check (
    bucket_id = 'food-images'
    and name ~ ('^' || auth.uid()::text || '/[A-Za-z0-9_][A-Za-z0-9_-]{0,100}\.(jpg|jpeg|png|heic|webp)$')
    and public.current_email_confirmed()
    and public.current_patient_linked()
  );

-- The app deletes the meal log first, then its photo; a photo a log still
-- points at cannot be pulled out from under it.
drop policy if exists food_images_objects_self_delete_unfiled on storage.objects;
create policy food_images_objects_self_delete_unfiled on storage.objects
  for delete to authenticated
  using (
    bucket_id = 'food-images'
    and split_part(objects.name, '/', 1) = auth.uid()::text
    and public.current_email_confirmed()
    and public.current_patient_linked()
    and not exists (select 1 from public.food_logs f where f.image_path = objects.name)
  );

drop policy if exists food_images_objects_staff_select on storage.objects;
create policy food_images_objects_staff_select on storage.objects
  for select to authenticated
  using (
    bucket_id = 'food-images'
    and public.has_aal2()
    and public.current_role() in ('physician', 'care_coordinator')
    and exists (
      select 1 from public.food_logs f
       where f.image_path = objects.name
         and f.org_id = public.current_org_id()
    )
  );

-- A hand-made policy elsewhere on storage.objects that mentions this bucket
-- would be OR-ed with the ones above and could reopen it.
do $$
declare
  foreign_policies text;
begin
  select string_agg(policyname, ', ') into foreign_policies
    from pg_policies
   where schemaname = 'storage' and tablename = 'objects'
     and policyname not in ('food_images_objects_self_select', 'food_images_objects_self_insert',
                            'food_images_objects_self_delete_unfiled', 'food_images_objects_staff_select')
     and (coalesce(qual, '') || coalesce(with_check, '')) like '%food-images%';
  if foreign_policies is not null then
    raise exception 'APP-08: unreviewed storage.objects policies mention food-images: %', foreign_policies;
  end if;
end;
$$;
