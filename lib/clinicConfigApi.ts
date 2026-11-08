import { supabase } from './supabase';
import { num, str } from './clinicalApi';

// POR-05 range sets and PP-01 plan/modules: typed calls to the SECURITY
// DEFINER config RPCs. The server enforces role, aal2, clinic and lifecycle;
// the client only maps payloads (whitelist) and surfaces errors.

export type RangeSetStatus = 'draft' | 'approved' | 'superseded' | 'discarded';
export type RangeSex = 'any' | 'female' | 'male';

export interface RangeSet {
  id: string;
  version: number;
  status: RangeSetStatus;
  note: string | null;
  itemCount: number;
  createdByName: string | null;
  createdAt: string | null;
  approvedByName: string | null;
  approvedAt: string | null;
  closedAt: string | null;
}

export interface RangeItem {
  id: string;
  analyteKey: string;
  analyteLabel: string;
  sex: RangeSex;
  low: number | null;
  high: number | null;
  unit: string;
}

export interface RangeItemInput {
  analyteKey: string;
  analyteLabel: string;
  sex: RangeSex;
  low: number | null;
  high: number | null;
  unit: string;
}

export interface PlanModule {
  moduleKey: string;
  label: string;
  kind: 'core' | 'standard';
  // Seed not yet confirmed against Schedule B of the agreement.
  isPlaceholder: boolean;
}

export interface OrgPlan {
  tier: string;
  standardModules: string[];
  effectiveFrom: string | null;
  maxStandardModules: number;
  catalog: PlanModule[];
}

export interface PlanPeriod {
  id: string;
  tier: string;
  standardModules: string[];
  effectiveFrom: string | null;
  effectiveTo: string | null;
  changedByName: string | null;
  reason: string | null;
}

export interface RangesApi {
  listRangeSets(): Promise<RangeSet[]>;
  fetchRangeItems(setId: string): Promise<RangeItem[]>;
  createDraft(note?: string | null): Promise<string>;
  saveItem(setId: string, item: RangeItemInput): Promise<void>;
  deleteItem(itemId: string): Promise<void>;
  approve(setId: string): Promise<void>;
  discard(setId: string): Promise<void>;
}

export interface PlanApi {
  fetchPlan(): Promise<OrgPlan>;
  fetchHistory(): Promise<PlanPeriod[]>;
  setPlan(tier: string, standardModules: string[], reason?: string | null): Promise<void>;
}

type Raw = Record<string, unknown>;
const arr = (v: unknown): Raw[] => (Array.isArray(v) ? (v as Raw[]) : []);
const strArr = (v: unknown): string[] => (Array.isArray(v) ? v.filter((x): x is string => typeof x === 'string') : []);

function asSetStatus(v: unknown): RangeSetStatus {
  return v === 'approved' || v === 'superseded' || v === 'discarded' ? v : 'draft';
}

function asSex(v: unknown): RangeSex {
  return v === 'female' || v === 'male' ? v : 'any';
}

export function mapRangeSet(r: Raw): RangeSet {
  return {
    id: String(r.id),
    version: num(r.version) ?? 0,
    status: asSetStatus(r.status),
    note: str(r.note),
    itemCount: num(r.item_count) ?? 0,
    createdByName: str(r.created_by_name),
    createdAt: str(r.created_at),
    approvedByName: str(r.approved_by_name),
    approvedAt: str(r.approved_at),
    closedAt: str(r.closed_at),
  };
}

export function mapRangeItem(r: Raw): RangeItem {
  return {
    id: String(r.id),
    analyteKey: String(r.analyte_key ?? ''),
    analyteLabel: String(r.analyte_label ?? r.analyte_key ?? ''),
    sex: asSex(r.sex),
    low: num(r.low),
    high: num(r.high),
    unit: String(r.unit ?? ''),
  };
}

export function mapPlan(v: unknown): OrgPlan {
  const d = (v && typeof v === 'object' ? v : {}) as Raw;
  return {
    tier: String(d.tier ?? 'core'),
    standardModules: strArr(d.standard_modules),
    effectiveFrom: str(d.effective_from),
    maxStandardModules: num(d.max_standard_modules) ?? 2,
    catalog: arr(d.catalog).map((m) => ({
      moduleKey: String(m.module_key ?? ''),
      label: String(m.label ?? m.module_key ?? ''),
      kind: m.kind === 'core' ? 'core' : 'standard',
      // Fail towards "placeholder": only an explicit false clears the label.
      isPlaceholder: m.is_placeholder !== false,
    })),
  };
}

export function mapPlanPeriod(r: Raw): PlanPeriod {
  return {
    id: String(r.id),
    tier: String(r.tier ?? ''),
    standardModules: strArr(r.standard_modules),
    effectiveFrom: str(r.effective_from),
    effectiveTo: str(r.effective_to),
    changedByName: str(r.changed_by_name),
    reason: str(r.reason),
  };
}

async function call<T = unknown>(fn: string, args?: Record<string, unknown>): Promise<T> {
  const { data, error } = await supabase.rpc(fn, args);
  if (error) throw error;
  return data as T;
}

export const supabaseRangesApi: RangesApi = {
  listRangeSets: async () => arr(await call('list_range_sets')).map(mapRangeSet),
  fetchRangeItems: async (setId) => arr(await call('get_range_set_items', { p_set_id: setId })).map(mapRangeItem),
  createDraft: async (note) => String(await call('create_range_set_draft', { p_note: note ?? null })),
  saveItem: async (setId, item) => {
    await call('upsert_range_set_item', {
      p_set_id: setId,
      p_analyte_key: item.analyteKey,
      p_analyte_label: item.analyteLabel,
      p_sex: item.sex,
      p_low: item.low,
      p_high: item.high,
      p_unit: item.unit,
    });
  },
  deleteItem: async (itemId) => {
    await call('delete_range_set_item', { p_item_id: itemId });
  },
  approve: async (setId) => {
    await call('approve_range_set', { p_set_id: setId });
  },
  discard: async (setId) => {
    await call('discard_range_set_draft', { p_set_id: setId });
  },
};

export const supabasePlanApi: PlanApi = {
  fetchPlan: async () => mapPlan(await call('get_org_plan')),
  fetchHistory: async () => arr(await call('list_org_plan_history')).map(mapPlanPeriod),
  setPlan: async (tier, standardModules, reason) => {
    await call('set_org_plan', { p_tier: tier, p_standard_modules: standardModules, p_reason: reason ?? null });
  },
};
