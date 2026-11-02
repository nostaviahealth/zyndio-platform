#!/usr/bin/env tsx

/**
 * Database schema setup (deprecated).
 *
 * This script used to create the old flat `profiles` table by hand. As of
 * TC-005's clean baseline the SQL migrations under supabase/migrations/ are the
 * ONLY source of schema truth, and TC-026 moved every runtime read/write off
 * `profiles` onto the real patient/user tables. There is nothing left for this
 * script to create, so it no longer touches the database.
 *
 * To stand up the schema locally, apply the migrations instead:
 *   supabase db reset        # reapply every migration from scratch
 * Then bootstrap the first org admin:
 *   npm run admin:setup      # see admin-setup.md
 */

console.log('ℹ️  scripts/setup-database.ts is deprecated.');
console.log('   Schema now comes exclusively from supabase/migrations/.');
console.log('');
console.log('   Apply the schema:   supabase db reset');
console.log('   Create an admin:    npm run admin:setup   (see admin-setup.md)');
process.exit(0);
