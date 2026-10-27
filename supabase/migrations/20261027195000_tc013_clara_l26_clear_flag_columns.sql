-- Clara L26: clearing needs_review must also null flagged_by / flagged_at.
-- The audit_log row from flag_lab_report_needs_review already records who
-- raised the flag, so keeping provenance on the row after the flag is gone
-- is redundant (Henry: clear both columns along with the flag).
-- Builds on L25's owner-role check for the RPC write path.
create or replace function public._enforce_lab_reports_flag_columns()
returns trigger
language plpgsql
as $$
declare
  v_owner name;
begin
  select r.rolname into v_owner
    from pg_catalog.pg_proc p
    join pg_catalog.pg_namespace n on n.oid = p.pronamespace
    join pg_catalog.pg_roles r on r.oid = p.proowner
   where n.nspname = 'public'
     and p.proname = 'flag_lab_report_needs_review'
   order by p.oid
   limit 1;

  if coalesce(current_setting('app.lab_report_flag_rpc', true), 'off') = 'on'
     and current_user = v_owner then
    return new;
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
