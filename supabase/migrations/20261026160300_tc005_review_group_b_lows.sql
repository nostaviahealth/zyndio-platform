-- TC-005 PR #4 review, group B - cheap Lows.
--
-- L3: consume_recovery_code() didn't apply the same 10-minute
-- password_verified_at window that auth_hooks.mfa_verification_attempt()
-- applies to a TOTP code, so an old aal1 session (password verified long
-- ago, then abandoned) could still use a recovery code. Same check, same
-- 'challenge_expired' status shape as the MFA hook.
--
-- L4: the old code was select-then-update (select the matching row, then
-- update it by id as a separate statement) - two concurrent calls with the
-- same code could both pass the select before either's update lands, so
-- both would succeed. Fold the match and the claim into one UPDATE ...
-- WHERE used_at is null ... RETURNING, so the row lock and the one-time-use
-- check happen atomically; a second concurrent caller's UPDATE then matches
-- zero rows.
create or replace function public.consume_recovery_code(p_code text)
returns jsonb
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
declare
  v_user_id uuid := auth.uid();
  v_state public.auth_attempt_state;
  v_bump record;
  v_org_id uuid;
  v_claimed_id uuid;
begin
  if v_user_id is null then
    raise exception 'not authorized' using errcode = '42501';
  end if;

  select * into v_state from public.auth_attempt_state where user_id = v_user_id for update;

  if v_state.locked_until is not null and v_state.locked_until > now() then
    return jsonb_build_object('status', 'locked');
  end if;

  -- L3: same recency window as the TOTP step (auth_hooks.mfa_verification_attempt).
  if v_state.password_verified_at is null or v_state.password_verified_at < now() - interval '10 minutes' then
    return jsonb_build_object('status', 'challenge_expired');
  end if;

  select org_id into v_org_id from public.org_members where user_id = v_user_id;

  -- L4: atomic claim - match and consume in one statement.
  update public.mfa_recovery_codes
    set used_at = now()
    where user_id = v_user_id
      and used_at is null
      and code_hash = extensions.crypt(p_code, code_hash)
    returning id into v_claimed_id;

  if v_claimed_id is null then
    select * into v_bump from public.bump_wrong_attempt(v_user_id);
    if v_bump.just_locked then
      perform public._audit_log_insert(
        'mfa_lockout', v_user_id, v_user_id, v_org_id,
        jsonb_build_object('wrong_count', v_bump.wrong_count, 'locked_until', v_bump.locked_until, 'source', 'recovery_code')
      );
    end if;
    return jsonb_build_object('status', 'invalid');
  end if;

  update public.auth_attempt_state
    set wrong_count = 0, locked_until = null, updated_at = now()
    where user_id = v_user_id;

  insert into public.mfa_reenrollment_required (user_id) values (v_user_id)
    on conflict (user_id) do nothing;

  perform public._audit_log_insert('recovery_code_used', v_user_id, v_user_id, v_org_id, '{}'::jsonb);

  return jsonb_build_object('status', 'ok', 'must_reenrol', true);
end;
$$;
