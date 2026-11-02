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

// Admin helper functions.
//
// The old profiles-based helpers (createAdminUser / getUserWithProfile /
// isUserAdmin / listUsersWithProfiles / updateUserRole) were removed in TC-026:
// roles live in `org_members` now and the supported admin bootstrap is
// `npm run admin:setup` (scripts/supabase-admin-setup.ts), not a flat
// `profiles.role` write. Only the auth-level delete helper, which never touched
// `profiles`, remains.
export const adminHelpers = {
    // Delete user
    async deleteUser(userId: string) {
        const { error } = await supabaseAdmin.auth.admin.deleteUser(userId);
        if (error) throw error;
    }
};

export default supabaseAdmin;
