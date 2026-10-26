#!/usr/bin/env tsx

import { supabaseAdmin } from '../lib/supabaseAdmin';

async function checkDatabase() {
    console.log('🔍 CHECKING DATABASE\n');

    try {
        // Get all users
        const { data: { users }, error: usersError } = await supabaseAdmin.auth.admin.listUsers();

        if (usersError) {
            console.error('❌ Error getting users:', usersError);
            return;
        }

        console.log(`📋 Found ${users.length} user(s):\n`);

        for (const user of users) {
            console.log(`👤 User: ${user.email}`);
            console.log(`   ID: ${user.id}`);

            // Check profile
            const { data: profile, error: profileError } = await supabaseAdmin
                .from('profiles')
                .select('*')
                .eq('user_id', user.id)
                .single();

            if (profileError) {
                console.log(`   ❌ NO PROFILE FOUND!`);
                console.log(`   Error:`, profileError.message);

                // Create profile with admin role
                console.log(`   🔧 Creating admin profile...`);
                const { error: insertError } = await supabaseAdmin
                    .from('profiles')
                    .insert({
                        user_id: user.id,
                        role: 'admin',
                        name: user.email?.split('@')[0] || 'Admin'
                    });

                if (insertError) {
                    console.log(`   ❌ Failed to create:`, insertError.message);
                } else {
                    console.log(`   ✅ Profile created with ADMIN role!`);
                }
            } else {
                console.log(`   ✅ Profile exists`);
                console.log(`   Role: ${profile.role}`);
                console.log(`   Name: ${profile.name}`);

                if (profile.role !== 'admin') {
                    console.log(`   ⚠️  Role is NOT admin, updating...`);
                    const { error: updateError } = await supabaseAdmin
                        .from('profiles')
                        .update({ role: 'admin' })
                        .eq('user_id', user.id);

                    if (updateError) {
                        console.log(`   ❌ Update failed:`, updateError.message);
                    } else {
                        console.log(`   ✅ Updated to ADMIN!`);
                    }
                }
            }
            console.log('');
        }

        console.log('✅ Database check complete!');
        console.log('\n📝 Try logging in again now.');

    } catch (error: any) {
        console.error('❌ Error:', error.message);
    }
}

checkDatabase();
