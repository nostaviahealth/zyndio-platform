#!/usr/bin/env tsx

import { supabaseAdmin } from '../lib/supabaseAdmin';

async function setupEverything() {
    console.log('🚀 Complete Automated Setup\n');

    try {
        // Step 1: Create tables using raw SQL
        console.log('📊 Setting up database schema...');

        const { error: schemaError } = await supabaseAdmin.rpc('exec_sql', {
            sql: `
                CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
                
                CREATE TABLE IF NOT EXISTS public.profiles (
                    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
                    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL UNIQUE,
                    role TEXT NOT NULL DEFAULT 'user' CHECK (role IN ('user', 'admin', 'doctor', 'nutritionist')),
                    name TEXT,
                    avatar_url TEXT,
                    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW() NOT NULL,
                    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW() NOT NULL
                );
            `
        }).catch(() => ({ error: null })); // Ignore if already exists

        // Step 2: Create admin user
        console.log('👤 Creating admin user...');

        const { data: authData, error: authError } = await supabaseAdmin.auth.admin.createUser({
            email: 'support@zyndio.example',
            password: 'admin123',
            email_confirm: true,
            user_metadata: { name: 'Admin User' }
        });

        if (authError) {
            if (authError.message.includes('already')) {
                console.log('ℹ️  Admin user already exists');

                // Get existing user
                const { data: { users } } = await supabaseAdmin.auth.admin.listUsers();
                const adminUser = users.find(u => u.email === 'support@zyndio.example');

                if (adminUser) {
                    // Update profile with admin role using raw insert
                    await supabaseAdmin.from('profiles').upsert({
                        user_id: adminUser.id,
                        role: 'admin',
                        name: 'Admin User'
                    }, { onConflict: 'user_id' });

                    console.log('✅ Admin role assigned');
                }
            } else {
                throw authError;
            }
        } else {
            // Create profile for new user
            await supabaseAdmin.from('profiles').insert({
                user_id: authData.user.id,
                role: 'admin',
                name: 'Admin User'
            });

            console.log('✅ Admin user created');
        }

        console.log('\n🎉 Setup Complete!\n');
        console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
        console.log('📌 Admin Credentials:');
        console.log('   Email: support@zyndio.example');
        console.log('   Password: admin123');
        console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');
        console.log('🌐 Login at:');
        console.log('   Local: http://localhost:3001/login');
        console.log('   Production: https://zyndio.example/login\n');
        console.log('⚠️  IMPORTANT: Change the default password in production!');

    } catch (error: any) {
        console.error('\n❌ Setup failed:', error.message);
        process.exit(1);
    }
}

setupEverything();
