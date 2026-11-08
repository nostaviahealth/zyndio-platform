-- PR #40: deleting a clinician anonymizes the foreign key and leaves the
-- approved range and the billing period. Deleting the clinic removes both,
-- because that is what the foreign keys declare. Direct edits stay refused.
-- Synthetic rows only. The transaction rolls back.
begin;
select no_plan();

reset role;
select set_config('request.jwt.claims', '', true);

insert into auth.users (id, email, email_confirmed_at, aud, role) values
  ('00000000-0000-0000-0000-0000000e9401', 'synthetic-doctor@example.test', now(), 'authenticated', 'authenticated'),
  ('00000000-0000-0000-0000-0000000e9402', 'synthetic-admin@example.test', now(), 'authenticated', 'authenticated');

insert into public.organizations (id, name) values
  ('00000000-0000-0000-0000-0000000e9410', 'Synthetic Deletion Clinic');

insert into public.org_members (user_id, org_id, role, status) values
  ('00000000-0000-0000-0000-0000000e9402', '00000000-0000-0000-0000-0000000e9410', 'org_admin', 'active');

insert into public.lab_range_sets (id, org_id, version, status, created_by, approved_by, approved_at)
values ('00000000-0000-0000-0000-0000000e9420', '00000000-0000-0000-0000-0000000e9410', 1, 'approved',
        '00000000-0000-0000-0000-0000000e9401', '00000000-0000-0000-0000-0000000e9401', now());

select throws_ok($$
  update public.lab_range_sets set approved_by = null where id = '00000000-0000-0000-0000-0000000e9420'
$$, '42501', null, 'clearing approved_by while the doctor still exists is refused');
select throws_ok($$
  update public.lab_range_sets set created_by = null where id = '00000000-0000-0000-0000-0000000e9420'
$$, '42501', null, 'clearing created_by while the doctor still exists is refused');
select throws_ok($$
  update public.lab_range_sets set closed_at = now() where id = '00000000-0000-0000-0000-0000000e9420'
$$, '42501', null, 'closed_at on an approved set is frozen');
select throws_ok($$
  delete from public.lab_range_sets where id = '00000000-0000-0000-0000-0000000e9420'
$$, '42501', null, 'a range set is not deleted while its clinic exists');
select throws_ok($$
  delete from public.org_plan_history where org_id = '00000000-0000-0000-0000-0000000e9410'
$$, '42501', null, 'plan history is not deleted while its clinic exists');
select throws_ok($$
  insert into public.org_plan_history (org_id, tier, standard_modules, effective_from, effective_to)
  values ('00000000-0000-0000-0000-0000000e9410', 'core', '{}', now() - interval '1 hour', now() + interval '1 hour')
$$, '23514', null, 'an overlapping plan period is refused, including for the table owner');

select tests.authenticate_as('00000000-0000-0000-0000-0000000e9402', 'aal2');
select public.set_org_plan('core', array['wearables'], 'synthetic order');
delete from public.organizations where id = '00000000-0000-0000-0000-0000000e9410';
reset role;
select set_config('request.jwt.claims', '', true);
select is((select count(*)::int from public.organizations where id = '00000000-0000-0000-0000-0000000e9410'), 1,
  'the clinic admin cannot delete the organization directly');
select throws_ok($$
  update public.org_plan_history set changed_by = null
   where org_id = '00000000-0000-0000-0000-0000000e9410' and changed_by = '00000000-0000-0000-0000-0000000e9402'
$$, '42501', null, 'clearing changed_by while the admin still exists is refused');

delete from auth.users where id = '00000000-0000-0000-0000-0000000e9401';
select is((select approved_by is null and created_by is null and status = 'approved' and approved_at is not null
             from public.lab_range_sets where id = '00000000-0000-0000-0000-0000000e9420'), true,
  'deleting the approving doctor nulls only the user references');

delete from auth.users where id = '00000000-0000-0000-0000-0000000e9402';
select is((select changed_by is null and standard_modules = array['wearables']
             from public.org_plan_history
            where org_id = '00000000-0000-0000-0000-0000000e9410' and effective_to is null), true,
  'deleting the admin keeps the billing period and drops the personal reference');

delete from public.organizations where id = '00000000-0000-0000-0000-0000000e9410';
select is((select count(*)::int from public.lab_range_sets where id = '00000000-0000-0000-0000-0000000e9420'), 0,
  'deleting the clinic removes its range sets');
select is((select count(*)::int from public.org_plan_history where org_id = '00000000-0000-0000-0000-0000000e9410'), 0,
  'deleting the clinic removes its plan history');

select ok(position('identity_hold' in (
  select qual from pg_policies where schemaname = 'public' and policyname = 'lab_reports_self_select'
)) > 0, 'the held-report patient policy is still in place');

select * from finish();
rollback;
