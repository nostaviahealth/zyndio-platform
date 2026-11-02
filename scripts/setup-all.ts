#!/usr/bin/env tsx

/**
 * Complete setup (deprecated).
 *
 * This script used to create the old flat `profiles` table and seed an admin
 * user with a `profiles.role = 'admin'` row. Both of those are gone:
 *   - Schema comes only from supabase/migrations/ now (TC-005 baseline); run
 *     `supabase db reset` to apply it.
 *   - Roles live in `org_members`, not `profiles`; the correct, idempotent admin
 *     bootstrap is `npm run admin:setup` (scripts/supabase-admin-setup.ts), which
 *     creates the auth user, the organization, and the active org_admin row.
 *
 * It no longer touches the database. Use the two commands below instead.
 */

console.log('ℹ️  scripts/setup-all.ts is deprecated.');
console.log('   The old profiles-based schema + admin seeding is gone.');
console.log('');
console.log('   Apply the schema:   supabase db reset');
console.log('   Create an admin:    npm run admin:setup   (see admin-setup.md)');
process.exit(0);
