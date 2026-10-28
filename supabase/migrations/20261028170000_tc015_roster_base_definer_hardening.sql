-- TC-015 fix round (28 Oct): Henry's conditions for the named SECURITY DEFINER
-- exception on public.physician_roster_base() (taken in 34fdd87 for the
-- 5,000-patient budget; see docs/architecture/ADR-0001-roster-base-security-definer.md).
--   1. search_path pinned to '' - the body already schema-qualifies every
--      relation and helper (public.*); built-ins resolve from pg_catalog, which
--      is always searched implicitly. No object a caller can create can shadow
--      a name the definer body uses.
--   2. EXECUTE explicitly revoked from PUBLIC and anon; only authenticated
--      (the invoker roster RPCs call it as the signed-in caller) and
--      service_role keep it.
--   3. No parameters: the clinic comes only from public.current_org_id(),
--      i.e. the caller's own active org_members row looked up by auth.uid()
--      from the verified JWT - never from an argument or a JWT org claim.
-- Body and gate are otherwise byte-identical to 20261028160000.
-- Tests: supabase/tests/722_tc015_roster_base_definer_gate.sql.

create or replace function public.physician_roster_base()
returns table (
  patient_id uuid,
  display_name text,
  mrn text,
  sex text,
  birth_date date,
  program_started_on date,
  latest_lab_at timestamptz,
  last_activity_at timestamptz,
  open_questions int,
  flags text[]
)
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_org uuid;
begin
  -- One-time staff gate, identical semantics to the staff-select RLS.
  if not coalesce(
       public.has_aal2()
       and public.current_role() in ('physician', 'care_coordinator', 'read_only'),
       false) then
    return;
  end if;
  v_org := public.current_org_id();
  if v_org is null then
    return;
  end if;

  return query
  select
    p.id,
    p.display_name,
    p.mrn,
    m.sex,
    m.birth_date,
    m.program_started_on,
    s.latest_lab_at,
    m.last_activity_at,
    coalesce(m.open_questions, 0),
    array_remove(array[
      case when coalesce(s.has_treatment, false) then 'clinical_context' end,
      case when coalesce(s.has_outside_range, false) then 'outside_range' end,
      case when coalesce(s.has_needs_review, false) then 'needs_review' end,
      case when coalesce(s.has_identity_hold, false) then 'identity_hold' end,
      case when not coalesce(s.has_any_labs, false) then 'missing_labs' end,
      case when coalesce(m.open_questions, 0) > 0 then 'question_waiting' end
    ], null)
  from public.patients p
  left join public.patient_roster_meta m on m.patient_id = p.id
  left join public.patient_roster_summary s on s.patient_id = p.id
  where p.org_id = v_org;
end;
$$;

revoke all on function public.physician_roster_base() from public, anon;
grant execute on function public.physician_roster_base() to authenticated, service_role;
