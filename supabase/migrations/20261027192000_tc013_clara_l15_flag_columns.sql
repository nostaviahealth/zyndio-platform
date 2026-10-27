-- Clara L15: lab_reports_physician_update (20261026150000) lets a
-- physician UPDATE any column on an in-org row, including flagged_by /
-- flagged_at - so a physician could set flagged_by to any user_id, forging
-- who raised a "Needs review" flag. Those two columns must only ever be
-- written by flag_lab_report_needs_review() (which sets them from
-- auth.uid() / now()), never by a direct client UPDATE.
--
-- RLS policies don't do column-level grants, so this uses a BEFORE UPDATE
-- trigger: unless the write comes from inside the flag RPC (marked via a
-- transaction-local setting), flagged_by/flagged_at are pinned back to
-- their OLD values rather than whatever the client's UPDATE tried to set -
-- silently ignored, same as every other write the care_coordinator role has
-- no privilege for at all (620_lab_review_flag.sql's existing pattern).
create function public._enforce_lab_reports_flag_columns()
returns trigger
language plpgsql
as $$
begin
  if coalesce(current_setting('app.lab_report_flag_rpc', true), 'off') <> 'on' then
    new.flagged_by := old.flagged_by;
    new.flagged_at := old.flagged_at;
  end if;
  return new;
end;
$$;

create trigger lab_reports_protect_flag_columns
  before update on public.lab_reports
  for each row
  execute function public._enforce_lab_reports_flag_columns();

-- Mark the one sanctioned path. set_config's third argument (is_local =
-- true) scopes the setting to the current transaction, but a single client
-- call can still share a transaction with other statements (e.g. the pgTAP
-- suite wraps a whole file in one begin/rollback) - so this turns the flag
-- back off immediately after its own UPDATE rather than relying on the
-- transaction boundary to clear it.
create or replace function public.flag_lab_report_needs_review(p_lab_report_id uuid)
returns void
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
declare
  v_org_id uuid;
  v_report_org_id uuid;
begin
  if not public.has_aal2() or public.current_role() not in ('physician', 'care_coordinator') then
    raise exception 'not authorized' using errcode = '42501';
  end if;

  v_org_id := public.current_org_id();

  select org_id into v_report_org_id
    from public.lab_reports
    where id = p_lab_report_id;

  if v_report_org_id is null or v_report_org_id <> v_org_id then
    raise exception 'lab report not found' using errcode = 'P0002';
  end if;

  perform set_config('app.lab_report_flag_rpc', 'on', true);

  update public.lab_reports
    set needs_review = true,
        flagged_at = now(),
        flagged_by = auth.uid()
    where id = p_lab_report_id;

  perform set_config('app.lab_report_flag_rpc', 'off', true);

  perform public._audit_log_insert(
    'lab_report_flagged_needs_review', auth.uid(), null, v_org_id,
    jsonb_build_object('lab_report_id', p_lab_report_id)
  );
end;
$$;

revoke all on function public.flag_lab_report_needs_review(uuid) from public;
grant execute on function public.flag_lab_report_needs_review(uuid) to authenticated;
