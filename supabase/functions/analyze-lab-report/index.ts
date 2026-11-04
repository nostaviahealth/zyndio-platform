// TC-039 / APP-05: see ../_shared/analyzeLabReport.ts for the rules (service
// role or the report's own patient, real lab_reports columns, file by
// pdf_path, SHA-256 dedupe, no invented results, no error text in logs or
// responses) and ../_shared/labExtractor.ts for the AI extractor flag.
import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { serviceRoleClient } from "../_shared/requireOrgAdminActor.ts"
import { handleAnalyzeLabReport } from "../_shared/analyzeLabReport.ts"
import { labExtractorFromEnv } from "../_shared/labExtractor.ts"
import { DEFAULT_CONFIDENCE_THRESHOLD } from "../_shared/labNormalize.ts"

function confidenceThreshold(): number {
    const n = Number(Deno.env.get('LAB_CONFIDENCE_THRESHOLD'))
    return Number.isFinite(n) && n > 0 && n <= 1 ? n : DEFAULT_CONFIDENCE_THRESHOLD
}

serve((req) => handleAnalyzeLabReport(req, {
    env: Deno.env,
    db: serviceRoleClient(),
    // OFF unless LAB_AI_EXTRACTION_ENABLED=true (and GEMINI_API_KEY is set).
    // No BAA yet: only ever enable it where every report is fictional.
    extractor: labExtractorFromEnv(Deno.env, fetch),
    confidenceThreshold: confidenceThreshold(),
    log: (code) => console.error(code),
}))
