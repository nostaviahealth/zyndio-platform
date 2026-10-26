import React, { useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { ChevronLeft, Sparkles, Activity, CheckCircle, AlertCircle } from 'lucide-react';
import { GENETIC_PANEL_REPORT } from '../../constants';

export default function GeneticPanelDetail() {
  const navigate = useNavigate();
  const [selectedCategory, setSelectedCategory] = useState<string>('All');

  // Derive categories dynamically from markers, adding 'All'
  const categories = ['All', ...Array.from(new Set(GENETIC_PANEL_REPORT.markers.map(m => m.category)))];

  const filteredMarkers = selectedCategory === 'All' 
    ? GENETIC_PANEL_REPORT.markers 
    : GENETIC_PANEL_REPORT.markers.filter(m => m.category === selectedCategory);

  const optimalCount = GENETIC_PANEL_REPORT.markers.filter(m => m.status === 'Optimal').length;
  const normalCount = GENETIC_PANEL_REPORT.markers.filter(m => m.status === 'Normal').length;
  const riskCount = GENETIC_PANEL_REPORT.markers.filter(m => m.status === 'Abnormal').length;

  const getRiskColor = (riskLevel?: string) => {
    switch (riskLevel?.toLowerCase()) {
      case 'low': return 'bg-emerald-100 text-emerald-700';
      case 'high': return 'bg-red-100 text-red-700';
      case 'moderate': return 'bg-amber-100 text-amber-700';
      default: return 'bg-stone-100 text-stone-700';
    }
  };

  return (
    <div className="min-h-screen bg-stone-50 pb-20 md:pb-8">
      <div className="max-w-4xl mx-auto px-4 pt-6 md:pt-8 flex flex-col gap-4 md:gap-6">
        
        {/* Header */}
        <div className="flex flex-col gap-4">
          <button 
            onClick={() => navigate('/health-vault')}
            className="flex items-center gap-2 text-stone-500 hover:text-stone-700 transition-colors w-fit"
          >
            <ChevronLeft className="w-5 h-5" />
            <span>Back to Health Vault</span>
          </button>
          
          <div className="flex flex-col md:flex-row md:items-center justify-between gap-4">
            <div>
              <h1 className="text-2xl md:text-3xl font-serif font-bold text-brand-dark mb-2">Genetic Panel</h1>
              <span className="inline-flex items-center gap-1.5 px-3 py-1.5 rounded-full text-xs font-medium bg-stone-200 text-stone-700">
                {GENETIC_PANEL_REPORT.providerName}
              </span>
            </div>
            <div className="bg-indigo-50 border border-indigo-100 px-4 py-2.5 rounded-xl flex items-center gap-2 shadow-sm">
              <span className="text-sm font-medium text-indigo-700">🧬 One-Time Upload — Results Never Change</span>
            </div>
          </div>
        </div>

        {/* AI Interpretation */}
        <div className="bg-white rounded-2xl md:rounded-3xl shadow-sm border border-stone-100 p-4 md:p-6 flex flex-col gap-3">
          <div className="flex items-center gap-2 text-brand-dark">
            <Sparkles className="w-5 h-5 text-indigo-500" />
            <h2 className="font-serif font-bold text-lg">AI Interpretation</h2>
          </div>
          <p className="text-sm md:text-base text-stone-700 leading-relaxed">
            {GENETIC_PANEL_REPORT.aiInterpretation}
          </p>
        </div>

        {/* Summary Stats */}
        <div className="grid grid-cols-3 gap-3 md:gap-4">
          <div className="bg-white rounded-2xl shadow-sm border border-stone-100 p-4 flex flex-col items-center justify-center gap-1">
            <CheckCircle className="w-6 h-6 text-emerald-500 mb-1" />
            <span className="text-2xl font-bold text-emerald-700">{optimalCount}</span>
            <span className="text-xs md:text-sm text-stone-500 font-medium">Optimal</span>
          </div>
          <div className="bg-white rounded-2xl shadow-sm border border-stone-100 p-4 flex flex-col items-center justify-center gap-1">
            <Activity className="w-6 h-6 text-blue-500 mb-1" />
            <span className="text-2xl font-bold text-blue-700">{normalCount}</span>
            <span className="text-xs md:text-sm text-stone-500 font-medium">Normal</span>
          </div>
          <div className="bg-white rounded-2xl shadow-sm border border-stone-100 p-4 flex flex-col items-center justify-center gap-1">
            <AlertCircle className="w-6 h-6 text-red-500 mb-1" />
            <span className="text-2xl font-bold text-red-700">{riskCount}</span>
            <span className="text-xs md:text-sm text-stone-500 font-medium">Risk Variants</span>
          </div>
        </div>

        {/* Categories */}
        <div className="flex overflow-x-auto pb-2 -mx-4 px-4 md:mx-0 md:px-0 gap-2 hide-scrollbar">
          {categories.map((cat) => (
            <button
              key={cat}
              onClick={() => setSelectedCategory(cat)}
              className={`whitespace-nowrap px-3 py-1.5 md:px-4 md:py-2 text-xs md:text-sm rounded-full font-medium transition-colors ${
                selectedCategory === cat 
                  ? 'bg-brand-dark text-white shadow-sm' 
                  : 'bg-white text-stone-600 border border-stone-200 hover:bg-stone-50'
              }`}
            >
              {cat}
            </button>
          ))}
        </div>

        {/* Gene Variant Cards */}
        <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
          {filteredMarkers.map((marker, index) => (
            <div key={index} className="bg-white rounded-2xl md:rounded-3xl shadow-sm border border-stone-100 p-4 md:p-6 flex flex-col gap-4">
              <div className="flex items-start justify-between gap-4">
                <div className="flex flex-col gap-1">
                  <h3 className="font-serif font-bold text-lg md:text-xl text-brand-dark">{marker.name}</h3>
                  <span className="text-xs text-stone-500">Ref: {marker.range}</span>
                </div>
                <span className={`inline-flex items-center justify-center px-3 py-1.5 rounded-full text-sm font-bold ${getRiskColor(marker.riskLevel)}`}>
                  {marker.genotype || marker.value}
                </span>
              </div>
              
              <div className="bg-stone-50 rounded-xl p-3 md:p-4 mt-auto">
                <p className="text-sm text-stone-700">
                  {marker.insight}
                </p>
              </div>
              
              <div className="flex mt-1">
                <span className="inline-flex px-2 py-1 bg-stone-100 text-stone-600 text-[10px] uppercase tracking-wider font-semibold rounded-md">
                  {marker.category}
                </span>
              </div>
            </div>
          ))}
        </div>
      </div>
    </div>
  );
}
