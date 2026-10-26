-- B5 / Henry ruling 3: notification_outbox needs a status for "the stub
-- sender handled this" that's distinct from 'sent' (a real provider having
-- actually delivered it, TC-006) and 'failed'.
alter table public.notification_outbox drop constraint notification_outbox_status_check;
alter table public.notification_outbox
  add constraint notification_outbox_status_check
  check (status in ('pending', 'sent_stub', 'sent', 'failed'));
