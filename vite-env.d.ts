/// <reference types="vite/client" />

interface ImportMetaEnv {
    readonly VITE_SUPABASE_URL: string;
    readonly VITE_SUPABASE_ANON_KEY: string;
    readonly SUPABASE_SERVICE_KEY: string;
    // TC-026: "true" shows the 4 legacy patient screens (see lib/featureFlags.ts). Off by default.
    readonly VITE_FEATURE_LEGACY_PATIENT_SCREENS?: string;
}

interface ImportMeta {
    readonly env: ImportMetaEnv;
}

// Set true only by `vite build --mode preview` (npm run build:preview) -
// gates the /__preview screenshot harness route so it's dead code (and
// tree-shaken out) of the default `npm run build` bundle.
declare const __PREVIEW_BUILD__: boolean;
