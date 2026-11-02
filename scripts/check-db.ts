#!/usr/bin/env tsx

import { supabaseAdmin } from '../lib/supabaseAdmin';

/**
 * Read-only database diagnostic.
 *
 * Roles no longer live on a flat `profiles.role` column - they live in
 * `org_members` (TC-005). This reports each auth user's org membership and role
 * so you can see who has access, but it does NOT create or promote anyone: the
 * only supported way to grant an org_admin is `npm run admin:setup`
 * (scripts/supabase-admin-setup.ts). See admin-setup.md.
 */
async function checkDatabase() {
    console.log('🔍 CHECKING DATABASE (read-only)\n');

    try {
        // Get all users
        const { data: { users }, error: usersError } = await supabaseAdmin.auth.admin.listUsers();

        if (usersError) {
            console.error('❌ Error getting users:', usersError.message);
            return;
        }

        console.log(`📋 Found ${users.length} user(s):\n`);

        for (const user of users) {
            console.log(`👤 User: ${user.email}`);
            console.log(`   ID: ${user.id}`);

            // Role lives in org_members now, not a flat profiles.role column.
            const { data: memberships, error: memberError } = await supabaseAdmin
                .from('org_members')
                .select('org_id, role, status')
                .eq('user_id', user.id);

            if (memberError) {
                console.log(`   ❌ Error reading org_members:`, memberError.message);
            } else if (!memberships || memberships.length === 0) {
                console.log(`   ⚠️  No org membership (not staff).`);
                console.log(`   To grant an org_admin, run: npm run admin:setup`);
            } else {
                for (const m of memberships) {
                    console.log(`   ✅ org ${m.org_id}: role=${m.role}, status=${m.status}`);
                }
            }
            console.log('');
        }

        console.log('✅ Database check complete!');

    } catch (error: any) {
        console.error('❌ Error:', error.message);
    }
}

checkDatabase();
