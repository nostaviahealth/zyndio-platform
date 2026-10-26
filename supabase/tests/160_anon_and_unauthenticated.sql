-- Cross-cutting anon/unauthenticated sweep. Every policy in the per-table
-- files above is scoped `to authenticated`, so an anon-role request (a
-- valid Supabase anon key, no signed-in user) or a request with no JWT
-- claims at all should see nothing anywhere, even on rows that would
-- otherwise be visible to a signed-in patient or staff member. Checked once
-- here across a representative sample rather than duplicated per table.
begin;
select no_plan();

select tests.authenticate_as_anon();
select is((select count(*) from public.organizations)::int, 0, 'anon sees no organizations');
select is((select count(*) from public.org_members)::int, 0, 'anon sees no org_members');
select is((select count(*) from public.patients)::int, 0, 'anon sees no patients');
select is((select count(*) from public.patient_profiles)::int, 0, 'anon sees no patient_profiles');
select is((select count(*) from public.lab_reports)::int, 0, 'anon sees no lab_reports');
select is((select count(*) from public.consents)::int, 0, 'anon sees no consents');
select is((select count(*) from public.invites)::int, 0, 'anon sees no invites');
select throws_ok(
  $$ insert into public.patients (id, org_id, display_name, mrn)
     values ('00000000-0000-0000-0000-0000000a1001', '00000000-0000-0000-0000-00000000000a', 'x', 'x') $$,
  '42501', null,
  'anon cannot insert into patients'
);

select tests.clear_authentication();
select is((select count(*) from public.organizations)::int, 0, 'unauthenticated (no claims) sees no organizations');
select is((select count(*) from public.org_members)::int, 0, 'unauthenticated sees no org_members');
select is((select count(*) from public.patients)::int, 0, 'unauthenticated sees no patients');
select is((select count(*) from public.invites)::int, 0, 'unauthenticated sees no invites');

select * from finish();
rollback;
