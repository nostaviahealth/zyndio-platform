-- TC-018 item 4 (L36): changing the role of another clinic's member must
-- behave like the other cross-clinic actions (cancel-invite, deactivate,
-- reset-mfa all return 404 not_found) - never a 500. Today change_member_role
-- raises the cross-org "member not found" case with errcode P0002, which
-- PostgREST maps to HTTP 500 (confirmed in api-probe.txt: "B change A
-- physician role: 500 {code:P0002,...}"). PostgREST maps a 'PTxyz' sqlstate
-- straight to HTTP status xyz, so the fix recreates change_member_role
-- raising 'PT404' for that branch instead. This test pins the sqlstate the
-- RPC raises; it does not exercise PostgREST's HTTP mapping directly (no
-- live HTTP layer in pgTAP), but 'PT404' is the documented and
-- already-adjacent convention for "this RPC error must surface as 404".
begin;
select no_plan();

-- org_admin_a (org A) targets physician_b, who is in org B - cross-org.
select tests.authenticate_as('00000000-0000-0000-0000-0000000a0001', 'aal2');

select throws_ok(
  $$ select public.change_member_role('00000000-0000-0000-0000-0000000b0001', 'physician') $$,
  'PT404', null,
  'org_admin_a x change_member_role() x cross-org target: 404, not a 500 (P0002)'
);

-- Unchanged: physician_b's role in org B must still be untouched by the
-- rejected attempt. org_admin_a's own SELECT policies (org_members_self_select,
-- org_members_admin_select) only ever expose org A rows, so reading this as
-- org_admin_a would return zero rows (NULL) regardless of whether the update
-- had actually gone through - that would pass even a broken RPC that let the
-- cross-org write succeed. Reset to the pg_prove session role (postgres,
-- superuser - bypasses RLS) first, same convention 200_cross_org_matrix.sql
-- uses for its "unchanged after" checks, so this actually reads the
-- underlying row instead of a policy-filtered empty result.
reset role;
select is(
  (select role from public.org_members where user_id = '00000000-0000-0000-0000-0000000b0001')::text,
  'physician',
  'physician_b role unchanged after the rejected cross-org attempt'
);

select * from finish();
rollback;
