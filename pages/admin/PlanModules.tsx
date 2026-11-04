import React, { useCallback, useEffect, useState } from 'react';
import { Check, Info } from 'lucide-react';
import PageHeader from '../../components/ui/PageHeader';
import Button from '../../components/admin-auth/Button';
import TextInput from '../../components/ui/TextInput';
import CriticalBanner from '../../components/ui/CriticalBanner';
import { OrgPlan, PlanApi, PlanPeriod, supabasePlanApi } from '../../lib/clinicConfigApi';
import { formatMonthDayYear } from '../../lib/clinicalFormat';

// PP-01: the clinic's tier and modules (org admin only). Core = five core
// modules (always on) + up to two standard modules the clinic picks. Each
// saved change closes the current billing period and opens a new one; the
// history below is what invoices pro-rate from. (The /__preview admin shell
// carries the FICTIONAL DATA tag for this page.)

const CARD = 'rounded-2xl border border-slate-200 bg-white p-6 dark:border-[#222838] dark:bg-[#10141F]';
const TIER_LABELS: Record<string, string> = { core: 'Core' };

const PlaceholderTag: React.FC = () => (
  <span className="ml-2 inline-flex items-center rounded border border-dashed border-slate-400 px-1.5 py-0.5 text-[10px] font-medium uppercase tracking-wide text-slate-500 dark:border-[#6C7690] dark:text-[#A6B0C3]">
    Placeholder
  </span>
);

export interface PlanModulesProps {
  api?: PlanApi;
}

