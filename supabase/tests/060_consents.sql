-- consents: patient self select/insert/update (grants/updates their own
-- consent); staff write for physician+care_coordinator; read_only select;
-- org_admin excluded.
begin;
select no_plan();

select tests.authenticate_as('00000000-0000-0000-0000-0000000a1001', 'aal2'); -- patient_a1
select is(
  (select array_agg(id) from public.consents),
  array['00000000-0000-0000-0000-0000000a4001']::uuid[],
  'patient_a1 sees only their own consent row'
);
update public.consents set granted = false where patient_id = '00000000-0000-0000-0000-0000000a1001';
select is(
  (select granted from public.consents where patient_id = '00000000-0000-0000-0000-0000000a1001'),
  false,
  'patient_a1 can revoke (update) their own consent'
);
insert into public.consents (id, org_id, patient_id, consent_type, granted)
  values ('00000000-0000-0000-0000-0000000a6006', '00000000-0000-0000-0000-00000000000a', '00000000-0000-0000-0000-0000000a1001', 'marketing', true);
select is(
  (select granted from public.consents where id = '00000000-0000-0000-0000-0000000a6006'),
  true,
  'patient_a1 can insert a new consent row for themselves'
);

select tests.authenticate_as('00000000-0000-0000-0000-0000000a0001', 'aal2'); -- org_admin_a
select is(
  (select count(*) from public.consents)::int,
  0,
  'org_admin_a cannot see any consents row'
);

select tests.authenticate_as('00000000-0000-0000-0000-0000000a0003', 'aal2'); -- care_coordinator_a
select is(
  (select count(*) from public.consents where org_id = '00000000-0000-0000-0000-00000000000a')::int,
  2,
  'care_coordinator_a can see org A consents'
);
update public.consents set granted = true where id = '00000000-0000-0000-0000-0000000a6006';
select is(
  (select granted from public.consents where id = '00000000-0000-0000-0000-0000000a6006'),
  true,
  'care_coordinator_a (staff) can update a consent in their own org'
);

select tests.authenticate_as('00000000-0000-0000-0000-0000000b0001', 'aal2'); -- physician_b, cross-org
select is(
  (select count(*) from public.consents where org_id = '00000000-0000-0000-0000-00000000000a')::int,
  0,
  'physician_b cannot see org A consents'
);

select * from finish();
rollback;
