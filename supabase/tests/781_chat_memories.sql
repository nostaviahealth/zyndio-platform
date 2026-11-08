-- chat_memories / match_memories (migration 20261108120000).
--
-- Proves: the table exists with RLS forced; a confirmed, linked patient reads
-- and deletes only their own memories (positive controls included); nobody
-- can insert or update through the API - rows come only from embed-memory
-- running as service_role; anon sees nothing; match_memories is service-role
-- only and never returns another user's rows; size caps hold.
begin;
set local search_path = public, extensions, pg_catalog;
select no_plan();

reset role;
select set_config('request.jwt.claims', '', true);

select has_table('public', 'chat_memories', 'chat_memories exists');
select ok(
  (select relrowsecurity and relforcerowsecurity from pg_class where oid = 'public.chat_memories'::regclass),
  'chat_memories has RLS enabled and forced'
);

-- Fixtures: a1001 (clinic A) and b1001 (clinic B) are confirmed, linked
-- patients in the global fixtures.
insert into public.chat_memories (id, user_id, content, embedding, memory_type) values
  ('00000000-0000-0000-0000-0000000c7a01', '00000000-0000-0000-0000-0000000a1001',
   'Fictional: prefers morning workouts', array_fill(0.1::real, array[1536])::extensions.vector, 'user_fact'),
  ('00000000-0000-0000-0000-0000000c7a02', '00000000-0000-0000-0000-0000000a1001',
   'Fictional: knee niggle last spring', array_fill(0.1::real, array[1536])::extensions.vector, 'health_event'),
  ('00000000-0000-0000-0000-0000000c7b01', '00000000-0000-0000-0000-0000000b1001',
   'Fictional: vegetarian', array_fill(0.1::real, array[1536])::extensions.vector, 'user_fact');

-- ── service_role (embed-memory / search-memory) ──
select tests.authenticate_as_service_role();
select is(
  (select count(*)::int from public.match_memories(
     array_fill(0.1::real, array[1536])::extensions.vector,
     '00000000-0000-0000-0000-0000000a1001', 5, 0.3)),
  2,
  'match_memories returns the requested patient''s own matches (positive control)'
);
select is(
  (select count(*)::int from public.match_memories(
     array_fill(0.1::real, array[1536])::extensions.vector,
     '00000000-0000-0000-0000-0000000a1001', 5, 0.3) m
   where m.id = '00000000-0000-0000-0000-0000000c7b01'),
  0,
  'match_memories never returns another patient''s memory'
);
select is(
  (select count(*)::int from public.match_memories(
     array_fill(0.1::real, array[1536])::extensions.vector,
     '00000000-0000-0000-0000-0000000a1001', 100000, 0.3)),
  2,
  'match_memories accepts a huge match_count without error (clamped)'
);

-- ── grants ──
reset role;
select ok(not has_function_privilege('authenticated',
  'public.match_memories(extensions.vector, uuid, integer, double precision)', 'EXECUTE'),
  'authenticated cannot execute match_memories');
select ok(not has_function_privilege('anon',
  'public.match_memories(extensions.vector, uuid, integer, double precision)', 'EXECUTE'),
  'anon cannot execute match_memories');
select ok(has_function_privilege('service_role',
  'public.match_memories(extensions.vector, uuid, integer, double precision)', 'EXECUTE'),
  'service_role can execute match_memories');
select ok(not has_table_privilege('authenticated', 'public.chat_memories', 'INSERT'),
  'authenticated has no INSERT on chat_memories');
select ok(not has_table_privilege('authenticated', 'public.chat_memories', 'UPDATE'),
  'authenticated has no UPDATE on chat_memories');
select ok(not has_table_privilege('anon', 'public.chat_memories', 'SELECT'),
  'anon has no SELECT on chat_memories');

-- ── patient A1 ──
select tests.authenticate_as('00000000-0000-0000-0000-0000000a1001', 'aal2');
select is(
  (select count(*)::int from public.chat_memories),
  2,
  'patient A1 sees exactly their own two memories (positive control)'
);
select is(
  (select count(*)::int from public.chat_memories
    where user_id = '00000000-0000-0000-0000-0000000b1001'),
  0,
  'patient A1 cannot read patient B1''s memories'
);
select throws_ok(
  $$ insert into public.chat_memories (user_id, content)
     values ('00000000-0000-0000-0000-0000000a1001', 'forged') $$,
  '42501',
  null,
  'patient cannot insert memories directly (only embed-memory can)'
);
select throws_ok(
  $$ update public.chat_memories set content = 'changed'
      where id = '00000000-0000-0000-0000-0000000c7a01' $$,
  '42501',
  null,
  'patient cannot update memories'
);
delete from public.chat_memories where id = '00000000-0000-0000-0000-0000000c7b01';
delete from public.chat_memories where id = '00000000-0000-0000-0000-0000000c7a02';
select throws_ok(
  $$ select * from public.match_memories(
       array_fill(0.1::real, array[1536])::extensions.vector,
       '00000000-0000-0000-0000-0000000b1001', 5, 0.3) $$,
  '42501',
  null,
  'patient cannot call match_memories'
);

-- ── anon ──
select tests.authenticate_as_anon();
select throws_ok(
  $$ select count(*) from public.chat_memories $$,
  '42501',
  null,
  'anon cannot read chat_memories'
);

-- ── effects of the patient deletes, checked as the owner ──
reset role;
select set_config('request.jwt.claims', '', true);
select is(
  (select count(*)::int from public.chat_memories where id = '00000000-0000-0000-0000-0000000c7b01'),
  1,
  'patient A1''s delete did not remove patient B1''s memory'
);
select is(
  (select count(*)::int from public.chat_memories where id = '00000000-0000-0000-0000-0000000c7a02'),
  0,
  'patient A1 can delete their own memory (positive control)'
);

-- ── size caps ──
select throws_ok(
  $$ insert into public.chat_memories (user_id, content)
     values ('00000000-0000-0000-0000-0000000a1001', repeat('x', 4001)) $$,
  '23514',
  null,
  'content over 4000 characters is rejected'
);
select throws_ok(
  $$ insert into public.chat_memories (user_id, content, memory_type)
     values ('00000000-0000-0000-0000-0000000a1001', 'x', 'anything') $$,
  '23514',
  null,
  'unknown memory_type is rejected'
);
select throws_ok(
  $$ insert into public.chat_memories (user_id, content, metadata)
     values ('00000000-0000-0000-0000-0000000a1001', 'x', '[]'::jsonb) $$,
  '23514',
  null,
  'non-object metadata is rejected'
);

select * from finish();
rollback;
