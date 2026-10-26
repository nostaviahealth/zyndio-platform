-- TC-005 step 3: invites.user_id links an invite straight to the auth.users
-- row invite-user already created (no email->user_id resolution needed in
-- accept-invite). Nullable (existing/pre-step-3 rows never had one), FK'd to
-- auth.users with on delete cascade, indexed.
begin;
select no_plan();

select has_column('public', 'invites', 'user_id', 'invites has a user_id column');
select col_is_fk('public', 'invites', 'user_id', 'invites.user_id is a foreign key');
select is(
  (select is_nullable from information_schema.columns
     where table_schema = 'public' and table_name = 'invites' and column_name = 'user_id'),
  'YES',
  'invites.user_id is nullable'
);
select has_index('public', 'invites', 'invites_user_id_idx', 'invites_user_id_idx exists');

-- functional: on delete cascade from auth.users removes the invite row too.
insert into auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data, created_at, updated_at
) values (
  '00000000-0000-0000-0000-000000000000', '00000000-0000-0000-0000-0000000c0001',
  'authenticated', 'authenticated', 'cascade-check@example.test',
  extensions.crypt('Testpassw0rd!123', extensions.gen_salt('bf')),
  now(), '{"provider":"email","providers":["email"]}'::jsonb, '{}'::jsonb, now(), now()
);

insert into public.invites (id, org_id, email, role, token_hash, invited_by, user_id) values (
  '00000000-0000-0000-0000-0000000c5001', '00000000-0000-0000-0000-00000000000a',
  'cascade-check@example.test', 'physician', 'fixturehash-c', '00000000-0000-0000-0000-0000000a0001',
  '00000000-0000-0000-0000-0000000c0001'
);

select is(
  (select user_id from public.invites where id = '00000000-0000-0000-0000-0000000c5001'),
  '00000000-0000-0000-0000-0000000c0001'::uuid,
  'the invite row stores the linked user_id'
);

delete from auth.users where id = '00000000-0000-0000-0000-0000000c0001';

select is(
  (select count(*)::int from public.invites where id = '00000000-0000-0000-0000-0000000c5001'),
  0,
  'deleting the auth.users row cascades to delete its invites row'
);

select * from finish();
rollback;
