-- APP-08: food_logs and the private `food-images` bucket. Each patient reaches
-- only their own meal logs and photos; own-clinic physicians / coordinators
-- read them (aal2), photos only through a meal log they can read; read_only,
-- other clinics, other patients and anon get nothing; org_id always comes
-- from the patient. Fictional data only.
begin;
select no_plan();

reset role;
select set_config('request.jwt.claims', '', true);
select set_config('storage.allow_delete_query', 'true', true);

-- Actors (global fixtures): patient A1 a1001 (clinic A), patient B1 b1001
-- (clinic B), physician A a0002, coordinator A a0003, read_only A a0004,
-- physician B b0001.

-- ---------------------------------------------------------------------------
-- Structure
-- ---------------------------------------------------------------------------
select has_table('public', 'food_logs', 'food_logs exists');
select is((select relforcerowsecurity from pg_class where oid = 'public.food_logs'::regclass), true,
          'food_logs forces RLS');
select is((select coalesce((to_jsonb(b) ->> 'public')::boolean, false) from storage.buckets b where id = 'food-images'),
          false, 'food-images bucket exists and is NOT public');
select is(
  (select array_agg(policyname::text order by policyname) from pg_policies
    where schemaname = 'storage' and tablename = 'objects'
      and (coalesce(qual, '') || coalesce(with_check, '')) like '%food-images%'),
  array['food_images_objects_self_delete_unfiled', 'food_images_objects_self_insert',
        'food_images_objects_self_select', 'food_images_objects_staff_select'],
  'exactly the four reviewed storage.objects policies cover food-images');
select ok(not has_function_privilege('authenticated', 'public.food_logs_set_org()', 'EXECUTE'),
          'trigger function is not callable by clients');

-- ---------------------------------------------------------------------------
-- Patient A1 logs meals; org_id is taken from the patient, not the client
-- ---------------------------------------------------------------------------
select tests.authenticate_as('00000000-0000-0000-0000-0000000a1001', 'aal1');

select lives_ok($$
  insert into public.food_logs (id, patient_id, image_path, analysis_json, meal_type, logged_at)
  values ('00000000-0000-0000-0000-0000000f0a01', '00000000-0000-0000-0000-0000000a1001',
          '00000000-0000-0000-0000-0000000a1001/1730700000000.jpg', '{"calories": 540}', 'MEAL', now())
$$, 'patient logs a photo meal');
select lives_ok($$
  insert into public.food_logs (id, patient_id, org_id, analysis_json)
  values ('00000000-0000-0000-0000-0000000f0a02', '00000000-0000-0000-0000-0000000a1001',
          '00000000-0000-0000-0000-00000000000b', '{"calories": 210}')
$$, 'patient logs a text meal (spoofed org_id is overwritten)');
select is((select org_id from public.food_logs where id = '00000000-0000-0000-0000-0000000f0a02'),
          '00000000-0000-0000-0000-00000000000a'::uuid, 'org_id comes from the patient row');

select throws_ok($$
  insert into public.food_logs (patient_id, analysis_json)
  values ('00000000-0000-0000-0000-0000000b1001', '{}')
$$, '42501', null, 'patient cannot log a meal for another patient');
select throws_ok($$
  insert into public.food_logs (patient_id, image_path)
  values ('00000000-0000-0000-0000-0000000a1001', '00000000-0000-0000-0000-0000000b1001/1.jpg')
$$, '23514', null, 'image_path must be inside the patient''s own folder');

select lives_ok($$
  update public.food_logs set validation_insight = 'Heart rate settled within 40 minutes.',
         validation_hr_delta = 6 where id = '00000000-0000-0000-0000-0000000f0a01'
$$, 'patient app writes the post-meal check back');
select is((select count(*)::int from public.food_logs), 2, 'patient sees only their own two logs');

