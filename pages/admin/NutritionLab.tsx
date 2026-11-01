import React, { useState, useEffect } from 'react';
import { useNavigate, useSearchParams } from 'react-router-dom';
import {
    ArrowLeft, Sparkles, Save, Calendar, Edit2, CheckCircle, X, Plus,
    Sun, Moon, Coffee, Utensils, Users, Brain, TrendingUp, AlertCircle, Send,
    Copy, Trash2, Eye, Clock, ChevronDown, Search, Filter
} from 'lucide-react';
import { useAdmin } from '../../contexts/AdminContext';
import { supabase } from '../../lib/supabase';

interface Meal {
    time: string;
    name: string;
    desc: string;
    calories?: number;
    protein?: string;
    carbs?: string;
    fats?: string;
}

interface DayPlan {
    day: string;
    date: string;
    meals: Meal[];
}

interface MealPlan {
    id: string;
    version: number;
    weekStartDate: string;
    weeklyPlan: DayPlan[];
    approved: boolean;
    createdAt: string;
    lastUpdated: string;
    notes: string;
}

const NutritionLab: React.FC = () => {
    const navigate = useNavigate();
    const [searchParams] = useSearchParams();
    const patientId = searchParams.get('patient');
    const { getPatient } = useAdmin();

    const [patient, setPatient] = useState<any>(null);
    const [view, setView] = useState<'plans' | 'editor'>('plans');
    const [selectedDay, setSelectedDay] = useState(0);

    // Plan management
    const [allPlans, setAllPlans] = useState<MealPlan[]>([]);
    const [currentPlan, setCurrentPlan] = useState<MealPlan | null>(null);
    const [isGenerating, setIsGenerating] = useState(false);
    const [editingMeal, setEditingMeal] = useState<{ dayIdx: number; mealIdx: number } | null>(null);

    // Patient context data
    const [patientContext, setPatientContext] = useState<any>(null);

    // Meal library
    const [mealLibrary] = useState([
        { name: 'Warm Spiced Oatmeal', category: 'Breakfast', calories: 380, protein: '12g', carbs: '58g', fats: '12g' },
        { name: 'Greek Yogurt Parfait', category: 'Breakfast', calories: 360, protein: '18g', carbs: '42g', fats: '14g' },
        { name: 'Scrambled Eggs & Avocado', category: 'Breakfast', calories: 420, protein: '22g', carbs: '32g', fats: '24g' },
        { name: 'Grilled Chicken Salad', category: 'Lunch', calories: 480, protein: '35g', carbs: '28g', fats: '24g' },
        { name: 'Salmon & Quinoa', category: 'Dinner', calories: 560, protein: '42g', carbs: '38g', fats: '28g' },
    ]);

    useEffect(() => {
        if (patientId) {
            const foundPatient = getPatient(patientId);
            if (foundPatient) {
                setPatient(foundPatient);

                // Load patient context (questionnaire data, lab results, etc.)
                loadPatientContext();

                // Load meal plans from database
                loadMealPlans();
            }
        }
        // eslint-disable-next-line react-hooks/exhaustive-deps
    }, [patientId]);

    const loadPatientContext = async () => {
        if (!patientId) return;
        try {
            // patient_profiles is the org-scoped clinical replacement for the
            // removed `profiles` table (TC-018/TC-026); questionnaire + lab data
            // live in its `data` jsonb, read under staff RLS by patient_id.
            const { data: profile } = await supabase
                .from('patient_profiles')
                .select('data')
                .eq('patient_id', patientId)
                .single();

            if (profile?.data) {
                setPatientContext({
                    questionnaire: profile.data.questionnaire_data,
                    labData: profile.data.lab_report_url
                });
            }
        } catch (error) {
            console.error('Error loading patient context:', error);
        }
    };

    const loadMealPlans = async () => {
        if (!patientId) return;
        try {
            const { data, error } = await supabase
                .from('meal_plans')
                .select('*')
                .eq('profile_id', patientId)
                .order('created_at', { ascending: false });

            if (error) {
                // Table might not exist yet - that's okay
                console.log('Meal plans table not set up yet:', error.message);
                setAllPlans([]);
                return;
            }

            // Transform database records to MealPlan format
            const plans: MealPlan[] = (data || []).map(record => ({
                id: record.id,
                version: record.version,
                weekStartDate: record.week_start_date,
                weeklyPlan: record.weekly_plan as DayPlan[],
                approved: record.approved,
                createdAt: record.created_at,
                lastUpdated: record.updated_at,
                notes: record.notes || ''
            }));

            setAllPlans(plans);
        } catch (error) {
            console.error('Error loading meal plans:', error);
        }
    };

    const createNewPlan = () => {
        const newPlan: MealPlan = {
            id: `plan-${Date.now()}`,
            version: allPlans.length + 1,
            weekStartDate: new Date().toISOString(),
            weeklyPlan: [],
            approved: false,
            createdAt: new Date().toLocaleString(),
            lastUpdated: new Date().toLocaleString(),
            notes: ''
        };
        setCurrentPlan(newPlan);
        setView('editor');
    };

    const generateWithAI = async () => {
        if (!currentPlan) return;

        setIsGenerating(true);

        // Simulate AI generation
        setTimeout(() => {
            const generatedPlan: DayPlan[] = [
                {
                    day: 'Monday',
                    date: '15',
                    meals: [
                        { time: '08:00 AM', name: 'Warm Spiced Oatmeal', desc: 'Steel-cut oats with cardamom, cinnamon, almond milk, stewed apple.', calories: 380, protein: '12g', carbs: '58g', fats: '12g' },
                        { time: '01:00 PM', name: 'Kitchari Bowl', desc: 'Basmati rice, moong dal, cilantro, ghee, roasted zucchini.', calories: 450, protein: '18g', carbs: '65g', fats: '14g' },
                        { time: '07:30 PM', name: 'Steamed Fish & Greens', desc: 'White fish with turmeric rub, steamed spinach, sweet potato mash.', calories: 520, protein: '38g', carbs: '42g', fats: '18g' }
                    ]
                },
                {
                    day: 'Tuesday',
                    date: '16',
                    meals: [
                        { time: '08:00 AM', name: 'Smoothie Bowl', desc: 'Banana, spinach, protein powder, almond butter, coconut flakes.', calories: 420, protein: '24g', carbs: '48g', fats: '16g' },
                        { time: '01:00 PM', name: 'Grilled Chicken Salad', desc: 'Mixed greens, avocado, cherry tomatoes, olive oil dressing.', calories: 480, protein: '35g', carbs: '28g', fats: '24g' },
                        { time: '07:30 PM', name: 'Lentil Soup & Salad', desc: 'Red lentil soup with turmeric, side arugula salad.', calories: 440, protein: '22g', carbs: '58g', fats: '12g' }
                    ]
                },
                {
                    day: 'Wednesday',
                    date: '17',
                    meals: [
                        { time: '08:00 AM', name: 'Greek Yogurt Parfait', desc: 'Unsweetened yogurt with walnuts, berries, honey drizzle.', calories: 360, protein: '18g', carbs: '42g', fats: '14g' },
                        { time: '01:00 PM', name: 'Quinoa Buddha Bowl', desc: 'Quinoa, chickpeas, tahini dressing, roasted veggies.', calories: 520, protein: '20g', carbs: '68g', fats: '18g' },
                        { time: '07:30 PM', name: 'Salmon & Asparagus', desc: 'Wild-caught salmon with garlic butter asparagus.', calories: 560, protein: '42g', carbs: '18g', fats: '36g' }
                    ]
                },
                {
                    day: 'Thursday',
                    date: '18',
                    meals: [
                        { time: '08:00 AM', name: 'Scrambled Eggs & Avocado', desc: 'Pasture-raised eggs with spinach, half avocado, sourdough.', calories: 420, protein: '22g', carbs: '32g', fats: '24g' },
                        { time: '01:00 PM', name: 'Turkey Stir-fry', desc: 'Lean turkey breast with bell peppers, snap peas, ginger.', calories: 480, protein: '38g', carbs: '36g', fats: '18g' },
                        { time: '07:30 PM', name: 'Baked Cod & Veggies', desc: 'Lemon-herb cod with roasted Brussels sprouts.', calories: 440, protein: '36g', carbs: '28g', fats: '20g' }
                    ]
                },
                {
                    day: 'Friday',
                    date: '19',
                    meals: [
                        { time: '08:00 AM', name: 'Chia Pudding', desc: 'Overnight chia with almond milk, mango, coconut.', calories: 340, protein: '12g', carbs: '42g', fats: '16g' },
                        { time: '01:00 PM', name: 'Mediterranean Bowl', desc: 'Hummus, falafel, cucumber, tomato, pita, tahini.', calories: 520, protein: '18g', carbs: '62g', fats: '22g' },
                        { time: '07:30 PM', name: 'Shrimp Tacos', desc: 'Lettuce-wrapped shrimp with avocado salsa, lime.', calories: 460, protein: '32g', carbs: '38g', fats: '20g' }
                    ]
                },
                {
                    day: 'Saturday',
                    date: '20',
                    meals: [
                        { time: '09:00 AM', name: 'Protein Pancakes', desc: 'Oat flour pancakes with egg whites, topped with berries.', calories: 440, protein: '28g', carbs: '52g', fats: '12g' },
                        { time: '01:30 PM', name: 'Turkey Burger & Sweet Potato', desc: 'Bun-less turkey burger with sweet potato fries.', calories: 540, protein: '38g', carbs: '52g', fats: '18g' },
                        { time: '08:00 PM', name: 'Steak & Asparagus', desc: 'Grass-fed steak with garlic butter asparagus.', calories: 620, protein: '48g', carbs: '22g', fats: '38g' }
                    ]
                },
                {
                    day: 'Sunday',
                    date: '21',
                    meals: [
                        { time: '09:00 AM', name: 'Veggie Omelette', desc: 'Three-egg omelette with peppers, onions, spinach.', calories: 380, protein: '24g', carbs: '18g', fats: '24g' },
                        { time: '01:30 PM', name: 'Cobb Salad', desc: 'Hard-boiled eggs, bacon, avocado, greens, blue cheese.', calories: 560, protein: '32g', carbs: '22g', fats: '38g' },
                        { time: '07:00 PM', name: 'Roast Chicken & Vegetables', desc: 'Herb-roasted chicken with root vegetables.', calories: 580, protein: '42g', carbs: '38g', fats: '28g' }
                    ]
                }
            ];

            setCurrentPlan({
                ...currentPlan,
                weeklyPlan: generatedPlan,
                lastUpdated: new Date().toLocaleString()
            });
            setIsGenerating(false);
        }, 4000);
    };

    const handleEditMeal = (dayIdx: number, mealIdx: number, field: string, value: string) => {
        if (!currentPlan) return;
        const newPlan = { ...currentPlan };
        newPlan.weeklyPlan[dayIdx].meals[mealIdx] = {
            ...newPlan.weeklyPlan[dayIdx].meals[mealIdx],
            [field]: value
        };
        newPlan.lastUpdated = new Date().toLocaleString();
        setCurrentPlan(newPlan);
    };

    const handleSavePlan = async () => {
        if (!patientId || !currentPlan) return;

        try {
            const dbPlan = {
                profile_id: patientId,
                version: currentPlan.version,
                week_start_date: currentPlan.weekStartDate,
                weekly_plan: currentPlan.weeklyPlan,
                approved: currentPlan.approved,
                notes: currentPlan.notes
            };

            // Check if plan exists (has a UUID id)
            const isExisting = currentPlan.id && currentPlan.id.length > 20;

            if (isExisting) {
                // Update existing plan
                const { error } = await supabase
                    .from('meal_plans')
                    .update({ ...dbPlan, updated_at: new Date().toISOString() })
                    .eq('id', currentPlan.id);

                if (error) throw error;
            } else {
                // Insert new plan
                const { data, error } = await supabase
                    .from('meal_plans')
                    .insert([dbPlan])
                    .select()
                    .single();

                if (error) throw error;

                // Update current plan with database ID
                setCurrentPlan({
                    ...currentPlan,
                    id: data.id,
                    createdAt: data.created_at,
                    lastUpdated: data.updated_at
                });
            }

            // Reload plans from database
            await loadMealPlans();
            alert('Plan saved successfully!');
        } catch (error) {
            console.error('Error saving meal plan:', error);
            alert('Failed to save plan. Please try again.');
        }
    };

    const handleApprovePlan = async () => {
        if (!patientId || !currentPlan) return;

        try {
            // First, unapprove all other plans for this patient
            await supabase
                .from('meal_plans')
                .update({ approved: false })
                .eq('profile_id', patientId);

            // Then approve this plan
            const { error } = await supabase
                .from('meal_plans')
                .update({ approved: true, updated_at: new Date().toISOString() })
                .eq('id', currentPlan.id);

            if (error) throw error;

            // Update local state
            setCurrentPlan({ ...currentPlan, approved: true });
            await loadMealPlans();

            alert('Plan approved and set as active!');
        } catch (error) {
            console.error('Error approving plan:', error);
            alert('Failed to approve plan. Please try again.');
        }
    };

    const handleDuplicatePlan = (plan: MealPlan) => {
        const duplicated: MealPlan = {
            ...plan,
            id: `plan-${Date.now()}`, // Temp ID, will be replaced after save
            version: allPlans.length + 1,
            approved: false,
            createdAt: new Date().toLocaleString(),
            lastUpdated: new Date().toLocaleString()
        };
        setCurrentPlan(duplicated);
        setView('editor');
    };

    const handleDeletePlan = async (planId: string) => {
        if (!confirm('Are you sure you want to delete this plan?')) return;

        try {
            const { error } = await supabase
                .from('meal_plans')
                .delete()
                .eq('id', planId);

            if (error) throw error;

            // Reload plans
            await loadMealPlans();

            // If we deleted the current plan, clear it
            if (currentPlan?.id === planId) {
                setCurrentPlan(null);
                setView('plans');
            }
        } catch (error) {
            console.error('Error deleting plan:', error);
            alert('Failed to delete plan. Please try again.');
        }
    };
    const getTotalNutrients = (meals: Meal[]) => {
        const totals = { calories: 0, protein: 0, carbs: 0, fats: 0 };
        meals.forEach(meal => {
            totals.calories += meal.calories || 0;
            totals.protein += parseInt(meal.protein || '0');
            totals.carbs += parseInt(meal.carbs || '0');
            totals.fats += parseInt(meal.fats || '0');
        });
        return totals;
    };

    const currentDay = currentPlan?.weeklyPlan[selectedDay];
    const dailyTotals = currentDay ? getTotalNutrients(currentDay.meals) : null;
    const activePlan = allPlans.find(p => p.approved);

    // Show loading if patient not loaded yet
    if (!patient) {
        return (
            <div className="p-6 max-w-7xl mx-auto">
                <div className="bg-white rounded-3xl p-8 shadow-soft border border-slate-100 text-center">
                    <p className="text-slate-600">Loading patient data...</p>
                    <button
                        onClick={() => navigate('/admin')}
                        className="mt-4 px-6 py-2 bg-emerald-500 text-white rounded-xl"
                    >
                        Back to Dashboard
                    </button>
                </div>
            </div>
        );
    }

    return (
        <div className="p-6 max-w-[1800px] mx-auto space-y-6">
            {/* Header */}
            <div className="bg-white rounded-3xl p-6 shadow-soft border border-slate-100">
                <div className="flex items-center justify-between">
                    <div className="flex items-center gap-4">
                        <button onClick={() => navigate(`/admin/patient/${patientId}`)} className="p-2 hover:bg-slate-100 rounded-xl transition-colors">
                            <ArrowLeft className="w-5 h-5" />
                        </button>
                        <div className="h-8 w-px bg-slate-200"></div>
                        <Brain className="w-8 h-8 text-emerald-500" />
                        <div>
                            <h1 className="text-2xl font-serif text-slate-900">Nutrition Lab</h1>
                            <p className="text-sm text-slate-500">AI-Powered Meal Planning for {patient.name}</p>
                        </div>
                    </div>

                    <div className="flex gap-3">
                        {view === 'plans' ? (
                            <button
                                onClick={createNewPlan}
                                className="flex items-center gap-2 px-6 py-3 bg-gradient-to-r from-emerald-500 to-emerald-600 text-white rounded-xl font-semibold shadow-lg hover:from-emerald-600 hover:to-emerald-700 transition-all"
                            >
                                <Plus className="w-5 h-5" />
                                Create New Plan
                            </button>
                        ) : (
                            <>
                                <button onClick={() => setView('plans')} className="flex items-center gap-2 px-5 py-3 border-2 border-slate-200 text-slate-700 rounded-xl font-medium hover:bg-slate-50 transition-all">
                                    <ArrowLeft className="w-5 h-5" />
                                    Back to Plans
                                </button>
                                {currentPlan && !currentPlan.approved && (
                                    <>
                                        <button onClick={handleSavePlan} className="flex items-center gap-2 px-5 py-3 border-2 border-slate-200 text-slate-700 rounded-xl font-medium hover:bg-slate-50 transition-all">
                                            <Save className="w-5 h-5" />
                                            Save Draft
                                        </button>
                                        <button onClick={handleApprovePlan} className="flex items-center gap-2 px-6 py-3 bg-gradient-to-r from-emerald-500 to-emerald-600 text-white rounded-xl font-semibold shadow-lg hover:from-emerald-600 hover:to-emerald-700 transition-all">
                                            <Send className="w-5 h-5" />
                                            Approve & Publish
                                        </button>
                                    </>
                                )}
                            </>
                        )}
                    </div>
                </div>
            </div>

            {view === 'plans' ? (
                /* Plans List View */
                <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
                    {/* Active Plan */}
                    {activePlan && (
                        <div className="lg:col-span-2 bg-gradient-to-br from-emerald-50 to-emerald-100/50 rounded-3xl p-8 border-2 border-emerald-200">
                            <div className="flex items-start justify-between mb-6">
                                <div>
                                    <div className="flex items-center gap-2 mb-2">
                                        <span className="px-3 py-1 bg-emerald-600 text-white rounded-full text-xs font-bold">ACTIVE</span>
                                        <span className="text-sm text-slate-600">Version {activePlan.version}</span>
                                    </div>
                                    <h2 className="text-2xl font-serif text-slate-900 mb-1">Current Meal Plan</h2>
                                    <p className="text-sm text-slate-600">Published {activePlan.createdAt}</p>
                                </div>
                                <div className="flex gap-2">
                                    <button onClick={() => { setCurrentPlan(activePlan); setView('editor'); }} className="p-2 hover:bg-emerald-200 rounded-lg transition-colors">
                                        <Eye className="w-5 h-5 text-emerald-700" />
                                    </button>
                                    <button onClick={() => handleDuplicatePlan(activePlan)} className="p-2 hover:bg-emerald-200 rounded-lg transition-colors">
                                        <Copy className="w-5 h-5 text-emerald-700" />
                                    </button>
                                </div>
                            </div>
                            <div className="grid grid-cols-7 gap-2">
                                {activePlan.weeklyPlan.map((day, idx) => (
                                    <div key={idx} className="bg-white p-3 rounded-xl text-center border border-emerald-200">
                                        <div className="text-xs font-semibold text-emerald-700 mb-1">{day.day.slice(0, 3)}</div>
                                        <div className="text-xs text-slate-500">{day.meals.length} meals</div>
                                    </div>
                                ))}
                            </div>
                        </div>
                    )}

                    {/* Plan History */}
                    <div className={activePlan ? 'lg:col-span-1' : 'lg:col-span-3'}>
                        <div className="bg-white rounded-2xl p-6 border border-slate-200 shadow-sm">
                            <h3 className="font-semibold text-slate-900 mb-4 flex items-center gap-2">
                                <Clock className="w-5 h-5" />
                                Plan History ({allPlans.length})
                            </h3>
                            <div className="space-y-3 max-h-96 overflow-y-auto">
                                {allPlans.sort((a, b) => b.version - a.version).map(plan => (
                                    <div key={plan.id} className={`p-4 rounded-xl border-2 transition-all ${plan.approved ? 'border-emerald-200 bg-emerald-50' : 'border-slate-200 hover:border-slate-300'}`}>
                                        <div className="flex items-start justify-between mb-2">
                                            <div>
                                                <div className="flex items-center gap-2 mb-1">
                                                    <span className="font-semibold text-slate-900">Version {plan.version}</span>
                                                    {plan.approved && <CheckCircle className="w-4 h-4 text-emerald-600" />}
                                                </div>
                                                <p className="text-xs text-slate-500">{plan.createdAt}</p>
                                            </div>
                                            <div className="flex gap-1">
                                                <button onClick={() => { setCurrentPlan(plan); setView('editor'); }} className="p-1.5 hover:bg-slate-200 rounded-lg transition-colors" title="View">
                                                    <Eye className="w-4 h-4 text-slate-600" />
                                                </button>
                                                <button onClick={() => handleDuplicatePlan(plan)} className="p-1.5 hover:bg-slate-200 rounded-lg transition-colors" title="Duplicate">
                                                    <Copy className="w-4 h-4 text-slate-600" />
                                                </button>
                                                {!plan.approved && (
                                                    <button onClick={() => handleDeletePlan(plan.id)} className="p-1.5 hover:bg-red-50 rounded-lg transition-colors" title="Delete">
                                                        <Trash2 className="w-4 h-4 text-red-500" />
                                                    </button>
                                                )}
                                            </div>
                                        </div>
                                        {plan.weeklyPlan.length > 0 && (
                                            <div className="flex gap-1 mt-2">
                                                {plan.weeklyPlan.slice(0, 7).map((day, idx) => (
                                                    <div key={idx} className="flex-1 h-1 bg-emerald-300 rounded-full"></div>
                                                ))}
                                            </div>
                                        )}
                                    </div>
                                ))}
                                {allPlans.length === 0 && (
                                    <div className="text-center py-12 text-slate-500">
                                        <Calendar className="w-12 h-12 mx-auto mb-3 opacity-50" />
                                        <p>No meal plans yet</p>
                                        <p className="text-sm mt-1">Create your first plan to get started</p>
                                    </div>
                                )}
                            </div>
                        </div>
                    </div>

                    {/* Quick Stats */}
                    {!activePlan && (
                        <div className="bg-gradient-to-br from-blue-50 to-blue-100/50 rounded-2xl p-6 border-2 border-blue-200">
                            <h3 className="font-semibold text-slate-900 mb-4">Get Started</h3>
                            <p className="text-sm text-slate-600 mb-4">Create your first AI-powered meal plan for {patient.name}.</p>
                            <button onClick={createNewPlan} className="w-full bg-gradient-to-r from-blue-600 to-blue-700 text-white py-3 rounded-xl font-semibold shadow-lg hover:shadow-xl transition-all">
                                Create First Plan
                            </button>
                        </div>
                    )}
                </div>
            ) : (
                /* Editor View - (keep existing editor code but add AI button at top) */
                <div className="space-y-6">
                    {/* AI Generation Card */}
                    {currentPlan && currentPlan.weeklyPlan.length === 0 && (
                        <div className="bg-gradient-to-br from-blue-50 to-blue-100/50 rounded-2xl p-6 border-2 border-blue-200">
                            <div className="flex items-center justify-between">
                                <div className="flex items-center gap-4">
                                    <div className="w-14 h-14 bg-blue-200 rounded-2xl flex items-center justify-center">
                                        <Sparkles className="w-7 h-7 text-blue-700" />
                                    </div>
                                    <div>
                                        <h3 className="font-semibold text-lg text-slate-900 mb-1">AI Meal Plan Generation</h3>
                                        <p className="text-sm text-slate-600">Generate personalized weekly plan based on patient's complete health profile</p>
                                    </div>
                                </div>
                                <button
                                    onClick={generateWithAI}
                                    disabled={isGenerating}
                                    className={`flex items-center gap-2 px-8 py-4 rounded-xl font-semibold transition-all ${isGenerating
                                        ? 'bg-slate-200 text-slate-400 cursor-not-allowed'
                                        : 'bg-gradient-to-r from-blue-600 to-blue-700 text-white shadow-lg hover:shadow-xl'
                                        }`}
                                >
                                    {isGenerating ? (
                                        <>
                                            <div className="w-5 h-5 border-2 border-white border-t-transparent rounded-full animate-spin" />
                                            Generating...
                                        </>
                                    ) : (
                                        <>
                                            <Sparkles className="w-5 h-5" />
                                            Generate with AI
                                        </>
                                    )}
                                </button>
                            </div>
                        </div>
                    )}

                    {/* Meal Plan Editor (existing code) */}
                    {currentPlan && currentPlan.weeklyPlan.length > 0 && (
                        <div className="bg-white rounded-3xl border border-slate-200 shadow-xl overflow-hidden">
                            <div className="flex border-b border-slate-200">
                                {/* Day Selector */}
                                <div className="w-48 bg-slate-50 p-4 space-y-1 border-r border-slate-200">
                                    {currentPlan.weeklyPlan.map((day, idx) => (
                                        <button
                                            key={idx}
                                            onClick={() => setSelectedDay(idx)}
                                            className={`w-full text-left px-4 py-3 rounded-xl transition-all ${selectedDay === idx
                                                ? 'bg-emerald-500 text-white shadow-lg font-semibold'
                                                : 'text-slate-600 hover:bg-white hover:text-slate-900'
                                                }`}
                                        >
                                            <div className="flex items-center justify-between">
                                                <span>{day.day}</span>
                                                <span className="text-xs opacity-75">{day.date}</span>
                                            </div>
                                        </button>
                                    ))}
                                </div>

                                {/* Meals */}
                                <div className="flex-1 p-8">
                                    {currentDay && (
                                        <>
                                            <div className="flex items-center justify-between mb-6">
                                                <div>
                                                    <h2 className="text-2xl font-serif text-slate-900">{currentDay.day}</h2>
                                                    <p className="text-sm text-slate-500">Daily Total: {dailyTotals?.calories} kcal</p>
                                                </div>
                                                {dailyTotals && (
                                                    <div className="flex gap-6 text-sm">
                                                        <div>
                                                            <span className="text-slate-500">Protein: </span>
                                                            <span className="font-bold text-blue-600">{dailyTotals.protein}g</span>
                                                        </div>
                                                        <div>
                                                            <span className="text-slate-500">Carbs: </span>
                                                            <span className="font-bold text-purple-600">{dailyTotals.carbs}g</span>
                                                        </div>
                                                        <div>
                                                            <span className="text-slate-500">Fats: </span>
                                                            <span className="font-bold text-amber-600">{dailyTotals.fats}g</span>
                                                        </div>
                                                    </div>
                                                )}
                                            </div>

                                            <div className="space-y-6">
                                                {currentDay.meals.map((meal, mealIdx) => (
                                                    <div key={mealIdx} className="p-6 bg-slate-50 rounded-2xl border border-slate-200 hover:border-emerald-300 transition-all">
                                                        <div className="flex items-start gap-4">
                                                            <div className="w-12 h-12 rounded-xl bg-gradient-to-br from-emerald-400 to-emerald-600 flex items-center justify-center text-white">
                                                                {mealIdx === 0 && <Sun className="w-6 h-6" />}
                                                                {mealIdx === 1 && <Utensils className="w-6 h-6" />}
                                                                {mealIdx === 2 && <Moon className="w-6 h-6" />}
                                                            </div>

                                                            <div className="flex-1">
                                                                <div className="flex items-center justify-between mb-3">
                                                                    <div className="flex-1">
                                                                        <input
                                                                            type="text"
                                                                            value={meal.time}
                                                                            onChange={(e) => handleEditMeal(selectedDay, mealIdx, 'time', e.target.value)}
                                                                            className="text-xs text-slate-500 bg-transparent border-b border-transparent hover:border-slate-300 focus:border-emerald-500 outline-none px-1"
                                                                        />
                                                                        <input
                                                                            type="text"
                                                                            value={meal.name}
                                                                            onChange={(e) => handleEditMeal(selectedDay, mealIdx, 'name', e.target.value)}
                                                                            className="block text-lg font-bold text-slate-900 bg-transparent border-b-2 border-transparent hover:border-slate-300 focus:border-emerald-500 outline-none mt-1 w-full"
                                                                        />
                                                                    </div>
                                                                    <button
                                                                        onClick={() => setEditingMeal(editingMeal?.dayIdx === selectedDay && editingMeal?.mealIdx === mealIdx ? null : { dayIdx: selectedDay, mealIdx })}
                                                                        className="p-2 text-slate-400 hover:text-emerald-600 hover:bg-emerald-50 rounded-lg transition-colors"
                                                                    >
                                                                        <Edit2 className="w-4 h-4" />
                                                                    </button>
                                                                </div>

                                                                <textarea
                                                                    value={meal.desc}
                                                                    onChange={(e) => handleEditMeal(selectedDay, mealIdx, 'desc', e.target.value)}
                                                                    className="text-sm text-slate-600 leading-relaxed bg-transparent border border-transparent hover:border-slate-300 focus:border-emerald-500 outline-none rounded-lg p-2 w-full resize-none"
                                                                    rows={2}
                                                                />

                                                                <div className="flex gap-4 mt-3">
                                                                    <div className="px-3 py-1 bg-slate-200 rounded-full text-xs">
                                                                        <input
                                                                            type="text"
                                                                            value={meal.calories}
                                                                            onChange={(e) => handleEditMeal(selectedDay, mealIdx, 'calories', e.target.value)}
                                                                            className="w-12 bg-transparent outline-none font-semibold text-slate-700"
                                                                        />
                                                                        <span className="text-slate-600"> kcal</span>
                                                                    </div>
                                                                    <div className="px-3 py-1 bg-blue-100 rounded-full text-xs">
                                                                        <input
                                                                            type="text"
                                                                            value={meal.protein}
                                                                            onChange={(e) => handleEditMeal(selectedDay, mealIdx, 'protein', e.target.value)}
                                                                            className="w-8 bg-transparent outline-none font-semibold text-blue-700"
                                                                        />
                                                                        <span className="text-blue-600"> P</span>
                                                                    </div>
                                                                    <div className="px-3 py-1 bg-purple-100 rounded-full text-xs">
                                                                        <input
                                                                            type="text"
                                                                            value={meal.carbs}
                                                                            onChange={(e) => handleEditMeal(selectedDay, mealIdx, 'carbs', e.target.value)}
                                                                            className="w-8 bg-transparent outline-none font-semibold text-purple-700"
                                                                        />
                                                                        <span className="text-purple-600"> C</span>
                                                                    </div>
                                                                    <div className="px-3 py-1 bg-amber-100 rounded-full text-xs">
                                                                        <input
                                                                            type="text"
                                                                            value={meal.fats}
                                                                            onChange={(e) => handleEditMeal(selectedDay, mealIdx, 'fats', e.target.value)}
                                                                            className="w-8 bg-transparent outline-none font-semibold text-amber-700"
                                                                        />
                                                                        <span className="text-amber-600"> F</span>
                                                                    </div>
                                                                </div>
                                                            </div>
                                                        </div>
                                                    </div>
                                                ))}
                                            </div>
                                        </>
                                    )}
                                </div>
                            </div>
                        </div>
                    )}
                </div>
            )}
        </div>
    );
};

export default NutritionLab;
