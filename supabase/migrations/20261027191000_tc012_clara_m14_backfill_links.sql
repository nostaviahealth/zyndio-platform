-- Clara M14: M12 made current_patient_linked() require an active
-- patient_record_links row. Pre-M12 clinic-provisioned patients (org_id set
-- by create_patient_record before that migration started inserting a link
-- too) lose clinical access unless backfilled.
--
-- Self-signup accounts are never backfilled — they must bind via a second
-- proof, same as PSU-TO-15/16.

create or replace function public._backfill_clinic_provisioned_links()
returns void
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
begin
  insert into public.patient_record_links (
    app_user_id, org_id, telehealth_patient_id, status, linked_at, proof_method
  )
  select
    p.id,
    p.org_id,
    'clinic:' || p.id::text,
    'active',
    now(),
    'clinic_provisioned'
  from public.patients p
  where p.org_id is not null
    and not public.is_patient_self_signup(p.id)
    and not exists (
      select 1 from public.patient_record_links l
      where l.app_user_id = p.id and l.status = 'active'
    );
end;
$$;

revoke all on function public._backfill_clinic_provisioned_links() from public, anon, authenticated;
grant execute on function public._backfill_clinic_provisioned_links() to service_role;

comment on function public._backfill_clinic_provisioned_links() is
  'One-time (idempotent) backfill: active clinic_provisioned link for every '
  'org_id-bearing patients row with no active link and no self-signup marker '
  '(Clara M14). Re-running inserts nothing extra.';

-- Run once at migration time.
select public._backfill_clinic_provisioned_links();
