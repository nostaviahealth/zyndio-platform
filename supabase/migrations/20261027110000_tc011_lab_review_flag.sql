-- TC-011 M2: a flag-only "Needs review" path for lab_reports, so a care
-- coordinator can raise a flag on a lab value but still cannot edit or
-- confirm the underlying data (physician-only UPDATE policy from
-- 20261026150000 stays as-is). Coordinator SELECT/INSERT are unchanged.

alter table public.lab_reports
  add column needs_review boolean not null default false,
  add column flagged_at timestamptz,
  add column flagged_by uuid references auth.users (id);

-- SECURITY DEFINER so a care_coordinator (who has no UPDATE grant on
-- lab_reports at all) can still flip this one flag, without being able to
-- touch `data` or any other column. A physician may also flag; both must be
-- aal2 and in the report's own org.
create function public.flag_lab_report_needs_review(p_lab_report_id uuid)
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

  update public.lab_reports
    set needs_review = true,
        flagged_at = now(),
        flagged_by = auth.uid()
    where id = p_lab_report_id;

  perform public._audit_log_insert(
    'lab_report_flagged_needs_review', auth.uid(), null, v_org_id,
    jsonb_build_object('lab_report_id', p_lab_report_id)
  );
end;
$$;

revoke all on function public.flag_lab_report_needs_review(uuid) from public;
grant execute on function public.flag_lab_report_needs_review(uuid) to authenticated;

-- Clearing the flag is left to the physician-only UPDATE policy on
-- lab_reports (already in place): a physician reviewing/confirming a value
-- can set needs_review = false in the same UPDATE as any data change,
-- rather than adding a second RPC for the mirror-image of a plain column
-- write that policy already permits.
