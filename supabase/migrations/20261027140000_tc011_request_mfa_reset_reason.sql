-- TC-011: Ava's request-2fa-reset dialog (07-users-roles) has an optional
-- "Reason" field so a Zyndio admin reviewing the request has context ("Zyndio
-- admins see this with your name and time"). Add it as an optional parameter
-- with a default, so the existing single-argument call keeps working - it's
-- carried only in the audit metadata and outbox payload, no new table.
--
-- Postgres identifies a function by name + argument *types*, not names or
-- defaults - `(uuid)` and `(uuid, text)` are different signatures, so a
-- plain `create or replace` here would leave the old 1-arg function behind
-- as a dangling overload instead of replacing it. Drop it explicitly first.
drop function if exists public.request_mfa_reset(uuid);

create or replace function public.request_mfa_reset(p_target_user_id uuid, p_reason text default null)
returns void
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
declare
  v_org_id uuid;
  v_target_org_id uuid;
  v_admin_id uuid;
begin
  if not public.is_org_admin() or not public.has_aal2() then
    raise exception 'not authorized' using errcode = '42501';
  end if;

  if p_target_user_id = auth.uid() then
    raise exception 'cannot request own mfa reset' using errcode = '42501';
  end if;

  v_org_id := public.current_org_id();

  select org_id into v_target_org_id
    from public.org_members
    where user_id = p_target_user_id and org_id = v_org_id;

  if v_target_org_id is null then
    raise exception 'member not found in your organization' using errcode = 'P0002';
  end if;

  perform public.write_audit_log(
    'mfa_reset_requested', auth.uid(), p_target_user_id, v_org_id,
    jsonb_build_object('reason', p_reason)
  );

  for v_admin_id in select user_id from public.platform_admins loop
    insert into public.notification_outbox (user_id, org_id, type, payload)
    values (
      v_admin_id, v_org_id, 'mfa_reset_requested',
      jsonb_build_object('target_user_id', p_target_user_id, 'requested_by', auth.uid(), 'reason', p_reason)
    );
  end loop;
end;
$$;

revoke all on function public.request_mfa_reset(uuid, text) from public;
grant execute on function public.request_mfa_reset(uuid, text) to authenticated;
