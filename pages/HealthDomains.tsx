import React, { useState } from 'react';
import { ArrowLeft, Heart, Flame, Activity, Zap, Brain, ChevronDown, ChevronUp, Info } from 'lucide-react';
import { useNavigate } from 'react-router-dom';
import { getGradeFromScore } from '../utils/grading';

import { useUser } from '../contexts/UserContext';
import LoadingSkeleton, { SkeletonCard } from '../components/LoadingSkeleton';

const HealthDomains: React.FC = () => {
    const navigate = useNavigate();
    const { publishedIntelligence, loading } = useUser();
    const [expandedDomain, setExpandedDomain] = useState<string | null>('Heart');

    // Static config for visual presentation
    const domainConfig: Record<string, any> = {
        'Heart': {
            icon: Heart,
            color: 'text-red-500',
            bg: 'bg-red-50',
            border: 'border-red-100',
            desc: 'Cardiovascular health analysis based on your biomarkers.'
        },
        'Metabolic': {
            icon: Flame,
            color: 'text-amber-500',
            bg: 'bg-amber-50',
            border: 'border-amber-100',
            desc: 'Metabolic flexibility and efficiency analysis.'
        },
        'Respiratory': {
            icon: Activity,
            color: 'text-blue-500',
            bg: 'bg-blue-50',
            border: 'border-blue-100',
            desc: 'Respiratory function and oxygen utilization.'
        },
        'Immune': {
            icon: Zap,
            color: 'text-emerald-500',
            bg: 'bg-emerald-50',
            border: 'border-emerald-100',
            desc: 'Immune system resilience and inflammation markers.'
        },
        'Cognitive': {
            icon: Brain,
            color: 'text-purple-500',
            bg: 'bg-purple-50',
            border: 'border-purple-100',
            desc: 'Cognitive performance and neural health indicators.'
        }
    };

    if (loading) {
        return (
            <div className="max-w-5xl mx-auto space-y-6 animate-pulse">
                <div className="flex gap-4">
                    <div className="w-10 h-10 rounded-full bg-slate-100"></div>
                    <div>
                        <div className="h-6 w-32 bg-slate-100 rounded mb-2"></div>
                        <div className="h-4 w-48 bg-slate-100 rounded"></div>
                    </div>
                </div>
                <div className="space-y-4">
                    {[1, 2, 3, 4, 5].map(i => (
                        <div key={i} className="bg-white rounded-3xl p-6 border border-slate-100 h-32">
                            <div className="flex justify-between">
                                <div className="flex gap-4">
                                    <div className="w-12 h-12 bg-slate-100 rounded-xl"></div>
                                    <div className="space-y-2">
                                        <div className="h-5 w-32 bg-slate-100 rounded"></div>
                                        <div className="h-4 w-48 bg-slate-100 rounded"></div>
                                    </div>
                                </div>
                                <div className="h-10 w-16 bg-slate-100 rounded-xl"></div>
                            </div>
                        </div>
                    ))}
                </div>
            </div>
        );
    }

    // Merge real data with config
    const domains = publishedIntelligence?.healthDomains?.map(domain => {
        const config = domainConfig[domain.name] || domainConfig['Heart']; // Fallback
        return {
            ...domain,
            ...config,
            metrics: [] // Real metrics would come from intelligence data if available
        };
    }) || [];

    // Fallback if no published data (should handle gracefully)
    if (domains.length === 0) {
        return (
            <div className="flex items-center justify-center min-h-[50vh]">
                <div className="text-center">
                    <Info className="w-12 h-12 text-slate-300 mx-auto mb-4" />
                    <p className="text-slate-500">No health domain analysis available yet.</p>
                </div>
            </div>
        );
    }

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
                    <h1 className="text-3xl font-serif text-slate-900">Health Domains</h1>
                    <p className="text-slate-500">Deep dive into your physiological systems.</p>
                </div>
            </div>

            {/* Domains Grid */}
            <div className="grid grid-cols-1 gap-6">
                {domains.map((domain) => {
                    const isExpanded = expandedDomain === domain.name;
                    const gradeInfo = getGradeFromScore(domain.score);
                    return (
                        <div
                            key={domain.name}
                            className={`bg-white rounded-3xl shadow-soft overflow-hidden transition-all duration-300 border ${isExpanded ? domain.border : 'border-transparent'}`}
                        >
                            <div
                                className="p-6 flex items-center justify-between cursor-pointer"
                                onClick={() => setExpandedDomain(isExpanded ? null : domain.name)}
                            >
                                <div className="flex items-center gap-6">
                                    <div className={`w-16 h-16 rounded-2xl flex items-center justify-center ${domain.bg} ${domain.color}`}>
                                        <domain.icon className="w-8 h-8" />
                                    </div>
                                    <div>
                                        <h3 className="text-xl font-bold text-slate-900">{domain.name} Health</h3>
                                        <div className="flex items-center gap-3 mt-1">
                                            <span className={`text-xs font-bold px-2 py-0.5 rounded-full uppercase tracking-wide ${gradeInfo.bgColor} ${gradeInfo.textColor}`}>
                                                {gradeInfo.label}
                                            </span>
                                            <span className="text-sm text-slate-400">Target: Grade B+</span>
                                        </div>
                                    </div>
                                </div>
                                <div className="flex items-center gap-6">
                                    <div className="text-right">
                                        <div className={`text-4xl font-bold ${gradeInfo.textColor}`}>{gradeInfo.grade}</div>
                                        <div className="text-xs text-slate-400 uppercase tracking-wider font-medium">Grade</div>
                                    </div>
                                    <div className={`w-10 h-10 rounded-full bg-slate-50 flex items-center justify-center text-slate-400 transition-transform duration-300 ${isExpanded ? 'rotate-180' : ''}`}>
                                        <ChevronDown className="w-5 h-5" />
                                    </div>
                                </div>
                            </div>

                            {isExpanded && (
                                <div className="px-6 pb-6 pt-0 animate-fade-in">
                                    <div className="p-4 bg-slate-50 rounded-2xl mb-6 text-slate-600 text-sm leading-relaxed border border-slate-100 flex gap-3">
                                        <Info className="w-5 h-5 text-slate-400 flex-shrink-0 mt-0.5" />
                                        {domain.desc}
                                    </div>

                                    <h4 className="text-sm font-bold text-slate-900 uppercase tracking-wider mb-4">Key Biomarkers</h4>
                                    <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-4">
                                        {domain.metrics.map((metric, idx) => (
                                            <div key={idx} className="bg-white p-4 rounded-xl border border-slate-100 shadow-sm">
                                                <div className="text-xs text-slate-500 mb-1">{metric.name}</div>
                                                <div className="text-lg font-bold text-slate-900 mb-2">{metric.value}</div>
                                                <div className="flex items-center justify-between">
                                                    <span className={`text-[10px] font-bold px-1.5 py-0.5 rounded uppercase ${metric.status === 'Optimal' ? 'bg-emerald-50 text-emerald-600' :
                                                        metric.status === 'Good' ? 'bg-blue-50 text-blue-600' :
                                                            metric.status === 'Fair' ? 'bg-amber-50 text-amber-600' :
                                                                'bg-red-50 text-red-600'
                                                        }`}>
                                                        {metric.status}
                                                    </span>
                                                    <span className={`text-[10px] font-medium ${metric.trend === 'up' && metric.status !== 'Low' ? 'text-emerald-500' :
                                                        metric.trend === 'down' && metric.status === 'Optimal' ? 'text-emerald-500' :
                                                            'text-slate-400'
                                                        }`}>
                                                        {metric.trend === 'up' ? '↑' : metric.trend === 'down' ? '↓' : '–'} Trend
                                                    </span>
                                                </div>
                                            </div>
                                        ))}
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

export default HealthDomains;
