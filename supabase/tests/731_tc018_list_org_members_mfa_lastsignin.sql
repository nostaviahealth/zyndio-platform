-- TC-018 item 5 (L37): list_org_members() must return mfa_enrolled (a
-- boolean from verified auth.mfa_factors, never factor detail) and
-- last_sign_in_at (from auth.users), scoped to the caller's own org, to
-- roles allowed on the users screen (org_admin + aal2 only, same guard as
-- today). Fails now: the function has no such columns.
begin;
select no_plan();

-- physician_a ('...a0002') gets a verified TOTP factor.
insert into auth.mfa_factors (id, user_id, friendly_name, factor_type, status, created_at, updated_at)
values (
  '00000000-0000-0000-0000-0000000f1801', '00000000-0000-0000-0000-0000000a0002',
  'Authenticator', 'totp', 'verified', now(), now()
);

-- care_coordinator_a ('...a0003') has an unverified factor only - must not
-- count as enrolled.
insert into auth.mfa_factors (id, user_id, friendly_name, factor_type, status, created_at, updated_at)
values (
  '00000000-0000-0000-0000-0000000f1802', '00000000-0000-0000-0000-0000000a0003',
  'Authenticator', 'totp', 'unverified', now(), now()
);

-- org_admin_a ('...a0001') has signed in before; read_only_a ('...a0004')
-- never has.
update auth.users set last_sign_in_at = '2026-10-30T12:00:00Z'
  where id = '00000000-0000-0000-0000-0000000a0001';
update auth.users set last_sign_in_at = null
  where id = '00000000-0000-0000-0000-0000000a0004';

select tests.authenticate_as('00000000-0000-0000-0000-0000000a0001', 'aal2'); -- org_admin_a

select is(
  (select mfa_enrolled from public.list_org_members() where user_id = '00000000-0000-0000-0000-0000000a0002'),
  true,
  'list_org_members: a verified factor reports mfa_enrolled = true'
);
select is(
  (select mfa_enrolled from public.list_org_members() where user_id = '00000000-0000-0000-0000-0000000a0003'),
  false,
  'list_org_members: an unverified-only factor reports mfa_enrolled = false'
);
select is(
  (select mfa_enrolled from public.list_org_members() where user_id = '00000000-0000-0000-0000-0000000a0004'),
  false,
  'list_org_members: no factor at all reports mfa_enrolled = false'
);
select is(
  (select last_sign_in_at from public.list_org_members() where user_id = '00000000-0000-0000-0000-0000000a0001'),
  '2026-10-30T12:00:00Z'::timestamptz,
  'list_org_members: returns the member''s last_sign_in_at from auth.users'
);
select is(
  (select last_sign_in_at from public.list_org_members() where user_id = '00000000-0000-0000-0000-0000000a0004'),
  null,
  'list_org_members: a member who has never signed in reports null, not fabricated'
);

-- Own-org scope + role guard are unchanged: org B's member never appears,
-- and a non-admin / aal1 admin is still refused (regression guard for this
-- migration - full coverage already lives in 600_step8_users_roles.sql).
select is(
  (select count(*)::int from public.list_org_members() where user_id = '00000000-0000-0000-0000-0000000b0001'),
  0,
  'list_org_members: still scoped to the caller''s own org after adding the new columns'
);

select * from finish();
rollback;
