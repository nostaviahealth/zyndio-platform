// APP-05: the reviewed analyte -> LOINC rows exactly as the migration seeds
// public.lab_analyte_loinc, read from the SQL file itself so the vitest
// suite tests the real mapping (not a copy that could drift).
import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import type { AnalyteMapRow } from '../../supabase/functions/_shared/labNormalize.ts';

export const LAB_PIPELINE_MIGRATION = fileURLToPath(
  new URL('../../supabase/migrations/20261104130000_app05_lab_pipeline.sql', import.meta.url),
);

export interface SeededAnalyte extends AnalyteMapRow {
  display_name: string;
  canonical_unit: string;
}

function sqlStrings(list: string): string[] {
  return [...list.matchAll(/'((?:[^']|'')*)'/g)].map((m) => m[1].replace(/''/g, "'"));
}

export function reviewedAnalyteMap(): SeededAnalyte[] {
  const sql = readFileSync(LAB_PIPELINE_MIGRATION, 'utf8');
  const insert = sql.split('insert into public.lab_analyte_loinc')[1]?.split(';')[0];
  if (!insert) throw new Error('lab_analyte_loinc seed not found in migration');
  const rows: SeededAnalyte[] = [];
  const re = /\(\s*'([a-z0-9_]+)',\s*'((?:[^']|'')*)',\s*'([0-9-]+)',\s*'((?:[^']|'')*)',\s*array\[(.*?)\],\s*'[^']*',\s*'[0-9-]+'\s*\)/g;
  for (const m of insert.matchAll(re)) {
    rows.push({
      analyte_key: m[1],
      display_name: m[2].replace(/''/g, "'"),
      loinc: m[3],
      canonical_unit: m[4].replace(/''/g, "'"),
      aliases: sqlStrings(m[5]),
    });
  }
  return rows;
}
