-- TC-011 L5: recovery codes carried only ~40 bits of entropy (10 hex
-- characters sliced from a uuid). Raise this to 16 base32 characters (RFC
-- 4648 alphabet, A-Z2-7) drawn from pgcrypto's CSPRNG - 16 bytes of
-- gen_random_bytes(), one byte per character. 256 is an exact multiple of
-- 32, so `byte % 32` is a uniform, bias-free index into the 32-symbol
-- alphabet: ~80 bits of entropy per code, well above what the existing 5
-- attempts / 15-minute lockout budget (auth_hooks.sql) needs to stay safe.
-- bcrypt hash storage, one-time use and regeneration-deletes-old-codes are
-- unchanged.
create or replace function public._generate_base32_code(p_length int)
returns text
language plpgsql
set search_path = pg_catalog, public, extensions
as $$
declare
  v_alphabet text := 'ABCDEFGHIJKLMNOPQRSTUVWXYZ234567';
  v_bytes bytea := extensions.gen_random_bytes(p_length);
  v_result text := '';
  i int;
begin
  for i in 0..p_length - 1 loop
    v_result := v_result || substr(v_alphabet, (get_byte(v_bytes, i) % 32) + 1, 1);
  end loop;
  return v_result;
end;
$$;

revoke all on function public._generate_base32_code(int) from public, anon, authenticated;

create or replace function public.generate_recovery_codes()
returns text[]
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
declare
  v_user_id uuid := auth.uid();
  v_factor_id uuid;
  v_codes text[] := '{}';
  v_code text;
  i int;
begin
  if v_user_id is null or not public.has_aal2() then
    raise exception 'not authorized' using errcode = '42501';
  end if;

  select id into v_factor_id
    from auth.mfa_factors
    where user_id = v_user_id and factor_type = 'totp' and status = 'verified'
    order by created_at desc
    limit 1;

  if v_factor_id is null then
    raise exception 'no verified authenticator enrolled' using errcode = 'P0003';
  end if;

  delete from public.mfa_recovery_codes where user_id = v_user_id;

  for i in 1..10 loop
    v_code := public._generate_base32_code(16);
    v_codes := array_append(v_codes, v_code);
    insert into public.mfa_recovery_codes (user_id, factor_id, code_hash)
      values (v_user_id, v_factor_id, extensions.crypt(v_code, extensions.gen_salt('bf')));
  end loop;

  delete from public.mfa_reenrollment_required where user_id = v_user_id;

  perform public._audit_log_insert(
    'recovery_codes_regenerated', v_user_id, v_user_id,
    (select org_id from public.org_members where user_id = v_user_id),
    '{}'::jsonb
  );

  return v_codes;
end;
$$;

revoke all on function public.generate_recovery_codes() from public, anon, authenticated;
grant execute on function public.generate_recovery_codes() to authenticated;
