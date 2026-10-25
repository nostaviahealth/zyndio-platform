import React, { useState, useMemo } from 'react';
import { useNavigate } from 'react-router-dom';
import { ArrowDown, Activity, Utensils, CheckCircle2, ChevronRight, Send, Sparkles, Quote, ArrowRight, CheckCircle, Moon, Zap, FileText, Clock, AlertCircle } from 'lucide-react';
import { LineChart, Line, XAxis, YAxis, CartesianGrid, Tooltip, ResponsiveContainer, ReferenceLine, RadarChart, PolarGrid, PolarAngleAxis, PolarRadiusAxis, Radar } from 'recharts';
import { useUser } from '../contexts/UserContext';
import { useAuth } from '../contexts/AuthContext';
import { supabase } from '../lib/supabase';
import { SkeletonCard, SkeletonStat } from '../components/LoadingSkeleton';

const Home: React.FC = () => {
    const navigate = useNavigate();
    const { user } = useAuth();
    const { patientProfile, loading, publishedIntelligence, publishedJourney, currentPhase, getProtocolSection } = useUser();
    const [selectedDiseaseIndex, setSelectedDiseaseIndex] = useState(0);
    const [completedRhythmItems, setCompletedRhythmItems] = useState<Set<string>>(new Set());
    const [activeTab, setActiveTab] = useState<'for-you' | 'food'>('for-you');

    const toggleRhythmItem = (id: string) => {
        setCompletedRhythmItems(prev => {
            const next = new Set(prev);
            if (next.has(id)) {
                next.delete(id);
            } else {
                next.add(id);
            }
            return next;
        });
    };

    // Compute personalized data from intelligence and protocol
    // ONLY use real published data - no fallbacks!
    const personalizedData = useMemo(() => {
        // Get user's chronological age from questionnaire
        const questionnaireAge = patientProfile?.age || null;

        // Only compute if intelligence is published
        const hasIntelligence = publishedIntelligence && publishedIntelligence.published;

        // Biological age - only if intelligence published
        const bioAge = hasIntelligence && questionnaireAge
            ? Math.round(questionnaireAge - (100 - publishedIntelligence.overallScore) / 10)
            : null;

        // Pace of aging - only if intelligence published
        const paceOfAging = hasIntelligence ? publishedIntelligence.lifestyleScore : null;

        // Age difference
        const ageDiff = (bioAge && questionnaireAge) ? questionnaireAge - bioAge : null;

        // Health domains - only from published intelligence, no fallback
        const healthDomains = hasIntelligence && publishedIntelligence.healthDomains?.length > 0
            ? publishedIntelligence.healthDomains.map(d => ({
                subject: d.name,
                A: d.score,
                fullMark: 100
            }))
            : null;

        // Disease risks - only from published intelligence, no fallback
        const diseaseRisks = hasIntelligence && publishedIntelligence.diseaseRisks?.length > 0
            ? publishedIntelligence.diseaseRisks
            : null;

        // Generate risk predictions for each disease - current + next 3 months
        const allDiseaseRiskHistories = diseaseRisks
            ? diseaseRisks.map(risk => {
                const currentRisk = risk.probability || 12;
                // Get current month and next 3 months
                const now = new Date();
                const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
                const currentMonth = months[now.getMonth()];
                const month1 = months[(now.getMonth() + 1) % 12];
                const month2 = months[(now.getMonth() + 2) % 12];
                const month3 = months[(now.getMonth() + 3) % 12];

                // Calculate predicted risk reduction (assumes ~2% reduction per month if following protocol)
                const predictedReduction = 2;
                return {
                    condition: risk.condition,
                    probability: currentRisk,
                    level: risk.level,
                    drivers: risk.drivers,
                    history: [
                        { date: currentMonth, value: currentRisk, label: 'Current' },
                        { date: month1, value: Math.max(currentRisk - predictedReduction, 5), label: 'Predicted' },
                        { date: month2, value: Math.max(currentRisk - predictedReduction * 2, 5), label: 'Predicted' },
                        { date: month3, value: Math.max(currentRisk - predictedReduction * 3, 5), label: 'Predicted' },
                    ]
                };
            })
            : null;

        // Get protocol items for Today's Rhythm - only if published sections exist
        const lifestyleSection = getProtocolSection('lifestyle');
        const dietSection = getProtocolSection('diet');
        const supplementsSection = getProtocolSection('supplements');

        // Only build rhythm items if at least one section is published
        const hasAnyProtocol = lifestyleSection || dietSection || supplementsSection;

        const rhythmItems = hasAnyProtocol ? [
            lifestyleSection?.items?.[0] && {
                title: lifestyleSection.items[0].name,
                desc: lifestyleSection.items[0].details || '',
                time: '07:00 AM',
                color: 'rose',
                icon: 'activity'
            },
            supplementsSection?.items?.[0] && {
                title: supplementsSection.items[0].name,
                desc: supplementsSection.items[0].details || '',
                time: '08:00 AM',
                color: 'purple',
                icon: 'zap'
            },
            dietSection?.items?.[0] && {
                title: dietSection.items[0].name,
                desc: dietSection.items[0].details || '',
                time: '01:00 PM',
                color: 'emerald',
                icon: 'utensils'
            },
            lifestyleSection?.items?.[1] && {
                title: lifestyleSection.items[1].name,
                desc: lifestyleSection.items[1].details || '',
                time: '10:30 PM',
                color: 'indigo',
                icon: 'moon'
            }
        ].filter(Boolean) : null;

        // Daily wisdom - only if intelligence published
        const wisdom = hasIntelligence && publishedIntelligence.diseaseRisks?.[0]
            ? {
                quote: `Focus on ${publishedIntelligence.diseaseRisks[0].drivers?.[0] || 'healthy habits'} to reduce your health risks.`,
                context: publishedIntelligence.healthDomains?.[0]
                    ? `Based on your ${publishedIntelligence.healthDomains[0].name} trends`
                    : "Based on your health analysis"
            }
            : null;

        return {
            bioAge,
            chronAge: questionnaireAge,
            ageDiff,
            paceOfAging,
            healthDomains,
            allDiseaseRiskHistories,
            rhythmItems,
            wisdom,
            hasIntelligence,
            hasProtocol: hasAnyProtocol
        };
    }, [patientProfile, publishedIntelligence, getProtocolSection]);

    // All hooks must be declared before any conditional returns
    const [dailyLog, setDailyLog] = useState({
        sleep: '',
        stress: 0,
        energy: 0,
        tags: [] as string[],
        note: ''
    });

    // Show loading skeleton while fetching profile
    if (loading) {
        return (
            <div className="space-y-6 max-w-7xl mx-auto px-4 py-8 animate-pulse">
                {/* Hero Stats Skeleton */}
                <div className="grid grid-cols-1 lg:grid-cols-12 gap-6">
                    {/* Bio Age Hero */}
                    <div className="lg:col-span-5 bg-white rounded-3xl p-6 border border-slate-100 h-48">
                        <div className="h-4 w-24 bg-slate-100 rounded mb-4"></div>
                        <div className="h-12 w-32 bg-slate-100 rounded mb-2"></div>
                        <div className="h-4 w-40 bg-slate-100 rounded"></div>
                    </div>
                    {/* Pace of Aging */}
                    <div className="lg:col-span-4 bg-white rounded-3xl p-6 border border-slate-100 h-48">
                        <div className="h-4 w-32 bg-slate-100 rounded mb-4"></div>
                        <div className="h-12 w-32 bg-slate-100 rounded mb-2"></div>
                        <div className="h-4 w-48 bg-slate-100 rounded"></div>
                    </div>
                    {/* Daily Wisdom */}
                    <div className="lg:col-span-3 bg-white rounded-3xl p-6 border border-slate-100 h-48">
                        <div className="h-4 w-24 bg-slate-100 rounded mb-4"></div>
                        <div className="space-y-2">
                            <div className="h-4 w-full bg-slate-100 rounded"></div>
                            <div className="h-4 w-3/4 bg-slate-100 rounded"></div>
                        </div>
                    </div>
                </div>

                {/* Charts Skeleton */}
                <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
                    <div className="lg:col-span-2 bg-white rounded-3xl p-6 border border-slate-100 h-80">
                        <div className="h-6 w-48 bg-slate-100 rounded mb-6"></div>
                        <div className="h-56 w-full bg-slate-100 rounded-xl"></div>
                    </div>
                    <div className="lg:col-span-1 bg-white rounded-3xl p-6 border border-slate-100 h-80">
                        <div className="h-6 w-32 bg-slate-100 rounded mb-6"></div>
                        <div className="h-48 w-48 mx-auto bg-slate-100 rounded-full"></div>
                    </div>
                </div>
            </div>
        );
    }

    // If user is not at protocol_ready stage, show onboarding
    if (!patientProfile || patientProfile.stage !== 'protocol_ready') {
        const rawStage = patientProfile?.stage || 'questionnaire_pending';
        const currentStage = rawStage === 'profile_creation' ? 'questionnaire_pending' : rawStage;

        // Define what action the user needs to take
        const getNextAction = (stage: string) => {
            switch (stage) {
                case 'questionnaire_pending':
                    return {
                        title: 'Complete Your Health Questionnaire',
                        description: 'Share your health history and goals to help us create your personalized protocol.',
                        action: 'Start Questionnaire',
                        route: '/questionnaire',
                        icon: FileText,
                        color: 'blue'
                    };
                case 'lab_test_scheduled':
                    return {
                        title: 'Schedule Your Lab Test',
                        description: 'Book your comprehensive lab test to unlock AI-powered health insights.',
                        action: 'Schedule Test',
                        route: '/lab-test',
                        icon: Activity,
                        color: 'purple'
                    };
                case 'lab_processing':
                    return {
                        title: 'Lab Results Processing',
                        description: 'Our team is analyzing your lab results. You\'ll be notified once complete.',
                        action: null,
                        route: null,
                        icon: Clock,
                        color: 'amber'
                    };
                case 'doctor_verification':
                case 'intelligence_generation':
                case 'consultation_scheduled':
                    return {
                        title: 'Wellness Optimization in Progress',
                        description: 'Our wellness expertise team is reviewing your results and creating your personalized protocol.',
                        action: null,
                        route: null,
                        icon: AlertCircle,
                        color: 'orange'
                    };
                default:
                    return {
                        title: 'Get Started',
                        description: 'Begin your journey to optimized longevity.',
                        action: 'Continue',
                        route: '/questionnaire',
                        icon: Sparkles,
                        color: 'emerald'
                    };
            }
        };

        const nextAction = getNextAction(currentStage);
        const Icon = nextAction.icon;

        return (
            <div className="max-w-4xl mx-auto py-12 px-4">
                {/* Header */}
                <div className="text-center mb-12">
                    <h1 className="text-4xl font-serif text-slate-900 mb-4">Welcome to Zyndio</h1>
                    <p className="text-lg text-slate-600">
                        Your journey to optimized longevity has begun
                    </p>
                </div>

                {/* Action Card */}
                <div className="bg-gradient-to-br from-white to-slate-50 rounded-3xl border border-slate-200 p-8 md:p-10 shadow-lg">
                    <div className="flex items-start gap-6">
                        <div className={`flex-shrink-0 w-16 h-16 rounded-2xl bg-${nextAction.color}-100 flex items-center justify-center`}>
                            <Icon className={`w-8 h-8 text-${nextAction.color}-600`} />
                        </div>
                        <div className="flex-1">
                            <h2 className="text-2xl font-bold text-slate-900 mb-3">{nextAction.title}</h2>
                            <p className="text-slate-600 mb-6 leading-relaxed">
                                {nextAction.description}
                            </p>
                            {nextAction.action && nextAction.route && (
                                <button
                                    onClick={() => navigate(nextAction.route!)}
                                    className="bg-brand-dark text-white px-8 py-3 rounded-xl font-medium hover:bg-slate-800 transition-all shadow-lg flex items-center gap-2"
                                >
                                    {nextAction.action}
                                    <ChevronRight className="w-5 h-5" />
                                </button>
                            )}
                            {!nextAction.action && (
                                <div className="flex items-center gap-2 text-slate-500">
                                    <Clock className="w-5 h-5 animate-pulse" />
                                    <span className="font-medium">We'll notify you when ready</span>
                                </div>
                            )}
                        </div>
                    </div>
                </div>

                {/* Info Cards */}
                <div className="grid grid-cols-1 md:grid-cols-3 gap-4 mt-8">
                    <div className="bg-white rounded-2xl border border-slate-200 p-6 text-center">
                        <div className="w-12 h-12 bg-blue-50 rounded-xl flex items-center justify-center mx-auto mb-3">
                            <Activity className="w-6 h-6 text-blue-600" />
                        </div>
                        <h3 className="font-semibold text-slate-900 mb-2">Comprehensive Testing</h3>
                        <p className="text-sm text-slate-600">100+ biomarker analysis</p>
                    </div>
                    <div className="bg-white rounded-2xl border border-slate-200 p-6 text-center">
                        <div className="w-12 h-12 bg-purple-50 rounded-xl flex items-center justify-center mx-auto mb-3">
                            <Sparkles className="w-6 h-6 text-purple-600" />
                        </div>
                        <h3 className="font-semibold text-slate-900 mb-2">AI-Powered Insights</h3>
                        <p className="text-sm text-slate-600">Personalized recommendations</p>
                    </div>
                    <div className="bg-white rounded-2xl border border-slate-200 p-6 text-center">
                        <div className="w-12 h-12 bg-green-50 rounded-xl flex items-center justify-center mx-auto mb-3">
                            <CheckCircle className="w-6 h-6 text-green-600" />
                        </div>
                        <h3 className="font-semibold text-slate-900 mb-2">Expert Review</h3>
                        <p className="text-sm text-slate-600">Clinician-verified protocols</p>
                    </div>
                </div>
            </div>
        );
    }

    return (
        <div className="space-y-4 md:space-y-6">


            {activeTab === 'for-you' ? (
                <>
                    {/* Top Row: Hero Stats */}
            <div className="grid grid-cols-1 lg:grid-cols-12 gap-4 md:gap-6">
                {/* Biological Age Card */}
                <div className="bg-white p-5 rounded-3xl shadow-soft border border-slate-100 relative overflow-hidden group hover:shadow-lg transition-all duration-300 lg:col-span-5 flex flex-row items-center justify-between gap-4">
                    <div className="z-10 space-y-2 flex-1 min-w-0">
                        <h3 className="text-slate-500 font-medium text-xs uppercase tracking-wider">Biological Age</h3>
                        {personalizedData.hasIntelligence ? (
                            <>
                                <div className="flex flex-col items-start gap-0.5">
                                    <span className="text-5xl font-bold text-brand-dark tracking-tight">{personalizedData.bioAge}</span>
                                    <span className="text-slate-400 font-medium text-xs">vs {personalizedData.chronAge} Chronological</span>
                                </div>
                                <div className="flex justify-start mt-2">
                                    <div className="flex items-center gap-1 text-emerald-600 bg-emerald-50 px-3 py-1 rounded-full text-xs font-bold whitespace-nowrap">
                                        <ArrowDown className="w-3 h-3" />
                                        {personalizedData.ageDiff} Years Younger
                                    </div>
                                </div>
                                <p className="text-xs text-slate-500 mt-3 leading-relaxed hidden sm:block">
                                    Your cellular aging has slowed down. Keep focusing on <span className="text-brand-dark font-semibold">Stress Management</span> to reach -{(personalizedData.ageDiff || 0) + 1} years.
                                </p>
                            </>
                        ) : (
                            <div className="py-4">
                                <p className="text-2xl font-semibold text-slate-300">Pending</p>
                                <p className="text-xs text-slate-400 mt-2">Your intelligence analysis is being prepared by our expertise team.</p>
                            </div>
                        )}
                    </div>

                    {/* Decorative Gauge/Visual */}
                    <div className="relative w-32 h-32 flex-shrink-0">
                        {/* Gauge Background */}
                        <svg className="w-full h-full transform -rotate-90">
                            <circle
                                cx="64"
                                cy="64"
                                r="56"
                                stroke="#f5f5f4"
                                strokeWidth="8"
                                fill="none"
                            />
                            <circle
                                cx="64"
                                cy="64"
                                r="56"
                                stroke="#10b981"
                                strokeWidth="8"
                                fill="none"
                                strokeDasharray="351"
                                strokeDashoffset="70"
                                strokeLinecap="round"
                                className="drop-shadow-sm"
                            />
                        </svg>
                        <div className="absolute inset-0 flex flex-col items-center justify-center">
                            <span className="text-[10px] text-slate-400 font-medium uppercase tracking-wide">Cellular</span>
                            <span className="text-lg font-bold text-emerald-600">Good</span>
                        </div>
                    </div>
                </div>

                {/* Pace of Aging Card */}
                <div className="bg-white p-5 rounded-3xl shadow-soft border border-slate-100 relative overflow-hidden group hover:shadow-lg transition-all duration-300 lg:col-span-3">
                    {/* Decorative Background */}
                    <div className="absolute top-0 right-0 w-24 h-24 bg-slate-200 rounded-full blur-3xl opacity-50 -mr-8 -mt-8"></div>

                    <div className="relative z-10 space-y-3">
                        <h3 className="text-slate-500 font-medium text-xs uppercase tracking-wider">Pace of Aging</h3>
                        {personalizedData.hasIntelligence && personalizedData.paceOfAging ? (
                            <>
                                <div className="flex items-baseline gap-2">
                                    <span className="text-5xl font-bold tracking-tight text-emerald-600">
                                        {personalizedData.paceOfAging}
                                    </span>
                                    <span className="text-2xl font-semibold text-emerald-600">%</span>
                                </div>

                                <div className="space-y-2">
                                    <div className="flex items-center gap-2">
                                        <div className="h-2 flex-1 bg-slate-100 rounded-full overflow-hidden">
                                            <div
                                                className="h-full rounded-full transition-all duration-500 bg-gradient-to-r from-emerald-500 to-emerald-400"
                                                style={{ width: `${100 - personalizedData.paceOfAging}%` }}
                                            ></div>
                                        </div>
                                    </div>

                                    <p className="text-xs text-slate-600 font-medium">
                                        Aging {100 - personalizedData.paceOfAging}% slower than normal
                                    </p>
                                </div>

                                <div className="pt-2 border-t border-slate-100">
                                    <p className="text-[10px] text-slate-400 leading-relaxed">
                                        For every year that passes, you age only <span className="text-brand-dark font-bold">{(personalizedData.paceOfAging / 100 * 12).toFixed(1)} months</span> biologically.
                                    </p>
                                </div>
                            </>
                        ) : (
                            <div className="py-4">
                                <p className="text-2xl font-semibold text-slate-300">Pending</p>
                                <p className="text-xs text-slate-400 mt-2">Awaiting published intelligence data.</p>
                            </div>
                        )}
                    </div>
                </div>

                {/* Daily Wisdom / Personalized Insight */}
                <div
                    onClick={() => navigate('/intelligence')}
                    className="bg-brand-dark text-white p-4 md:p-6 rounded-2xl md:rounded-3xl shadow-glow flex flex-col justify-between relative overflow-hidden cursor-pointer group transition-all hover:scale-[1.02] hover:shadow-xl lg:col-span-4"
                >
                    {/* Decorative Blur */}
                    <div className="absolute top-0 right-0 w-32 h-32 bg-brand-gold rounded-full blur-3xl opacity-10 -mr-10 -mt-10"></div>

                    <div className="flex items-center justify-between z-10">
                        <h3 className="text-slate-400 font-medium text-sm uppercase tracking-wider flex items-center gap-2">
                            <Sparkles className="w-3 h-3 text-brand-gold" /> Daily Wisdom
                        </h3>
                        <Quote className="w-5 h-5 text-slate-600 opacity-50" />
                    </div>

                    {personalizedData.wisdom ? (
                        <>
                            <div className="z-10 mt-3 md:mt-4 mb-3 md:mb-4">
                                <p className="font-serif text-base md:text-xl italic text-white leading-relaxed opacity-90">
                                    "{personalizedData.wisdom.quote}"
                                </p>
                            </div>

                            <div className="mt-auto z-10">
                                <div className="h-px w-full bg-slate-700/50 mb-3"></div>
                                <div className="flex items-center justify-between text-xs">
                                    <span className="text-brand-gold font-medium">{personalizedData.wisdom.context}</span>
                                    <div className="flex items-center gap-1 text-slate-300 group-hover:text-white transition-colors">
                                        <span>Discuss with AI</span>
                                        <ArrowRight className="w-3 h-3" />
                                    </div>
                                </div>
                            </div>
                        </>
                    ) : (
                        <div className="z-10 mt-4 mb-4">
                            <p className="font-serif text-lg italic text-slate-400 leading-relaxed">
                                Your personalized insights will appear here once your intelligence analysis is published.
                            </p>
                        </div>
                    )}
                </div>
            </div>

            {/* Middle Row: Charts */}
            <div className="grid grid-cols-1 lg:grid-cols-3 gap-4 md:gap-6">
                {/* Disease Risk Trends */}
                <div className="bg-white p-4 md:p-6 rounded-2xl md:rounded-3xl shadow-soft border border-slate-100 lg:col-span-2">
                    <div className="flex justify-between items-center mb-6">
                        <div>
                            <h3 className="font-semibold text-lg text-brand-dark">
                                Watchlist: {personalizedData.allDiseaseRiskHistories?.[selectedDiseaseIndex]?.condition || 'Disease Risk'}
                            </h3>
                            <p className="text-xs text-slate-500">Predicted 3-Month Risk Trajectory (If Following Protocol)</p>
                        </div>
                        {personalizedData.allDiseaseRiskHistories && (
                            <select
                                className="bg-slate-50 border-none text-sm text-slate-600 rounded-lg px-3 py-2 outline-none cursor-pointer hover:bg-slate-100 transition-colors"
                                value={selectedDiseaseIndex}
                                onChange={(e) => setSelectedDiseaseIndex(Number(e.target.value))}
                            >
                                {personalizedData.allDiseaseRiskHistories.map((disease, index) => (
                                    <option key={index} value={index}>{disease.condition}</option>
                                ))}
                            </select>
                        )}
                    </div>

                    {personalizedData.allDiseaseRiskHistories ? (
                        <div className="h-64 w-full">
                            <ResponsiveContainer width="100%" height="100%">
                                <LineChart data={personalizedData.allDiseaseRiskHistories[selectedDiseaseIndex]?.history || []}>
                                    <CartesianGrid strokeDasharray="3 3" vertical={false} stroke="#f0f0f0" />
                                    <XAxis dataKey="date" axisLine={false} tickLine={false} tick={{ fill: '#94a3b8', fontSize: 12 }} dy={10} />
                                    <YAxis domain={[0, 30]} axisLine={false} tickLine={false} tick={{ fill: '#94a3b8', fontSize: 12 }} unit="%" />
                                    <Tooltip
                                        contentStyle={{ backgroundColor: '#1e293b', border: 'none', borderRadius: '8px', color: '#fff' }}
                                        itemStyle={{ color: '#cbd5e1' }}
                                        formatter={(value: number, name: string, props: any) => {
                                            const label = props.payload?.label === 'Current' ? 'Current Risk' : 'Predicted Risk';
                                            return [`${value}%`, label];
                                        }}
                                    />
                                    {/* Target Range Indicator */}
                                    <ReferenceLine y={10} stroke="#10b981" strokeDasharray="3 3" label={{ position: 'insideTopRight', value: 'Low Risk Goal (<10%)', fill: '#10b981', fontSize: 10 }} />

                                    <Line
                                        type="monotone"
                                        dataKey="value"
                                        stroke="#0f172a"
                                        strokeWidth={3}
                                        strokeDasharray="0"
                                        dot={(props: any) => {
                                            const { cx, cy, payload } = props;
                                            const isCurrent = payload?.label === 'Current';
                                            return (
                                                <circle
                                                    cx={cx}
                                                    cy={cy}
                                                    r={isCurrent ? 6 : 4}
                                                    fill={isCurrent ? '#10b981' : '#0f172a'}
                                                    stroke="#fff"
                                                    strokeWidth={2}
                                                />
                                            );
                                        }}
                                        activeDot={{ r: 6, fill: '#f59e0b' }}
                                    />
                                </LineChart>
                            </ResponsiveContainer>
                        </div>
                    ) : (
                        <div className="h-64 w-full flex items-center justify-center">
                            <div className="text-center">
                                <AlertCircle className="w-12 h-12 text-slate-200 mx-auto mb-3" />
                                <p className="text-slate-400 font-medium">Awaiting Published Data</p>
                                <p className="text-xs text-slate-300 mt-1">Your disease risk analysis will appear here once published.</p>
                            </div>
                        </div>
                    )}
                </div>

                {/* Disease Risk Radar */}
                <div className="bg-white p-6 rounded-3xl shadow-soft border border-slate-100 flex flex-col">
                    <h3 className="font-semibold text-lg text-brand-dark mb-2">System Balance</h3>
                    <p className="text-xs text-slate-500 mb-4">Ayurvedic & Allopathic Integration</p>

                    {personalizedData.healthDomains ? (
                        <div className="flex-1 min-h-[250px] relative">
                            <ResponsiveContainer width="100%" height="100%">
                                <RadarChart cx="50%" cy="50%" outerRadius="70%" data={personalizedData.healthDomains}>
                                    <PolarGrid gridType="circle" stroke="#e2e8f0" />
                                    <PolarAngleAxis dataKey="subject" tick={{ fill: '#64748b', fontSize: 10, fontWeight: 500 }} />
                                    <PolarRadiusAxis angle={30} domain={[0, 100]} tick={false} axisLine={false} />
                                    <Radar
                                        name="Health Score"
                                        dataKey="A"
                                        stroke="#059669"
                                        fill="#10b981"
                                        fillOpacity={0.2}
                                    />
                                </RadarChart>
                            </ResponsiveContainer>
                        </div>
                    ) : (
                        <div className="flex-1 min-h-[250px] flex items-center justify-center">
                            <div className="text-center">
                                <AlertCircle className="w-12 h-12 text-slate-200 mx-auto mb-3" />
                                <p className="text-slate-400 font-medium">Awaiting Published Data</p>
                                <p className="text-xs text-slate-300 mt-1">Health domains will appear here once published.</p>
                            </div>
                        </div>
                    )}
                </div>
            </div>

            {/* Redesigned Daily Protocol Section: Today's Rhythm */}
            <div className="bg-white p-6 rounded-3xl shadow-soft border border-slate-100 relative overflow-hidden">
                <div className="flex items-center justify-between mb-6">
                    <div>
                        <h3 className="font-semibold text-lg text-brand-dark">Today's Rhythm</h3>
                        <p className="text-xs text-slate-500">Stay in sync with your circadian clock.</p>
                    </div>
                    <button
                        onClick={() => navigate('/protocol')}
                        className="text-xs font-medium text-brand-dark hover:text-zyndio-blue transition-colors"
                    >
                        View Full Schedule
                    </button>
                </div>

                <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4">
                    {/* Card 1: Movement */}
                    <div className={`p-4 rounded-2xl border flex flex-col gap-3 group cursor-pointer hover:shadow-md transition-all ${completedRhythmItems.has('morning_yoga')
                        ? 'bg-orange-100 border-orange-200'
                        : 'bg-orange-50 border-orange-100'
                        }`}>
                        <div className="flex justify-between items-start">
                            <div className={`w-10 h-10 rounded-full flex items-center justify-center shadow-sm ${completedRhythmItems.has('morning_yoga')
                                ? 'bg-orange-200 text-orange-700'
                                : 'bg-white text-orange-500'
                                }`}>
                                <Activity className="w-5 h-5" />
                            </div>
                            <span className={`text-[10px] font-bold uppercase tracking-wide px-2 py-1 rounded-full ${completedRhythmItems.has('morning_yoga')
                                ? 'bg-orange-200 text-orange-800'
                                : 'bg-white text-orange-400'
                                }`}>07:00 AM</span>
                        </div>
                        <div>
                            <h4 className="font-semibold text-slate-900">Morning Yoga</h4>
                            <p className="text-xs text-slate-500">15 min • Cortisol Awakening</p>
                        </div>
                        <button
                            onClick={() => toggleRhythmItem('morning_yoga')}
                            className={`mt-auto pt-2 flex items-center gap-2 text-xs font-medium group-hover:text-orange-700 transition-colors ${completedRhythmItems.has('morning_yoga') ? 'text-orange-800' : 'text-orange-600'
                                }`}
                        >
                            <CheckCircle2 className={`w-4 h-4 ${completedRhythmItems.has('morning_yoga') ? 'fill-current' : ''}`} />
                            {completedRhythmItems.has('morning_yoga') ? 'Done' : 'Mark Done'}
                        </button>
                    </div>

                    {/* Card 2: Supplement */}
                    <div className={`p-4 rounded-2xl border flex flex-col gap-3 group cursor-pointer hover:shadow-md transition-all ${completedRhythmItems.has('ashwagandha')
                        ? 'bg-purple-100 border-purple-200'
                        : 'bg-purple-50 border-purple-100'
                        }`}>
                        <div className="flex justify-between items-start">
                            <div className={`w-10 h-10 rounded-full flex items-center justify-center shadow-sm ${completedRhythmItems.has('ashwagandha')
                                ? 'bg-purple-200 text-purple-700'
                                : 'bg-white text-purple-500'
                                }`}>
                                <Zap className="w-5 h-5" />
                            </div>
                            <span className={`text-[10px] font-bold uppercase tracking-wide px-2 py-1 rounded-full ${completedRhythmItems.has('ashwagandha')
                                ? 'bg-purple-200 text-purple-800'
                                : 'bg-white text-purple-400'
                                }`}>08:00 AM</span>
                        </div>
                        <div>
                            <h4 className="font-semibold text-slate-900">Ashwagandha</h4>
                            <p className="text-xs text-slate-500">300mg • Stress Resilience</p>
                        </div>
                        <button
                            onClick={() => toggleRhythmItem('ashwagandha')}
                            className={`mt-auto pt-2 flex items-center gap-2 text-xs font-medium group-hover:text-purple-700 transition-colors ${completedRhythmItems.has('ashwagandha') ? 'text-purple-800' : 'text-purple-600'
                                }`}
                        >
                            <CheckCircle2 className={`w-4 h-4 ${completedRhythmItems.has('ashwagandha') ? 'fill-current' : ''}`} />
                            {completedRhythmItems.has('ashwagandha') ? 'Done' : 'Mark Done'}
                        </button>
                    </div>

                    {/* Card 3: Nutrition */}
                    <div className="p-4 rounded-2xl bg-emerald-50 border border-emerald-100 flex flex-col gap-3 group cursor-pointer hover:shadow-md transition-all">
                        <div className="flex justify-between items-start">
                            <div className="w-10 h-10 rounded-full bg-white flex items-center justify-center text-emerald-500 shadow-sm">
                                <Utensils className="w-5 h-5" />
                            </div>
                            <span className="text-[10px] font-bold text-emerald-400 uppercase tracking-wide bg-white px-2 py-1 rounded-full">01:00 PM</span>
                        </div>
                        <div>
                            <h4 className="font-semibold text-slate-900">Mung Bean Soup</h4>
                            <p className="text-xs text-slate-500">Pitta Pacifying Meal</p>
                        </div>
                        <button
                            onClick={() => navigate('/protocol?section=diet')}
                            className="mt-auto pt-2 flex items-center gap-2 text-xs font-medium text-emerald-600 group-hover:text-emerald-700"
                        >
                            <ChevronRight className="w-4 h-4" /> View Recipe
                        </button>
                    </div>

                    {/* Card 4: Sleep */}
                    <div className="p-4 rounded-2xl bg-indigo-50 border border-indigo-100 flex flex-col gap-3 group cursor-pointer hover:shadow-md transition-all">
                        <div className="flex justify-between items-start">
                            <div className="w-10 h-10 rounded-full bg-white flex items-center justify-center text-indigo-500 shadow-sm">
                                <Moon className="w-5 h-5" />
                            </div>
                            <span className="text-[10px] font-bold text-indigo-400 uppercase tracking-wide bg-white px-2 py-1 rounded-full">10:30 PM</span>
                        </div>
                        <div>
                            <h4 className="font-semibold text-slate-900">Wind Down</h4>
                            <p className="text-xs text-slate-500">No screens • Melatonin Boost</p>
                        </div>
                        <button
                            onClick={() => navigate('/protocol?section=lifestyle')}
                            className="mt-auto pt-2 flex items-center gap-2 text-xs font-medium text-indigo-600 group-hover:text-indigo-700"
                        >
                            <ChevronRight className="w-4 h-4" /> View Routine
                        </button>
                    </div>
                </div>
            </div>

            {/* New Section: Daily Bio-Log */}
            <div className="bg-white p-6 rounded-3xl shadow-soft border border-slate-100 relative overflow-hidden">
                <div className="flex items-center justify-between mb-6">
                    <div>
                        <h3 className="font-semibold text-lg text-brand-dark">Daily Bio-Log</h3>
                        <p className="text-xs text-slate-500">Track your vitals to train your AI model.</p>
                    </div>
                    <span className="text-xs text-slate-400 font-medium uppercase tracking-wider bg-slate-50 px-3 py-1 rounded-full">
                        {new Date().toLocaleDateString('en-US', { weekday: 'long', month: 'short', day: 'numeric' })}
                    </span>
                </div>

                <div className="flex flex-col md:flex-row gap-8 items-center">
                    {/* Sleep */}
                    <div className="flex-1 w-full space-y-3">
                        <label className="text-xs font-bold text-slate-400 uppercase tracking-wide flex items-center gap-2">
                            <Moon className="w-3 h-3" /> Sleep Quality
                        </label>
                        <div className="flex gap-2">
                            {['Poor', 'Fair', 'Good', 'Great'].map((level) => (
                                <button
                                    key={level}
                                    onClick={() => setDailyLog(prev => ({ ...prev, sleep: level }))}
                                    className={`flex-1 py-3 rounded-xl text-sm font-medium border transition-all focus:ring-2 focus:ring-brand-dark/20 ${dailyLog.sleep === level
                                        ? 'bg-brand-dark text-white border-brand-dark shadow-md'
                                        : 'bg-slate-50 text-slate-600 border-slate-100 hover:border-brand-dark hover:text-brand-dark hover:bg-slate-50'
                                        }`}
                                >
                                    {level}
                                </button>
                            ))}
                        </div>
                    </div>

                    {/* Stress */}
                    <div className="flex-1 w-full space-y-3">
                        <label className="text-xs font-bold text-slate-400 uppercase tracking-wide flex items-center gap-2">
                            <Activity className="w-3 h-3" /> Stress
                        </label>
                        <div className="flex justify-between bg-slate-50 p-2 rounded-xl">
                            {[1, 2, 3, 4, 5].map((lvl) => (
                                <button
                                    key={lvl}
                                    onClick={() => setDailyLog(prev => ({ ...prev, stress: lvl }))}
                                    className={`w-10 h-10 rounded-lg text-sm font-bold transition-all ${dailyLog.stress === lvl
                                        ? 'bg-brand-dark text-white shadow-md scale-110'
                                        : 'text-slate-500 hover:bg-white hover:shadow-sm hover:text-brand-dark'
                                        }`}
                                >
                                    {lvl}
                                </button>
                            ))}
                        </div>
                    </div>

                    {/* Energy */}
                    <div className="flex-1 w-full space-y-3">
                        <label className="text-xs font-bold text-slate-400 uppercase tracking-wide flex items-center gap-2">
                            <Zap className="w-3 h-3" /> Energy
                        </label>
                        <div className="flex justify-between bg-slate-50 p-2 rounded-xl">
                            {[1, 2, 3, 4, 5].map((lvl) => (
                                <button
                                    key={lvl}
                                    onClick={() => setDailyLog(prev => ({ ...prev, energy: lvl }))}
                                    className={`w-10 h-10 rounded-lg text-sm font-bold transition-all ${dailyLog.energy === lvl
                                        ? 'bg-brand-gold text-white shadow-md scale-110'
                                        : 'text-slate-500 hover:bg-white hover:shadow-sm hover:text-brand-dark'
                                        }`}
                                >
                                    {lvl}
                                </button>
                            ))}
                        </div>
                    </div>
                </div>

                <div className="mt-6 flex justify-end">
                    <button
                        onClick={async () => {
                            if (!patientProfile?.id) {
                                alert('Please complete your profile first.');
                                return;
                            }
                            if (!dailyLog.sleep && !dailyLog.stress && !dailyLog.energy) {
                                alert('Please log at least one vital.');
                                return;
                            }
                            try {
                                const { error } = await supabase
                                    .from('daily_bio_logs')
                                    .insert({
                                        profile_id: patientProfile.id,
                                        sleep_quality: dailyLog.sleep || null,
                                        stress_level: dailyLog.stress || null,
                                        energy_level: dailyLog.energy || null,
                                    });
                                if (error) throw error;
                                alert('Vitals logged successfully!');
                                setDailyLog(prev => ({ ...prev, sleep: '', stress: 0, energy: 0 }));
                            } catch (err: any) {
                                console.error('Error logging vitals:', err);
                                alert('Failed to log vitals. Please try again.');
                            }
                        }}
                        className="bg-brand-dark text-white px-6 py-2 rounded-xl text-sm font-medium shadow-glow hover:bg-slate-800 transition-colors flex items-center gap-2"
                    >
                        Log Vitals <CheckCircle2 className="w-4 h-4" />
                    </button>
                </div>
            </div>

            {/* New Section: Daily Journal */}
            <div className="bg-gradient-to-br from-white to-slate-50 p-8 rounded-3xl shadow-soft border border-slate-100 relative overflow-hidden">
                <div className="flex items-center gap-3 mb-6">
                    <div className="w-10 h-10 rounded-xl bg-slate-100 flex items-center justify-center text-brand-dark">
                        <Quote className="w-5 h-5" />
                    </div>
                    <div>
                        <h3 className="font-serif text-2xl text-slate-900">Daily Journal</h3>
                        <p className="text-sm text-slate-500">Reflect on your day, symptoms, or gratitude.</p>
                    </div>
                </div>

                <div className="relative">
                    <textarea
                        value={dailyLog.note}
                        onChange={(e) => setDailyLog(prev => ({ ...prev, note: e.target.value }))}
                        placeholder="Write your thoughts here..."
                        className="w-full bg-white border-none shadow-inner rounded-2xl p-6 text-base outline-none focus:ring-2 focus:ring-brand-dark/10 transition-all placeholder-slate-300 text-slate-700 resize-none h-48 leading-relaxed"
                    ></textarea>
                    <div className="absolute bottom-4 right-4 flex gap-2">
                        <button className="p-2 rounded-lg text-slate-400 hover:bg-slate-100 hover:text-brand-dark transition-colors" title="Add Photo">
                            <Sparkles className="w-5 h-5" />
                        </button>
                        <button
                            onClick={async () => {
                                if (!patientProfile?.id) {
                                    alert('Please complete your profile first.');
                                    return;
                                }
                                if (!dailyLog.note.trim()) {
                                    alert('Please write something before saving.');
                                    return;
                                }
                                try {
                                    const { error } = await supabase
                                        .from('daily_journals')
                                        .insert({
                                            profile_id: patientProfile.id,
                                            content: dailyLog.note.trim(),
                                        });
                                    if (error) throw error;
                                    alert('Journal entry saved!');
                                    setDailyLog(prev => ({ ...prev, note: '' }));
                                } catch (err: any) {
                                    console.error('Error saving journal:', err);
                                    alert('Failed to save journal. Please try again.');
                                }
                            }}
                            className="bg-brand-dark text-white px-6 py-2 rounded-xl text-sm font-medium shadow-lg shadow-slate-900/20 hover:bg-slate-800 transition-all flex items-center gap-2"
                        >
                            Save Entry <Send className="w-4 h-4" />
                        </button>
                    </div>
                </div>
                </div>
                </>
            ) : (
                <div className="space-y-6 animate-in fade-in slide-in-from-bottom-4 duration-500">
                    <div 
                        onClick={() => navigate('/food-intelligence')}
                        className="bg-gradient-to-b from-[#10B981] to-[#022C22] rounded-[32px] pt-8 px-8 pb-[21px] text-white shadow-2xl relative overflow-hidden group min-h-[440px] flex flex-col items-center cursor-pointer active:scale-[0.99] transition-all"
                    >
                        {/* Background Decorative Glow */}
                        <div className="absolute top-0 w-full h-80 bg-[radial-gradient(circle_at_50%_-20%,rgba(16,185,129,0.15),transparent_70%)] pointer-events-none" />

                        <div className="relative z-10 w-full flex flex-col items-center flex-1">
                            <h3 className="text-white/50 text-[11px] font-black tracking-[0.2em] uppercase mb-10">Food Intelligence</h3>

                            {/* Segmented SVG Dial */}
                            <div className="relative w-full max-w-[280px] aspect-[1.5/1] flex flex-col items-center justify-center">
                                <svg viewBox="0 0 200 120" className="w-full h-full transform -rotate-0">
                                    {Array.from({ length: 40 }).map((_, i) => {
                                        const angle = -190 + (i * 5); // Start at -190deg, 5deg per segment
                                        const radius = 85;
                                        const innerRadius = 72;
                                        const progress = 1450 / 2200;
                                        const isActive = i / 40 < progress;
                                        
                                        const x1 = 100 + radius * Math.cos((angle * Math.PI) / 180);
                                        const y1 = 110 + radius * Math.sin((angle * Math.PI) / 180);
                                        const x2 = 100 + innerRadius * Math.cos((angle * Math.PI) / 180);
                                        const y2 = 110 + innerRadius * Math.sin((angle * Math.PI) / 180);

                                        return (
                                            <line
                                                key={i}
                                                x1={x1}
                                                y1={y1}
                                                x2={x2}
                                                y2={y2}
                                                stroke={isActive ? "white" : "rgba(255,255,255,0.1)"}
                                                strokeWidth="4"
                                                strokeLinecap="round"
                                                className="transition-all duration-700 ease-out"
                                                style={{ transitionDelay: `${i * 10}ms` }}
                                            />
                                        );
                                    })}
                                </svg>
                                
                                {/* Dial Content */}
                                <div className="absolute top-1/2 left-1/2 -translate-x-1/2 -translate-y-1/4 flex flex-col items-center mt-[20px]">
                                    <div className="flex flex-col items-center">
                                        <span className="text-5xl font-bold text-white tracking-tighter leading-none">1450</span>
                                        <span className="text-xs font-semibold text-white/30 uppercase tracking-[0.2em] mt-1">kcal</span>
                                    </div>
                                    <div className="mt-4 bg-white/10 backdrop-blur-md px-3 py-1.5 rounded-full border border-white/10 flex items-center gap-2">
                                        <span className="text-[9px] font-black tracking-widest uppercase text-white/80">
                                            {(() => {
                                                const cal = 1450;
                                                if (cal === 0) return "FASTING";
                                                const phases = ["ABSORPTION", "REPLENISHING", "REBUILDING"];
                                                const phase = cal < 500 ? phases[0] : (cal < 1500 ? phases[1] : phases[2]);
                                                return phase;
                                            })()}
                                        </span>
                                    </div>
                                </div>
                            </div>

                            {/* Analysis Text */}
                            <div className="text-center mt-4 mb-8">
                                <p className="text-[15px] font-bold text-white/90 mb-1 tracking-tight">
                                    {(() => {
                                        const cal = 1450;
                                        if (cal === 0) return "Your body is repairing";
                                        if (cal < 500) return "Processing your last meal";
                                        if (cal < 1500) return "Refilling your fuel tanks";
                                        return "Building and recovering";
                                    })()}
                                </p>
                                <p className="text-xs text-white/40 leading-relaxed max-w-[300px] mx-auto">
                                    {(() => {
                                        const cal = 1450;
                                        const pro = 112;
                                        const carb = 154;
                                        const fat = 45;
                                        const goalPro = 150;
                                        const goalCal = 2200;

                                        // Profile Logic
                                        let profile = "balanced";
                                        if (cal === 0) profile = "start";
                                        else {
                                            const total = pro + carb + fat;
                                            if (pro / total > 0.35) profile = "protein";
                                            else if (carb / total > 0.45) profile = "carb";
                                            else if (fat / total > 0.35) profile = "fat";
                                        }

                                        // Matrix
                                        if (cal === 0) {
                                            if (profile === "start") return "Good morning! Your body spent the night repairing. You're primed and ready for your first meal.";
                                            return "You're in deep repair mode. Your body is clearing old cells, but let's prioritize protein in your next meal.";
                                        }
                                        if (cal < 500) {
                                            if (profile === "protein") return "You've fueled up with quality protein. Your body is busy breaking this down to support your muscle tissue.";
                                            if (profile === "carb") return "You've got a fresh energy boost. Your body is converting those carbs into immediate fuel for your brain.";
                                            return "Your body is taking in nutrients from your recent log to fuel your upcoming activity levels.";
                                        }
                                        if (cal < 1500) {
                                            if (profile === "protein") return "Your energy stores are refilling, and that extra protein is ensuring your recovery is high-quality today.";
                                            if (profile === "carb") return "You're topping up your glycogen tanks. You'll feel strong and energized for your next physical challenge.";
                                            return "Your fuel levels are rising steadily. You're providing your body with exactly what it needs to stay at peak.";
                                        }
                                        if (pro >= goalPro) return "Great job on the protein! Your body is in a prime state for muscle growth and tissue repair right now.";
                                        return "You've hit the metabolic sweet spot. Your body has everything it needs to rebuild stronger than before.";
                                    })()}
                                </p>
                            </div>

                            {/* Macro Bar */}
                            <div className="w-full bg-black/20 backdrop-blur-md rounded-[20px] p-4 flex justify-around items-center border border-white/5 mt-10">
                                <div className="flex flex-col items-center">
                                    <span className="text-[11px] font-black text-white/40 uppercase tracking-widest mb-1">Protein</span>
                                    <span className="text-2xl font-bold">112g</span>
                                </div>
                                <div className="w-[1px] h-6 bg-white/5" />
                                <div className="flex flex-col items-center">
                                    <span className="text-[11px] font-black text-white/40 uppercase tracking-widest mb-1">Carbs</span>
                                    <span className="text-2xl font-bold">145g</span>
                                </div>
                                <div className="w-[1px] h-6 bg-white/5" />
                                <div className="flex flex-col items-center">
                                    <span className="text-[11px] font-black text-white/40 uppercase tracking-widest mb-1">Fats</span>
                                    <span className="text-2xl font-bold">48g</span>
                                </div>
                            </div>
                        </div>
                    </div>

                    {/* Metabolic Insight Card */}
                    <div className="bg-white/5 backdrop-blur-md rounded-3xl p-6 border border-white/5 flex items-center gap-5">
                        <div className="w-12 h-12 rounded-2xl bg-[#10B981]/10 flex items-center justify-center text-[#10B981]">
                            <Brain className="w-6 h-6" />
                        </div>
                        <div>
                            <h4 className="text-[10px] font-bold uppercase tracking-[0.2em] text-white/30 mb-1">Metabolic Insight</h4>
                            <p className="text-sm text-white/60 leading-relaxed">Your metabolic rate is peaking. Recommend a protein-rich snack before 8 PM.</p>
                        </div>
                    </div>
                </div>
            )}
        </div>
    );
};

export default Home;
