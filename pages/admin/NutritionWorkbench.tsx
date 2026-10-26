import React, { useState } from 'react';
import {
    Search,
    Filter,
    Plus,
    Calendar,
    ChefHat,
    Utensils,
    ChevronRight,
    Brain,
    CheckCircle,
    Sun,
    Moon,
    Coffee,
    ArrowLeft,
    GripVertical
} from 'lucide-react';
import { useAdmin } from '../../contexts/AdminContext';

const NutritionWorkbench: React.FC = () => {
    const { patients, updatePatient, saveDietPlan, showToast } = useAdmin();
    const [selectedPatient, setSelectedPatient] = useState<string | null>(null);
    const [view, setView] = useState<'list' | 'planner'>('list');

    const patientsNeedingPlan = patients.filter(p =>
        p.stage === 'consultation_scheduled' || p.stage === 'doctor_verification' || p.stage === 'intelligence_generation'
    );

    const [weeklyPlan, setWeeklyPlan] = useState<Record<string, any[]>>({});
    const [isGenerating, setIsGenerating] = useState(false);

    const handleAutoGenerate = () => {
        setIsGenerating(true);
        // Simulate AI delay
        setTimeout(() => {
            setWeeklyPlan({
                'Breakfast': [{ name: 'Oatmeal with Berries', calories: 350, protein: '12g' }],
                'Lunch': [{ name: 'Grilled Chicken Salad', calories: 450, protein: '35g' }],
                'Dinner': [{ name: 'Salmon with Asparagus', calories: 500, protein: '40g' }],
                'Snack': [{ name: 'Almonds & Dark Chocolate', calories: 200, protein: '6g' }]
            });
            setIsGenerating(false);
        }, 1500);
    };

    const handlePublish = () => {
        if (selectedPatient) {
            // Save the plan
            const planId = `plan-${Date.now()}`;
            // In a real app, we would map the weeklyPlan state to the WeeklyDietPlan type correctly
            // For now, we'll just save a placeholder since the types don't perfectly match the UI state yet
            saveDietPlan({
                id: planId,
                patientId: selectedPatient,
                weekStartDate: new Date().toISOString(),
                status: 'published',
                days: [] // Placeholder
            });

            // Update patient status
            updatePatient(selectedPatient, {
                isDietPlanCreated: true,
                stage: 'protocol_ready'
            });

            showToast('Diet protocol published to patient app', 'success');
            setView('list');
            setSelectedPatient(null);
        }
    };

    return (
        <div className="space-y-6 p-8 max-w-7xl mx-auto">
            <div className="flex items-center justify-between">
                <div>
                    <h1 className="text-3xl font-serif font-bold text-stone-900">Nutrition Workbench</h1>
                    <p className="text-stone-500 mt-1">Create and manage AI-assisted diet protocols</p>
                </div>
                <button className="flex items-center gap-2 px-5 py-2.5 bg-brand-dark text-white rounded-xl hover:bg-stone-800 transition-all shadow-lg shadow-stone-900/20 active:scale-95">
                    <Plus className="w-4 h-4" />
                    New Template
                </button>
            </div>

            {view === 'list' ? (
                <div className="grid grid-cols-1 lg:grid-cols-3 gap-8">
                    {/* Patient Queue */}
                    <div className="lg:col-span-2 space-y-6">
                        <div className="bg-white p-4 rounded-2xl border border-stone-100 shadow-sm flex items-center gap-4 focus-within:ring-2 focus-within:ring-brand-gold/20 transition-all">
                            <Search className="w-5 h-5 text-stone-400" />
                            <input
                                type="text"
                                placeholder="Search patients waiting for protocols..."
                                className="flex-1 outline-none text-stone-900 bg-transparent"
                            />
                            <button className="p-2 hover:bg-stone-100 rounded-lg text-stone-500 transition-colors">
                                <Filter className="w-5 h-5" />
                            </button>
                        </div>

                        <div className="bg-white rounded-2xl border border-stone-100 shadow-sm overflow-hidden">
                            <div className="p-6 border-b border-stone-100 bg-stone-50/50 flex justify-between items-center">
                                <h3 className="font-bold text-stone-900">Pending Plans ({patientsNeedingPlan.length})</h3>
                            </div>
                            <div className="divide-y divide-stone-100">
                                {patientsNeedingPlan.map(patient => (
                                    <div key={patient.id} className="p-6 hover:bg-stone-50 transition-colors flex items-center justify-between group">
                                        <div className="flex items-center gap-5">
                                            <div className="w-12 h-12 bg-emerald-100 rounded-full flex items-center justify-center text-emerald-700 font-bold text-lg shadow-sm">
                                                {patient.name.charAt(0)}
                                            </div>
                                            <div>
                                                <p className="font-bold text-stone-900 text-lg">{patient.name}</p>
                                                <div className="flex items-center gap-2 text-sm text-stone-500 mt-0.5">
                                                    <span className="w-2 h-2 bg-emerald-500 rounded-full"></span>
                                                    Labs Analyzed
                                                    <span className="text-stone-300">•</span>
                                                    Ready for Protocol
                                                </div>
                                            </div>
                                        </div>
                                        <button
                                            onClick={() => {
                                                setSelectedPatient(patient.id);
                                                setView('planner');
                                            }}
                                            className="px-4 py-2 text-sm font-medium text-brand-gold bg-stone-900 rounded-lg opacity-0 group-hover:opacity-100 transition-all transform translate-x-2 group-hover:translate-x-0 shadow-lg shadow-stone-900/10"
                                        >
                                            Open Planner
                                        </button>
                                    </div>
                                ))}
                                {patientsNeedingPlan.length === 0 && (
                                    <div className="p-12 text-center text-stone-500 flex flex-col items-center gap-4">
                                        <div className="w-16 h-16 bg-stone-100 rounded-full flex items-center justify-center">
                                            <CheckCircle className="w-8 h-8 text-stone-400" />
                                        </div>
                                        <p>No patients currently waiting for diet plans.</p>
                                    </div>
                                )}
                            </div>
                        </div>
                    </div>

                    {/* Stats / Quick Actions */}
                    <div className="space-y-6">
                        <div className="bg-gradient-to-br from-brand-dark to-stone-800 text-white p-8 rounded-3xl shadow-xl relative overflow-hidden">
                            <div className="absolute top-0 right-0 w-32 h-32 bg-brand-gold rounded-full blur-3xl opacity-20 -mr-10 -mt-10"></div>
                            <div className="relative z-10">
                                <div className="flex items-center gap-3 mb-6">
                                    <div className="p-2 bg-white/10 rounded-lg backdrop-blur-sm">
                                        <Brain className="w-6 h-6 text-brand-gold" />
                                    </div>
                                    <h3 className="font-bold text-lg">AI Assistant</h3>
                                </div>
                                <p className="text-stone-300 mb-6 leading-relaxed">
                                    Generate a baseline plan based on metabolic type and lab markers.
                                </p>
                                <button className="w-full py-3 bg-white/10 hover:bg-white/20 rounded-xl text-sm font-bold transition-colors border border-white/5">
                                    Configure AI Model
                                </button>
                            </div>
                        </div>

                        <div className="bg-white p-6 rounded-2xl border border-stone-100 shadow-sm">
                            <h3 className="font-bold text-stone-900 mb-4">Popular Templates</h3>
                            <div className="space-y-2">
                                {['Anti-Inflammatory', 'Ketogenic Cycling', 'Gut Repair', 'Metabolic Reset'].map(template => (
                                    <div key={template} className="flex items-center justify-between p-3 hover:bg-stone-50 rounded-xl cursor-pointer transition-all group">
                                        <div className="flex items-center gap-3">
                                            <div className="p-2 bg-stone-100 rounded-lg group-hover:bg-white group-hover:shadow-sm transition-all">
                                                <ChefHat className="w-4 h-4 text-stone-500 group-hover:text-brand-gold" />
                                            </div>
                                            <span className="text-sm font-medium text-stone-700 group-hover:text-stone-900">{template}</span>
                                        </div>
                                        <ChevronRight className="w-4 h-4 text-stone-300 group-hover:text-stone-500" />
                                    </div>
                                ))}
                            </div>
                        </div>
                    </div>
                </div>
            ) : (
                /* Planner View */
                <div className="bg-white rounded-3xl border border-stone-200 min-h-[700px] flex flex-col shadow-xl shadow-stone-200/50 overflow-hidden">
                    <div className="p-6 border-b border-stone-100 flex items-center justify-between bg-white z-10">
                        <div className="flex items-center gap-6">
                            <button
                                onClick={() => setView('list')}
                                className="p-2 hover:bg-stone-100 rounded-full transition-colors text-stone-500 hover:text-stone-900"
                            >
                                <ArrowLeft className="w-5 h-5" />
                            </button>
                            <div className="h-8 w-px bg-stone-200" />
                            <div>
                                <h2 className="font-bold text-xl text-stone-900">
                                    Diet Plan for {patients.find(p => p.id === selectedPatient)?.name}
                                </h2>
                                <div className="flex items-center gap-2 text-xs text-stone-500 mt-1">
                                    <span className="px-2 py-0.5 bg-stone-100 rounded text-stone-600 font-medium">Week 1</span>
                                    <span>•</span>
                                    <span>Anti-Inflammatory Focus</span>
                                </div>
                            </div>
                        </div>
                        <div className="flex gap-3">
                            <button
                                onClick={handleAutoGenerate}
                                disabled={isGenerating}
                                className={`px-4 py-2.5 text-sm border border-stone-200 rounded-xl hover:bg-stone-50 flex items-center gap-2 disabled:opacity-50 transition-all ${isGenerating ? 'bg-stone-50' : 'bg-white'
                                    }`}
                            >
                                <Brain className={`w-4 h-4 text-brand-gold ${isGenerating ? 'animate-pulse' : ''}`} />
                                {isGenerating ? 'Analyzing Labs...' : 'Auto-Generate'}
                            </button>
                            <button
                                onClick={handlePublish}
                                className="px-5 py-2.5 bg-brand-gold text-stone-900 font-bold rounded-xl hover:bg-amber-400 shadow-lg shadow-amber-500/20 transition-all active:scale-95"
                            >
                                Publish to App
                            </button>
                        </div>
                    </div>

                    <div className="flex-1 flex bg-stone-50/50">
                        {/* Days Sidebar */}
                        <div className="w-56 border-r border-stone-200 p-4 space-y-1 bg-white">
                            {['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'].map((day, i) => (
                                <button
                                    key={day}
                                    className={`w-full text-left px-4 py-3 rounded-xl text-sm font-medium transition-all flex justify-between items-center group ${i === 0
                                        ? 'bg-stone-900 text-white shadow-md'
                                        : 'text-stone-500 hover:bg-stone-50 hover:text-stone-900'
                                        }`}
                                >
                                    {day}
                                    {i === 0 && <div className="w-2 h-2 bg-brand-gold rounded-full"></div>}
                                </button>
                            ))}
                        </div>

                        {/* Meal Slots */}
                        <div className="flex-1 p-8 overflow-y-auto">
                            <div className="space-y-8 max-w-3xl mx-auto">
                                {['Breakfast', 'Lunch', 'Dinner', 'Snack'].map((mealType) => (
                                    <div key={mealType} className="group">
                                        <div className="flex items-center justify-between mb-4">
                                            <h4 className="font-bold text-stone-900 flex items-center gap-2">
                                                {mealType === 'Breakfast' && <Sun className="w-4 h-4 text-amber-500" />}
                                                {mealType === 'Lunch' && <Sun className="w-4 h-4 text-orange-500" />}
                                                {mealType === 'Dinner' && <Moon className="w-4 h-4 text-indigo-500" />}
                                                {mealType === 'Snack' && <Coffee className="w-4 h-4 text-stone-400" />}
                                                {mealType}
                                            </h4>
                                            <button className="text-xs font-medium text-stone-400 hover:text-brand-gold flex items-center gap-1 opacity-0 group-hover:opacity-100 transition-opacity">
                                                <Plus className="w-3 h-3" /> Add Item
                                            </button>
                                        </div>

                                        {/* Meal Items */}
                                        <div className="space-y-3">
                                            {weeklyPlan[mealType]?.map((item, idx) => (
                                                <div key={idx} className="bg-white p-4 rounded-2xl border border-stone-200 shadow-sm hover:shadow-md hover:border-brand-gold/30 transition-all cursor-move group/item relative overflow-hidden">
                                                    <div className="absolute left-0 top-0 bottom-0 w-1 bg-brand-gold opacity-0 group-hover/item:opacity-100 transition-opacity"></div>
                                                    <div className="flex items-center justify-between">
                                                        <div className="flex items-center gap-4">
                                                            <div className="w-12 h-12 bg-stone-50 rounded-xl flex items-center justify-center group-hover/item:bg-brand-gold/10 transition-colors relative">
                                                                <GripVertical className="w-3 h-3 text-stone-300 absolute -left-1 top-1/2 -translate-y-1/2 opacity-0 group-hover/item:opacity-100 transition-opacity" />
                                                                <Utensils className="w-5 h-5 text-stone-400 group-hover/item:text-brand-gold transition-colors" />
                                                            </div>
                                                            <div>
                                                                <p className="font-bold text-stone-900">{item.name}</p>
                                                                <div className="flex items-center gap-3 text-xs text-stone-500 mt-1">
                                                                    <span className="bg-stone-100 px-1.5 py-0.5 rounded text-stone-600">{item.calories} kcal</span>
                                                                    <span>•</span>
                                                                    <span className="text-emerald-600 font-medium">{item.protein} Protein</span>
                                                                </div>
                                                            </div>
                                                        </div>
                                                        <button className="text-stone-300 hover:text-red-500 transition-colors p-2">
                                                            <Plus className="w-5 h-5 rotate-45" />
                                                        </button>
                                                    </div>
                                                </div>
                                            ))}
                                            {!weeklyPlan[mealType] && (
                                                <div className="h-24 border-2 border-dashed border-stone-200 rounded-2xl flex flex-col items-center justify-center text-stone-400 gap-2 hover:border-stone-300 hover:bg-stone-50 transition-all cursor-pointer">
                                                    <Plus className="w-6 h-6 opacity-50" />
                                                    <span className="text-sm font-medium">Drop items here</span>
                                                </div>
                                            )}
                                        </div>
                                    </div>
                                ))}
                            </div>
                        </div>

                        {/* Food Bank Sidebar */}
                        <div className="w-72 border-l border-stone-200 bg-white flex flex-col">
                            <div className="p-4 border-b border-stone-100">
                                <h3 className="font-bold text-stone-900 mb-4">Food Bank</h3>
                                <div className="relative">
                                    <Search className="w-4 h-4 absolute left-3 top-1/2 -translate-y-1/2 text-stone-400" />
                                    <input
                                        type="text"
                                        placeholder="Search ingredients..."
                                        className="w-full pl-9 pr-3 py-2.5 bg-stone-50 border border-stone-200 rounded-xl text-sm outline-none focus:border-brand-gold focus:bg-white transition-all"
                                    />
                                </div>
                            </div>

                            <div className="flex-1 overflow-y-auto p-4 space-y-6">
                                <div>
                                    <h5 className="text-xs font-bold text-stone-400 uppercase tracking-wider mb-3">Recommended for Pitta</h5>
                                    <div className="space-y-2">
                                        {['Avocado', 'Walnuts', 'Blueberries', 'Turmeric', 'Coconut Water', 'Cucumber'].map(food => (
                                            <div key={food} className="bg-white p-3 rounded-xl border border-stone-200 text-sm text-stone-700 cursor-move hover:border-brand-gold hover:shadow-sm transition-all flex items-center justify-between group">
                                                <span className="font-medium">{food}</span>
                                                <Plus className="w-4 h-4 text-stone-300 group-hover:text-brand-gold" />
                                            </div>
                                        ))}
                                    </div>
                                </div>
                            </div>
                        </div>
                    </div>
                </div>
            )}
        </div>
    );
};

export default NutritionWorkbench;
