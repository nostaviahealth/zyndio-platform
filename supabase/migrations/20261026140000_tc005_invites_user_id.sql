-- TC-005 step 3: invite-user creates the auth.users row and the org_members
-- row (status='invited') up front, so accept-invite only needs to set a
-- password and flip status to 'active' - it never has to resolve an email
-- back to a user id through the admin API. Add the missing link column (the
-- invites table has no rows yet in any environment that ran step 1/2, so no
-- backfill is needed).

alter table public.invites add column user_id uuid references auth.users (id) on delete cascade;

create index invites_user_id_idx on public.invites (user_id);
