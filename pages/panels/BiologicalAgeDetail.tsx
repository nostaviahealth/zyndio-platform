import React, { useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { 
  ChevronLeft, Activity, Info, Clock, 
  Shield, Zap, Flame, Target, TrendingDown 
} from 'lucide-react';
import { METHYLATION_REPORT } from '../../constants';

const BiologicalAgeDetail = () => {
  const navigate = useNavigate();
  const [activeCategory, setActiveCategory] = useState<string>('All');
  
  const report = METHYLATION_REPORT;

  // TC-030 (19): a real/QA panel may be missing some of these fields (the
  // epigenetic data isn't in yet), so every value read must be null-safe -
  // reading `.toFixed()` off an undefined metric used to crash the page.
  // `chronoAge`/`bioAge`/`paceOfAging` map onto the PanelMetadata schema
  // (chronologicalAge / biologicalAge / paceOfAging). Clock scores carry a
  // `value` in the schema; keep `age` as a fallback for older fixtures.
  const metadata: any = report.panelMetadata || {};
  const chronoAge: number | undefined = metadata.chronologicalAge ?? metadata.chronoAge;
  const bioAge: number | undefined = metadata.biologicalAge ?? metadata.bioAge;
  const paceOfAging: number | undefined = metadata.paceOfAging;
  const clockScores: any[] = Array.isArray(metadata.clockScores) ? metadata.clockScores : [];
  const systemAges: any[] = Array.isArray(metadata.systemAges) ? metadata.systemAges : [];

  // The page is meaningless without at least a biological age to anchor it.
  const hasCoreMetrics = typeof bioAge === 'number';

  const ageDiff =
    typeof bioAge === 'number' && typeof chronoAge === 'number' ? bioAge - chronoAge : null;
  const diffAbs = ageDiff !== null ? Math.abs(ageDiff).toFixed(1) : null;
  const diffLabel =
    ageDiff === null
      ? null
      : ageDiff <= 0
        ? `-${diffAbs} years younger`
        : `+${diffAbs} years older`;
  const diffColor = ageDiff !== null && ageDiff <= 0 ? 'text-emerald-500' : 'text-red-500';

  // Calculate pace progress (0.5 to 1.5 range)
  const pacePercentage =
    typeof paceOfAging === 'number' ? ((paceOfAging - 0.5) / (1.5 - 0.5)) * 100 : 0;
  let paceColor = 'bg-cyan-500';
  if (typeof paceOfAging === 'number' && paceOfAging >= 1.0 && paceOfAging <= 1.2) paceColor = 'bg-amber-500';
  if (typeof paceOfAging === 'number' && paceOfAging > 1.2) paceColor = 'bg-red-500';

  // SVG Gauge calculations
  const radius = 90;
  const circumference = 2 * Math.PI * radius;
  const arcLength = 0.75 * circumference;
  const gaugeFill =
    hasCoreMetrics && typeof chronoAge === 'number'
      ? Math.min((bioAge as number) / Math.max(chronoAge, 1), 1.5)
      : 0;

  // For other markers, filter from report.markers
  const categories = ['All', ...Array.from(new Set((report.markers || []).map((m: any) => m.category)))];

  const filteredMarkers = activeCategory === 'All'
    ? report.markers
    : report.markers?.filter((m: any) => m.category === activeCategory);

  return (
    <div className="min-h-screen bg-stone-50 pb-20">
      {/* Header */}
      <div className="bg-white px-4 pt-12 pb-4 shadow-sm border-b border-stone-100 sticky top-0 z-10">
        <div className="flex items-center justify-between mb-4">
          <button 
            onClick={() => navigate('/health-vault')}
            className="p-2 -ml-2 rounded-xl hover:bg-stone-50 text-stone-700 transition-colors"
          >
            <ChevronLeft size={24} />
          </button>
          <div className="flex items-center gap-2">
            <span className="text-xs font-medium px-2.5 py-1 bg-stone-100 text-stone-600 rounded-full">
              {report.providerName || 'TruDiagnostic'}
            </span>
          </div>
          <div className="w-10"></div> {/* spacer */}
        </div>
        <h1 className="font-serif font-bold text-2xl text-brand-dark">
          Biological Age
        </h1>
        <p className="text-sm text-stone-500 mt-1">{report.date || 'Recent'}</p>
      </div>

      <div className="p-4 flex flex-col gap-6 max-w-2xl mx-auto">

        {/* TC-030 (19): empty/partial-data state when epigenetic metrics
            haven't been reported yet, instead of crashing on undefined reads. */}
        {!hasCoreMetrics && (
          <div className="bg-white rounded-3xl p-8 shadow-sm border border-stone-100 flex flex-col items-center text-center">
            <div className="p-3 rounded-full bg-stone-100 text-stone-400 mb-4">
              <Clock size={28} />
            </div>
            <h2 className="font-serif font-bold text-xl text-brand-dark mb-2">
              Biological age pending
            </h2>
            <p className="text-sm text-stone-500 max-w-md">
              Your epigenetic results aren't available yet. Once your methylation
              panel is processed, your biological age and aging pace will appear here.
            </p>
          </div>
        )}

        {/* Hero Bio Age Gauge */}
        {hasCoreMetrics && (
        <div className="bg-white rounded-3xl p-6 shadow-sm border border-stone-100 flex flex-col items-center">
          <div className="relative w-64 h-64 flex items-center justify-center mb-2">
            {/* SVG Gauge */}
            <svg className="w-full h-full transform -rotate-90" viewBox="0 0 200 200">
              {/* Background Arc */}
              <circle
                cx="100" cy="100" r="90"
                fill="none"
                stroke="#f5f5f4"
                strokeWidth="12"
                strokeLinecap="round"
                strokeDasharray={`${arcLength} ${circumference}`}
                className="transform rotate-[135deg] origin-center"
              />
              {/* Foreground Arc */}
              <circle
                cx="100" cy="100" r="90"
                fill="none"
                stroke="#06B6D4"
                strokeWidth="12"
                strokeLinecap="round"
                strokeDasharray={`${arcLength} ${circumference}`}
                strokeDashoffset={circumference - (arcLength * gaugeFill)}
                className="transform rotate-[135deg] origin-center transition-all duration-1000 ease-out"
              />
            </svg>

            {/* Center Text */}
            <div className="absolute flex flex-col items-center justify-center text-center">
              <span className="text-6xl font-serif font-bold text-brand-dark tracking-tighter">
                {(bioAge as number).toFixed(1)}
              </span>
              <span className="text-sm text-stone-500 font-medium uppercase tracking-wider mt-1">
                years
              </span>
            </div>
          </div>

          <div className="text-center mt-2">
            {typeof chronoAge === 'number' && (
              <p className="text-stone-500 mb-1 text-sm">vs Chronological Age {chronoAge}</p>
            )}
            {diffLabel && (
              <p className={`font-semibold text-lg ${diffColor}`}>
                {diffLabel}
              </p>
            )}
          </div>
        </div>
        )}

        {/* DunedinPACE Card */}
        {typeof paceOfAging === 'number' && (
        <div className="bg-white rounded-3xl p-6 shadow-sm border border-stone-100">
          <div className="flex justify-between items-start mb-6">
            <div>
              <h3 className="font-serif font-bold text-brand-dark text-xl flex items-center gap-2">
                Pace of Aging <Info size={16} className="text-stone-400" />
              </h3>
              <p className="text-sm text-stone-500 mt-1">DunedinPACE rate</p>
            </div>
            <div className="bg-emerald-100 text-emerald-700 px-3 py-1.5 rounded-full text-xs font-semibold flex items-center gap-1">
              <TrendingDown size={14} />
              Top 22% for age cohort
            </div>
          </div>

          <div className="flex flex-col items-center mb-6">
            <span className="text-5xl font-bold text-brand-dark mb-2">
              {paceOfAging.toFixed(2)}
            </span>
            <span className="text-stone-600 font-medium bg-stone-100 px-3 py-1 rounded-full text-sm">
              Aging at {Math.round(paceOfAging * 100)}% of normal speed
            </span>
          </div>

          <div className="relative h-4 bg-stone-100 rounded-full w-full overflow-hidden">
            {/* Dashed line at 1.0 (which is 50% on 0.5-1.5 scale) */}
            <div className="absolute top-0 bottom-0 left-1/2 w-0.5 border-l-2 border-dashed border-stone-400 z-10" />

            {/* Progress bar */}
            <div
              className={`h-full ${paceColor} rounded-full`}
              style={{ width: `${Math.max(0, Math.min(100, pacePercentage))}%` }}
            />
          </div>
          <div className="flex justify-between text-xs text-stone-400 mt-2 font-medium">
            <span>0.5</span>
            <span>1.0 (Normal)</span>
            <span>1.5</span>
          </div>
        </div>
        )}

        {/* Epigenetic Clock Comparison */}
        {clockScores.length > 0 && (
        <div className="bg-white rounded-3xl p-6 shadow-sm border border-stone-100">
          <h3 className="font-serif font-bold text-brand-dark text-xl mb-6">
            Epigenetic Clocks
          </h3>

          <div className="space-y-5">
            {clockScores.map((clock: any, idx: number) => {
              // Schema uses `value`; keep `age` as a fallback for older fixtures.
              const clockAge = clock.value ?? clock.age;
              const fillPct =
                typeof clockAge === 'number' && typeof chronoAge === 'number'
                  ? (clockAge / Math.max(chronoAge, 1)) * 60
                  : 0;
              return (
              <div key={idx} className="relative">
                <div className="flex justify-between text-sm mb-2">
                  <span className="font-medium text-stone-700">{clock.name}</span>
                  <span className="font-bold text-brand-dark">
                    {typeof clockAge === 'number' ? `${clockAge} yrs` : '—'}
                  </span>
                </div>
                <div className="h-2.5 bg-stone-100 rounded-full w-full relative">
                  {/* Background Reference line for chrono age */}
                  <div
                    className="absolute top-[-4px] bottom-[-4px] w-0.5 border-l border-dashed border-stone-400 z-10"
                    style={{ left: '60%' }} // arbitrary visual scale where chronoAge is at 60%
                  />

                  {/* Fill */}
                  <div
                    className="absolute top-0 bottom-0 left-0 bg-cyan-500 rounded-full"
                    style={{ width: `${fillPct}%` }}
                  />
                </div>
              </div>
              );
            })}
            {typeof chronoAge === 'number' && (
              <div className="flex justify-center mt-4">
                <div className="flex items-center gap-2 text-xs text-stone-500">
                  <div className="w-4 border-t border-dashed border-stone-400" />
                  <span>Chronological Age ({chronoAge})</span>
                </div>
              </div>
            )}
          </div>
        </div>
        )}

        {/* System Ages Grid */}
        {systemAges.length > 0 && (
        <div className="grid grid-cols-3 gap-3 md:gap-4">
          {systemAges.map((sys: any, idx: number) => {
            const sysAge = sys.value ?? sys.age;
            const isOptimal =
              typeof sysAge === 'number' && typeof chronoAge === 'number' && sysAge < chronoAge;
            const statusBg = isOptimal ? 'bg-emerald-100' : 'bg-red-100';
            const statusText = isOptimal ? 'text-emerald-700' : 'text-red-700';

            let Icon = Activity;
            if ((sys.name || '').includes('Immune')) Icon = Shield;
            else if ((sys.name || '').includes('Metabolic')) Icon = Zap;
            else if ((sys.name || '').includes('Inflammation')) Icon = Flame;

            return (
              <div key={idx} className="bg-white rounded-2xl p-4 shadow-sm border border-stone-100 flex flex-col items-center text-center">
                <div className={`p-2 rounded-full mb-3 ${statusBg} ${statusText}`}>
                  <Icon size={20} />
                </div>
                <span className="text-xl font-bold text-brand-dark mb-1">
                  {typeof sysAge === 'number' ? sysAge : '—'}
                </span>
                <span className="text-xs font-medium text-stone-500 leading-tight">{sys.name}</span>
              </div>
            );
          })}
        </div>
        )}

        {/* Additional Markers */}
        {filteredMarkers && filteredMarkers.length > 0 && (
          <div className="mt-4">
            <div className="flex items-center justify-between mb-4">
              <h3 className="font-serif font-bold text-brand-dark text-xl">
                All Markers
              </h3>
            </div>
            
            {categories.length > 1 && (
              <div className="flex gap-2 overflow-x-auto pb-4 scrollbar-hide">
                {categories.map((cat: string, idx: number) => (
                  <button
                    key={idx}
                    onClick={() => setActiveCategory(cat)}
                    className={`px-3 py-1.5 text-xs rounded-full font-medium whitespace-nowrap transition-colors ${
                      activeCategory === cat 
                        ? 'bg-brand-dark text-white' 
                        : 'bg-white text-stone-600 border border-stone-200'
                    }`}
                  >
                    {cat}
                  </button>
                ))}
              </div>
            )}

            <div className="space-y-3">
              {filteredMarkers.map((marker: any, idx: number) => (
                <div key={idx} className="bg-white rounded-2xl p-4 shadow-sm border border-stone-100 hover:border-stone-200 transition-all">
                  <div className="flex justify-between items-start mb-2">
                    <div>
                      <h4 className="font-medium text-stone-800">{marker.name}</h4>
                      <span className="text-xs text-stone-500">{marker.category}</span>
                    </div>
                    <span className={`inline-flex items-center px-2 py-1 rounded-full text-[10px] font-bold uppercase tracking-wider ${
                      marker.status === 'Optimal' ? 'bg-emerald-100 text-emerald-700' :
                      marker.status === 'Normal' ? 'bg-blue-100 text-blue-700' :
                      'bg-red-100 text-red-700'
                    }`}>
                      {marker.status}
                    </span>
                  </div>
                  
                  <div className="flex items-end gap-2 mt-3">
                    <span className="text-2xl font-bold text-brand-dark">{marker.value}</span>
                    <span className="text-sm text-stone-500 mb-1">{marker.unit}</span>
                  </div>
                  <div className="text-xs text-stone-400 mt-1">
                    Reference: {marker.referenceRange}
                  </div>
                </div>
              ))}
            </div>
          </div>
        )}
      </div>
    </div>
  );
};

export default BiologicalAgeDetail;
