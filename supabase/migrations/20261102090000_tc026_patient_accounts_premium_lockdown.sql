-- TC-026 fix: the premium columns on public.patient_accounts were NOT actually
-- locked down for patients. The create migration (20261101132940) used
--   revoke update (is_premium, subscription_plan, subscription_expires_at)
--     on public.patient_accounts from authenticated, anon;
-- but Supabase grants table-level UPDATE to authenticated/anon by default, and
-- in PostgreSQL a role's effective privilege on a column is the UNION of the
-- table-level and column-level grants. So a column-level REVOKE has no effect
-- while a table-level UPDATE grant is still present -- the owner could still
-- UPDATE/UPSERT is_premium on their own row. (See the Postgres GRANT docs:
-- "granting UPDATE on a table and then revoking it for one column will not
-- prevent the user from updating that column.") pgTAP 734 caught this.
--
-- The robust fix is to drop the subsuming table-level grant entirely and then
-- re-grant INSERT/UPDATE back at the column level for every column EXCEPT the
-- three premium columns. With no column-level privilege on the premium columns,
-- any authenticated/anon statement that names one in an INSERT column list or an
-- UPDATE SET list (plain UPDATE, multi-column UPDATE, or upsert's ON CONFLICT DO
-- UPDATE) fails with 42501 before the write happens -- while every other column
-- stays writable so the normal Flutter patient flows (name/avatar/questionnaire/
-- xp/coins/league/fcm_token) keep working.
--
-- Unaffected on purpose:
--   * service_role (the RevenueCat webhook identity) is never revoked here, so it
--     keeps its Supabase-granted table-level INSERT/UPDATE and remains the only
--     caller that can write the premium columns.
--   * the table owner / superuser (migrations, pgTAP fixtures) bypass column
--     privileges entirely.
--   * SELECT is untouched, so patients still read their own premium state.

-- Neutralise the table-level grants that made the original column REVOKE a no-op.
revoke insert, update on public.patient_accounts from authenticated, anon;

-- Re-grant INSERT/UPDATE at the column level for every non-premium column.
-- Columns omitted from an INSERT fall back to their defaults with no privilege
-- check, so a patient can still create their row; is_premium/subscription_plan/
-- subscription_expires_at default to false/'free'/null and can never be set by
-- the patient themselves.
grant insert (
  patient_id, name, age, avatar_url, organization, stage, questionnaire_data,
  fcm_token, xp, coins, league_xp, current_league, league_reset_at,
  league_badges, created_at, updated_at
) on public.patient_accounts to authenticated;

grant update (
  patient_id, name, age, avatar_url, organization, stage, questionnaire_data,
  fcm_token, xp, coins, league_xp, current_league, league_reset_at,
  league_badges, created_at, updated_at
) on public.patient_accounts to authenticated;
