import React, { useState } from 'react';
import { ArrowLeft, AlertTriangle, ShieldCheck, Activity, ChevronDown, ChevronUp, Info } from 'lucide-react';
import { useNavigate } from 'react-router-dom';
import { AI_ANALYSIS_DATA } from '../constants';

const DiseaseRiskAnalysis: React.FC = () => {
    const navigate = useNavigate();
    const [expandedRisk, setExpandedRisk] = useState<string | null>(null);

    return (
        <div className="space-y-8 max-w-5xl mx-auto animate-fade-in">
            {/* Header */}
            <div className="flex items-center gap-4">
                <button
                    onClick={() => navigate('/intelligence')}
                    className="w-10 h-10 rounded-full bg-white shadow-soft flex items-center justify-center text-slate-500 hover:text-slate-900 transition-colors"
                >
                    <ArrowLeft className="w-5 h-5" />
                </button>
                <div>
                    <h1 className="text-3xl font-serif text-slate-900">Disease Risk Analysis</h1>
                    <p className="text-slate-500">Predictive modeling based on your biomarkers and genetics.</p>
                </div>
            </div>

            {/* Risk Overview Cards */}
            <div className="grid grid-cols-1 md:grid-cols-3 gap-6">
                <div className="bg-white p-6 rounded-3xl shadow-soft border-none">
                    <div className="flex items-center gap-3 mb-4">
                        <div className="w-10 h-10 rounded-xl bg-emerald-50 text-emerald-500 flex items-center justify-center">
                            <ShieldCheck className="w-5 h-5" />
                        </div>
                        <h3 className="font-bold text-slate-900">Overall Protection</h3>
                    </div>
                    <div className="text-3xl font-bold text-emerald-600 mb-1">High</div>
                    <p className="text-xs text-slate-500">Your lifestyle offers strong protection against chronic diseases.</p>
                </div>
                <div className="bg-white p-6 rounded-3xl shadow-soft border-none">
                    <div className="flex items-center gap-3 mb-4">
                        <div className="w-10 h-10 rounded-xl bg-amber-50 text-amber-500 flex items-center justify-center">
                            <AlertTriangle className="w-5 h-5" />
                        </div>
                        <h3 className="font-bold text-slate-900">Primary Concern</h3>
                    </div>
                    <div className="text-3xl font-bold text-amber-600 mb-1">Metabolic</div>
                    <p className="text-xs text-slate-500">Insulin resistance is the main driver of your current risk profile.</p>
                </div>
                <div className="bg-white p-6 rounded-3xl shadow-soft border-none">
                    <div className="flex items-center gap-3 mb-4">
                        <div className="w-10 h-10 rounded-xl bg-blue-50 text-blue-500 flex items-center justify-center">
                            <Activity className="w-5 h-5" />
                        </div>
                        <h3 className="font-bold text-slate-900">Actionable</h3>
                    </div>
                    <div className="text-3xl font-bold text-blue-600 mb-1">3 Factors</div>
                    <p className="text-xs text-slate-500">You can reduce your top risks by addressing 3 key biomarkers.</p>
                </div>
            </div>

            {/* Detailed Risk List */}
            <div className="space-y-4">
                <h2 className="text-xl font-bold text-slate-900">Condition Breakdown</h2>
                {AI_ANALYSIS_DATA.diseaseRisks.map((risk, idx) => {
                    const isExpanded = expandedRisk === risk.condition;
                    return (
                        <div key={idx} className="bg-white rounded-3xl shadow-soft overflow-hidden border border-transparent hover:border-slate-100 transition-all">
                            <div
                                className="p-6 flex items-center justify-between cursor-pointer"
                                onClick={() => setExpandedRisk(isExpanded ? null : risk.condition)}
                            >
                                <div className="flex items-center gap-4">
                                    <div className={`w-12 h-12 rounded-full flex items-center justify-center border-4 ${risk.level === 'High' ? 'border-red-100 text-red-500' :
                                            risk.level === 'Moderate' ? 'border-amber-100 text-amber-500' :
                                                'border-emerald-100 text-emerald-500'
                                        }`}>
                                        <span className="text-sm font-bold">{risk.probability}%</span>
                                    </div>
                                    <div>
                                        <h3 className="text-lg font-bold text-slate-900">{risk.condition}</h3>
                                        <span className={`text-[10px] font-bold px-2 py-0.5 rounded-full uppercase tracking-wide ${risk.level === 'High' ? 'bg-red-100 text-red-600' :
                                                risk.level === 'Moderate' ? 'bg-amber-100 text-amber-600' :
                                                    'bg-emerald-100 text-emerald-600'
                                            }`}>
                                            {risk.level} Risk
                                        </span>
                                    </div>
                                </div>
                                <div className={`w-8 h-8 rounded-full bg-slate-50 flex items-center justify-center text-slate-400 transition-transform duration-300 ${isExpanded ? 'rotate-180' : ''}`}>
                                    <ChevronDown className="w-4 h-4" />
                                </div>
                            </div>

                            {isExpanded && (
                                <div className="px-6 pb-6 pt-0 animate-fade-in border-t border-slate-50">
                                    <div className="grid grid-cols-1 md:grid-cols-2 gap-6 mt-6">
                                        <div>
                                            <h4 className="text-xs font-bold text-slate-400 uppercase tracking-wider mb-3">Risk Drivers</h4>
                                            <div className="flex flex-wrap gap-2">
                                                {risk.drivers.map((driver, i) => (
                                                    <span key={i} className="px-3 py-1.5 bg-slate-50 border border-slate-100 rounded-lg text-xs font-medium text-slate-700">
                                                        {driver}
                                                    </span>
                                                ))}
                                            </div>
                                        </div>
                                        <div>
                                            <h4 className="text-xs font-bold text-slate-400 uppercase tracking-wider mb-3">Mitigation Strategy</h4>
                                            <p className="text-sm text-slate-600 leading-relaxed">
                                                Focus on lowering inflammation and improving metabolic flexibility.
                                                Specific interventions include increasing Zone 2 cardio and optimizing sleep duration.
                                            </p>
                                        </div>
                                    </div>
                                </div>
                            )}
                        </div>
                    );
                })}
            </div>
        </div>
    );
};

export default DiseaseRiskAnalysis;
