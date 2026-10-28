-- TC-005 PR #4 review, group B.
--
-- B3 (M4): reset-mfa and deactivate-user each did flag/status + force
-- sign-out + audit + outbox as separate round trips from the Edge Function,
-- with at least one failure silently swallowed (a logged console.error, 200
-- returned anyway). Move the DB side of each into one SECURITY DEFINER RPC,
-- service_role only, so it is one transaction: any failure rolls back the
-- whole thing and the Edge Function gets a real error instead of a half
-- applied state. Both are called after the (necessarily separate, GoTrue
-- admin API) factor deletion in reset-mfa.

-- Returns the new notification_outbox row's id (not void) so the caller can
-- hand it straight to the B5 email stub sender without a second round trip
-- to guess which row it just created.
create function public.finalize_mfa_reset(
  p_target_user_id uuid,
  p_actor_user_id uuid,
  p_org_id uuid
)
returns uuid
language plpgsql
security definer
set search_path = pg_catalog, public, auth
as $$
declare
  v_notification_id uuid;
begin
  insert into public.mfa_reenrollment_required (user_id)
    values (p_target_user_id)
    on conflict (user_id) do update set created_at = now();

  perform public.force_sign_out(p_target_user_id);

  perform public.write_audit_log('mfa_reset', p_actor_user_id, p_target_user_id, p_org_id, '{}'::jsonb);

  insert into public.notification_outbox (user_id, org_id, type, payload)
    values (p_target_user_id, p_org_id, 'mfa_reset', '{}'::jsonb)
    returning id into v_notification_id;

  return v_notification_id;
end;
$$;

revoke all on function public.finalize_mfa_reset(uuid, uuid, uuid) from public, anon, authenticated;
grant execute on function public.finalize_mfa_reset(uuid, uuid, uuid) to service_role;

create function public.finalize_deactivation(
  p_target_user_id uuid,
  p_actor_user_id uuid,
  p_org_id uuid
)
returns uuid
language plpgsql
security definer
set search_path = pg_catalog, public, auth
as $$
declare
  v_notification_id uuid;
begin
  update public.org_members
    set status = 'deactivated'
    where user_id = p_target_user_id and org_id = p_org_id;

  if not found then
    raise exception 'member not found in organization' using errcode = 'P0002';
  end if;

  -- H3 / A3: a deactivated member must not reactivate themselves via a
  -- still-live invite link - stays inside the same transaction as the
  -- status flip, not a separate best-effort call.
  update public.invites
    set revoked_at = now()
    where org_id = p_org_id
      and user_id = p_target_user_id
      and accepted_at is null
      and revoked_at is null;

  perform public.force_sign_out(p_target_user_id);

  perform public.write_audit_log('user_deactivated', p_actor_user_id, p_target_user_id, p_org_id, '{}'::jsonb);

  insert into public.notification_outbox (user_id, org_id, type, payload)
    values (p_target_user_id, p_org_id, 'user_deactivated', '{}'::jsonb)
    returning id into v_notification_id;

  return v_notification_id;
end;
$$;

revoke all on function public.finalize_deactivation(uuid, uuid, uuid) from public, anon, authenticated;
grant execute on function public.finalize_deactivation(uuid, uuid, uuid) to service_role;
