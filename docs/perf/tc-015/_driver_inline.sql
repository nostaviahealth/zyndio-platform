\pset pager off
begin;
set local role authenticated;
select set_config('request.jwt.claims','{"sub":"0000f015-0000-0000-0000-0000000a0002","role":"authenticated","aal":"aal2"}', true);
explain (analyze, buffers)
  with filtered as (
    select
      p.id, p.display_name, p.mrn, m.sex, m.birth_date, m.program_started_on,
      s.latest_lab_at, m.last_activity_at, coalesce(m.open_questions,0) as open_questions,
      array_remove(array[
        case when coalesce(s.has_treatment,false) then 'clinical_context' end,
        case when coalesce(s.has_outside_range,false) then 'outside_range' end,
        case when coalesce(s.has_needs_review,false) then 'needs_review' end,
        case when coalesce(s.has_identity_hold,false) then 'identity_hold' end,
        case when not coalesce(s.has_any_labs,false) then 'missing_labs' end,
        case when coalesce(m.open_questions,0) > 0 then 'question_waiting' end
      ], null) as flags
    from public.patients p
    left join public.patient_roster_meta m on m.patient_id = p.id
    left join public.patient_roster_summary s on s.patient_id = p.id
    where p.org_id = public.current_org_id()
  )
  select *, count(*) over() from filtered
  order by last_activity_at desc nulls last, display_name asc
  limit 8;
rollback;
