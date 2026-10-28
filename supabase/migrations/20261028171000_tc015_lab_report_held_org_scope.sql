-- TC-015 fix round (28 Oct, Clara Low): scope public.lab_report_held() to the
-- caller's clinic. It is SECURITY DEFINER (reads lab_reports past RLS), and
-- before this it answered for any report uuid in any clinic - false for
-- another clinic's non-held report - which made it a cross-clinic oracle on
-- report existence and hold state. Now another clinic's report gives exactly
-- the same answer as a report that does not exist: true (held / hidden), i.e.
-- it still fails CLOSED.
--
-- Its client callers (patient_trend, patient_latest_results, all SECURITY
-- INVOKER and already org-scoped by RLS) are unaffected for own-clinic data.
-- The roster-summary maintenance path is different: triggers and the
-- refresh_* functions run with whatever session did the clinical write
-- (often service_role, with no clinic), so they must see the real hold state
-- of every report. They now call public.lab_report_held_unscoped(), which is
-- NOT client-callable (EXECUTE revoked from PUBLIC, anon and authenticated;
-- only the definer-owned refresh functions use it). The refresh bodies are
-- otherwise byte-identical to 20261028160000; grants on them are preserved by
-- create or replace.
-- Tests: supabase/tests/723_tc015_lab_report_held_org_scope.sql (+ 720 parity).

create or replace function public.lab_report_held(p_lab_report_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce(
    (select r.identity_hold
       from public.lab_reports r
      where r.id = p_lab_report_id
        and r.org_id = public.current_org_id()),
    true
  );
$$;

revoke all on function public.lab_report_held(uuid) from public, anon;
grant execute on function public.lab_report_held(uuid) to authenticated, service_role;

create function public.lab_report_held_unscoped(p_lab_report_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce(
    (select r.identity_hold from public.lab_reports r where r.id = p_lab_report_id),
    true
  );
$$;

revoke all on function public.lab_report_held_unscoped(uuid) from public, anon, authenticated, service_role;

create or replace function public.refresh_roster_summary(p_patient_id uuid)
returns void
language sql
security definer
set search_path = pg_catalog, public
as $$
  insert into public.patient_roster_summary as s (
    patient_id, org_id, latest_lab_at,
    has_outside_range, has_needs_review, has_identity_hold, has_any_labs, has_treatment
  )
  select
    p.id, p.org_id,
    la.latest_lab_at,
    coalesce(la.has_outside_range, false),
    coalesce(la.has_needs_review, false),
    coalesce(la.has_identity_hold, false),
    coalesce(la.has_any_labs, false),
    coalesce(tr.has_treatment, false)
  from public.patients p
  left join lateral (
    select
      max(lr.taken_at) filter (where not public.lab_report_held_unscoped(lr.lab_report_id)) as latest_lab_at,
      bool_or(lr.status = 'outside_range' and not public.lab_report_held_unscoped(lr.lab_report_id)) as has_outside_range,
      bool_or(lr.status = 'needs_review' and not public.lab_report_held_unscoped(lr.lab_report_id)) as has_needs_review,
      bool_or(public.lab_report_held_unscoped(lr.lab_report_id)) as has_identity_hold,
      count(lr.id) filter (where not public.lab_report_held_unscoped(lr.lab_report_id)) > 0 as has_any_labs
    from public.lab_results lr
    where lr.patient_id = p.id
  ) la on true
  left join lateral (
    select true as has_treatment
    from public.patient_treatments t
    where t.patient_id = p.id
    limit 1
  ) tr on true
  where p.id = p_patient_id
  on conflict (patient_id) do update set
    org_id            = excluded.org_id,
    latest_lab_at     = excluded.latest_lab_at,
    has_outside_range = excluded.has_outside_range,
    has_needs_review  = excluded.has_needs_review,
    has_identity_hold = excluded.has_identity_hold,
    has_any_labs      = excluded.has_any_labs,
    has_treatment     = excluded.has_treatment;
$$;

create or replace function public.refresh_roster_summary_all()
returns void
language sql
security definer
set search_path = pg_catalog, public
as $$
  insert into public.patient_roster_summary as s (
    patient_id, org_id, latest_lab_at,
    has_outside_range, has_needs_review, has_identity_hold, has_any_labs, has_treatment
  )
  select
    p.id, p.org_id,
    la.latest_lab_at,
    coalesce(la.has_outside_range, false),
    coalesce(la.has_needs_review, false),
    coalesce(la.has_identity_hold, false),
    coalesce(la.has_any_labs, false),
    coalesce(tr.has_treatment, false)
  from public.patients p
  left join lateral (
    select
      max(lr.taken_at) filter (where not public.lab_report_held_unscoped(lr.lab_report_id)) as latest_lab_at,
      bool_or(lr.status = 'outside_range' and not public.lab_report_held_unscoped(lr.lab_report_id)) as has_outside_range,
      bool_or(lr.status = 'needs_review' and not public.lab_report_held_unscoped(lr.lab_report_id)) as has_needs_review,
      bool_or(public.lab_report_held_unscoped(lr.lab_report_id)) as has_identity_hold,
      count(lr.id) filter (where not public.lab_report_held_unscoped(lr.lab_report_id)) > 0 as has_any_labs
    from public.lab_results lr
    where lr.patient_id = p.id
  ) la on true
  left join lateral (
    select true as has_treatment
    from public.patient_treatments t
    where t.patient_id = p.id
    limit 1
  ) tr on true
  on conflict (patient_id) do update set
    org_id            = excluded.org_id,
    latest_lab_at     = excluded.latest_lab_at,
    has_outside_range = excluded.has_outside_range,
    has_needs_review  = excluded.has_needs_review,
    has_identity_hold = excluded.has_identity_hold,
    has_any_labs      = excluded.has_any_labs,
    has_treatment     = excluded.has_treatment;
$$;
