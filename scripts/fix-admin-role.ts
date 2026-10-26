#!/usr/bin/env tsx

import { supabaseAdmin } from '../lib/supabaseAdmin';

async function fixAdminRole() {
    console.log('🔧 Fixing admin role...\n');

    try {
        // Get all users
        const { data: { users }, error: usersError } = await supabaseAdmin.auth.admin.listUsers();

        if (usersError) throw usersError;

        console.log('📋 Found users:');
        users.forEach(u => {
            console.log(`  - ${u.email} (ID: ${u.id})`);
        });

        // Find admin user
        const adminUser = users.find(u => u.email === 'support@zyndio.example');

        if (!adminUser) {
            console.log('\n❌ Admin user not found!');
            process.exit(1);
        }

        console.log('\n✅ Found admin user:', adminUser.id);

        // Check current profile
        const { data: currentProfile } = await supabaseAdmin
            .from('profiles')
            .select('*')
            .eq('user_id', adminUser.id)
            .single();

        console.log('\n📊 Current profile:', currentProfile);

        // Upsert admin profile
        const { data, error } = await supabaseAdmin
            .from('profiles')
            .upsert({
                user_id: adminUser.id,
                role: 'admin',
                name: 'Admin User'
            }, {
                onConflict: 'user_id'
            })
            .select()
            .single();

        if (error) {
            console.error('❌ Error updating profile:', error);
            throw error;
        }

        console.log('\n✅ Profile updated successfully!');
        console.log('📊 New profile:', data);

        console.log('\n🎉 Admin role fixed!');
        console.log('\n👉 Please log out and log in again to see the admin dashboard.');

    } catch (error: any) {
        console.error('\n❌ Error:', error.message);
        console.error('\nDetails:', error);
        process.exit(1);
    }
}

fixAdminRole();
