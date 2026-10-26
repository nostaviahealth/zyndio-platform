import React, { useState, useEffect } from 'react';
import { useSearchParams } from 'react-router-dom';
import {
    Sun, Moon, Coffee, Pill, CheckCircle2, Circle,
    Utensils, Dumbbell, Brain, Leaf, ChevronRight,
    Calendar, Clock, Flame, Droplets, Apple, Activity, ShieldCheck, ChevronUp, ChevronDown,
    RefreshCw, AlertCircle, Sparkles
} from 'lucide-react';
import LoadingSkeleton, { SkeletonCard } from '../components/LoadingSkeleton';
import { useUser } from '../contexts/UserContext';

const Protocol: React.FC = () => {
    const {
        publishedJourney,
        currentPhase,
        currentPhaseIndex,
        setCurrentPhaseIndex,
        getProtocolSection,
        hasAnyPublishedContent,
        refreshJourney,
        loading,
        isPro,
        isUltimate
    } = useUser();

    const [searchParams] = useSearchParams();
    const [activeTab, setActiveTab] = useState<'lifestyle' | 'diet' | 'fitness' | 'supplements'>('diet');
    const [completedTasks, setCompletedTasks] = useState<string[]>([]);
    const [completedSupplements, setCompletedSupplements] = useState<string[]>([]); // Separate tracking for supplements
    const [isBlueprintExpanded, setIsBlueprintExpanded] = useState(true);
    const [selectedDay, setSelectedDay] = useState('Mon');

    // Initialize tab from URL param
    useEffect(() => {
        const section = searchParams.get('section');
        if (section && ['lifestyle', 'diet', 'fitness', 'supplements'].includes(section)) {
            setActiveTab(section as any);
        }
    }, [searchParams]);

    // Refresh journey on mount
    useEffect(() => {
        refreshJourney();
    }, [refreshJourney]);

    const toggleTask = (taskName: string) => {
        if (completedTasks.includes(taskName)) {
            setCompletedTasks(completedTasks.filter(t => t !== taskName));
        } else {
            setCompletedTasks([...completedTasks, taskName]);
        }
    };

    const tabs = [
        { id: 'lifestyle', label: 'Lifestyle', icon: Brain },
        { id: 'diet', label: 'Diet', icon: Utensils },
        { id: 'fitness', label: 'Fitness', icon: Dumbbell },
        { id: 'supplements', label: 'Supplements', icon: Pill },
    ];

    // Loading Skeleton
    if (loading) {
        return (
            <div className="space-y-8 animate-pulse">
                {/* Tabs Skeleton */}
                <div className="flex gap-4 overflow-x-auto pb-2">
                    {[1, 2, 3, 4].map(i => (
                        <div key={i} className="h-10 w-32 bg-slate-100 rounded-xl flex-shrink-0"></div>
                    ))}
                </div>

                {/* Blueprint Card Skeleton */}
                <div className="bg-white rounded-3xl p-8 border border-slate-100 h-64">
                    <div className="flex justify-between items-start mb-8">
                        <div className="flex gap-4">
                            <div className="w-12 h-12 bg-slate-100 rounded-xl"></div>
                            <div>
                                <div className="h-6 w-48 bg-slate-100 rounded mb-2"></div>
                                <div className="h-4 w-32 bg-slate-100 rounded"></div>
                            </div>
                        </div>
                    </div>
                    <div className="space-y-3">
                        <div className="h-4 w-full bg-slate-100 rounded"></div>
                        <div className="h-4 w-3/4 bg-slate-100 rounded"></div>
                    </div>
                </div>

                {/* Schedule Skeleton */}
                <div className="bg-white rounded-3xl p-6 border border-slate-100">
                    <div className="flex gap-2 mb-6 overflo-x-auto">
                        {[1, 2, 3, 4, 5, 6, 7].map(i => (
                            <div key={i} className="w-14 h-20 bg-slate-100 rounded-xl flex-shrink-0"></div>
                        ))}
                    </div>
                    <div className="space-y-4">
                        {[1, 2, 3].map(i => (
                            <div key={i} className="h-24 w-full bg-slate-100 rounded-2xl"></div>
                        ))}
                    </div>
                </div>
            </div>
        );
    }

    // No published content state
    if (!hasAnyPublishedContent()) {
        return (
            <div className="flex items-center justify-center min-h-[60vh]">
                <div className="text-center max-w-md">
                    <div className="w-20 h-20 bg-gradient-to-br from-purple-100 to-blue-100 rounded-full flex items-center justify-center mx-auto mb-6">
                        <Sparkles className="w-10 h-10 text-purple-600" />
                    </div>
                    <h2 className="text-2xl font-serif text-slate-900 mb-3">Your Protocol is Being Prepared</h2>
                    <p className="text-slate-600 mb-6">
                        Your personalized health protocol is currently being created by your health advisor.
                        You'll be notified once it's ready.
                    </p>
                    <button
                        onClick={refreshJourney}
                        className="flex items-center gap-2 px-6 py-3 bg-slate-100 hover:bg-slate-200 text-slate-700 rounded-xl font-medium transition-colors mx-auto"
                    >
                        <RefreshCw className="w-4 h-4" />
                        Check for Updates
                    </button>
                </div>
            </div>
        );
    }

    // Get published protocol sections
    const lifestyleProtocol = getProtocolSection('lifestyle');
    const dietProtocol = getProtocolSection('diet');
    const fitnessProtocol = getProtocolSection('fitness');
    const supplementsProtocol = getProtocolSection('supplements');

    // Render Diet Tab
    const renderDiet = () => {
        if (!dietProtocol) {
            return (
                <div className="text-center py-12">
                    <AlertCircle className="w-12 h-12 text-slate-300 mx-auto mb-4" />
                    <p className="text-slate-500">Diet protocol not yet published</p>
                </div>
            );
        }

        return (
            <div className="space-y-6 animate-fade-in">
                {/* Diet Blueprint Card */}
                <div className="bg-brand-dark text-white rounded-3xl shadow-glow relative overflow-hidden transition-all duration-300">
                    <div className="relative z-10 p-8">
                        <div
                            className="flex items-center justify-between cursor-pointer group"
                            onClick={() => setIsBlueprintExpanded(!isBlueprintExpanded)}
                        >
                            <div className="flex items-center gap-3">
                                <div className="w-10 h-10 rounded-xl bg-white/10 flex items-center justify-center group-hover:bg-white/20 transition-colors">
                                    <Utensils className="w-5 h-5 text-brand-sageDark" />
                                </div>
                                <h2 className="text-2xl font-serif">Diet Blueprint</h2>
                            </div>
                            <button className="w-10 h-10 rounded-full bg-white/5 flex items-center justify-center hover:bg-white/10 transition-colors">
                                {isBlueprintExpanded ? <ChevronUp className="w-5 h-5" /> : <ChevronDown className="w-5 h-5" />}
                            </button>
                        </div>

                        {isBlueprintExpanded && (
                            <div className="grid grid-cols-1 md:grid-cols-3 gap-8 mt-8 animate-fade-in">
                                {/* Column 1: Features of Diet */}
                                <div className="space-y-4">
                                    <h3 className="text-sm font-bold text-slate-400 uppercase tracking-wider">Features of Diet</h3>
                                    <div className="space-y-3">
                                        {/* Macros Summary */}
                                        <div className="grid grid-cols-3 gap-2 mb-2">
                                            <div className="bg-white/5 p-2 rounded-lg border border-white/10 text-center">
                                                <div className="text-[10px] text-slate-400 uppercase">Protein</div>
                                                <div className="font-bold text-emerald-400">{dietProtocol.macros.protein}</div>
                                            </div>
                                            <div className="bg-white/5 p-2 rounded-lg border border-white/10 text-center">
                                                <div className="text-[10px] text-slate-400 uppercase">Fats</div>
                                                <div className="font-bold text-amber-400">{dietProtocol.macros.fats}</div>
                                            </div>
                                            <div className="bg-white/5 p-2 rounded-lg border border-white/10 text-center">
                                                <div className="text-[10px] text-slate-400 uppercase">Carbs</div>
                                                <div className="font-bold text-blue-400">{dietProtocol.macros.carbs}</div>
                                            </div>
                                        </div>

                                        {/* Feature Points */}
                                        {dietProtocol.principles.map((principle: string, i: number) => (
                                            <div key={i} className="bg-white/5 p-4 rounded-xl border border-white/10 flex items-start gap-3 hover:bg-white/10 transition-colors">
                                                <div className="w-8 h-8 rounded-lg bg-brand-sageDark/30 flex items-center justify-center text-brand-sage flex-shrink-0 mt-0.5">
                                                    <CheckCircle2 className="w-4 h-4" />
                                                </div>
                                                <div>
                                                    <h4 className="text-sm font-bold text-slate-200 mb-1">{principle}</h4>
                                                </div>
                                            </div>
                                        ))}
                                    </div>
                                </div>

                                {/* Column 2: Daily Targets */}
                                <div className="space-y-4">
                                    <h3 className="text-sm font-bold text-slate-400 uppercase tracking-wider">Daily Targets</h3>
                                    <div className="bg-white/5 p-4 rounded-xl border border-white/10">
                                        <div className="space-y-3">
                                            <div>
                                                <p className="text-xs text-slate-400">Calories</p>
                                                <p className="text-2xl font-bold">{dietProtocol.calories}</p>
                                            </div>
                                            <div>
                                                <p className="text-xs text-slate-400">Protein</p>
                                                <p className="text-lg font-bold text-emerald-400">{dietProtocol.macros.protein}</p>
                                            </div>
                                            <div>
                                                <p className="text-xs text-slate-400">Fats</p>
                                                <p className="text-lg font-bold text-amber-400">{dietProtocol.macros.fats}</p>
                                            </div>
                                            <div>
                                                <p className="text-xs text-slate-400">Carbs</p>
                                                <p className="text-lg font-bold text-blue-400">{dietProtocol.macros.carbs}</p>
                                            </div>
                                        </div>
                                    </div>
                                </div>

                                {/* Column 3: Don'ts */}
                                <div className="space-y-4">
                                    <h3 className="text-sm font-bold text-slate-400 uppercase tracking-wider">Avoid</h3>
                                    <ul className="space-y-3">
                                        {dietProtocol.exclusions.map((item: string, i: number) => (
                                            <li key={i} className="flex items-start gap-3 text-sm text-slate-200">
                                                <div className="w-5 h-5 rounded-full bg-red-500/20 flex items-center justify-center flex-shrink-0 mt-0.5">
                                                    <span className="text-red-500 font-bold text-xs">✕</span>
                                                </div>
                                                <span className="text-slate-300">{item}</span>
                                            </li>
                                        ))}
                                    </ul>
                                </div>
                            </div>
                        )}
                    </div>
                    {/* Decoration */}
                    <div className="absolute top-0 right-0 w-64 h-64 bg-brand-sageDark/10 rounded-full blur-3xl -mr-16 -mt-16"></div>
                </div>
            </div>
        );
    };

    // Render Supplements Tab
    const renderSupplements = () => {
        if (!supplementsProtocol || !supplementsProtocol.items || supplementsProtocol.items.length === 0) {
            return (
                <div className="text-center py-12">
                    <AlertCircle className="w-12 h-12 text-slate-300 mx-auto mb-4" />
                    <p className="text-slate-500">Supplements protocol not yet published</p>
                </div>
            );
        }

        const timeSlots = [
            { label: 'Morning', icon: Sun, color: 'text-amber-500', bg: 'bg-amber-50' },
            { label: 'Afternoon', icon: Coffee, color: 'text-orange-500', bg: 'bg-orange-50' },
            { label: 'Night', icon: Moon, color: 'text-indigo-500', bg: 'bg-indigo-50' },
        ];

        const totalSupplements = supplementsProtocol.items.length;
        const completedCount = completedSupplements.length;
        const completionPercentage = totalSupplements > 0
            ? Math.round((completedCount / totalSupplements) * 100)
            : 0;

        const toggleSupplement = (name: string) => {
            if (completedSupplements.includes(name)) {
                setCompletedSupplements(completedSupplements.filter(s => s !== name));
            } else {
                setCompletedSupplements([...completedSupplements, name]);
            }
        };

        return (
            <div className="space-y-6 animate-fade-in">
                <div className="flex flex-col md:flex-row md:items-center justify-between gap-4 mb-2">
                    <h2 className="text-xl font-semibold text-slate-900">Daily Supplement Stack</h2>
                    <div className="flex items-center gap-2 bg-white px-4 py-2 rounded-full shadow-soft">
                        <div className="w-20 h-2 bg-slate-100 rounded-full overflow-hidden">
                            <div
                                className="h-full bg-brand-sageDark rounded-full transition-all duration-500"
                                style={{ width: `${completionPercentage}%` }}
                            />
                        </div>
                        <span className="text-xs font-medium text-slate-600">
                            {completionPercentage}% Complete
                        </span>
                    </div>
                </div>

                {/* All Supplements in Grid */}
                <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
                    {supplementsProtocol.items.map((supp: any) => {
                        const isCompleted = completedSupplements.includes(supp.name);

                        // Determine icon based on timing
                        let IconComponent = Sun;
                        let colorClass = 'text-amber-500';
                        let bgClass = 'bg-amber-50';

                        const timing = supp.timing.toLowerCase();
                        if (timing.includes('afternoon') || timing.includes('lunch')) {
                            IconComponent = Coffee;
                            colorClass = 'text-orange-500';
                            bgClass = 'bg-orange-50';
                        } else if (timing.includes('night') || timing.includes('evening') || timing.includes('dinner')) {
                            IconComponent = Moon;
                            colorClass = 'text-indigo-500';
                            bgClass = 'bg-indigo-50';
                        }

                        return (
                            <div
                                key={supp.name}
                                onClick={() => toggleSupplement(supp.name)}
                                className={`flex items-start gap-4 p-4 rounded-2xl cursor-pointer transition-all duration-200 border ${isCompleted
                                    ? 'bg-brand-sage/30 border-brand-sage'
                                    : 'bg-slate-50 border-transparent hover:bg-slate-100'
                                    }`}
                            >
                                <div className={`flex-shrink-0 transition-colors ${isCompleted ? 'text-brand-sageDark' : 'text-slate-300'}`}>
                                    {isCompleted ? <CheckCircle2 className="w-6 h-6" /> : <Circle className="w-6 h-6" />}
                                </div>
                                <div className="flex-1 min-w-0">
                                    <div className="flex items-start justify-between gap-2 mb-1">
                                        <p className={`font-medium transition-colors ${isCompleted ? 'text-slate-800' : 'text-slate-600'}`}>
                                            {supp.name}
                                        </p>
                                        <div className={`w-8 h-8 rounded-lg flex items-center justify-center flex-shrink-0 ${bgClass} ${colorClass}`}>
                                            <IconComponent className="w-4 h-4" />
                                        </div>
                                    </div>
                                    <div className="flex items-center gap-2 mt-1">
                                        <Pill className="w-3 h-3 text-slate-400" />
                                        <span className="text-xs text-slate-500">{supp.dosage}</span>
                                    </div>
                                    <p className="text-xs text-slate-500 mt-1">{supp.timing}</p>
                                    <p className="text-xs text-slate-400 mt-1 line-clamp-2">{supp.purpose}</p>
                                </div>
                            </div>
                        );
                    })}
                </div>
            </div>
        );
    };

    // Render Fitness Tab
    const renderFitness = () => {
        if (!fitnessProtocol || !fitnessProtocol.pillars || fitnessProtocol.pillars.length === 0) {
            return (
                <div className="text-center py-12">
                    <AlertCircle className="w-12 h-12 text-slate-300 mx-auto mb-4" />
                    <p className="text-slate-500">Fitness protocol not yet published</p>
                </div>
            );
        }

        return (
            <div className="space-y-6 animate-fade-in">
                <div className="bg-white rounded-3xl p-8 shadow-soft border-none">
                    <div className="flex items-center justify-between mb-8">
                        <h2 className="text-2xl font-serif text-slate-900">Fitness Protocol</h2>
                        {currentPhase?.goal.description && (
                            <span className="bg-slate-100 text-slate-600 px-4 py-1.5 rounded-full text-xs font-bold uppercase tracking-wide">
                                {currentPhase.goal.description}
                            </span>
                        )}
                    </div>
                    <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
                        {fitnessProtocol.pillars.map((pillar: any, idx: number) => (
                            <div key={idx} className="bg-slate-50 p-6 rounded-2xl border border-slate-100 hover:border-slate-200 hover:shadow-md transition-all group">
                                <div className="flex items-start justify-between mb-4">
                                    <div className="w-12 h-12 rounded-xl flex items-center justify-center bg-blue-100 text-blue-600">
                                        <Dumbbell className="w-6 h-6" />
                                    </div>
                                    <span className="text-[10px] font-bold uppercase tracking-wider bg-white px-2 py-1 rounded-md text-slate-500 shadow-sm">
                                        {pillar.tag}
                                    </span>
                                </div>
                                <h4 className="text-lg font-bold text-slate-900 mb-2">{pillar.title}</h4>
                                <p className="text-sm text-slate-500 leading-relaxed">
                                    {pillar.desc}
                                </p>
                            </div>
                        ))}
                    </div>
                </div>
            </div>
        );
    };

    // Render Lifestyle Tab
    const renderLifestyle = () => {
        if (!lifestyleProtocol || !lifestyleProtocol.habits || lifestyleProtocol.habits.length === 0) {
            return (
                <div className="text-center py-12">
                    <AlertCircle className="w-12 h-12 text-slate-300 mx-auto mb-4" />
                    <p className="text-slate-500">Lifestyle protocol not yet published</p>
                </div>
            );
        }

        return (
            <div className="space-y-6 animate-fade-in">
                <div className="grid grid-cols-1 md:grid-cols-2 gap-6">
                    {lifestyleProtocol.habits.map((habit: any) => (
                        <div key={habit.name} className="bg-white p-6 rounded-3xl shadow-soft border-none flex items-start gap-4 hover:shadow-lg transition-shadow">
                            <div className="w-14 h-14 rounded-2xl flex items-center justify-center bg-purple-100 text-purple-600 flex-shrink-0">
                                <Brain className="w-7 h-7" />
                            </div>
                            <div className="flex-1">
                                <h3 className="font-semibold text-slate-900">{habit.name}</h3>
                                <p className="text-xs text-slate-500 mt-1 leading-relaxed mb-2">{habit.desc}</p>
                                <div className="flex items-center gap-3 text-xs text-slate-400">
                                    <span className="flex items-center gap-1"><Clock className="w-3 h-3" /> {habit.time}</span>
                                    {habit.duration && <span>• {habit.duration}</span>}
                                </div>
                            </div>
                            <button className="w-10 h-10 rounded-full bg-slate-50 hover:bg-brand-sage/20 text-slate-300 hover:text-brand-sageDark flex items-center justify-center transition-colors mt-2">
                                <CheckCircle2 className="w-6 h-6" />
                            </button>
                        </div>
                    ))}
                </div>
            </div>
        );
    };

    return (
        <div className="space-y-8">
            {/* Header with Phase Navigation */}
            <div className="flex flex-col md:flex-row md:items-center justify-between gap-4">
                <div>
                    <h1 className="text-3xl font-serif text-slate-900 mb-2">My Protocol</h1>
                    <p className="text-slate-500">Holistic plan optimized for your biology.</p>
                </div>

                {publishedJourney && publishedJourney.phases.length > 1 && (
                    <div className="flex items-center gap-2">
                        <span className="text-sm text-slate-600 font-medium">Phase:</span>
                        <div className="flex gap-2">
                            {publishedJourney.phases.map((phase, idx) => (
                                <button
                                    key={phase.id}
                                    onClick={() => setCurrentPhaseIndex(idx)}
                                    className={`px-4 py-2 rounded-xl text-sm font-semibold transition-all ${idx === currentPhaseIndex
                                        ? 'bg-gradient-to-r from-purple-600 to-blue-600 text-white shadow-lg'
                                        : 'bg-slate-100 text-slate-600 hover:bg-slate-200'
                                        }`}
                                >
                                    Phase {phase.phaseNumber}
                                </button>
                            ))}
                        </div>
                    </div>
                )}
            </div>

            {/* Current Phase Info */}
            {currentPhase && (
                <div className="bg-gradient-to-r from-slate-900 to-slate-800 rounded-3xl p-6 text-white">
                    <div className="flex items-center justify-between">
                        <div>
                            <h2 className="text-xl font-serif mb-1">{currentPhase.goal.description}</h2>
                            <p className="text-slate-300 text-sm">
                                {currentPhase.durationWeeks} weeks • {currentPhase.goal.type.replace('_', ' ')}
                            </p>
                        </div>
                        <button
                            onClick={refreshJourney}
                            className="p-2 bg-white/10 hover:bg-white/20 rounded-xl transition-colors"
                            title="Refresh protocol"
                        >
                            <RefreshCw className="w-5 h-5" />
                        </button>
                    </div>
                </div>
            )}

            {/* Tabs */}
            <div className="flex p-1 bg-white rounded-2xl shadow-sm w-full md:w-fit overflow-x-auto">
                {tabs.map((tab) => {
                    const isActive = activeTab === tab.id;
                    return (
                        <button
                            key={tab.id}
                            onClick={() => setActiveTab(tab.id as any)}
                            className={`flex items-center gap-2 px-6 py-3 rounded-xl text-sm font-medium transition-all whitespace-nowrap ${isActive
                                ? 'bg-brand-dark text-white shadow-md'
                                : 'text-slate-500 hover:text-slate-900 hover:bg-slate-50'
                                }`}
                        >
                            <tab.icon className="w-4 h-4" />
                            {tab.label}
                        </button>
                    );
                })}
            </div>

            {/* Content Area */}
            <div className="min-h-[400px]">
                {activeTab === 'diet' && renderDiet()}
                {activeTab === 'supplements' && renderSupplements()}
                {activeTab === 'fitness' && renderFitness()}
                {activeTab === 'lifestyle' && renderLifestyle()}
            </div>
        </div>
    );
};

export default Protocol;
