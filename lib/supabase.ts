import { createClient } from '@supabase/supabase-js';

// Supabase configuration
const supabaseUrl = import.meta.env.VITE_SUPABASE_URL as string;
const supabaseAnonKey = import.meta.env.VITE_SUPABASE_ANON_KEY as string;

// Initialize Supabase client
export const supabase = createClient(supabaseUrl, supabaseAnonKey, {
    auth: {
        autoRefreshToken: true,
        persistSession: true,
        detectSessionInUrl: true
    }
});

// Database types (will be auto-generated later with Supabase CLI)
export type Json =
    | string
    | number
    | boolean
    | null
    | { [key: string]: Json | undefined }
    | Json[];

export interface Database {
    public: {
        Tables: {
            profiles: {
                Row: {
                    id: string;
                    user_id: string;
                    role: 'user' | 'admin' | 'doctor' | 'nutritionist';
                    name: string | null;
                    avatar_url: string | null;
                    created_at: string;
                    updated_at: string;
                };
                Insert: {
                    id?: string;
                    user_id: string;
                    role?: 'user' | 'admin' | 'doctor' | 'nutritionist';
                    name?: string | null;
                    avatar_url?: string | null;
                    created_at?: string;
                    updated_at?: string;
                };
                Update: {
                    id?: string;
                    user_id?: string;
                    role?: 'user' | 'admin' | 'doctor' | 'nutritionist';
                    name?: string | null;
                    avatar_url?: string | null;
                    created_at?: string;
                    updated_at?: string;
                };
            };
            patients: {
                Row: {
                    id: string;
                    user_id: string;
                    name: string;
                    email: string | null;
                    phone: string | null;
                    age: number | null;
                    bio_age: number | null;
                    health_grade: string | null;
                    primary_goal: string | null;
                    is_premium: boolean;
                    pace_of_aging: number;
                    avatar_url: string | null;
                    stage: string;
                    preferences: Json | null;
                    doctor_notes: string | null;
                    nutritionist_notes: string | null;
                    created_at: string;
                    updated_at: string;
                };
                Insert: Omit<Database['public']['Tables']['patients']['Row'], 'id' | 'created_at' | 'updated_at'> & {
                    id?: string;
                    created_at?: string;
                    updated_at?: string;
                };
                Update: Partial<Database['public']['Tables']['patients']['Insert']>;
            };
            health_journeys: {
                Row: {
                    id: string;
                    patient_id: string;
                    title: string;
                    overview: string | null;
                    phases: Json;
                    published: boolean;
                    published_at: string | null;
                    created_at: string;
                    updated_at: string;
                };
                Insert: Omit<Database['public']['Tables']['health_journeys']['Row'], 'id' | 'created_at' | 'updated_at'> & {
                    id?: string;
                    created_at?: string;
                    updated_at?: string;
                };
                Update: Partial<Database['public']['Tables']['health_journeys']['Insert']>;
            };
            meal_plans: {
                Row: {
                    id: string;
                    patient_id: string;
                    name: string;
                    description: string | null;
                    days: Json;
                    approved: boolean;
                    published: boolean;
                    published_at: string | null;
                    created_at: string;
                    updated_at: string;
                };
                Insert: Omit<Database['public']['Tables']['meal_plans']['Row'], 'id' | 'created_at' | 'updated_at'> & {
                    id?: string;
                    created_at?: string;
                    updated_at?: string;
                };
                Update: Partial<Database['public']['Tables']['meal_plans']['Insert']>;
            };
            intelligence_data: {
                Row: {
                    id: string;
                    patient_id: string;
                    overall_score: number | null;
                    biomarkers_score: number | null;
                    lifestyle_score: number | null;
                    risk_factors_score: number | null;
                    health_domains: Json | null;
                    disease_risks: Json | null;
                    approved: boolean;
                    published: boolean;
                    generated_at: string | null;
                    published_at: string | null;
                    created_at: string;
                    updated_at: string;
                };
                Insert: Omit<Database['public']['Tables']['intelligence_data']['Row'], 'id' | 'created_at' | 'updated_at'> & {
                    id?: string;
                    created_at?: string;
                    updated_at?: string;
                };
                Update: Partial<Database['public']['Tables']['intelligence_data']['Insert']>;
            };
            daily_bio_logs: {
                Row: {
                    id: string;
                    profile_id: string;
                    sleep_quality: 'Poor' | 'Fair' | 'Good' | 'Great' | null;
                    stress_level: number | null;
                    energy_level: number | null;
                    logged_at: string;
                    created_at: string;
                };
                Insert: {
                    id?: string;
                    profile_id: string;
                    sleep_quality?: 'Poor' | 'Fair' | 'Good' | 'Great' | null;
                    stress_level?: number | null;
                    energy_level?: number | null;
                    logged_at?: string;
                    created_at?: string;
                };
                Update: Partial<Database['public']['Tables']['daily_bio_logs']['Insert']>;
            };
            daily_journals: {
                Row: {
                    id: string;
                    profile_id: string;
                    content: string;
                    logged_at: string;
                    created_at: string;
                };
                Insert: {
                    id?: string;
                    profile_id: string;
                    content: string;
                    logged_at?: string;
                    created_at?: string;
                };
                Update: Partial<Database['public']['Tables']['daily_journals']['Insert']>;
            };
        };
    };
}

export default supabase;
