
import { createClient } from '@supabase/supabase-js';
import * as dotenv from 'dotenv';
dotenv.config();

const SUPABASE_URL = process.env.VITE_SUPABASE_URL;
const SERVICE_KEY = process.env.SUPABASE_SERVICE_KEY || process.env.VITE_SUPABASE_ANON_KEY;

if (!SUPABASE_URL || !SERVICE_KEY) {
    console.error('Missing env vars');
    process.exit(1);
}

const supabase = createClient(SUPABASE_URL, SERVICE_KEY);

async function checkTables() {
    console.log('Checking for health tables...');
    const tables = [
        'profiles',
        'lab_reports',
        'lab_results',
        'biomarkers',
        'health_data',
        'patient_data',
        'health_records',
        'uploaded_files',
        'documents'
    ];

    for (const table of tables) {
        try {
            const { data, error } = await supabase.from(table).select('*').limit(1);
            if (error) {
                console.log(`[${table}] Error: ${error.message}`);
            } else {
                console.log(`[${table}] FOUND! Rows:`, data.length);
                console.log(`[${table}] Keys:`, Object.keys(data[0]));
                console.log(`Sample FKs:`,
                    'user_id' in data[0] ? `user_id: ${data[0].user_id}` : 'no user_id',
                    'profile_id' in data[0] ? `profile_id: ${data[0].profile_id}` : 'no profile_id',
                    'patient_id' in data[0] ? `patient_id: ${data[0].patient_id}` : 'no patient_id'
                );
            }
        } catch (e) {
            console.log(`[${table}] Exception:`, e);
        }
    }
}

checkTables();
