-- TC-018 item 6 (L8, corrected by Clara): nothing ever scrubs
-- notification_outbox rows, so a plaintext invite token stays there
-- indefinitely (process-outbox/sendNotificationStub redacts on send, but
-- nothing schedules it, and a row that never gets processed - status stays
-- 'pending' - has no age-based backstop at all). _scrub_stale_notification_
-- outbox() must null the token once the row is no longer pending, or by 15
-- minutes of age regardless, and the same function doubles as the one-time
-- backfill for rows that already exist. Fails now: the function and the
-- scrubbed_at column don't exist.
begin;
select no_plan();

-- Aged, still-pending row (simulates a pre-existing row the backfill must
-- catch, and the 15-minute age backstop for a row that never gets "sent").
insert into public.notification_outbox (id, user_id, org_id, type, status, payload, created_at)
values (
  '00000000-0000-0000-0000-0000000e1801',
  '00000000-0000-0000-0000-0000000a0002',
  '00000000-0000-0000-0000-00000000000a',
  'invite',
  'pending',
  jsonb_build_object('email', 'invitee-tc018@example.test', 'token', 'plaintext-token-aged'),
  now() - interval '20 minutes'
);

-- Fresh, still-pending row - must not be touched yet (well under 15 min and
-- still pending/unsent).
insert into public.notification_outbox (id, user_id, org_id, type, status, payload, created_at)
values (
  '00000000-0000-0000-0000-0000000e1802',
  '00000000-0000-0000-0000-0000000a0002',
  '00000000-0000-0000-0000-00000000000a',
  'invite',
  'pending',
  jsonb_build_object('email', 'invitee-tc018-fresh@example.test', 'token', 'plaintext-token-fresh'),
  now()
);

-- Already processed (sent_stub) but somehow not yet scrubbed - fresh by
-- age, but "sent" is enough on its own, independent of the 15-minute clock.
insert into public.notification_outbox (id, user_id, org_id, type, status, payload, created_at)
values (
  '00000000-0000-0000-0000-0000000e1803',
  '00000000-0000-0000-0000-0000000a0002',
  '00000000-0000-0000-0000-00000000000a',
  'invite',
  'sent_stub',
  jsonb_build_object('email', 'invitee-tc018-sent@example.test', 'token', 'plaintext-token-sent'),
  now()
);

reset role;
select set_config('request.jwt.claims', json_build_object('role', 'service_role')::text, true);
set local role service_role;

select lives_ok(
  $$select public._scrub_stale_notification_outbox()$$,
  'TC-018 item 6: _scrub_stale_notification_outbox() runs'
);

reset role;

select is(
  (select payload ->> 'token' from public.notification_outbox where id = '00000000-0000-0000-0000-0000000e1801'),
  null,
  'TC-018 item 6: an aged (>15m) pending row has its plaintext token removed - doubles as the backfill for pre-existing rows'
);
select ok(
  (select scrubbed_at is not null from public.notification_outbox where id = '00000000-0000-0000-0000-0000000e1801'),
  'TC-018 item 6: scrubbed_at is set on the aged row'
);

select is(
  (select payload ->> 'token' from public.notification_outbox where id = '00000000-0000-0000-0000-0000000e1802'),
  'plaintext-token-fresh',
  'TC-018 item 6: a fresh (<15m) still-pending row is left alone - not due yet'
);
select ok(
  (select scrubbed_at is null from public.notification_outbox where id = '00000000-0000-0000-0000-0000000e1802'),
  'TC-018 item 6: fresh pending row scrubbed_at stays null'
);

select is(
  (select payload ->> 'token' from public.notification_outbox where id = '00000000-0000-0000-0000-0000000e1803'),
  null,
  'TC-018 item 6: a sent (non-pending) row is scrubbed immediately, regardless of age'
);

select * from finish();
rollback;
