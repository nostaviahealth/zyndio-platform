-- TC-014: can_grant_role hierarchy + finalize_invite_cancel same-clinic /
-- invited-only. Edge Function coverage (missing name/role, accept role,
-- cancelled token, cross-clinic) lives in tests/integration.
begin;
select no_plan();

-- Grant hierarchy (immutable SQL; no auth needed)
select ok(
  public.can_grant_role('org_admin', 'org_admin'),
  'org_admin can grant org_admin'
);
select ok(
  public.can_grant_role('org_admin', 'read_only'),
  'org_admin can grant read_only'
);
select ok(
  not public.can_grant_role('physician', 'org_admin'),
  'physician cannot grant org_admin (above inviter)'
);
select ok(
  public.can_grant_role('physician', 'physician'),
  'physician can grant physician'
);
select ok(
  public.can_grant_role('physician', 'read_only'),
  'physician can grant read_only'
);
select ok(
  not public.can_grant_role('care_coordinator', 'physician'),
  'care_coordinator cannot grant physician'
);
select ok(
  not public.can_grant_role('read_only', 'care_coordinator'),
  'read_only cannot grant care_coordinator'
);

-- finalize_invite_cancel is service_role only
select tests.authenticate_as('00000000-0000-0000-0000-0000000a0001', 'aal2');
select throws_ok(
  $$ select public.finalize_invite_cancel(
       '00000000-0000-0000-0000-0000000a00f4'::uuid,
       '00000000-0000-0000-0000-0000000a0001'::uuid,
       '00000000-0000-0000-0000-00000000000a'::uuid
     ) $$,
  '42501', null,
  'an authenticated org_admin cannot execute finalize_invite_cancel directly'
);
reset role;

-- Seed an invited member + live invite in org A
insert into auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data, created_at, updated_at
) values (
  '00000000-0000-0000-0000-000000000000',
  '00000000-0000-0000-0000-0000000a00f4',
  'authenticated',
  'authenticated',
  'tc014-cancel@example.test',
  extensions.crypt('Placeholder1!', extensions.gen_salt('bf')),
  now(),
  '{"provider":"email","providers":["email"]}'::jsonb,
  '{"full_name":"Casey Cancel"}'::jsonb,
  now(),
  now()
);

insert into public.org_members (user_id, org_id, role, status)
values (
  '00000000-0000-0000-0000-0000000a00f4',
  '00000000-0000-0000-0000-00000000000a',
  'physician',
  'invited'
);

insert into public.invites (org_id, email, role, full_name, token_hash, invited_by, user_id)
values (
  '00000000-0000-0000-0000-00000000000a',
  'tc014-cancel@example.test',
  'physician',
  'Casey Cancel',
  'tc014-cancel-hash',
  '00000000-0000-0000-0000-0000000a0001',
  '00000000-0000-0000-0000-0000000a00f4'
);

select tests.authenticate_as_service_role();
select lives_ok(
  $$ select public.finalize_invite_cancel(
       '00000000-0000-0000-0000-0000000a00f4'::uuid,
       '00000000-0000-0000-0000-0000000a0001'::uuid,
       '00000000-0000-0000-0000-00000000000a'::uuid
     ) $$,
  'finalize_invite_cancel succeeds for an invited same-clinic member'
);
reset role;

select is(
  (select count(*) from public.org_members where user_id = '00000000-0000-0000-0000-0000000a00f4')::int,
  0,
  'finalize_invite_cancel removes the org_members row'
);

select is(
  (select count(*) from public.invites
     where user_id = '00000000-0000-0000-0000-0000000a00f4'
       and revoked_at is not null)::int,
  1,
  'finalize_invite_cancel sets revoked_at on the live invite'
);

select is(
  (select count(*) from public.audit_log
     where event_type = 'invite_cancelled'
       and target_user_id = '00000000-0000-0000-0000-0000000a00f4')::int,
  1,
  'finalize_invite_cancel writes invite_cancelled audit'
);

-- Cross-clinic: target in org A, claimed org B → member not found
select tests.authenticate_as_service_role();
select throws_ok(
  $$ select public.finalize_invite_cancel(
       '00000000-0000-0000-0000-0000000a0002'::uuid,
       '00000000-0000-0000-0000-0000000b0001'::uuid,
       '00000000-0000-0000-0000-00000000000b'::uuid
     ) $$,
  'P0002',
  'member not found in organization',
  'finalize_invite_cancel refuses a target not in the claimed org'
);

-- Active member cannot be cancelled via this RPC
select throws_ok(
  $$ select public.finalize_invite_cancel(
       '00000000-0000-0000-0000-0000000a0002'::uuid,
       '00000000-0000-0000-0000-0000000a0001'::uuid,
       '00000000-0000-0000-0000-00000000000a'::uuid
     ) $$,
  'P0001',
  'not an invited member',
  'finalize_invite_cancel refuses an active (non-invited) member'
);
reset role;

select * from finish();
rollback;
