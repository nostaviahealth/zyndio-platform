-- TC-012 PSU-EV-05: change-email re-verify. Old email stays authoritative for
-- auth until the new address confirms. No clinical / link side effects here
-- (matching still blocked pending Clara Approve of RECORD_MATCHING).

create table public.patient_email_change_requests (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  new_email text not null,
  token_hash text not null,
  expires_at timestamptz not null,
  used_at timestamptz,
  created_at timestamptz not null default now()
);

create index patient_email_change_requests_user_idx
  on public.patient_email_change_requests (user_id)
  where used_at is null;

alter table public.patient_email_change_requests enable row level security;
alter table public.patient_email_change_requests force row level security;
revoke all on public.patient_email_change_requests from anon, authenticated;

-- Redeem: mark token used, set auth.users.email + email_confirmed_at for new
-- address. Service role only. Old sessions: caller should force_sign_out.
create or replace function public.redeem_patient_email_change(p_token_hash text)
returns jsonb
language plpgsql
security definer
set search_path = pg_catalog, public, auth
as $$
declare
  v_row public.patient_email_change_requests;
begin
  select * into v_row
  from public.patient_email_change_requests
  where token_hash = p_token_hash
    and used_at is null
    and expires_at > now()
  for update;

  if not found then
    return jsonb_build_object('ok', false, 'error', 'invalid_or_expired_link');
  end if;

  -- Refuse if another auth.users row already owns the new email.
  if exists (
    select 1 from auth.users u
    where lower(u.email) = lower(v_row.new_email)
      and u.id <> v_row.user_id
  ) then
    return jsonb_build_object('ok', false, 'error', 'email_unavailable');
  end if;

  update auth.users
  set email = v_row.new_email,
      email_confirmed_at = now(),
      updated_at = now()
  where id = v_row.user_id;

  update public.patient_email_change_requests
  set used_at = now()
  where id = v_row.id;

  -- Void any other outstanding change requests for this user.
  update public.patient_email_change_requests
  set used_at = coalesce(used_at, now())
  where user_id = v_row.user_id
    and id <> v_row.id
    and used_at is null;

  return jsonb_build_object('ok', true, 'user_id', v_row.user_id);
end;
$$;

revoke all on function public.redeem_patient_email_change(text) from public, anon, authenticated;
grant execute on function public.redeem_patient_email_change(text) to service_role;
