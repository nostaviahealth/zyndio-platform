# Legacy SQL (pre-TC-005)

Everything in this directory predates `supabase/config.toml` and the `supabase/migrations/`
baseline introduced by TC-005. None of it is applied by any tooling — not `supabase db reset`,
not CI, not any script in `scripts/`. It is kept only for historical reference.

## Why it's here

These files were hand-run ad hoc against whatever Supabase project existed at the time, in
whatever order someone happened to run them. Several are successive, overlapping attempts to
patch the same recursive-RLS bug on the old `public.profiles` table (`enable-rls.sql`,
`fix-rls.sql`, `fix_profiles_rls.sql`, `complete-fix.sql`, `complete_fix.sql`, `master-fix.sql`,
`nuclear-fix.sql`, `FINAL_FIX_admin_access.sql`, `ROLLBACK_restore_original_profiles_rls.sql`).
`FINAL_FIX_admin_access.sql` in particular documents the exact bug class — a policy whose
`USING` clause queried the same table it protected, causing infinite recursion — that the new
`current_org_id()`/`current_role()`/`is_org_admin()` SECURITY DEFINER helper functions
(`supabase/migrations/`) are designed to avoid, by reading role/org state through a function with
a pinned `search_path` instead of a self-referential policy subquery.

## `_legacy/migrations/`

The old `supabase/migrations/*.sql` files (gamification, leagues, fcm tokens, menstrual logs,
user correlations, daily rhythms/notifications) depend on legacy tables (`public.profiles` and
others this card's schema doesn't create) and were never actually applied by the Supabase CLI —
running `supabase db reset` against them from a clean database fails. They're moved here
unmodified, not deleted, since they document prior feature work. The new TC-005 migrations in
`supabase/migrations/` are a clean baseline and do not build on these.

## What this means going forward

- Nothing in `_legacy/` is dropped or migrated forward. No `DROP TABLE` statements were written
  against the tables these scripts created — the tables they reference (if any still exist in a
  given environment) are simply outside the new baseline's schema.
- The old patient-app React pages that read from legacy tables (e.g. `public.profiles`) are
  unchanged and out of scope for TC-005; the new admin/portal routes added by this card do not
  depend on any table defined here.
- Do not resurrect any of these files into `supabase/migrations/`. If a past fix is still needed,
  re-derive it as a proper migration against the new schema.
