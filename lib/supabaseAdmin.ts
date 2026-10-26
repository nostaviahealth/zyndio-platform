import { createClient } from '@supabase/supabase-js';
import type { Database } from './supabase';
import * as dotenv from 'dotenv';

// Load environment variables from .env file
dotenv.config();

// Admin client with service role key for server-side operations
const supabaseUrl = process.env.VITE_SUPABASE_URL as string;
const supabaseServiceKey = process.env.SUPABASE_SERVICE_KEY as string;

export const supabaseAdmin = createClient<Database>(supabaseUrl, supabaseServiceKey, {
    auth: {
        autoRefreshToken: false,
        persistSession: false
    }
});

// Admin helper functions
export const adminHelpers = {
    // Create admin user
    async createAdminUser(email: string, password: string, name: string) {
        // Create auth user
        const { data: authData, error: authError } = await supabaseAdmin.auth.admin.createUser({
            email,
            password,
            email_confirm: true,
            user_metadata: { name }
        });

        if (authError) throw authError;

        // Create profile with admin role
        const { error: profileError } = await supabaseAdmin
            .from('profiles')
            .insert({
                user_id: authData.user.id,
                role: 'admin',
                name
            });

        if (profileError) throw profileError;

        return authData.user;
    },

    // Get user with profile
    async getUserWithProfile(userId: string) {
        const { data, error } = await supabaseAdmin
            .from('profiles')
            .select('*')
            .eq('user_id', userId)
            .single();

        if (error) throw error;
        return data;
    },

    // Check if user is admin
    async isUserAdmin(userId: string): Promise<boolean> {
        const { data } = await supabaseAdmin
            .from('profiles')
            .select('role')
            .eq('user_id', userId)
            .single();

        return data?.role === 'admin';
    },

    // List all users with profiles
    async listUsersWithProfiles() {
        const { data: { users }, error: authError } = await supabaseAdmin.auth.admin.listUsers();

        if (authError) throw authError;

        const profiles = await Promise.all(
            users.map(async (user) => {
                const { data: profile } = await supabaseAdmin
                    .from('profiles')
                    .select('*')
                    .eq('user_id', user.id)
                    .single();

                return {
                    ...user,
                    profile
                };
            })
        );

        return profiles;
    },

    // Update user role
    async updateUserRole(userId: string, role: 'user' | 'admin' | 'doctor' | 'nutritionist') {
        const { error } = await supabaseAdmin
            .from('profiles')
            .update({ role })
            .eq('user_id', userId);

        if (error) throw error;
    },

    // Delete user
    async deleteUser(userId: string) {
        const { error } = await supabaseAdmin.auth.admin.deleteUser(userId);
        if (error) throw error;
    }
};

export default supabaseAdmin;
