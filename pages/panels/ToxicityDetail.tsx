import React, { useState, useMemo } from 'react';
import { useNavigate } from 'react-router-dom';
import { 
  ChevronLeft, 
  Sparkles, 
  ArrowUp, 
  Search, 
  AlertTriangle,
  CheckCircle2,
  Activity
} from 'lucide-react';
import { TOXICITY_REPORT } from '../../constants';

export default function ToxicityDetail() {
  const navigate = useNavigate();
  const [activeCategory, setActiveCategory] = useState<string>('All');
  const [searchQuery, setSearchQuery] = useState('');

  const report = TOXICITY_REPORT;
  // TC-030 (19): tolerate a QA/real report with no markers or no score.
  const markers = Array.isArray(report.markers) ? report.markers : [];
  const score = typeof report.panelMetadata?.toxinLoadScore === 'number'
    ? report.panelMetadata.toxinLoadScore
    : 0;

  // Color logic
  let scoreColor = '#10B981'; // emerald
  let scoreClass = 'text-emerald-500';
  if (score > 50) {
    scoreColor = '#F43F5E'; // rose
    scoreClass = 'text-rose-500';
  } else if (score >= 25) {
    scoreColor = '#F59E0B'; // amber
    scoreClass = 'text-amber-500';
  }

  // SVG Gauge logic
  const radius = 60;
  const circumference = 2 * Math.PI * radius;
  const strokeDashoffset = circumference - (score / 100) * circumference;

  const categories = ['All', ...Array.from(new Set(markers.map(m => m.category || 'Other')))];

  const filteredMarkers = useMemo(() => {
    return markers.filter(m => {
      const matchesSearch = (m.name || '').toLowerCase().includes(searchQuery.toLowerCase());
      const matchesCategory = activeCategory === 'All' || m.category === activeCategory;
      return matchesSearch && matchesCategory;
    });
  }, [markers, searchQuery, activeCategory]);

  return (
    <div className="flex flex-col gap-4 md:gap-6 pb-20">
      {/* Header */}
      <div className="flex items-center gap-3">
        <button 
          onClick={() => navigate('/health-vault')}
          className="p-2 hover:bg-stone-100 rounded-full transition-colors"
        >
          <ChevronLeft className="w-6 h-6 text-stone-600" />
        </button>
        <div>
          <h1 className="text-2xl font-serif font-bold text-brand-dark">Toxicity Panel</h1>
          <div className="inline-flex items-center gap-1.5 px-3 py-1 rounded-full bg-stone-100 text-stone-600 text-xs font-medium mt-1">
            <Activity className="w-3 h-3" />
            {report.providerName}
          </div>
        </div>
      </div>

      <div className="grid grid-cols-1 md:grid-cols-3 gap-4 md:gap-6">
        {/* Toxin Load Score */}
        <div className="bg-white rounded-2xl md:rounded-3xl shadow-sm border border-stone-100 p-6 flex flex-col items-center justify-center md:col-span-1">
          <h3 className="font-serif font-bold text-brand-dark mb-6">Toxin Load Score</h3>
          <div className="relative flex items-center justify-center">
            <svg width="160" height="160" className="transform -rotate-90">
              <circle
                cx="80"
                cy="80"
                r={radius}
                fill="none"
                stroke="#F5F5F4"
                strokeWidth="12"
              />
              <circle
                cx="80"
                cy="80"
                r={radius}
                fill="none"
                stroke={scoreColor}
                strokeWidth="12"
                strokeLinecap="round"
                strokeDasharray={circumference}
                strokeDashoffset={strokeDashoffset}
                className="transition-all duration-1000 ease-out"
              />
            </svg>
            <div className="absolute flex flex-col items-center justify-center">
              <span className={`text-4xl font-serif font-bold ${scoreClass}`}>{score}</span>
              <span className="text-xs text-stone-500 font-medium">/ 100</span>
            </div>
          </div>
          <p className="text-sm text-stone-500 mt-6 text-center">
            Lower score indicates fewer detected toxins
          </p>
        </div>

        {/* AI Interpretation */}
        <div className="bg-white rounded-2xl md:rounded-3xl shadow-sm border border-stone-100 p-6 md:col-span-2 flex flex-col">
          <div className="flex items-center gap-2 mb-4">
            <div className="p-2 bg-indigo-50 rounded-lg text-indigo-600">
              <Sparkles className="w-5 h-5" />
            </div>
            <h3 className="font-serif font-bold text-brand-dark">AI Interpretation</h3>
          </div>
          <p className="text-stone-700 text-sm md:text-base leading-relaxed">
            {report.aiInterpretation}
          </p>
        </div>
      </div>

      {/* Detection Matrix */}
      <div className="bg-white rounded-2xl md:rounded-3xl shadow-sm border border-stone-100 p-6">
        <h3 className="font-serif font-bold text-brand-dark mb-4">Detection Matrix</h3>
        {/* TC-030 (19): empty/partial-data state when no toxins were reported. */}
        {markers.length === 0 ? (
          <div className="flex flex-col items-center text-center py-6">
            <div className="p-3 rounded-full bg-stone-100 text-stone-400 mb-4">
              <Activity className="w-7 h-7" />
            </div>
            <h4 className="font-serif font-bold text-brand-dark mb-2">No toxins reported yet</h4>
            <p className="text-sm text-stone-500 max-w-md">
              Your toxicity results aren't available yet. Once your panel is
              processed, detected and cleared toxins will appear here.
            </p>
          </div>
        ) : (
        <div className="grid grid-cols-2 md:grid-cols-3 gap-3 md:gap-4">
          {markers.map((marker, idx) => {
            const isAbnormal = marker.status === 'Abnormal';
            return (
              <div 
                key={idx} 
                className={`bg-stone-50 rounded-xl p-4 flex flex-col gap-2 ${
                  marker.detected && isAbnormal ? 'border-l-4 border-rose-500' : ''
                }`}
              >
                <div className="flex items-start justify-between gap-2">
                  <span className="font-medium text-stone-700 text-sm leading-tight">{marker.name}</span>
                  {marker.detected ? (
                    <span className="shrink-0 inline-flex items-center px-2 py-0.5 rounded text-[10px] font-bold bg-rose-100 text-rose-700 tracking-wider">
                      DETECTED
                    </span>
                  ) : (
                    <span className="shrink-0 inline-flex items-center px-2 py-0.5 rounded text-[10px] font-bold bg-emerald-100 text-emerald-700 tracking-wider">
                      CLEAR
                    </span>
                  )}
                </div>
                {marker.detected && (
                  <div className="flex items-center gap-1 text-stone-700 mt-auto pt-1">
                    <span className="text-lg font-bold">{marker.value}</span>
                    {isAbnormal && <ArrowUp className="w-4 h-4 text-rose-500" />}
                  </div>
                )}
              </div>
            );
          })}
        </div>
        )}
      </div>

      {/* Details Section */}
      <div className="bg-white rounded-2xl md:rounded-3xl shadow-sm border border-stone-100 p-6">
        <div className="flex flex-col md:flex-row md:items-center justify-between gap-4 mb-6">
          <h3 className="font-serif font-bold text-brand-dark">Detailed Analysis</h3>
          
          <div className="relative">
            <Search className="w-4 h-4 text-stone-400 absolute left-3 top-1/2 -translate-y-1/2" />
            <input 
              type="text" 
              placeholder="Search toxins..." 
              value={searchQuery}
              onChange={(e) => setSearchQuery(e.target.value)}
              className="pl-9 pr-4 py-2 bg-stone-50 border border-stone-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-brand-dark/20 w-full md:w-64"
            />
          </div>
        </div>

        {/* Filter Pills */}
        <div className="flex flex-wrap gap-2 mb-6">
          {categories.map((cat) => (
            <button
              key={cat}
              onClick={() => setActiveCategory(cat)}
              className={`px-3 py-1.5 text-xs rounded-full font-medium transition-colors ${
                activeCategory === cat 
                  ? 'bg-brand-dark text-white' 
                  : 'bg-stone-100 text-stone-600 hover:bg-stone-200'
              }`}
            >
              {cat}
            </button>
          ))}
        </div>

        {/* Marker Cards */}
        <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
          {filteredMarkers.map((marker, idx) => (
            <div key={idx} className="bg-stone-50 rounded-xl p-4 hover:bg-stone-100 transition-colors">
              <div className="flex justify-between items-start mb-3">
                <div>
                  <h4 className="font-medium text-stone-800">{marker.name}</h4>
                  <span className="text-xs text-stone-500">{marker.category}</span>
                </div>
                {marker.status === 'Optimal' || marker.status === 'Normal' ? (
                  <span className="inline-flex items-center gap-1.5 px-2.5 py-1 rounded-full text-xs font-medium bg-emerald-100 text-emerald-700">
                    <CheckCircle2 className="w-3.5 h-3.5" />
                    {marker.status === 'Normal' ? 'Normal' : 'Optimal'}
                  </span>
                ) : (
                  <span className="inline-flex items-center gap-1.5 px-2.5 py-1 rounded-full text-xs font-medium bg-rose-100 text-rose-700">
                    <AlertTriangle className="w-3.5 h-3.5" />
                    Abnormal
                  </span>
                )}
              </div>
              
              <div className="flex items-baseline gap-2 mb-3">
                <span className="text-2xl font-bold text-stone-800">{marker.value}</span>
                <span className="text-sm text-stone-500">Ref: {marker.range}</span>
              </div>
              
              {marker.insight && (
                <div className="mt-3 pt-3 border-t border-stone-200">
                  <p className="text-sm text-stone-600">{marker.insight}</p>
                </div>
              )}
            </div>
          ))}
        </div>
        
        {filteredMarkers.length === 0 && (
          <div className="text-center py-8 text-stone-500 text-sm">
            No toxins found matching your criteria.
          </div>
        )}
      </div>
    </div>
  );
}
