-- Partner API follow-up (Clara, PR #38 review).
--
-- M3: partner_patient_summary returned lab values after data_sharing was
-- withdrawn. Health fields are empty unless the latest data_sharing row for
-- that patient and clinic is granted. The consent event itself stays a
-- consent event (no biomarker payload).
--
-- Low: idempotency replay stored the one-time webhook secret for 7 days.
-- Those keys are removed before the body is saved. The live HTTP response
-- is unchanged; a replay does not get the secret back.
--
-- Low: client secret hashes were compared with <> . _sha256_hex_equal walks
-- every byte. partner_issue_token uses it. A mismatch is still invalid_client.

create function public._sha256_hex_equal(a text, b text)
returns boolean
language plpgsql
immutable
set search_path = pg_catalog
as $$
declare
  xa bytea;
  yb bytea;
  i int;
  diff int := 0;
begin
  if a is null or b is null or char_length(a) <> 64 or char_length(b) <> 64
     or a !~ '^[0-9a-f]{64}$' or b !~ '^[0-9a-f]{64}$' then
    return false;
  end if;
  xa := decode(a, 'hex');
  yb := decode(b, 'hex');
  for i in 0 .. octet_length(xa) - 1 loop
    diff := diff | (get_byte(xa, i) # get_byte(yb, i));
  end loop;
  return diff = 0;
end;
$$;

revoke all on function public._sha256_hex_equal(text, text) from public, anon, authenticated;
grant execute on function public._sha256_hex_equal(text, text) to current_user;

create or replace function public.partner_idempotency_complete(
  p_api_client_id uuid,
  p_key text,
  p_response_status int,
  p_response_body jsonb
)
returns void
language sql
security definer
set search_path = pg_catalog, public
as $$
  update public.api_idempotency_keys
     set response_status = p_response_status,
         response_body = coalesce(p_response_body, '{}'::jsonb)
           - 'secret' - 'client_secret' - 'previous_secret' - 'invite_token' - 'token',
         completed_at = now()
   where api_client_id = p_api_client_id and idempotency_key = p_key and completed_at is null;
$$;

create or replace function public.partner_issue_token(
  p_client_id text,
  p_secret_hash text,
  p_requested_scopes text[],
  p_token_hash text
)
returns jsonb
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
declare
  v_client public.api_clients%rowtype;
  v_scopes text[];
begin
  select * into v_client from public.api_clients where client_id = p_client_id;
  if not found or v_client.revoked_at is not null
     or not public._sha256_hex_equal(v_client.secret_hash, p_secret_hash) then
    return jsonb_build_object('error', 'invalid_client');
  end if;

  if p_requested_scopes is null then
    v_scopes := v_client.scopes;
  elsif cardinality(p_requested_scopes) = 0 or not p_requested_scopes <@ v_client.scopes then
    return jsonb_build_object('error', 'invalid_scope');
  else
    v_scopes := p_requested_scopes;
  end if;
  select array_agg(distinct s order by s) into v_scopes from unnest(v_scopes) s;

  insert into public.api_access_tokens (api_client_id, token_hash, scopes, expires_at)
    values (v_client.id, p_token_hash, v_scopes, now() + interval '15 minutes');
  update public.api_clients set last_used_at = now() where id = v_client.id;

  return jsonb_build_object('scopes', to_jsonb(v_scopes), 'expires_in', 900, 'environment', v_client.environment);
end;
$$;

create or replace function public.partner_patient_summary(p_api_client_id uuid, p_zyndio_patient_id text)
returns jsonb
language plpgsql
stable
security definer
set search_path = pg_catalog, public
as $$
declare
  v_client record;
  v_link public.zyndio_patient_links%rowtype;
  v_latest jsonb;
  v_flags jsonb;
  v_sharing boolean;
begin
  select * into v_client from public._partner_client(p_api_client_id);
  select * into v_link from public.zyndio_patient_links
   where org_id = v_client.org_id and environment = v_client.environment
     and zyndio_patient_id = p_zyndio_patient_id;
  if not found then
    return jsonb_build_object('error', 'not_found');
  end if;

  select c.granted into v_sharing
    from public.consents c
   where c.patient_id = v_link.patient_id
     and c.org_id = v_link.org_id
     and c.consent_type = 'data_sharing'
   order by c.updated_at desc, c.created_at desc, c.granted desc
   limit 1;
  if coalesce(v_sharing, false) is not true then
    return jsonb_build_object(
      'object', 'patient_summary',
      'zyndio_patient_id', v_link.zyndio_patient_id,
      'generated_at', public._iso_utc(now()),
      'consent', 'not_granted',
      'biomarkers', '[]'::jsonb,
      'wearables', jsonb_build_object('sources', '[]'::jsonb, 'daily', '[]'::jsonb),
      'open_flags', '[]'::jsonb
    );
  end if;

  select coalesce(jsonb_agg(jsonb_build_object(
           'analyte_key', x.analyte_key,
           'label', x.analyte_label,
           'value', x.value,
           'unit', x.unit,
           'status', x.status,
           'range_low', x.range_low,
           'range_high', x.range_high,
           'range_mapped', not x.is_unmapped,
           'taken_at', public._iso_utc(x.taken_at)
         ) order by x.analyte_key), '[]'::jsonb)
    into v_latest
    from (
      select distinct on (lr.analyte_key) lr.*
        from public.lab_results lr
       where lr.patient_id = v_link.patient_id
         and not public.lab_report_held_unscoped(lr.lab_report_id)
         and lr.original_value is null
       order by lr.analyte_key, lr.taken_at desc, lr.id desc
    ) x;

  select coalesce(jsonb_agg(f order by f ->> 'raised_at' desc nulls last, f ->> 'type'), '[]'::jsonb)
    into v_flags
    from (
      select jsonb_build_object('type', 'lab_report_needs_review', 'report_type', r.report_type,
                                'raised_at', public._iso_utc(coalesce(r.flagged_at, r.created_at))) as f
        from public.lab_reports r
       where r.patient_id = v_link.patient_id and r.needs_review
      union all
      select jsonb_build_object('type', 'lab_report_identity_hold', 'report_type', r.report_type,
                                'raised_at', public._iso_utc(r.created_at))
        from public.lab_reports r
       where r.patient_id = v_link.patient_id and r.identity_hold
      union all
      select jsonb_build_object('type', 'biomarker_' || (b ->> 'status'), 'analyte_key', b ->> 'analyte_key',
                                'raised_at', b ->> 'taken_at')
        from jsonb_array_elements(v_latest) b
       where b ->> 'status' in ('outside_range', 'needs_review')
    ) flags;

  return jsonb_build_object(
    'object', 'patient_summary',
    'zyndio_patient_id', v_link.zyndio_patient_id,
    'generated_at', public._iso_utc(now()),
    'biomarkers', v_latest,
    'wearables', public.integration_wearable_summary(v_link.patient_id),
    'open_flags', v_flags
  );
end;
$$;
