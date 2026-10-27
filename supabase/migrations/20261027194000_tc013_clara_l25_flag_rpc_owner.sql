-- Clara L25: L15's BEFORE UPDATE trigger trusts app.lab_report_flag_rpc, but
-- that custom GUC is settable by any role via set_config. A physician who
-- sets it to 'on' can then UPDATE flagged_by / flagged_at directly and forge
-- who raised a "Needs review" flag. Close the bypass by also requiring that
-- current_user equals the flag_lab_report_needs_review() owner role — which
-- is only true while that SECURITY DEFINER body is running the UPDATE
-- (Henry: check current_user against the flag function's owner role).
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

  new.flagged_by := old.flagged_by;
  new.flagged_at := old.flagged_at;
  return new;
end;
$$;
