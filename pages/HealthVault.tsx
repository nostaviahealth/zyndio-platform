import React from 'react';
import { useNavigate } from 'react-router-dom';
import { Activity, Bug, Dna, FlaskConical, AlertTriangle, ShieldAlert, ChevronRight, Upload, Sparkles, FolderOpen } from 'lucide-react';
import { PANEL_TYPE_CONFIG, LAB_REPORTS, GUT_MICROBIOME_REPORT, GENETIC_PANEL_REPORT, METHYLATION_REPORT, HEAVY_METALS_REPORT, TOXICITY_REPORT } from '../constants';
import { LabReport } from '../types';

// Map icon names to components
const iconMap: Record<string, React.FC<{ className?: string }>> = {
  Activity,
  Bug,
  Dna,
  FlaskConical,
  AlertTriangle,
  ShieldAlert,
};

// Aggregate all reports by type for counts
const allReports: Record<string, LabReport[]> = {
  standard_blood: LAB_REPORTS,
  gut_microbiome: [GUT_MICROBIOME_REPORT],
  genetic: [GENETIC_PANEL_REPORT],
  methylation: [METHYLATION_REPORT],
  heavy_metals: [HEAVY_METALS_REPORT],
  toxicity: [TOXICITY_REPORT],
};

// Cross-panel insights (demo)
const crossPanelInsights = [
  {
    icon: '🔗',
    text: 'Your MTHFR C677T variant may explain your borderline HbA1c — methylated B-vitamins could improve metabolic markers.',
    panels: ['Genetic', 'Blood Panel'],
  },
  {
    icon: '🧬',
    text: 'Gut diversity improved alongside biological age deceleration — your protocol is having measurable epigenetic impact.',
    panels: ['Gut Microbiome', 'Biological Age'],
  },
  {
    icon: '⚠️',
    text: 'Elevated mercury + functional GSTM1 genotype → your body can detox effectively with NAC and chelation support.',
    panels: ['Heavy Metals', 'Genetic'],
  },
];

const HealthVault: React.FC = () => {
  const navigate = useNavigate();

  return (
    <div className="flex flex-col gap-4 md:gap-6">

      {/* Header */}
      <div className="bg-white rounded-2xl md:rounded-3xl shadow-sm border border-stone-100 p-4 md:p-6">
        <div className="flex flex-col md:flex-row md:items-center justify-between gap-3">
          <div>
            <h1 className="text-2xl md:text-3xl font-serif font-bold text-brand-dark flex items-center gap-2 md:gap-3">
              <FolderOpen className="w-6 h-6 md:w-8 md:h-8 text-brand-sage" />
              Health Vault
            </h1>
            <p className="text-xs md:text-sm text-stone-500 mt-1">All your health reports in one place — blood work, genetics, microbiome, and more</p>
          </div>
          <button className="px-3 py-2 md:px-4 md:py-2 bg-brand-dark text-white rounded-xl hover:bg-opacity-90 transition-all flex items-center gap-2 text-sm md:text-base">
            <Upload className="w-4 h-4" />
            <span className="hidden sm:inline">Upload New Report</span>
            <span className="sm:hidden">Upload</span>
          </button>
        </div>
      </div>

      {/* Panel Type Cards Grid */}
      <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-3 md:gap-4">
        {PANEL_TYPE_CONFIG.map((panel) => {
          const Icon = iconMap[panel.icon] || Activity;
          const reports = allReports[panel.key] || [];
          const reportCount = reports.length;
          const latestDate = reports.length > 0
            ? new Date(reports[0].date).toLocaleDateString('en-US', { month: 'short', year: 'numeric' })
            : null;

          // Get status counts for the panel
          const optimalCount = reports.reduce((sum, r) => sum + r.markers.filter(m => m.status === 'Optimal').length, 0);
          const abnormalCount = reports.reduce((sum, r) => sum + r.markers.filter(m => m.status === 'Abnormal').length, 0);
          const totalMarkers = reports.reduce((sum, r) => sum + r.markers.length, 0);

          return (
            <button
              key={panel.key}
              onClick={() => navigate(panel.route)}
              className="bg-white rounded-2xl shadow-sm border border-stone-100 p-4 md:p-5 hover:shadow-md hover:border-stone-200 transition-all text-left group"
            >
              <div className="flex items-start justify-between mb-3">
                <div className={`w-10 h-10 md:w-12 md:h-12 rounded-xl ${panel.accentBg} border ${panel.accentBorder} flex items-center justify-center`}>
                  <Icon className={`w-5 h-5 md:w-6 md:h-6 ${panel.accentText}`} />
                </div>
                <ChevronRight className="w-4 h-4 text-stone-300 group-hover:text-stone-500 transition-colors mt-1" />
              </div>

              <h3 className="font-semibold text-stone-900 text-sm md:text-base">{panel.label}</h3>
              <p className="text-xs text-stone-500 mt-0.5 mb-3">{panel.description}</p>

              {reportCount > 0 ? (
                <div className="space-y-2">
                  <div className="flex items-center gap-2">
                    <span className="text-xs font-medium text-stone-600">
                      {reportCount} {reportCount === 1 ? 'report' : 'reports'}
                    </span>
                    <span className="text-xs text-stone-400">·</span>
                    <span className="text-xs text-stone-500">{totalMarkers} markers</span>
                  </div>

                  {/* Mini status bar */}
                  <div className="flex gap-1.5">
                    {optimalCount > 0 && (
                      <span className="inline-flex items-center px-1.5 py-0.5 rounded text-[10px] font-medium bg-emerald-50 text-emerald-600 border border-emerald-100">
                        {optimalCount} optimal
                      </span>
                    )}
                    {abnormalCount > 0 && (
                      <span className="inline-flex items-center px-1.5 py-0.5 rounded text-[10px] font-medium bg-red-50 text-red-600 border border-red-100">
                        {abnormalCount} attention
                      </span>
                    )}
                  </div>

                  <div className="text-[10px] text-stone-400 pt-1 border-t border-stone-50">
                    Latest: {latestDate}
                  </div>
                </div>
              ) : (
                <div className="text-xs text-stone-400 italic">No reports yet</div>
              )}
            </button>
          );
        })}
      </div>

      {/* Cross-Panel Insights */}
      <div className="bg-white rounded-2xl md:rounded-3xl shadow-sm border border-stone-100 p-4 md:p-6">
        <div className="flex items-center gap-2 mb-4">
          <Sparkles className="w-5 h-5 text-brand-sage" />
          <h2 className="text-lg md:text-xl font-serif font-bold text-brand-dark">Cross-Panel Insights</h2>
        </div>
        <p className="text-xs text-stone-500 mb-4">AI-powered correlations across your health reports</p>

        <div className="space-y-3">
          {crossPanelInsights.map((insight, idx) => (
            <div
              key={idx}
              className="bg-stone-50 rounded-xl p-3 md:p-4 border border-stone-100 hover:bg-stone-100 transition-all cursor-pointer"
            >
              <div className="flex gap-3">
                <span className="text-lg flex-shrink-0 mt-0.5">{insight.icon}</span>
                <div className="flex-1">
                  <p className="text-sm text-stone-700 leading-relaxed">{insight.text}</p>
                  <div className="flex gap-1.5 mt-2">
                    {insight.panels.map((panel) => (
                      <span
                        key={panel}
                        className="px-2 py-0.5 bg-white border border-stone-200 rounded-lg text-[10px] font-medium text-stone-500"
                      >
                        {panel}
                      </span>
                    ))}
                  </div>
                </div>
              </div>
            </div>
          ))}
        </div>
      </div>

    </div>
  );
};

export default HealthVault;
