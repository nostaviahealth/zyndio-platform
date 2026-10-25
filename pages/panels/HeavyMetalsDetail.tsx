import React, { useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { ChevronLeft, Info, Sparkles, Activity, AlertCircle, CheckCircle } from 'lucide-react';
import { HEAVY_METALS_REPORT } from '../../constants';

export default function HeavyMetalsDetail() {
  const navigate = useNavigate();
  const [activeCategory, setActiveCategory] = useState<string>('All');
  
  const report = HEAVY_METALS_REPORT;
  const categories = ['All', ...Array.from(new Set(report.markers.map(m => m.category).filter(Boolean)))];
  
  const filteredMarkers = activeCategory === 'All' 
    ? report.markers 
    : report.markers.filter(m => m.category === activeCategory);

  const stats = {
    optimal: report.markers.filter(m => m.status === 'Optimal').length,
    normal: report.markers.filter(m => m.status === 'Normal').length,
    abnormal: report.markers.filter(m => m.status === 'Abnormal').length,
  };

  const parseValue = (str: string) => {
    const match = str.match(/[\d.]+/);
    return match ? parseFloat(match[0]) : 0;
  };
  
  const extractUnit = (str: string) => {
    return str.replace(/[<>\d.\s]/g, '');
  };

  const getStatusColor = (status: string) => {
    if (status === 'Optimal') return 'bg-emerald-100 text-emerald-700';
    if (status === 'Normal') return 'bg-blue-100 text-blue-700';
    return 'bg-red-100 text-red-700';
  };

  const getStatusIcon = (status: string) => {
    if (status === 'Optimal') return <CheckCircle className="w-3.5 h-3.5" />;
    if (status === 'Normal') return <Activity className="w-3.5 h-3.5" />;
    return <AlertCircle className="w-3.5 h-3.5" />;
  };

  return (
    <div className="min-h-screen bg-stone-50 pb-20">
      <div className="bg-white border-b border-stone-100 sticky top-0 z-10 px-4 py-4 md:px-8 flex items-center justify-between">
        <div className="flex items-center gap-3">
          <button 
            onClick={() => navigate('/health-vault')}
            className="p-2 hover:bg-stone-50 rounded-full transition-colors"
          >
            <ChevronLeft className="w-6 h-6 text-brand-dark" />
          </button>
          <div>
            <h1 className="font-serif font-bold text-xl text-brand-dark">Heavy Metals</h1>
            <p className="text-sm text-stone-500">{report.date}</p>
          </div>
        </div>
        <div className="px-3 py-1 bg-stone-100 rounded-full text-xs font-medium text-stone-600">
          {report.providerName}
        </div>
      </div>

      <div className="p-4 md:p-8 max-w-4xl mx-auto flex flex-col gap-4 md:gap-6">
        
        {/* Specimen Info Banner */}
        <div className="bg-amber-50 rounded-2xl md:rounded-3xl p-4 md:p-5 border border-amber-100 flex items-start gap-3">
          <Info className="w-5 h-5 text-amber-600 flex-shrink-0 mt-0.5" />
          <div>
            <div className="flex flex-wrap items-center gap-x-4 gap-y-2 mb-1">
              <div className="text-amber-900">
                <span className="font-medium">Specimen Type:</span>{' '}
                <span className="capitalize">{report.panelMetadata?.specimenType?.replace('_', ' ')}</span>
              </div>
              <div className="text-amber-900">
                <span className="font-medium">Provocation Agent:</span>{' '}
                {report.panelMetadata?.provocationAgent}
              </div>
            </div>
            <p className="text-sm text-amber-700 mt-2 opacity-90">
              Reference ranges are specimen-type specific.
            </p>
          </div>
        </div>

        {/* AI Interpretation */}
        <div className="bg-white rounded-2xl md:rounded-3xl p-5 md:p-6 shadow-sm border border-stone-100 relative overflow-hidden">
          <div className="absolute top-0 left-0 w-1 h-full bg-brand-dark"></div>
          <div className="flex items-center gap-2 mb-3">
            <Sparkles className="w-5 h-5 text-brand-dark" />
            <h2 className="font-serif font-bold text-brand-dark">AI Interpretation</h2>
          </div>
          <p className="text-stone-700 leading-relaxed text-sm md:text-base">
            {report.aiInterpretation}
          </p>
        </div>

        {/* Summary Stats */}
        <div className="grid grid-cols-3 gap-3 md:gap-4">
          <div className="bg-white rounded-2xl md:rounded-3xl p-4 md:p-5 shadow-sm border border-stone-100 flex flex-col items-center justify-center text-center">
            <div className="text-2xl md:text-3xl font-bold text-emerald-600 mb-1">{stats.optimal}</div>
            <div className="text-xs md:text-sm font-medium text-stone-500 uppercase tracking-wider">Optimal</div>
          </div>
          <div className="bg-white rounded-2xl md:rounded-3xl p-4 md:p-5 shadow-sm border border-stone-100 flex flex-col items-center justify-center text-center">
            <div className="text-2xl md:text-3xl font-bold text-blue-600 mb-1">{stats.normal}</div>
            <div className="text-xs md:text-sm font-medium text-stone-500 uppercase tracking-wider">Normal</div>
          </div>
          <div className="bg-white rounded-2xl md:rounded-3xl p-4 md:p-5 shadow-sm border border-stone-100 flex flex-col items-center justify-center text-center">
            <div className="text-2xl md:text-3xl font-bold text-red-600 mb-1">{stats.abnormal}</div>
            <div className="text-xs md:text-sm font-medium text-stone-500 uppercase tracking-wider">Elevated</div>
          </div>
        </div>

        {/* Categories */}
        <div className="flex flex-wrap gap-2 mt-2">
          {categories.map((cat, idx) => (
            <button
              key={idx}
              onClick={() => setActiveCategory(cat as string)}
              className={`px-3 py-1.5 md:px-4 md:py-2 text-xs md:text-sm font-medium rounded-full transition-colors ${
                activeCategory === cat
                  ? 'bg-brand-dark text-white'
                  : 'bg-white border border-stone-200 text-stone-600 hover:bg-stone-50'
              }`}
            >
              {cat}
            </button>
          ))}
        </div>

        {/* Metal Thermometer Gauges */}
        <div className="flex flex-col gap-4">
          {filteredMarkers.map((marker, idx) => {
            const val = parseValue(marker.value);
            const refMax = parseValue(marker.range);
            const unit = extractUnit(marker.value);
            
            // Calculate scale and position. 
            // We want refMax to be roughly at 60% of the gauge width so we can show overflow.
            const gaugeMax = Math.max(refMax * 1.5, val * 1.2); 
            const valPercent = Math.min((val / gaugeMax) * 100, 100);
            
            // Safe zone (green): 0 to 60% of refMax
            const safeZoneWidth = (refMax * 0.6 / gaugeMax) * 100;
            // Caution zone (yellow): 60% to 100% of refMax
            const cautionZoneWidth = (refMax * 0.4 / gaugeMax) * 100;
            // Danger zone (red): > 100% of refMax
            const dangerZoneWidth = 100 - safeZoneWidth - cautionZoneWidth;

            return (
              <div key={idx} className="bg-white rounded-2xl md:rounded-3xl p-4 md:p-5 shadow-sm border border-stone-100">
                <div className="flex items-center justify-between mb-4">
                  <div>
                    <h3 className="font-bold text-stone-800 md:text-lg">{marker.name}</h3>
                    <p className="text-xs text-stone-500">Ref: {marker.range}</p>
                  </div>
                  <div className="flex flex-col items-end">
                    <div className="font-bold text-lg text-brand-dark">
                      {val} <span className="text-sm font-medium text-stone-500">{unit}</span>
                    </div>
                    <span className={`inline-flex items-center gap-1 mt-1 px-2 py-0.5 rounded-full text-[10px] font-bold uppercase tracking-wider ${getStatusColor(marker.status)}`}>
                      {getStatusIcon(marker.status)}
                      {marker.status}
                    </span>
                  </div>
                </div>

                {/* Gauge */}
                <div className="relative h-4 rounded-full overflow-hidden bg-stone-100 mb-2">
                  <div className="absolute top-0 left-0 h-full bg-emerald-400" style={{ width: `${safeZoneWidth}%` }}></div>
                  <div className="absolute top-0 h-full bg-yellow-400" style={{ left: `${safeZoneWidth}%`, width: `${cautionZoneWidth}%` }}></div>
                  <div className="absolute top-0 h-full bg-red-400" style={{ left: `${safeZoneWidth + cautionZoneWidth}%`, width: `${dangerZoneWidth}%` }}></div>
                  
                  {/* The actual value marker */}
                  <div 
                    className="absolute top-0 h-full w-1.5 bg-brand-dark shadow-md"
                    style={{ left: `calc(${valPercent}% - 3px)` }}
                  ></div>
                </div>

                {/* Insight */}
                {marker.insight && (
                  <div className="mt-4 p-3 bg-stone-50 rounded-xl text-sm text-stone-700">
                    <span className="font-medium mr-1">Insight:</span>
                    {marker.insight}
                  </div>
                )}
              </div>
            );
          })}
        </div>

      </div>
    </div>
  );
}