const PlanModules: React.FC<PlanModulesProps> = ({ api = supabasePlanApi }) => {
  const [plan, setPlan] = useState<OrgPlan | null>(null);
  const [history, setHistory] = useState<PlanPeriod[] | null>(null);
  const [chosen, setChosen] = useState<string[]>([]);
  const [reason, setReason] = useState('');
  const [error, setError] = useState<string | null>(null);
  const [saved, setSaved] = useState(false);
  const [busy, setBusy] = useState(false);

  const load = useCallback(async () => {
    setError(null);
    try {
      const [p, h] = await Promise.all([api.fetchPlan(), api.fetchHistory()]);
      setPlan(p);
      setHistory(h);
      setChosen([...p.standardModules].sort());
    } catch {
      setError("We couldn't load your clinic's plan. Check your connection and try again.");
    }
  }, [api]);

  useEffect(() => {
    load();
  }, [load]);

  if (!plan) {
    return (
      <div className="relative">
        <PageHeader title="Plan and modules" />
        {error ? (
          <div className="mt-6">
            <CriticalBanner>{error}</CriticalBanner>
          </div>
        ) : (
          <p className="mt-6 text-sm text-[#48556A] dark:text-[#A6B0C3]" role="status">
            Loading…
          </p>
        )}
      </div>
    );
  }

  const core = plan.catalog.filter((m) => m.kind === 'core');
  const standard = plan.catalog.filter((m) => m.kind === 'standard');
  const max = plan.maxStandardModules;
  const current = [...plan.standardModules].sort();
  const dirty = chosen.join(',') !== current.join(',');
  const anyPlaceholder = plan.catalog.some((m) => m.isPlaceholder);
  const labelOf = (key: string) => plan.catalog.find((m) => m.moduleKey === key)?.label ?? key;

  const toggle = (key: string) => {
    setSaved(false);
    setChosen((c) => (c.includes(key) ? c.filter((k) => k !== key) : c.length >= max ? c : [...c, key].sort()));
  };

  const save = async () => {
    setBusy(true);
    setError(null);
    setSaved(false);
    try {
      await api.setPlan(plan.tier, chosen, reason.trim() || null);
      setReason('');
      await load();
      setSaved(true);
    } catch {
      setError("We couldn't save the plan. Nothing changed. Try again.");
    } finally {
      setBusy(false);
    }
  };

  return (
    <div className="relative">
      <PageHeader
        title="Plan and modules"
        description="Your clinic's tier and the modules it uses. Each change starts a new billing period, so invoices can be pro-rated."
      />

      {anyPlaceholder && (
        <div className="mt-6 flex gap-3 rounded-xl border border-slate-200 bg-[#F8FAFF] p-4 dark:border-[#222838] dark:bg-[#0B0F19]">
          <Info className="mt-0.5 h-5 w-5 shrink-0 text-slate-400 dark:text-[#8F9AAF]" aria-hidden="true" />
          <p className="text-[13px] text-[#48556A] dark:text-[#A6B0C3]">
            Modules marked Placeholder are working names until the module schedule in the agreement is confirmed. They
            are not contractual.
          </p>
        </div>
      )}

      {error && (
        <div className="mt-6">
          <CriticalBanner>{error}</CriticalBanner>
        </div>
      )}
      {saved && (
        <p role="status" className="mt-6 text-sm font-semibold text-[#2C5CF2] dark:text-[#7C9CFF]">
          Plan saved. A new billing period started now.
        </p>
      )}

      <div className="mt-6 grid gap-6 xl:grid-cols-2">
        <section className={CARD} aria-labelledby="plan-core">
          <h2 id="plan-core" className="text-xl font-bold text-[#030616] dark:text-[#EEF1F8]">
            {TIER_LABELS[plan.tier] ?? plan.tier} tier
          </h2>
          <p className="mt-1 text-sm text-[#48556A] dark:text-[#A6B0C3]">
            Includes these {core.length} core modules, plus up to {max} standard modules of your choice.
            {plan.effectiveFrom ? ` Current period started ${formatMonthDayYear(plan.effectiveFrom)}.` : ''}
          </p>
          <ul className="mt-4 space-y-2">
            {core.map((m) => (
              <li key={m.moduleKey} className="flex items-center gap-2 text-sm text-[#030616] dark:text-[#EEF1F8]">
                <Check className="h-4 w-4 text-[#2C5CF2] dark:text-[#7C9CFF]" aria-hidden="true" />
                {m.label}
                {m.isPlaceholder && <PlaceholderTag />}
              </li>
            ))}
          </ul>
        </section>

        <section className={CARD} aria-labelledby="plan-standard">
          <h2 id="plan-standard" className="text-xl font-bold text-[#030616] dark:text-[#EEF1F8]">
            Standard modules
          </h2>
          <p className="mt-1 text-sm text-[#48556A] dark:text-[#A6B0C3]" id="plan-standard-hint">
            Choose up to {max}. {chosen.length} of {max} chosen.
          </p>
          <fieldset className="mt-4 space-y-1" aria-describedby="plan-standard-hint">
            <legend className="sr-only">Standard modules</legend>
            {standard.map((m) => {
              const checked = chosen.includes(m.moduleKey);
              const disabled = !checked && chosen.length >= max;
              return (
                <label
                  key={m.moduleKey}
                  className={`flex min-h-[44px] items-center gap-3 rounded-lg px-2 text-sm ${
                    disabled ? 'cursor-not-allowed text-slate-400 dark:text-[#6C7690]' : 'text-[#030616] dark:text-[#EEF1F8]'
                  }`}
                >
                  <input
                    type="checkbox"
                    checked={checked}
                    disabled={disabled}
                    onChange={() => toggle(m.moduleKey)}
                    className="h-4 w-4 accent-[#2C5CF2]"
                  />
                  {m.label}
                  {m.isPlaceholder && <PlaceholderTag />}
                </label>
              );
            })}
          </fieldset>
          <label className="mt-4 block text-[13px] font-semibold text-[#48556A] dark:text-[#A6B0C3]">
            Reason for the change (optional, kept with the billing history)
            <TextInput value={reason} maxLength={300} onChange={(e) => setReason(e.target.value)} className="mt-1" />
          </label>
          <Button type="button" className="mt-4" onClick={save} disabled={!dirty} busy={busy} busyLabel="Saving…">
            Save plan
          </Button>
        </section>
      </div>

      <section className={`mt-6 ${CARD}`} aria-labelledby="plan-history">
        <h2 id="plan-history" className="text-xl font-bold text-[#030616] dark:text-[#EEF1F8]">
          Billing history
        </h2>
        {history && history.length > 0 ? (
          <table className="mt-4 w-full text-sm">
            <thead>
              <tr className="border-b border-slate-200 text-left text-[13px] text-slate-500 dark:border-[#222838] dark:text-[#8F9AAF]">
                <th className="py-2 pr-4 font-semibold">From</th>
                <th className="py-2 pr-4 font-semibold">To</th>
                <th className="py-2 pr-4 font-semibold">Tier</th>
                <th className="py-2 pr-4 font-semibold">Standard modules</th>
                <th className="py-2 pr-4 font-semibold">Changed by</th>
                <th className="py-2 font-semibold">Reason</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-slate-100 dark:divide-[#222838]">
              {history.map((h) => (
                <tr key={h.id} className="text-[#030616] dark:text-[#EEF1F8]">
                  <td className="py-2 pr-4 tabular-nums">{formatMonthDayYear(h.effectiveFrom)}</td>
                  <td className="py-2 pr-4 tabular-nums">{h.effectiveTo ? formatMonthDayYear(h.effectiveTo) : 'Current'}</td>
                  <td className="py-2 pr-4">{TIER_LABELS[h.tier] ?? h.tier}</td>
                  <td className="py-2 pr-4">{h.standardModules.length ? h.standardModules.map(labelOf).join(', ') : 'None'}</td>
                  <td className="py-2 pr-4">{h.changedByName ?? '—'}</td>
                  <td className="py-2">{h.reason ?? ''}</td>
                </tr>
              ))}
            </tbody>
          </table>
        ) : (
          <p className="mt-2 text-sm text-[#48556A] dark:text-[#A6B0C3]">No billing periods yet.</p>
        )}
      </section>
    </div>
  );
};

export default PlanModules;
