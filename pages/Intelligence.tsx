import React, { useEffect, useState } from 'react';
import { Sparkles, ArrowRight, Heart, Flame, Activity, Zap, Brain, ChevronRight, Lock } from 'lucide-react';
import { useNavigate } from 'react-router-dom';
import { SUGGESTED_ACTIONS } from '../constants';
import { IntelligenceData } from '../types';
import { useUser } from '../contexts/UserContext';
import { supabase } from '../lib/supabase';
import { getGradeFromScore } from '../utils/grading';

const Intelligence: React.FC = () => {
    const navigate = useNavigate();
    const { patientProfile } = useUser();
    const [intelligenceData, setIntelligenceData] = useState<IntelligenceData | null>(null);
    const [isApproved, setIsApproved] = useState(false);
    const [loading, setLoading] = useState(true);

    useEffect(() => {
        const loadIntelligence = async () => {
            if (!patientProfile) {
                setLoading(false);
                return;
            }

            try {
                const { data, error } = await supabase
                    .from('intelligence_data')
                    .select('*')
                    .eq('profile_id', patientProfile.id)
                    .order('created_at', { ascending: false })
                    .limit(1)
                    .single();

                if (error) {
                    // No intelligence data found yet
                    setIntelligenceData(null);
                    setIsApproved(false);
                } else if (data) {
                    // Map database record to IntelligenceData format
                    const intelligence: IntelligenceData = {
                        overallScore: data.longevity_score || 75,
                        biomarkersScore: data.biomarker_summary?.overall_score || 82,
                        lifestyleScore: data.biomarker_summary?.lifestyle_score || 68,
                        riskFactorsScore: data.biomarker_summary?.risk_score || 71,
                        healthDomains: data.key_insights?.health_domains || [],
                        diseaseRisks: data.disease_risks || [],
                        published: true // If data exists, it's published
                    };
                    setIntelligenceData(intelligence);
                    setIsApproved(true);
                }
            } catch (error) {
                console.error('Error loading intelligence:', error);
            } finally {
                setLoading(false);
            }
        };

        loadIntelligence();
    }, [patientProfile]);

    if (loading) {
        return (
            <div className="space-y-8 animate-pulse">
                {/* Header Skeleton */}
                <div className="flex flex-col md:flex-row items-center justify-between gap-6 bg-white p-6 rounded-3xl border border-slate-100">
                    <div className="space-y-4 w-full">
                        <div className="h-4 w-32 bg-slate-100 rounded"></div>
                        <div className="h-12 w-24 bg-slate-100 rounded"></div>
                    </div>
                </div>

                {/* Health Domains Skeleton */}
                <div className="bg-white p-6 rounded-3xl border border-slate-100">
                    <div className="h-6 w-48 bg-slate-100 rounded mb-6"></div>
                    <div className="grid grid-cols-2 sm:grid-cols-3 md:grid-cols-5 gap-4">
                        {[1, 2, 3, 4, 5].map(i => (
                            <div key={i} className="flex flex-col items-center gap-3">
                                <div className="w-16 h-16 rounded-full bg-slate-100"></div>
                                <div className="h-4 w-16 bg-slate-100 rounded"></div>
                                <div className="h-6 w-12 bg-slate-100 rounded"></div>
                            </div>
                        ))}
                    </div>
                </div>

                {/* Risk Analysis Skeleton */}
                <div className="bg-white p-6 rounded-3xl border border-slate-100">
                    <div className="h-6 w-48 bg-slate-100 rounded mb-6"></div>
                    <div className="space-y-4">
                        {[1, 2, 3].map(i => (
                            <div key={i} className="h-16 w-full bg-slate-100 rounded-xl"></div>
                        ))}
                    </div>
                </div>
            </div>
        );
    }

    // If not approved, show pending state
    if (!isApproved || !intelligenceData) {
        return (
            <div className="flex items-center justify-center min-h-[60vh]">
                <div className="text-center max-w-md">
                    <div className="w-20 h-20 bg-gradient-to-br from-purple-100 to-blue-100 rounded-full flex items-center justify-center mx-auto mb-6">
                        <Lock className="w-10 h-10 text-purple-600" />
                    </div>
                    <h2 className="text-2xl font-serif text-slate-900 mb-3">Intelligence Analysis Pending</h2>
                    <p className="text-slate-600 mb-6">
                        Your health advisor is reviewing your lab results and biomarkers.
                        Your AI health score and disease risk analysis will be available soon.
                    </p>
                    <div className="flex items-center justify-center gap-2 text-sm text-slate-500">
                        <Brain className="w-4 h-4" />
                        <span>Analysis in progress</span>
                    </div>
                </div>
            </div>
        );
    }

    // Original Intelligence page content when approved
    // Mock data for the specific visual elements in the screenshot
    const healthDomains = intelligenceData.healthDomains.map((domain, idx) => {
        const colors = [
            { color: 'text-red-500', ringColor: 'text-red-500', bg: 'bg-red-50', icon: Heart },
            { color: 'text-amber-500', ringColor: 'text-amber-500', bg: 'bg-amber-50', icon: Flame },
            { color: 'text-blue-500', ringColor: 'text-blue-500', bg: 'bg-blue-50', icon: Activity },
            { color: 'text-emerald-500', ringColor: 'text-emerald-500', bg: 'bg-emerald-50', icon: Zap },
            { color: 'text-purple-500', ringColor: 'text-purple-500', bg: 'bg-purple-50', icon: Brain },
        ];
        return { ...domain, ...colors[idx % colors.length] };
    });

    const CircularProgress = ({ value, size = 120, strokeWidth = 10, color = "text-emerald-500", trackColor = "text-slate-100" }: { value: number, size?: number, strokeWidth?: number, color?: string, trackColor?: string }) => {
        const radius = (size - strokeWidth) / 2;
        const circumference = radius * 2 * Math.PI;
        const offset = circumference - (value / 100) * circumference;

        return (
            <div className="relative flex items-center justify-center" style={{ width: size, height: size }}>
                <svg className="transform -rotate-90 w-full h-full">
                    <circle
                        className={trackColor}
                        strokeWidth={strokeWidth}
                        stroke="currentColor"
                        fill="transparent"
                        r={radius}
                        cx={size / 2}
                        cy={size / 2}
                    />
                    <circle
                        className={color}
                        strokeWidth={strokeWidth}
                        strokeDasharray={circumference}
                        strokeDashoffset={offset}
                        strokeLinecap="round"
                        stroke="currentColor"
                        fill="transparent"
                        r={radius}
                        cx={size / 2}
                        cy={size / 2}
                    />
                </svg>
                <div className="absolute flex flex-col items-center justify-center text-slate-900">
                    <span className="text-3xl font-bold">{value}</span>
                    <span className="text-[10px] text-slate-400 font-medium uppercase tracking-wider">Overall</span>
                </div>
            </div>
        );
    };

    const SmallCircularProgress = ({ value, color = "text-red-500" }: { value: number, color?: string }) => {
        return (
            <div className="relative flex items-center justify-center w-16 h-16">
                <svg className="transform -rotate-90 w-full h-full">
                    <circle
                        className="text-slate-100"
                        strokeWidth="6"
                        stroke="currentColor"
                        fill="transparent"
                        r="26"
                        cx="32"
                        cy="32"
                    />
                    <circle
                        className={color}
                        strokeWidth="6"
                        strokeDasharray={26 * 2 * Math.PI}
                        strokeDashoffset={26 * 2 * Math.PI - (value / 100) * (26 * 2 * Math.PI)}
                        strokeLinecap="round"
                        stroke="currentColor"
                        fill="transparent"
                        r="26"
                        cx="32"
                        cy="32"
                    />
                </svg>
                <span className={`absolute text-sm font-bold ${color.replace('text-', 'text-')}`}>{value}</span>
            </div>
        );
    };

    return (
        <div className="space-y-6 max-w-7xl mx-auto">
            {/* Hero Section */}
            <div className="bg-white rounded-3xl p-8 shadow-soft border-none relative overflow-hidden">
                <div className="relative z-10">
                    <div className="flex items-center gap-2 mb-3">
                        <Sparkles className="w-4 h-4 text-emerald-500" />
                        <span className="text-xs font-bold text-emerald-600 tracking-wider uppercase">Zyndio Intelligence</span>
                    </div>
                    <div className="flex flex-col md:flex-row justify-between items-start md:items-end gap-6">
                        <div>
                            <h1 className="text-3xl font-serif text-slate-900 mb-2">How can I help you today?</h1>
                            <p className="text-slate-500 max-w-lg">
                                Ask about your labs, get protocol recommendations, or discuss health concerns.
                            </p>
                        </div>
                        <button
                            onClick={() => navigate('/chat')}
                            className="bg-brand-dark text-white px-6 py-3 rounded-xl font-medium shadow-lg shadow-slate-200 hover:bg-slate-800 transition-all flex items-center gap-2"
                        >
                            Start Chat <ArrowRight className="w-4 h-4" />
                        </button>
                    </div>
                </div>
            </div>

            <div className="grid grid-cols-1 lg:grid-cols-12 gap-6">
                {/* Left Column */}
                <div className="lg:col-span-4 space-y-6">
                    {/* AI Health Score */}
                    <div className="bg-white p-6 rounded-3xl shadow-soft border-none">
                        <h3 className="font-semibold text-lg text-slate-900 mb-6">AI Health Score</h3>
                        <div className="flex justify-center mb-8">
                            <CircularProgress value={intelligenceData.overallScore} color="text-emerald-500" />
                        </div>
                        <div className="space-y-4">
                            <div>
                                <div className="flex justify-between text-sm mb-1">
                                    <span className="font-medium text-slate-700">Biomarkers</span>
                                    <span className="font-bold text-emerald-600">{intelligenceData.biomarkersScore}</span>
                                </div>
                                <div className="h-2 bg-slate-100 rounded-full overflow-hidden">
                                    <div className="h-full bg-emerald-500 rounded-full" style={{ width: `${intelligenceData.biomarkersScore}%` }}></div>
                                </div>
                            </div>
                            <div>
                                <div className="flex justify-between text-sm mb-1">
                                    <span className="font-medium text-slate-700">Lifestyle</span>
                                    <span className="font-bold text-blue-600">{intelligenceData.lifestyleScore}</span>
                                </div>
                                <div className="h-2 bg-slate-100 rounded-full overflow-hidden">
                                    <div className="h-full bg-blue-500 rounded-full" style={{ width: `${intelligenceData.lifestyleScore}%` }}></div>
                                </div>
                            </div>
                            <div>
                                <div className="flex justify-between text-sm mb-1">
                                    <span className="font-medium text-slate-700">Risk Factors</span>
                                    <span className="font-bold text-amber-600">{intelligenceData.riskFactorsScore}</span>
                                </div>
                                <div className="h-2 bg-slate-100 rounded-full overflow-hidden">
                                    <div className="h-full bg-amber-500 rounded-full" style={{ width: `${intelligenceData.riskFactorsScore}%` }}></div>
                                </div>
                            </div>
                        </div>
                    </div>

                    {/* Quick Actions */}
                    <div className="bg-white p-6 rounded-3xl shadow-soft border-none">
                        <h3 className="font-semibold text-lg text-slate-900 mb-4">Quick Actions</h3>
                        <div className="space-y-2">
                            {SUGGESTED_ACTIONS.slice(0, 3).map((action, idx) => (
                                <button key={idx} className="w-full text-left p-4 rounded-2xl bg-slate-50 hover:bg-slate-100 transition-colors flex items-center justify-between group">
                                    <span className="text-sm font-medium text-slate-700 group-hover:text-slate-900">{action}</span>
                                    <ChevronRight className="w-4 h-4 text-slate-400 group-hover:text-slate-600" />
                                </button>
                            ))}
                        </div>
                    </div>
                </div>

                {/* Right Column */}
                <div className="lg:col-span-8 space-y-6">
                    {/* Health Domains */}
                    <div className="bg-white p-6 rounded-3xl shadow-soft border-none">
                        <div className="flex justify-between items-center mb-6">
                            <h3 className="font-semibold text-lg text-slate-900">Health Domains</h3>
                            <button
                                onClick={() => navigate('/intelligence/domains')}
                                className="text-sm font-medium text-slate-500 hover:text-slate-900 flex items-center gap-1"
                            >
                                View All <ChevronRight className="w-4 h-4" />
                            </button>
                        </div>
                        <div className="grid grid-cols-2 sm:grid-cols-3 md:grid-cols-5 gap-4">
                            {healthDomains.map((domain) => (
                                <div key={domain.name} className="flex flex-col items-center">
                                    <div className="relative mb-3">
                                        <div className={`w-16 h-16 rounded-full border-4 ${domain.bg.replace('bg-', 'border-')} flex items-center justify-center`}>
                                            <domain.icon className={`w-6 h-6 ${domain.color}`} />
                                        </div>
                                        <svg className="absolute top-0 left-0 w-16 h-16 transform -rotate-90">
                                            <circle
                                                className={domain.color}
                                                strokeWidth="4"
                                                strokeDasharray={56 * Math.PI}
                                                strokeDashoffset={56 * Math.PI - (domain.score / 100) * (56 * Math.PI)}
                                                strokeLinecap="round"
                                                stroke="currentColor"
                                                fill="transparent"
                                                r="28"
                                                cx="32"
                                                cy="32"
                                            />
                                        </svg>
                                    </div>
                                    <span className="text-xs font-bold text-slate-900 mb-1">{domain.name}</span>
                                    <div className="flex items-center gap-1">
                                        <span className={`text-lg font-bold ${getGradeFromScore(domain.score).textColor}`}>
                                            {getGradeFromScore(domain.score).grade}
                                        </span>
                                    </div>
                                </div>
                            ))}
                        </div>
                    </div>

                    {/* Disease Risk Analysis */}
                    <div className="bg-white p-6 rounded-3xl shadow-soft border-none">
                        <div className="flex justify-between items-center mb-6">
                            <h3 className="font-semibold text-lg text-slate-900">Disease Risk Analysis</h3>
                            <button
                                onClick={() => navigate('/intelligence/risks')}
                                className="text-sm font-medium text-slate-500 hover:text-slate-900 flex items-center gap-1"
                            >
                                View Details <ChevronRight className="w-4 h-4" />
                            </button>
                        </div>
                        <div className="space-y-4">
                            {intelligenceData.diseaseRisks.map((risk, idx) => (
                                <div key={idx} className="p-5 rounded-3xl bg-slate-50 border border-slate-100 flex items-center justify-between">
                                    <div className="flex-1">
                                        <div className="flex items-center gap-3 mb-2">
                                            <h4 className="font-bold text-slate-900">{risk.condition}</h4>
                                            <span className={`text-[10px] font-bold px-2 py-0.5 rounded-full uppercase tracking-wide ${risk.level === 'High' ? 'bg-red-100 text-red-600' :
                                                risk.level === 'Moderate' ? 'bg-amber-100 text-amber-600' :
                                                    'bg-emerald-100 text-emerald-600'
                                                }`}>
                                                {risk.level}
                                            </span>
                                        </div>
                                        <p className="text-xs text-slate-500 mb-3">
                                            10-year probability based on current biomarkers and risk factors.
                                        </p>
                                        <div className="flex flex-wrap gap-2">
                                            {risk.drivers.map((driver, i) => (
                                                <span key={i} className="px-2 py-1 bg-white border border-slate-200 rounded-lg text-[10px] font-medium text-slate-600">
                                                    {driver}
                                                </span>
                                            ))}
                                        </div>
                                    </div>
                                    <div className="ml-4 flex-shrink-0">
                                        <SmallCircularProgress
                                            value={risk.probability}
                                            color={
                                                risk.level === 'High' ? 'text-red-500' :
                                                    risk.level === 'Moderate' ? 'text-amber-500' :
                                                        'text-emerald-500'
                                            }
                                        />
                                    </div>
                                </div>
                            ))}
                        </div>
                    </div>
                </div>
            </div>
        </div>
    );
};

export default Intelligence;
