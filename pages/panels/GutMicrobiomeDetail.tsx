import React, { useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { ChevronLeft, Sparkles, AlertCircle, CheckCircle, Search, Activity, Bug } from 'lucide-react';
import { GUT_MICROBIOME_REPORT } from '../../constants';

export default function GutMicrobiomeDetail() {
  const navigate = useNavigate();
  const [selectedCategory, setSelectedCategory] = useState('All');
  const [searchQuery, setSearchQuery] = useState('');

  const report = GUT_MICROBIOME_REPORT;
  const { panelMetadata } = report;

  const categories = [
    'All',
    'Beneficial Bacteria',
    'Commensal Bacteria',
    'Gut Health Markers',
    'Digestive Markers',
    'Metabolites'
  ];

  const filteredMarkers = report.markers.filter((m: any) => {
    const matchesCat = selectedCategory === 'All' || m.category === selectedCategory;
    const matchesSearch = m.name.toLowerCase().includes(searchQuery.toLowerCase());
    return matchesCat && matchesSearch;
  });

  let cumulativePercent = 0;

  return (
    <div className="min-h-screen bg-white flex flex-col">
      {/* Header */}
      <div className="sticky top-0 z-10 bg-white/80 backdrop-blur-md border-b border-stone-100 px-4 py-4 md:px-8">
        <div className="flex flex-col gap-3">
          <button 
            onClick={() => navigate('/health-vault')}
            className="flex items-center text-stone-500 hover:text-stone-900 transition-colors w-fit"
          >
            <ChevronLeft className="w-5 h-5 mr-1" />
            <span className="font-medium text-sm">Back to Vault</span>
          </button>
          
          <div className="flex items-center justify-between">
            <h1 className="text-2xl md:text-3xl font-serif font-bold text-brand-dark">
              {report.title || 'Gut Microbiome'}
            </h1>
            {report.providerName && (
              <span className="px-3 py-1 bg-stone-100 text-stone-600 rounded-full text-xs font-medium">
                {report.providerName}
              </span>
            )}
          </div>
        </div>
      </div>

      <div className="flex-1 overflow-y-auto p-4 md:p-8 space-y-6 md:space-y-8">
        {/* AI Interpretation */}
        {report.aiInterpretation && (
          <div className="rounded-2xl md:rounded-3xl border border-stone-100 bg-gradient-to-br from-brand-dark/5 to-transparent p-5 md:p-6 shadow-sm">
            <div className="flex items-center gap-2 mb-3">
              <Sparkles className="w-5 h-5 text-brand-dark" />
              <h2 className="font-semibold text-brand-dark">AI Interpretation</h2>
            </div>
            <p className="text-stone-700 leading-relaxed text-sm md:text-base">
              {report.aiInterpretation}
            </p>
          </div>
        )}

        <div className="grid grid-cols-1 md:grid-cols-2 gap-6 md:gap-8">
          {/* Phylum Composition */}
          {panelMetadata.phylumRatios && (
            <div className="rounded-2xl md:rounded-3xl border border-stone-100 shadow-sm p-5 md:p-6 bg-white">
              <h2 className="text-lg font-bold font-serif text-brand-dark mb-6">Phylum Composition</h2>
              <div className="flex flex-col sm:flex-row items-center gap-6">
                <div className="w-48 h-48 relative flex-shrink-0">
                  <svg viewBox="0 0 42 42" className="w-full h-full transform -rotate-90">
                    <circle cx="21" cy="21" r="15.91549430918954" fill="transparent" stroke="#f5f5f4" strokeWidth="6" />
                    {panelMetadata.phylumRatios.map((item: any) => {
                      const offset = 100 - cumulativePercent;
                      cumulativePercent += item.percentage;
                      return (
                        <circle
                          key={item.name}
                          cx="21"
                          cy="21"
                          r="15.91549430918954"
                          fill="transparent"
                          stroke={item.color}
                          strokeWidth="6"
                          strokeDasharray={`${item.percentage} ${100 - item.percentage}`}
                          strokeDashoffset={offset}
                          className="transition-all duration-500 ease-in-out hover:stroke-[8px]"
                        />
                      );
                    })}
                  </svg>
                  <div className="absolute inset-0 flex flex-col items-center justify-center pointer-events-none">
                    <span className="text-xs font-medium text-stone-500">Phyla</span>
                  </div>
                </div>
                <div className="flex-1 w-full space-y-3">
                  {panelMetadata.phylumRatios.map((item: any) => (
                    <div key={item.name} className="flex items-center justify-between text-sm">
                      <div className="flex items-center gap-2">
                        <span className="w-3 h-3 rounded-full shadow-sm" style={{ backgroundColor: item.color }} />
                        <span className="text-stone-600 font-medium">{item.name}</span>
                      </div>
                      <span className="font-bold text-stone-900">{item.percentage}%</span>
                    </div>
                  ))}
                </div>
              </div>
            </div>
          )}

          {/* Diversity Indices */}
          {panelMetadata.diversityIndices && (
            <div className="rounded-2xl md:rounded-3xl border border-stone-100 shadow-sm p-5 md:p-6 bg-white flex flex-col">
              <h2 className="text-lg font-bold font-serif text-brand-dark mb-6">Diversity Indices</h2>
              <div className="flex flex-col gap-4 flex-1">
                {panelMetadata.diversityIndices.map((index: any) => {
                  let statusBg = 'bg-stone-100';
                  let statusText = 'text-stone-700';
                  
                  if (index.status === 'Good' || index.status === 'Optimal') {
                    statusBg = 'bg-emerald-100';
                    statusText = 'text-emerald-700';
                  } else if (index.status === 'Elevated' || index.status === 'Abnormal' || index.status === 'Poor') {
                    statusBg = 'bg-red-100';
                    statusText = 'text-red-700';
                  } else if (index.status === 'Normal') {
                    statusBg = 'bg-blue-100';
                    statusText = 'text-blue-700';
                  }

                  return (
                    <div key={index.name} className="bg-stone-50 rounded-xl p-4 flex items-center justify-between hover:bg-stone-100 transition-colors">
                      <div className="flex items-center gap-3">
                        <div className="p-2 bg-white rounded-lg shadow-sm border border-stone-100">
                          <Activity className="w-4 h-4 text-brand-dark" />
                        </div>
                        <span className="font-medium text-stone-800">{index.name}</span>
                      </div>
                      <div className="flex items-center gap-3">
                        <span className="text-lg font-bold text-brand-dark">{index.value}</span>
                        <span className={`px-2.5 py-1 rounded-full text-xs font-medium ${statusBg} ${statusText}`}>
                          {index.status}
                        </span>
                      </div>
                    </div>
                  );
                })}
              </div>
            </div>
          )}
        </div>

        {/* Pathogens Grid */}
        {panelMetadata.pathogens && (
          <div className="rounded-2xl md:rounded-3xl border border-stone-100 shadow-sm p-5 md:p-6 bg-white">
            <h2 className="text-lg font-bold font-serif text-brand-dark mb-6 flex items-center gap-2">
              <Bug className="w-5 h-5" /> Pathogen Detection
            </h2>
            <div className="grid grid-cols-1 sm:grid-cols-2 md:grid-cols-3 gap-4">
              {panelMetadata.pathogens.map((pathogen: any) => (
                <div 
                  key={pathogen.name} 
                  className={`rounded-xl p-4 border transition-colors ${
                    pathogen.detected ? 'border-red-100 bg-red-50/50 hover:bg-red-50' : 'border-stone-100 bg-stone-50 hover:bg-stone-100'
                  }`}
                >
                  <div className="flex items-start justify-between mb-3">
                    <span className="font-medium text-stone-800">{pathogen.name}</span>
                    {pathogen.detected ? (
                      <AlertCircle className="w-5 h-5 text-red-500 flex-shrink-0" />
                    ) : (
                      <CheckCircle className="w-5 h-5 text-emerald-500 flex-shrink-0" />
                    )}
                  </div>
                  <div className="flex items-center justify-between">
                    <span className={`text-xs font-medium px-2.5 py-1 rounded-full ${
                      pathogen.detected ? 'bg-red-100 text-red-700' : 'bg-emerald-100 text-emerald-700'
                    }`}>
                      {pathogen.detected ? 'Detected' : 'Not Detected'}
                    </span>
                    {pathogen.detected && pathogen.level && (
                      <span className="text-xs font-bold text-red-600">
                        {pathogen.level} Level
                      </span>
                    )}
                  </div>
                </div>
              ))}
            </div>
          </div>
        )}

        {/* Species & Markers */}
        <div className="space-y-4">
          <h2 className="text-xl font-serif font-bold text-brand-dark">Detailed Markers</h2>
          
          <div className="flex flex-col md:flex-row gap-4 items-start md:items-center justify-between">
            {/* Category Filter */}
            <div className="flex overflow-x-auto pb-2 -mx-4 px-4 md:mx-0 md:px-0 md:pb-0 scrollbar-hide w-full md:w-auto gap-2">
              {categories.map(cat => (
                <button
                  key={cat}
                  onClick={() => setSelectedCategory(cat)}
                  className={`flex-shrink-0 px-3 py-1.5 md:px-4 md:py-2 text-xs md:text-sm rounded-full font-medium transition-colors ${
                    selectedCategory === cat 
                      ? 'bg-brand-dark text-white' 
                      : 'bg-stone-100 text-stone-600 hover:bg-stone-200'
                  }`}
                >
                  {cat}
                </button>
              ))}
            </div>

            {/* Search */}
            <div className="relative w-full md:w-64 flex-shrink-0">
              <Search className="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-stone-400" />
              <input 
                type="text" 
                placeholder="Search markers..." 
                value={searchQuery}
                onChange={(e) => setSearchQuery(e.target.value)}
                className="w-full pl-9 pr-4 py-2 bg-stone-50 border border-stone-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-brand-dark/20 focus:border-brand-dark transition-all"
              />
            </div>
          </div>

          {/* Markers List */}
          <div className="grid grid-cols-1 md:grid-cols-2 xl:grid-cols-3 gap-4 pt-2">
            {filteredMarkers.map((marker: any, idx: number) => {
              let badgeStyle = 'bg-stone-100 text-stone-700';
              if (marker.status === 'Optimal') badgeStyle = 'bg-emerald-100 text-emerald-700';
              else if (marker.status === 'Normal') badgeStyle = 'bg-blue-100 text-blue-700';
              else if (marker.status === 'Abnormal') badgeStyle = 'bg-red-100 text-red-700';

              return (
                <div key={idx} className="bg-white rounded-2xl p-4 md:p-5 border border-stone-100 shadow-sm hover:shadow-md transition-shadow">
                  <div className="flex justify-between items-start mb-3">
                    <div>
                      <h3 className="font-semibold text-stone-900">{marker.name}</h3>
                      {marker.category && (
                        <span className="text-xs font-medium text-stone-500 mt-0.5 block">{marker.category}</span>
                      )}
                    </div>
                    <span className={`inline-flex items-center gap-1.5 px-3 py-1.5 rounded-full text-xs font-medium flex-shrink-0 ${badgeStyle}`}>
                      {marker.status}
                    </span>
                  </div>
                  
                  <div className="flex items-end justify-between mt-4">
                    <div>
                      <div className="text-2xl font-bold text-brand-dark">{marker.value}</div>
                      <div className="text-xs font-medium text-stone-500 mt-1">Ref: {marker.range}</div>
                    </div>
                  </div>

                  {marker.insight && (
                    <div className="mt-4 pt-3 border-t border-stone-100">
                      <p className="text-sm text-stone-600 line-clamp-2">
                        {marker.insight}
                      </p>
                    </div>
                  )}
                </div>
              );
            })}
            
            {filteredMarkers.length === 0 && (
              <div className="col-span-full py-12 text-center bg-stone-50 rounded-2xl border border-stone-100">
                <p className="text-stone-500 font-medium">No markers found matching your criteria.</p>
              </div>
            )}
          </div>
        </div>
      </div>
    </div>
  );
}
