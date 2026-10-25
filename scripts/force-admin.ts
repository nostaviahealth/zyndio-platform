#!/usr/bin/env tsx

import { supabaseAdmin } from '../lib/supabaseAdmin';

async function forceAdminAccess() {
    console.log('🔧 FORCING ADMIN ACCESS\n');

    try {
        // List all users
        const { data: { users } } = await supabaseAdmin.auth.admin.listUsers();

        console.log('👥 All users:');
        for (const user of users) {
            console.log(`  - ${user.email} (ID: ${user.id})`);

            // Force admin role for EVERY user
            const { error } = await supabaseAdmin
                .from('profiles')
                .upsert({
                    user_id: user.id,
                    role: 'admin',
                    name: user.email?.split('@')[0] || 'Admin'
                }, {
                    onConflict: 'user_id'
                });

            if (!error) {
                console.log(`    ✅ Set as ADMIN`);
            }
        }

        console.log('\n✅ ALL USERS NOW HAVE ADMIN ACCESS!');
        console.log('\n📝 Next steps:');
        console.log('   1. Go to: http://localhost:3000/login');
        console.log('   2. Login with ANY user');
        console.log('   3. You will be redirected to /admin');

    } catch (error: any) {
        console.error('❌ Error:', error.message);
    }
}

forceAdminAccess();
