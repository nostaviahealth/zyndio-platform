// TC-039: see ../_shared/analyzeLabReport.ts for the rules (service_role
// only, real lab_reports columns, file by pdf_path, no invented results, no
// error text in logs or responses).
import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { OpenAI } from "npm:openai@4.28.0"
import { serviceRoleClient } from "../_shared/requireOrgAdminActor.ts"
import { handleAnalyzeLabReport, type ExtractedMarker } from "../_shared/analyzeLabReport.ts"

const SYSTEM_PROMPT = `You are a medical lab analyzer. Extract biomarkers from the provided text into JSON format: [{name: "Hemoglobin", value: "13.5 g/dL", ...}]. Return ONLY JSON.`

async function analyzeText(text: string): Promise<ExtractedMarker[]> {
    const openai = new OpenAI({
        apiKey: Deno.env.get('GEMINI_API_KEY') ?? '',
        baseURL: "https://generativelanguage.googleapis.com/v1beta/openai/"
    })
    const completion = await openai.chat.completions.create({
        messages: [
            { role: "system", content: SYSTEM_PROMPT },
            { role: "user", content: `Analyze the following lab data: ${text}` }
        ],
        model: "gemini-3.5-flash",
    })
    const content = completion.choices[0]?.message?.content ?? ''
    const parsed = JSON.parse(content.replace(/```json/g, '').replace(/```/g, '').trim() || '[]')
    if (!Array.isArray(parsed)) throw new Error('not a list')
    return parsed as ExtractedMarker[]
}

serve((req) => handleAnalyzeLabReport(req, {
    env: Deno.env,
    db: serviceRoleClient(),
    // No server-side PDF/image text extraction exists yet (TC-039: the old
    // code analysed a hard-coded sample string). Until one does, nothing is
    // analysed or written; the app's own on-device analysis is unaffected.
    extractText: () => Promise.resolve(null),
    analyzeText,
    log: (code) => console.error(code),
}))
