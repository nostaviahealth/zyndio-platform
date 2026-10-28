-- Clara L27: a direct UPDATE can still flip needs_review true/false without
-- going through flag_lab_report_needs_review(), raising a flag with no
-- flagged_by and no audit row, and clearing with no audit at all.
--
-- 1. Raising (needs_review false → true) is only allowed on the flag RPC
--    path (same app.lab_report_flag_rpc + current_user = function-owner
--    gate as L25). A direct raise raises 42501.
-- 2. Every clear (true → false) writes lab_report_needs_review_cleared via
--    _audit_log_insert with actor auth.uid(), lab_report_id, and the
--    previous flagged_by / flagged_at (no patient data), then nulls the
--    columns as L26. Physician clear stays a direct UPDATE (no app clear
--    RPC today); audit runs from a SECURITY DEFINER AFTER trigger so the
--    INVOKER column-guard trigger can keep using current_user for L25.
create or replace function public._enforce_lab_reports_flag_columns()
returns trigger
language plpgsql
as $$
declare
  v_owner name;
  v_rpc boolean;
begin
  select r.rolname into v_owner
    from pg_catalog.pg_proc p
    join pg_catalog.pg_namespace n on n.oid = p.pronamespace
    join pg_catalog.pg_roles r on r.oid = p.proowner
   where n.nspname = 'public'
     and p.proname = 'flag_lab_report_needs_review'
   order by p.oid
   limit 1;

  v_rpc := coalesce(current_setting('app.lab_report_flag_rpc', true), 'off') = 'on'
           and current_user = v_owner;

  if v_rpc then
    return new;
  end if;

  -- Clara L27: reject a direct raise (false → true).
  if new.needs_review is true and old.needs_review is distinct from true then
    raise exception 'not authorized' using errcode = '42501';
  end if;

  if new.needs_review is false then
    new.flagged_by := null;
    new.flagged_at := null;
  else
    new.flagged_by := old.flagged_by;
    new.flagged_at := old.flagged_at;
  end if;
  return new;
end;
$$;

-- AFTER UPDATE: audit clears. SECURITY DEFINER so we can call
-- _audit_log_insert (EXECUTE revoked from authenticated). OLD still holds
-- the pre-clear flagged_by / flagged_at after the BEFORE trigger nulls NEW.
create function public._audit_lab_report_flag_cleared()
returns trigger
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
begin
  if old.needs_review is true and new.needs_review is false then
    perform public._audit_log_insert(
      'lab_report_needs_review_cleared',
      auth.uid(),
      null,
      old.org_id,
      jsonb_build_object(
        'lab_report_id', old.id,
        'previous_flagged_by', old.flagged_by,
        'previous_flagged_at', old.flagged_at
      )
    );
  end if;
  return null;
end;
$$;

revoke all on function public._audit_lab_report_flag_cleared() from public, anon, authenticated;

create trigger lab_reports_audit_flag_cleared
  after update on public.lab_reports
  for each row
  execute function public._audit_lab_report_flag_cleared();
