-- Clara M16: full_name on org_members is server-owned. list_org_members must
-- read it from there, not from auth.users.raw_user_meta_data (which the user
-- can edit themselves). A user who changes their own metadata name must not
-- change what the admin list shows.
begin;
select no_plan();

-- Physician a0002: plant a server-owned name, then forge user_metadata.
reset role;
select set_config('request.jwt.claims', '', true);

update public.org_members
  set full_name = 'Original Clinic Name'
  where user_id = '00000000-0000-0000-0000-0000000a0002';

update auth.users
  set raw_user_meta_data = jsonb_build_object('full_name', 'Hacked Self-Serve Name')
  where id = '00000000-0000-0000-0000-0000000a0002';

select tests.authenticate_as('00000000-0000-0000-0000-0000000a0001', 'aal2'); -- org_admin_a

select is(
  (select full_name from public.list_org_members()
    where user_id = '00000000-0000-0000-0000-0000000a0002'),
  'Original Clinic Name',
  'list_org_members keeps org_members.full_name after user_metadata is edited'
);

select isnt(
  (select full_name from public.list_org_members()
    where user_id = '00000000-0000-0000-0000-0000000a0002'),
  'Hacked Self-Serve Name',
  'list_org_members does not surface a self-edited user_metadata name'
);

select * from finish();
rollback;
