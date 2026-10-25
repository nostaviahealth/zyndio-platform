#!/usr/bin/env tsx

/**
 * Supabase Admin Setup Script
 * 
 * This script will:
 * 1. Create the admin user
 * 2. Assign admin role
 * 3. Verify setup
 * 
 * Usage: npm run admin:setup
 */

import { adminHelpers } from '../lib/supabaseAdmin';

const ADMIN_EMAIL = 'support@zyndio.example';
const ADMIN_PASSWORD = 'admin123'; // Change this in production!
const ADMIN_NAME = 'Admin User';

async function setupAdmin() {
    console.log('🚀 Zyndio - Supabase Admin Setup\n');

    try {
        // Check if admin already exists
        console.log('🔍 Checking for existing admin user...');
        const existingUsers = await adminHelpers.listUsersWithProfiles();
        const adminExists = existingUsers.some(u => u.email === ADMIN_EMAIL);

        if (adminExists) {
            console.log('ℹ️  Admin user already exists!');
            console.log(`   Email: ${ADMIN_EMAIL}`);

            // Check if they have admin role
            const adminUser = existingUsers.find(u => u.email === ADMIN_EMAIL);
            if (adminUser?.profile?.role === 'admin') {
                console.log('✅ Admin role confirmed\n');
                console.log('🎉 Setup complete! You can now log in.');
                console.log('   Email: support@zyndio.example');
                console.log('   Password: admin123');
                console.log('\n⚠️  Remember to change the password in production!');
                return;
            } else {
                console.log('⚙️  Updating user to admin role...');
                await adminHelpers.updateUserRole(adminUser!.id, 'admin');
                console.log('✅ Admin role assigned\n');
            }
        } else {
            // Create new admin user
            console.log('📝 Creating admin user...');
            const user = await adminHelpers.createAdminUser(ADMIN_EMAIL, ADMIN_PASSWORD, ADMIN_NAME);
            console.log('✅ Admin user created!');
            console.log(`   ID: ${user.id}`);
            console.log(`   Email: ${user.email}\n`);
        }

        console.log('🎉 Admin setup complete!\n');
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

        if (error.message.includes('connect')) {
            console.error('\n💡 Make sure your .env file has:');
            console.error('   VITE_SUPABASE_URL=your_project_url');
            console.error('   VITE_SUPABASE_ANON_KEY=your_anon_key');
            console.error('   SUPABASE_SERVICE_KEY=your_service_key\n');
        } else {
            console.error('\n💡 Error details:', error);
        }

        process.exit(1);
    }
}

// Run setup
setupAdmin();