-- Photos: own folder only
select lives_ok($$
  insert into storage.objects (bucket_id, name)
  values ('food-images', '00000000-0000-0000-0000-0000000a1001/1730700000000.jpg')
$$, 'patient uploads a meal photo into their folder');
select throws_ok($$
  insert into storage.objects (bucket_id, name)
  values ('food-images', '00000000-0000-0000-0000-0000000b1001/1730700000001.jpg')
$$, '42501', null, 'patient cannot upload into another patient''s folder');
select throws_ok($$
  insert into storage.objects (bucket_id, name)
  values ('food-images', '00000000-0000-0000-0000-0000000a1001/notes.pdf')
$$, '42501', null, 'only image files are accepted');
select is((select count(*)::int from storage.objects where bucket_id = 'food-images'
             and name = '00000000-0000-0000-0000-0000000a1001/1730700000000.jpg'), 1,
          'patient can read own photo');

-- ---------------------------------------------------------------------------
-- Patient B1 (other clinic) sees nothing of A1
-- ---------------------------------------------------------------------------
select tests.authenticate_as('00000000-0000-0000-0000-0000000b1001', 'aal1');
select is((select count(*)::int from public.food_logs), 0, 'other patient sees no meal logs');
select is((select count(*)::int from storage.objects where bucket_id = 'food-images'), 0,
          'other patient sees no meal photos');
select is((with d as (delete from public.food_logs returning 1) select count(*)::int from d), 0,
          'other patient cannot delete A1''s logs');

-- ---------------------------------------------------------------------------
-- Staff
-- ---------------------------------------------------------------------------
select tests.authenticate_as('00000000-0000-0000-0000-0000000a0002', 'aal2');
select is((select count(*)::int from public.food_logs), 2, 'own-clinic physician (aal2) reads the meal logs');
select is((select count(*)::int from storage.objects where bucket_id = 'food-images'), 1,
          'own-clinic physician reads the filed photo');
select throws_ok($$
  insert into public.food_logs (patient_id, analysis_json) values ('00000000-0000-0000-0000-0000000a1001', '{}')
$$, '42501', null, 'physician cannot write meal logs');

select tests.authenticate_as('00000000-0000-0000-0000-0000000a0002', 'aal1');
select is((select count(*)::int from public.food_logs), 0, 'physician without aal2 reads nothing');

select tests.authenticate_as('00000000-0000-0000-0000-0000000a0003', 'aal2');
select is((select count(*)::int from public.food_logs), 2, 'own-clinic care coordinator reads the meal logs');

select tests.authenticate_as('00000000-0000-0000-0000-0000000a0004', 'aal2');
select is((select count(*)::int from public.food_logs), 0, 'read_only reads no meal logs');
select is((select count(*)::int from storage.objects where bucket_id = 'food-images'), 0,
          'read_only reads no meal photos');

select tests.authenticate_as('00000000-0000-0000-0000-0000000b0001', 'aal2');
select is((select count(*)::int from public.food_logs), 0, 'other-clinic physician reads nothing');
select is((select count(*)::int from storage.objects where bucket_id = 'food-images'), 0,
          'other-clinic physician reads no photos');

select tests.authenticate_as_anon();
select throws_ok($$ select count(*) from public.food_logs $$, '42501', null, 'anon has no access to meal logs');
select is((select count(*)::int from storage.objects where bucket_id = 'food-images'), 0, 'anon lists no meal photos');

-- ---------------------------------------------------------------------------
-- Deleting: log first, then its photo (a filed photo can't be pulled out)
-- ---------------------------------------------------------------------------
select tests.authenticate_as('00000000-0000-0000-0000-0000000a1001', 'aal1');
select is((with d as (delete from storage.objects where bucket_id = 'food-images' returning 1)
           select count(*)::int from d), 0, 'a photo a meal log points at cannot be deleted');
select is((with d as (delete from public.food_logs where id = '00000000-0000-0000-0000-0000000f0a01' returning 1)
           select count(*)::int from d), 1, 'patient deletes their meal log');
select is((with d as (delete from storage.objects where bucket_id = 'food-images' returning 1)
           select count(*)::int from d), 1, 'then its photo');

select * from finish();
rollback;
