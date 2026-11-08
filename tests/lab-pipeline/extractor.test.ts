// APP-05: the AI extractor is OFF unless LAB_AI_EXTRACTION_ENABLED is
// exactly "true"; when on it sends the file itself inline with a structured
// schema, and whatever comes back is sanitised. No network: fetch is faked.
import { describe, expect, it } from 'vitest';
import {
  DEFAULT_LAB_MODEL,
  EXTRACTION_SCHEMA,
  LAB_AI_FLAG,
  labExtractorFromEnv,
  mimeTypeForPath,
  sanitizeExtraction,
} from '../../supabase/functions/_shared/labExtractor.ts';

const env = (vars: Record<string, string>) => ({ get: (k: string) => vars[k] });
const noFetch = () => { throw new Error('no network in tests'); };

describe('AI extractor flag', () => {
  it('is off by default, off for anything but "true", and off without a key', () => {
    expect(labExtractorFromEnv(env({ GEMINI_API_KEY: 'k' }), noFetch)).toBeNull();
    for (const v of ['1', 'TRUE', 'yes', 'on', ' true']) {
      expect(labExtractorFromEnv(env({ [LAB_AI_FLAG]: v, GEMINI_API_KEY: 'k' }), noFetch), v).toBeNull();
    }
    expect(labExtractorFromEnv(env({ [LAB_AI_FLAG]: 'true' }), noFetch)).toBeNull();
    expect(labExtractorFromEnv(env({ [LAB_AI_FLAG]: 'true', GEMINI_API_KEY: 'k' }), noFetch)?.name).toBe(DEFAULT_LAB_MODEL);
    expect(labExtractorFromEnv(env({ [LAB_AI_FLAG]: 'true', GEMINI_API_KEY: 'k', LAB_EXTRACTION_MODEL: 'm2' }), noFetch)?.name).toBe('m2');
  });
});

describe('Gemini extractor request', () => {
  it('sends the file inline with its MIME type, temperature 0 and the schema; key in a header, not the URL', async () => {
    const calls: { url: string; init: RequestInit }[] = [];
    const reply = { patient_name: 'RIVERA, JORDAN', confidence: { patient_name: 0.9 }, results: [{ analyte: 'HbA1c', value: '5.5', unit: '%', confidence: { analyte: 1, value: 1, unit: 1 } }] };
    const fakeFetch = async (url: string, init: RequestInit) => {
      calls.push({ url, init });
      return new Response(JSON.stringify({ candidates: [{ content: { parts: [{ text: JSON.stringify(reply) }] } }] }), { status: 200 });
    };
    const x = labExtractorFromEnv(env({ [LAB_AI_FLAG]: 'true', GEMINI_API_KEY: 'fictional-key' }), fakeFetch)!;
    const out = await x.extract(new Uint8Array([37, 80, 68, 70]), 'application/pdf');
    expect(calls).toHaveLength(1);
    expect(calls[0].url).toBe(`https://generativelanguage.googleapis.com/v1beta/models/${DEFAULT_LAB_MODEL}:generateContent`);
    expect(calls[0].url).not.toContain('fictional-key');
    expect((calls[0].init.headers as Record<string, string>)['x-goog-api-key']).toBe('fictional-key');
    const body = JSON.parse(String(calls[0].init.body));
    expect(body.contents[0].parts[0]).toEqual({ inlineData: { mimeType: 'application/pdf', data: 'JVBERg==' } });
    expect(body.generationConfig).toEqual({ temperature: 0, responseMimeType: 'application/json', responseSchema: EXTRACTION_SCHEMA });
    expect(out.results).toEqual([{ analyte: 'HbA1c', value: '5.5', unit: '%', reference_range: null, confidence: { analyte: 1, value: 1, unit: 1 } }]);
  });

  it('a provider error throws with the status only (the body is never read)', async () => {
    const x = labExtractorFromEnv(env({ [LAB_AI_FLAG]: 'true', GEMINI_API_KEY: 'k' }), async () => new Response('secret detail', { status: 500 }))!;
    await expect(x.extract(new Uint8Array([1]), 'image/png')).rejects.toThrow(/^extraction: provider status 500$/);
  });
});

describe('sanitizeExtraction', () => {
  it('drops rows without a name or value, caps lengths, clamps confidence, keeps nulls', () => {
    const out = sanitizeExtraction({
      patient_name: '  ', lab_name: 'L'.repeat(500),
      confidence: { lab_name: 7, patient_name: -1, collection_date: 'x' },
      results: [
        { analyte: 'HbA1c', value: 5.5, unit: '%', confidence: { analyte: 2, value: 0.5 } },
        { analyte: '', value: '1' },
        { analyte: 'X', value: null },
        'junk',
      ],
    });
    expect(out.patient_name).toBeNull();
    expect(out.lab_name).toHaveLength(200);
    expect(out.confidence).toEqual({ lab_name: 1, patient_name: 0 });
    expect(out.results).toEqual([{ analyte: 'HbA1c', value: '5.5', unit: '%', reference_range: null, confidence: { analyte: 1, value: 0.5 } }]);
  });

  it('rejects a non-object or a missing results list', () => {
    expect(() => sanitizeExtraction([])).toThrow();
    expect(() => sanitizeExtraction({ results: 'x' })).toThrow();
  });
});

describe('mimeTypeForPath', () => {
  it('knows exactly the bucket\'s file types', () => {
    expect(['a.pdf', 'a.jpg', 'a.jpeg', 'a.png', 'a.heic', 'a.webp', 'a.txt'].map(mimeTypeForPath))
      .toEqual(['application/pdf', 'image/jpeg', 'image/jpeg', 'image/png', 'image/heic', 'image/webp', null]);
  });
});
