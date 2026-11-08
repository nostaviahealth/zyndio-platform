import React, { useState, useEffect, useMemo } from 'react';
import { useNavigate } from 'react-router-dom';
import { 
    ChevronLeft, 
    Clock, 
    Utensils, 
    History,
    ChevronRight,
    Plus,
    X
} from 'lucide-react';
import { supabase } from '../lib/supabase';
import { useAuth } from '../contexts/AuthContext';

const FoodIntelligence: React.FC = () => {
    const navigate = useNavigate();
    const { user } = useAuth();
    const [selectedTab, setSelectedTab] = useState('Calories');
    const [logs, setLogs] = useState<any[]>([]);
    const [loading, setLoading] = useState(true);
    const [selectedMeal, setSelectedMeal] = useState<any>(null);

    const tabs = ['Calories', 'Protein', 'Carbs', 'Fat'];

    useEffect(() => {
        const fetchLogs = async () => {
            if (!user) return;
            try {
                setLoading(true);
                const { data, error } = await supabase
                    .from('food_logs')
                    .select('*')
                    .eq('patient_id', user.id)
                    .order('logged_at', { ascending: false });

                if (error) throw error;
                setLogs(data || []);
            } catch (err) {
                console.error('Error fetching food logs:', err);
            } finally {
                setLoading(false);
            }
        };

        fetchLogs();
    }, [user]);

    const groupedLogs = useMemo(() => {
        const groups: Record<string, any[]> = {};
        logs.forEach(log => {
            const date = new Date(log.logged_at);
            const today = new Date();
            const yesterday = new Date();
            yesterday.setDate(today.getDate() - 1);

            let key = '';
            if (date.toLocaleDateString() === today.toLocaleDateString()) key = 'Today';
            else if (date.toLocaleDateString() === yesterday.toLocaleDateString()) key = 'Yesterday';
            else key = date.toLocaleDateString('en-US', { month: 'long', day: 'numeric', year: 'numeric' });

            if (!groups[key]) groups[key] = [];
            groups[key].push(log);
        });
        return groups;
    }, [logs]);

    const dailyData = useMemo(() => {
        const totals: Record<string, any> = {};
        logs.forEach(log => {
            const date = new Date(log.logged_at).toLocaleDateString('en-US', { weekday: 'short' });
            const analysis = typeof log.analysis_json === 'string' ? JSON.parse(log.analysis_json) : log.analysis_json;
            
            if (!totals[date]) {
                totals[date] = { day: date, val: 0, pro: 0, carb: 0, fat: 0 };
            }
            
            totals[date].val += analysis.calories || 0;
            totals[date].pro += analysis.macros?.protein || 0;
            totals[date].carb += analysis.macros?.carbs || 0;
            totals[date].fat += analysis.macros?.fat || 0;
        });

        const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
        const sorted = Object.values(totals).sort((a, b) => days.indexOf(a.day) - days.indexOf(b.day));

        return sorted.length > 0 ? sorted : days.map(d => ({ day: d, val: 0, pro: 0, carb: 0, fat: 0 }));
    }, [logs]);

    const activeMetric = useMemo(() => {
        const mapping: Record<string, string> = { 'Calories': 'val', 'Protein': 'pro', 'Carbs': 'carb', 'Fat': 'fat' };
        return mapping[selectedTab];
    }, [selectedTab]);

    const activeGoal = useMemo(() => {
        const mapping: Record<string, number> = { 'Calories': 2000, 'Protein': 150, 'Carbs': 200, 'Fat': 70 };
        return mapping[selectedTab] || 2000;
    }, [selectedTab]);

    const activeUnit = useMemo(() => {
        return selectedTab === 'Calories' ? 'kcal' : 'g';
    }, [selectedTab]);

    const avg = useMemo(() => {
        if (dailyData.length === 0) return 0;
        const total = dailyData.reduce((acc, data) => {
            return acc + ((data as any)[activeMetric] || 0);
        }, 0);
        return Math.round(total / dailyData.length);
    }, [dailyData, activeMetric]);

    if (loading) {
        return (
            <div className="min-h-screen bg-[#0A0A0B] flex items-center justify-center">
                <div className="w-8 h-8 border-4 border-white/10 border-t-emerald-500 rounded-full animate-spin" />
            </div>
        );
    }

    return (
        <div className="min-h-screen bg-[#020617] text-white p-6 md:p-10 font-sans selection:bg-emerald-500/30 relative overflow-hidden">
            {/* Ambient Green Glow */}
            <div className="absolute top-0 left-1/2 -translate-x-1/2 w-full h-[500px] bg-[radial-gradient(circle_at_50%_-20%,rgba(16,185,129,0.12),transparent_70%)] pointer-events-none" />

            {/* Header */}
            <div className="max-w-md mx-auto mb-8 relative flex items-center justify-center z-10">
                <button 
                    onClick={() => navigate('/')}
                    className="absolute left-0 w-10 h-10 flex items-center justify-center text-white/80 hover:text-white transition-colors"
                >
                    <ChevronLeft className="w-6 h-6" />
                </button>
                <h1 className="text-xl font-bold tracking-tight">Nutrition Trends</h1>
            </div>

            {/* Tabs */}
            <div className="max-w-md mx-auto mb-8 relative z-10">
                <div className="bg-white/[0.03] p-1 rounded-full flex justify-between border border-white/[0.08] backdrop-blur-md">
                    {tabs.map(tab => (
                        <button
                            key={tab}
                            onClick={() => setSelectedTab(tab)}
                            className={`flex-1 py-2.5 rounded-full text-sm font-semibold transition-all ${selectedTab === tab ? 'bg-white text-black shadow-lg' : 'text-white/40 hover:text-white/60'}`}
                        >
                            {tab}
                        </button>
                    ))}
                </div>
            </div>

            {/* Main Chart Card */}
            <div className="max-w-md mx-auto mb-6 relative z-10">
                <div className="bg-white/[0.02] rounded-[32px] p-8 border border-white/[0.08] shadow-2xl relative overflow-hidden group backdrop-blur-md">
                    <div className="absolute inset-0 bg-gradient-to-br from-white/[0.02] to-transparent pointer-events-none" />
                    <div className="flex justify-between items-center mb-10 relative z-10">
                        <h3 className="text-lg font-bold">Daily {selectedTab}</h3>
                        <div className="bg-[#10B981]/10 px-4 py-1.5 rounded-full border border-[#10B981]/20">
                            <span className="text-[11px] font-black text-[#10B981] uppercase tracking-wider">Target: {activeGoal}{activeUnit}</span>
                        </div>
                    </div>

                    <div className="relative h-64 flex items-end justify-between gap-3 px-2 mb-4 relative z-10">
                        <div className="absolute inset-0 flex flex-col justify-between pointer-events-none pb-8">
                            {[0, 1, 2, 3, 4, 5].map(i => (
                                <div key={i} className="w-full border-t border-white/[0.03]" />
                            ))}
                        </div>
                        <div className="absolute w-full border-t border-dashed border-[#10B981]/30 z-10" style={{ bottom: `${(activeGoal / (selectedTab === 'Calories' ? 3000 : 250)) * 100}%` }} />

                        {dailyData.map((data, i) => {
                            const val = (data as any)[activeMetric];
                            const max = selectedTab === 'Calories' ? 3000 : 250;
                            const height = Math.min((val / max) * 100, 100);
                            const isHigh = val > activeGoal && selectedTab === 'Calories';
                            
                            return (
                                <div key={i} className="flex-1 flex flex-col items-center gap-4 z-20">
                                    <div className="w-full bg-white/[0.05] rounded-full relative overflow-hidden" style={{ height: '200px' }}>
                                        <div 
                                            className="absolute bottom-0 w-full rounded-full transition-all duration-1000 ease-out"
                                            style={{ 
                                                height: `${height}%`,
                                                backgroundColor: isHigh ? '#EF4444' : '#10B981',
                                                boxShadow: `0 0 20px ${isHigh ? 'rgba(239, 68, 68, 0.3)' : 'rgba(16, 185, 129, 0.2)'}`
                                            }}
                                        />
                                    </div>
                                    <span className="text-[10px] font-bold text-white/30 uppercase tracking-tighter">{data.day}</span>
                                </div>
                            );
                        })}
                    </div>
                </div>
            </div>

            {/* Summary Cards */}
            <div className="max-w-md mx-auto grid grid-cols-2 gap-4 mb-14 relative z-10">
                <div className="bg-white/[0.02] p-5 rounded-[24px] border border-white/[0.08] backdrop-blur-md">
                    <span className="text-[11px] font-bold text-white/40 uppercase tracking-widest block mb-3">7-Day Avg</span>
                    <span className="text-2xl font-bold">{avg}<span className="text-xs ml-1 text-white/30">{activeUnit}</span></span>
                </div>
                <div className="bg-white/[0.02] p-5 rounded-[24px] border border-white/[0.08] backdrop-blur-md">
                    <span className="text-[11px] font-bold text-white/40 uppercase tracking-widest block mb-3">Target Diff</span>
                    <span className={`text-2xl font-bold ${
                        selectedTab === 'Protein' 
                            ? (avg >= activeGoal ? 'text-[#10B981]' : 'text-red-500')
                            : (avg > activeGoal ? 'text-red-500' : 'text-[#10B981]')
                    }`}>
                        {avg - activeGoal > 0 ? '+' : ''}{avg - activeGoal}<span className="text-xs ml-1 opacity-50">{activeUnit}</span>
                    </span>
                </div>
            </div>

            {/* Grouped History */}
            <div className="max-w-md mx-auto pb-32 relative z-10">
                <h2 className="text-lg font-bold mb-6 text-white px-1">Meal History</h2>
                {Object.entries(groupedLogs).map(([day, dayLogs]) => (
                    <div key={day} className="mb-10">
                        <h4 className="text-[11px] font-black text-white/30 uppercase tracking-[0.2em] mb-6 px-1">{day}</h4>
                        <div className="space-y-3">
                            {dayLogs.map(log => {
                                const analysis = typeof log.analysis_json === 'string' ? JSON.parse(log.analysis_json) : log.analysis_json;
                                const time = new Date(log.logged_at).toLocaleTimeString('en-US', { hour: 'numeric', minute: '2-digit' });
                                const score = analysis.score || 0;
                                const scoreColor = score >= 80 ? 'text-emerald-500' : (score >= 50 ? 'text-emerald-500/80' : 'text-red-500');
                                const scoreBg = score >= 80 ? 'bg-emerald-500/10' : (score >= 50 ? 'bg-emerald-500/5' : 'bg-red-500/10');
                                const scoreBorder = score >= 80 ? 'border-emerald-500/20' : (score >= 50 ? 'border-emerald-500/10' : 'border-red-500/20');

                                return (
                                    <div 
                                        key={log.id} 
                                        onClick={() => setSelectedMeal(log)}
                                        className="bg-white/[0.02] py-3 px-4 rounded-[20px] border border-white/[0.08] flex items-center justify-between hover:bg-white/[0.04] transition-all active:scale-[0.98] cursor-pointer group backdrop-blur-md"
                                    >
                                        <div className="flex items-center gap-4">
                                            <div className={`w-11 h-11 rounded-full ${scoreBg} ${scoreBorder} border flex items-center justify-center transition-transform group-hover:scale-110`}>
                                                <span className={`text-base font-black ${scoreColor}`}>{score}</span>
                                            </div>
                                            <div>
                                                <h4 className="font-bold text-[15px] mb-0.5 truncate max-w-[180px]">{analysis.food_name || analysis.dish_name || 'Analyzed Meal'}</h4>
                                                <div className="flex items-center gap-2 text-[12px] font-medium text-white/40">
                                                    <span>{analysis.calories} kcal</span>
                                                    <span className="opacity-50">•</span>
                                                    <span>{time}</span>
                                                </div>
                                            </div>
                                        </div>
                                        <ChevronRight className="w-5 h-5 text-white/10 group-hover:text-white/30 transition-colors" />
                                    </div>
                                );
                            })}
                        </div>
                    </div>
                ))}
            </div>

            {/* Meal Detail Modal (Functional) */}
            {selectedMeal && (
                <div className="fixed inset-0 z-[100] flex items-end justify-center px-4 pb-10 bg-black/60 backdrop-blur-sm animate-in fade-in duration-300">
                    <div className="bg-[#121214] w-full max-w-md rounded-[32px] p-8 border border-white/10 shadow-2xl animate-in slide-in-from-bottom-10 duration-500">
                        <div className="flex justify-between items-start mb-8">
                            <div>
                                <span className="text-[10px] font-black text-emerald-500 uppercase tracking-widest block mb-2">Nutritional Analysis</span>
                                <h2 className="text-2xl font-bold">
                                    {(() => {
                                        const analysis = typeof selectedMeal.analysis_json === 'string' ? JSON.parse(selectedMeal.analysis_json) : selectedMeal.analysis_json;
                                        return analysis.food_name || analysis.dish_name;
                                    })()}
                                </h2>
                            </div>
                            <button onClick={() => setSelectedMeal(null)} className="w-10 h-10 bg-white/5 rounded-full flex items-center justify-center hover:bg-white/10 transition-colors">
                                <X className="w-5 h-5" />
                            </button>
                        </div>

                        {/* Analysis Grid */}
                        <div className="grid grid-cols-2 gap-4 mb-8">
                            {(() => {
                                const analysis = typeof selectedMeal.analysis_json === 'string' ? JSON.parse(selectedMeal.analysis_json) : selectedMeal.analysis_json;
                                return (
                                    <>
                                        <div className="bg-white/5 p-4 rounded-2xl">
                                            <span className="text-[10px] text-white/30 font-bold uppercase block mb-1">Calories</span>
                                            <span className="text-lg font-bold">{analysis.calories} <span className="text-xs opacity-50">kcal</span></span>
                                        </div>
                                        <div className="bg-white/5 p-4 rounded-2xl">
                                            <span className="text-[10px] text-white/30 font-bold uppercase block mb-1">Protein</span>
                                            <span className="text-lg font-bold">{analysis.macros?.protein || 0} <span className="text-xs opacity-50">g</span></span>
                                        </div>
                                        <div className="bg-white/5 p-4 rounded-2xl">
                                            <span className="text-[10px] text-white/30 font-bold uppercase block mb-1">Carbs</span>
                                            <span className="text-lg font-bold">{analysis.macros?.carbs || 0} <span className="text-xs opacity-50">g</span></span>
                                        </div>
                                        <div className="bg-white/5 p-4 rounded-2xl">
                                            <span className="text-[10px] text-white/30 font-bold uppercase block mb-1">Fat</span>
                                            <span className="text-lg font-bold">{analysis.macros?.fat || 0} <span className="text-xs opacity-50">g</span></span>
                                        </div>
                                    </>
                                );
                            })()}
                        </div>

                        <button 
                            onClick={() => setSelectedMeal(null)}
                            className="w-full bg-emerald-500 py-4 rounded-2xl font-bold text-sm hover:bg-emerald-400 transition-colors shadow-lg shadow-emerald-500/20"
                        >
                            Close Analysis
                        </button>
                    </div>
                </div>
            )}

            {/* Floating Log Button */}
            <div className="fixed bottom-10 left-0 right-0 z-50 flex justify-center px-6 pointer-events-none">
                <button 
                    onClick={() => navigate('/lens')}
                    className="bg-white text-black px-10 py-4 rounded-full font-bold text-sm shadow-[0_10px_40px_rgba(255,255,255,0.15)] flex items-center gap-3 active:scale-95 transition-all max-w-xs justify-center pointer-events-auto"
                >
                    <Plus className="w-5 h-5 stroke-[2.5px]" />
                    <span>LOG MEAL</span>
                </button>
            </div>
        </div>
    );
};

export default FoodIntelligence;
