-- Clara L28: the flag-column protect trigger only fired on UPDATE, so a
-- linked patient or in-clinic staff INSERT could plant needs_review = true
-- with arbitrary flagged_by / flagged_at and no audit row.
--
-- Extend the BEFORE trigger to INSERT as well. Non-RPC inserts force
-- needs_review = false and null flagged_by / flagged_at (silent strip —
-- not a 42501). The L25 RPC owner-role path is unchanged (flag RPC is
-- UPDATE-only today). UPDATE keep-or-raise behavior stays L27.
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

  -- Clara L28: INSERT never plants a forged flag outside the RPC path.
  if tg_op = 'INSERT' then
    new.needs_review := false;
    new.flagged_by := null;
    new.flagged_at := null;
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

drop trigger if exists lab_reports_protect_flag_columns on public.lab_reports;
create trigger lab_reports_protect_flag_columns
  before insert or update on public.lab_reports
  for each row
  execute function public._enforce_lab_reports_flag_columns();
