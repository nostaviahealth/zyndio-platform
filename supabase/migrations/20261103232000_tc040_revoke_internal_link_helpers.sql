-- TC-040 card item 5 (audit every table staff can write): the record-linking
-- internals were callable by any signed-in user (and anon) directly through
-- PostgREST /rpc. They are SECURITY DEFINER, were created without a REVOKE,
-- and so kept PostgreSQL's default EXECUTE for PUBLIC (+ Supabase's default
-- grants to anon / authenticated). Each trusts its arguments because it was
-- only ever meant to be called from inside a reviewed RPC:
--   _bind_patient_record(app_user, org, telehealth_id, proof)
--       writes patients + patient_record_links for ANY non-staff account into
--       ANY clinic and claims ANY not-yet-linked telehealth record id, with
--       no code (cross-clinic write; bypasses redeem_* and its brute-force
--       limits). The clinic's org_id is whatever the caller passes.
--   _enqueue_link_notices(...)       writes notification_outbox / telehealth
--                                    outbox rows for any user / clinic
--   _patient_link_clear_attempts(u)  resets anyone's code-guess lockout
--   _patient_link_register_wrong(..) locks anyone out / bumps their counter
--   _clinic_code_breaker_bump()      trips the global clinic-code breaker
--   _patient_link_locked(u), _clinic_code_breaker_tripped()
--                                    read lockout state of any account
-- Every caller is itself SECURITY DEFINER and owned by the same owner
-- (redeem_clinic_link_code, redeem_link_code, unlink_patient_record, ...),
-- which keeps EXECUTE as owner; no app, edge function or invoker function
-- calls them. service_role keeps EXECUTE for server-side jobs and tests.
-- Same treatment the other internal helpers already have (_audit_log_insert,
-- _link_code_pepper, _scrub_*: owner + service_role only).
revoke execute on function public._bind_patient_record(uuid, uuid, text, text) from public, anon, authenticated;
revoke execute on function public._enqueue_link_notices(uuid, uuid, text, text) from public, anon, authenticated;
revoke execute on function public._patient_link_clear_attempts(uuid) from public, anon, authenticated;
revoke execute on function public._patient_link_register_wrong(uuid, integer, integer) from public, anon, authenticated;
revoke execute on function public._patient_link_locked(uuid) from public, anon, authenticated;
revoke execute on function public._clinic_code_breaker_bump() from public, anon, authenticated;
revoke execute on function public._clinic_code_breaker_tripped() from public, anon, authenticated;
grant execute on function public._bind_patient_record(uuid, uuid, text, text) to service_role;
grant execute on function public._enqueue_link_notices(uuid, uuid, text, text) to service_role;
grant execute on function public._patient_link_clear_attempts(uuid) to service_role;
grant execute on function public._patient_link_register_wrong(uuid, integer, integer) to service_role;
grant execute on function public._patient_link_locked(uuid) to service_role;
grant execute on function public._clinic_code_breaker_bump() to service_role;
grant execute on function public._clinic_code_breaker_tripped() to service_role;
