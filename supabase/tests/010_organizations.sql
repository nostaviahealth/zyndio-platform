-- organizations: one policy, self-row select only (current_org_id() derived
-- from org_members). No aal2 requirement on this table - see 150 for the
-- aal1/aal2 sweep and 160 for anon/unauthenticated.
begin;
select no_plan();

select tests.authenticate_as('00000000-0000-0000-0000-0000000a0001'); -- org_admin_a
select is(
  (select array_agg(id order by id) from public.organizations),
  array['00000000-0000-0000-0000-00000000000a']::uuid[],
  'org_admin_a sees only org A, not org B'
);

select tests.authenticate_as('00000000-0000-0000-0000-0000000a0002'); -- physician_a
select is(
  (select array_agg(id order by id) from public.organizations),
  array['00000000-0000-0000-0000-00000000000a']::uuid[],
  'physician_a (any staff role) sees only their own org'
);

select tests.authenticate_as('00000000-0000-0000-0000-0000000b0001'); -- physician_b
select is(
  (select array_agg(id order by id) from public.organizations),
  array['00000000-0000-0000-0000-00000000000b']::uuid[],
  'physician_b sees only org B, cross-org denied'
);

select tests.authenticate_as('00000000-0000-0000-0000-0000000a1001'); -- patient_a1, no org_members row
select is(
  (select count(*) from public.organizations)::int,
  0,
  'a patient (no org_members row) sees no organizations'
);

select tests.authenticate_as('00000000-0000-0000-0000-0000000a0001');
select throws_ok(
  $$ insert into public.organizations (id, name) values ('00000000-0000-0000-0000-0000000a9999', 'Rogue Org') $$,
  null,
  null,
  'no INSERT policy exists on organizations, even for an org_admin'
);

select * from finish();
rollback;
