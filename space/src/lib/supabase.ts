/**
 * Supabase Client Configuration
 */

import { createClient } from '@supabase/supabase-js';

const supabaseUrl = import.meta.env.VITE_SUPABASE_URL ?? '';
const supabaseAnonKey = import.meta.env.VITE_SUPABASE_ANON_KEY ?? '';

export const supabase = createClient(supabaseUrl, supabaseAnonKey);

// Types for database
export interface UserHabits {
    id: string;
    user_id: string;
    daily_goal: number;
    space_theme: boolean;
    created_at: string;
    updated_at: string;
}

export interface MeditationSession {
    id: string;
    user_id: string;
    date: string;
    minutes: number;
    mode: string;
    created_at: string;
}
