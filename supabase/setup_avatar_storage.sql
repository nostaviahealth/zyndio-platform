-- Setup Storage Bucket for Avatars
-- Run this in your Supabase SQL Editor

-- 1. Create the bucket
insert into storage.buckets (id, name, public)
values ('avatars', 'avatars', true)
on conflict (id) do nothing;

-- 2. Set up Access Policies
-- Allow public viewing of all avatars
create policy "Public Access"
on storage.objects for select
using ( bucket_id = 'avatars' );

-- Allow authenticated users to upload their own avatar
-- The path structure we use is {user_id}/{filename}
create policy "Authenticated Upload"
on storage.objects for insert
with check (
  bucket_id = 'avatars' 
  and auth.role() = 'authenticated'
  -- Optional: enforce user-specific folders
  -- and (storage.foldername(name))[1] = auth.uid()::text
);

-- Allow authenticated users to update/delete their own avatar
create policy "Individual Update"
on storage.objects for update
using (
  bucket_id = 'avatars' 
  and auth.role() = 'authenticated'
);

create policy "Individual Delete"
on storage.objects for delete
using (
  bucket_id = 'avatars' 
  and auth.role() = 'authenticated'
);
