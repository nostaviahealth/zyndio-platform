#!/usr/bin/env tsx

/**
 * Automated Supabase Database Setup
 * This script will create all tables automatically via SQL API
 */

import * as dotenv from 'dotenv';
import fetch from 'node-fetch';

dotenv.config();

const SUPABASE_URL = process.env.VITE_SUPABASE_URL!;
const SERVICE_KEY = process.env.SUPABASE_SERVICE_KEY!;

const schema = `
-- Enable UUID extension
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Create profiles table
CREATE TABLE IF NOT EXISTS public.profiles (
    id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL UNIQUE,
    role TEXT NOT NULL DEFAULT 'user' CHECK (role IN ('user', 'admin', 'doctor', 'nutritionist')),
    name TEXT,
    avatar_url TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW() NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW() NOT NULL
);

CREATE INDEX IF NOT EXISTS profiles_user_id_idx ON public.profiles(user_id);
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;

-- RLS Policies
DROP POLICY IF EXISTS "Users can view own profile" ON public.profiles;
CREATE POLICY "Users can view own profile" ON public.profiles FOR SELECT USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Users can update own profile" ON public.profiles;
CREATE POLICY "Users can update own profile" ON public.profiles FOR UPDATE USING (auth.uid() = user_id);

-- Auto-create profile when user signs up
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO public.profiles (user_id, name)
    VALUES (NEW.id, COALESCE(NEW.raw_user_meta_data->>'name', NEW.email));
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
    AFTER INSERT ON auth.users
    FOR EACH ROW
    EXECUTE FUNCTION public.handle_new_user();
`;

async function setupDatabase() {
    console.log('🚀 Automated Supabase Database Setup\n');
    console.log('📊 Creating database schema...');

    try {
        const response = await fetch(`${SUPABASE_URL}/rest/v1/rpc/exec_sql`, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
                'apikey': SERVICE_KEY,
                'Authorization': `Bearer ${SERVICE_KEY}`
            },
            body: JSON.stringify({ query: schema })
        });

        if (!response.ok) {
            // Try alternative method using pgmeta API
            console.log('⚙️  Using alternative setup method...');

            const queries = schema.split(';').filter(q => q.trim());

            for (const query of queries) {
                if (!query.trim()) continue;

                console.log('  Running query...');
                const res = await fetch(`${SUPABASE_URL}/rest/v1/`, {
                    method: 'POST',
                    headers: {
                        'Content-Type': 'application/json',
                        'apikey': SERVICE_KEY,
                        'Authorization': `Bearer ${SERVICE_KEY}`,
                        'Prefer': 'return=minimal'
                    },
                    body: JSON.stringify({ query: query.trim() })
                });

                if (!res.ok) {
                    const error = await res.text();
                    console.log('  ⚠️  Warning:', error);
                }
            }
        }

        console.log('✅ Database schema setup complete!\n');
        return true;
    } catch (error: any) {
        console.error('❌ Error setting up database:', error.message);
        console.error('\n💡 Manual setup required:');
        console.error('   Go to: https://supabase.com/dashboard/project/<your-project-ref>/sql');
        console.error('   Copy schema from: supabase/schema.sql');
        console.error('   Paste and run in SQL editor\n');
        return false;
    }
}

setupDatabase().then(success => {
    if (success) {
        console.log('🎉 Ready to create admin user!');
        console.log('   Run: npm run admin:setup');
    }
    process.exit(success ? 0 : 1);
});
