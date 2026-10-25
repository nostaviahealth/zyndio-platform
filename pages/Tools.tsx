import React, { useState } from 'react';
import { Calculator, Scale, Heart, Utensils, Ruler, Activity, X, TrendingUp, TrendingDown } from 'lucide-react';

interface CalculatorModal {
    type: string | null;
}

const Tools: React.FC = () => {
    const [activeCalculator, setActiveCalculator] = useState<CalculatorModal>({ type: null });

    // BMI Calculator state
    const [bmiInputs, setBmiInputs] = useState({ weight: '', height: '', unit: 'metric' });
    const [bmiResult, setBmiResult] = useState<number | null>(null);

    // Macro Calculator state
    const [macroInputs, setMacroInputs] = useState({ weight: '', goal: 'maintain', activityLevel: 'moderate' });
    const [macroResult, setMacroResult] = useState<any>(null);

    // HR Zones Calculator state
    const [hrInputs, setHrInputs] = useState({ age: '', restingHR: '' });
    const [hrZones, setHrZones] = useState<any>(null);

    const calculateBMI = () => {
        const weight = parseFloat(bmiInputs.weight);
        const height = parseFloat(bmiInputs.height);

        if (isNaN(weight) || isNaN(height) || weight <= 0 || height <= 0) {
            alert('Please enter valid values');
            return;
        }

        let bmi;
        if (bmiInputs.unit === 'metric') {
            bmi = weight / ((height / 100) ** 2); // height in cm
        } else {
            bmi = (weight / (height ** 2)) * 703; // imperial
        }

        setBmiResult(parseFloat(bmi.toFixed(1)));
    };

    const calculateMacros = () => {
        const weight = parseFloat(macroInputs.weight);
        if (isNaN(weight) || weight <= 0) {
            alert('Please enter valid weight');
            return;
        }

        const activityMultipliers: any = {
            sedentary: 1.2,
            light: 1.375,
            moderate: 1.55,
            active: 1.725,
            veryActive: 1.9
        };

        const bmr = weight * 24; // Simplified BMR
        const tdee = bmr * activityMultipliers[macroInputs.activityLevel];

        let calories = tdee;
        if (macroInputs.goal === 'lose') calories -= 500;
        if (macroInputs.goal === 'gain') calories += 500;

        const protein = weight * 2.2; // grams
        const fat = (calories * 0.25) / 9; // 25% of calories from fat
        const carbs = (calories - (protein * 4) - (fat * 9)) / 4;

        setMacroResult({
            calories: Math.round(calories),
            protein: Math.round(protein),
            carbs: Math.round(carbs),
            fat: Math.round(fat)
        });
    };

    const calculateHRZones = () => {
        const age = parseInt(hrInputs.age);
        const resting = parseInt(hrInputs.restingHR);

        if (isNaN(age) || isNaN(resting) || age <= 0 || resting <= 0) {
            alert('Please enter valid values');
            return;
        }

        const maxHR = 220 - age;
        const reserve = maxHR - resting;

        setHrZones({
            zone1: { min: Math.round(resting + reserve * 0.50), max: Math.round(resting + reserve * 0.60), name: 'Recovery' },
            zone2: { min: Math.round(resting + reserve * 0.60), max: Math.round(resting + reserve * 0.70), name: 'Fat Burn' },
            zone3: { min: Math.round(resting + reserve * 0.70), max: Math.round(resting + reserve * 0.80), name: 'Aerobic' },
            zone4: { min: Math.round(resting + reserve * 0.80), max: Math.round(resting + reserve * 0.90), name: 'Anaerobic' },
            zone5: { min: Math.round(resting + reserve * 0.90), max: maxHR, name: 'Max Effort' }
        });
    };

    const tools = [
        { name: 'BMI Calculator', icon: Scale, desc: 'Calculate Body Mass Index', color: 'text-blue-500', bg: 'bg-blue-50', calculator: 'bmi' },
        { name: 'Macro Planner', icon: Utensils, desc: 'Personalized meal macros', color: 'text-emerald-500', bg: 'bg-emerald-50', calculator: 'macro' },
        { name: 'Heart Rate Zones', icon: Heart, desc: 'Optimize your cardio', color: 'text-red-500', bg: 'bg-red-50', calculator: 'hr' },
        { name: 'Body Fat %', icon: Ruler, desc: 'Estimate body composition', color: 'text-purple-500', bg: 'bg-purple-50', calculator: 'bodyfat' },
        { name: 'BMR Calculator', icon: Activity, desc: 'Basal Metabolic Rate', color: 'text-orange-500', bg: 'bg-orange-50', calculator: 'bmr' },
        { name: 'Water Intake', icon: Calculator, desc: 'Daily hydration goals', color: 'text-cyan-500', bg: 'bg-cyan-50', calculator: 'water' },
    ];

    const getBMICategory = (bmi: number) => {
        if (bmi < 18.5) return { category: 'Underweight', color: 'text-blue-600' };
        if (bmi < 25) return { category: 'Normal', color: 'text-emerald-600' };
        if (bmi < 30) return { category: 'Overweight', color: 'text-amber-600' };
        return { category: 'Obese', color: 'text-red-600' };
    };

    return (
        <div className="space-y-6">
            <div>
                <h1 className="text-2xl font-serif text-slate-900 mb-2">Health Tools</h1>
                <p className="text-slate-500">Calculators and utilities to track your progress.</p>
            </div>

            <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
                {tools.map((tool) => (
                    <div
                        key={tool.name}
                        onClick={() => setActiveCalculator({ type: tool.calculator })}
                        className="bg-white p-6 rounded-3xl shadow-soft border-none hover:shadow-lg transition-all duration-300 cursor-pointer group"
                    >
                        <div className={`w-14 h-14 rounded-2xl flex items-center justify-center mb-6 ${tool.bg} ${tool.color} group-hover:scale-110 transition-transform`}>
                            <tool.icon className="w-7 h-7" />
                        </div>
                        <h3 className="font-semibold text-lg text-slate-900 mb-2">{tool.name}</h3>
                        <p className="text-slate-500 text-sm">{tool.desc}</p>

                        <div className="mt-6 flex items-center text-sm font-medium text-brand-sageDark opacity-0 group-hover:opacity-100 transition-opacity transform translate-y-2 group-hover:translate-y-0">
                            Launch Tool
                        </div>
                    </div>
                ))}
            </div>

            {/* BMI Calculator Modal */}
            {activeCalculator.type === 'bmi' && (
                <div className="fixed inset-0 bg-black/50 backdrop-blur-sm z-50 flex items-center justify-center p-4" onClick={() => setActiveCalculator({ type: null })}>
                    <div className="bg-white rounded-3xl p-8 max-w-md w-full shadow-2xl" onClick={(e) => e.stopPropagation()}>
                        <div className="flex justify-between items-center mb-6">
                            <h2 className="text-2xl font-serif text-slate-900">BMI Calculator</h2>
                            <button onClick={() => setActiveCalculator({ type: null })} className="p-2 hover:bg-slate-100 rounded-full">
                                <X className="w-5 h-5" />
                            </button>
                        </div>

                        <div className="space-y-4">
                            <div>
                                <label className="block text-sm font-medium text-slate-700 mb-2">Unit System</label>
                                <select
                                    value={bmiInputs.unit}
                                    onChange={(e) => setBmiInputs({ ...bmiInputs, unit: e.target.value })}
                                    className="w-full p-3 border border-slate-200 rounded-xl focus:ring-2 focus:ring-emerald-500 outline-none"
                                >
                                    <option value="metric">Metric (kg/cm)</option>
                                    <option value="imperial">Imperial (lbs/in)</option>
                                </select>
                            </div>

                            <div>
                                <label className="block text-sm font-medium text-slate-700 mb-2">
                                    Weight ({bmiInputs.unit === 'metric' ? 'kg' : 'lbs'})
                                </label>
                                <input
                                    type="number"
                                    value={bmiInputs.weight}
                                    onChange={(e) => setBmiInputs({ ...bmiInputs, weight: e.target.value })}
                                    placeholder={bmiInputs.unit === 'metric' ? "70" : "154"}
                                    className="w-full p-3 border border-slate-200 rounded-xl focus:ring-2 focus:ring-emerald-500 outline-none"
                                />
                            </div>

                            <div>
                                <label className="block text-sm font-medium text-slate-700 mb-2">
                                    Height ({bmiInputs.unit === 'metric' ? 'cm' : 'inches'})
                                </label>
                                <input
                                    type="number"
                                    value={bmiInputs.height}
                                    onChange={(e) => setBmiInputs({ ...bmiInputs, height: e.target.value })}
                                    placeholder={bmiInputs.unit === 'metric' ? "175" : "69"}
                                    className="w-full p-3 border border-slate-200 rounded-xl focus:ring-2 focus:ring-emerald-500 outline-none"
                                />
                            </div>

                            <button
                                onClick={calculateBMI}
                                className="w-full bg-gradient-to-r from-emerald-500 to-emerald-600 text-white py-3 rounded-xl font-medium shadow-lg hover:from-emerald-600 hover:to-emerald-700 transition-all"
                            >
                                Calculate BMI
                            </button>

                            {bmiResult && (
                                <div className="mt-6 p-6 bg-gradient-to-br from-slate-50 to-emerald-50 rounded-2xl border border-emerald-100">
                                    <div className="text-center">
                                        <div className="text-5xl font-bold text-slate-900 mb-2">{bmiResult}</div>
                                        <div className={`text-lg font-semibold ${getBMICategory(bmiResult).color}`}>
                                            {getBMICategory(bmiResult).category}
                                        </div>
                                        <div className="mt-4 text-sm text-slate-600">
                                            <p>Normal range: 18.5 - 24.9</p>
                                        </div>
                                    </div>
                                </div>
                            )}
                        </div>
                    </div>
                </div>
            )}

            {/* Macro Calculator Modal */}
            {activeCalculator.type === 'macro' && (
                <div className="fixed inset-0 bg-black/50 backdrop-blur-sm z-50 flex items-center justify-center p-4" onClick={() => setActiveCalculator({ type: null })}>
                    <div className="bg-white rounded-3xl p-8 max-w-md w-full shadow-2xl" onClick={(e) => e.stopPropagation()}>
                        <div className="flex justify-between items-center mb-6">
                            <h2 className="text-2xl font-serif text-slate-900">Macro Planner</h2>
                            <button onClick={() => setActiveCalculator({ type: null })} className="p-2 hover:bg-slate-100 rounded-full">
                                <X className="w-5 h-5" />
                            </button>
                        </div>

                        <div className="space-y-4">
                            <div>
                                <label className="block text-sm font-medium text-slate-700 mb-2">Weight (kg)</label>
                                <input
                                    type="number"
                                    value={macroInputs.weight}
                                    onChange={(e) => setMacroInputs({ ...macroInputs, weight: e.target.value })}
                                    placeholder="70"
                                    className="w-full p-3 border border-slate-200 rounded-xl focus:ring-2 focus:ring-emerald-500 outline-none"
                                />
                            </div>

                            <div>
                                <label className="block text-sm font-medium text-slate-700 mb-2">Goal</label>
                                <select
                                    value={macroInputs.goal}
                                    onChange={(e) => setMacroInputs({ ...macroInputs, goal: e.target.value })}
                                    className="w-full p-3 border border-slate-200 rounded-xl focus:ring-2 focus:ring-emerald-500 outline-none"
                                >
                                    <option value="lose">Lose Weight</option>
                                    <option value="maintain">Maintain Weight</option>
                                    <option value="gain">Gain Muscle</option>
                                </select>
                            </div>

                            <div>
                                <label className="block text-sm font-medium text-slate-700 mb-2">Activity Level</label>
                                <select
                                    value={macroInputs.activityLevel}
                                    onChange={(e) => setMacroInputs({ ...macroInputs, activityLevel: e.target.value })}
                                    className="w-full p-3 border border-slate-200 rounded-xl focus:ring-2 focus:ring-emerald-500 outline-none"
                                >
                                    <option value="sedentary">Sedentary (Little/No Exercise)</option>
                                    <option value="light">Light (1-3 days/week)</option>
                                    <option value="moderate">Moderate (3-5 days/week)</option>
                                    <option value="active">Active (6-7 days/week)</option>
                                    <option value="veryActive">Very Active (2x per day)</option>
                                </select>
                            </div>

                            <button
                                onClick={calculateMacros}
                                className="w-full bg-gradient-to-r from-emerald-500 to-emerald-600 text-white py-3 rounded-xl font-medium shadow-lg hover:from-emerald-600 hover:to-emerald-700 transition-all"
                            >
                                Calculate Macros
                            </button>

                            {macroResult && (
                                <div className="mt-6 space-y-3">
                                    <div className="p-4 bg-gradient-to-r from-blue-50 to-blue-100 rounded-xl">
                                        <div className="text-sm text-blue-700 font-medium">Daily Calories</div>
                                        <div className="text-3xl font-bold text-blue-900">{macroResult.calories}</div>
                                    </div>
                                    <div className="grid grid-cols-3 gap-3">
                                        <div className="p-3 bg-emerald-50 rounded-xl text-center">
                                            <div className="text-xs text-emerald-700 font-medium">Protein</div>
                                            <div className="text-xl font-bold text-emerald-900">{macroResult.protein}g</div>
                                        </div>
                                        <div className="p-3 bg-amber-50 rounded-xl text-center">
                                            <div className="text-xs text-amber-700 font-medium">Carbs</div>
                                            <div className="text-xl font-bold text-amber-900">{macroResult.carbs}g</div>
                                        </div>
                                        <div className="p-3 bg-purple-50 rounded-xl text-center">
                                            <div className="text-xs text-purple-700 font-medium">Fat</div>
                                            <div className="text-xl font-bold text-purple-900">{macroResult.fat}g</div>
                                        </div>
                                    </div>
                                </div>
                            )}
                        </div>
                    </div>
                </div>
            )}

            {/* Heart Rate Zones Modal */}
            {activeCalculator.type === 'hr' && (
                <div className="fixed inset-0 bg-black/50 backdrop-blur-sm z-50 flex items-center justify-center p-4" onClick={() => setActiveCalculator({ type: null })}>
                    <div className="bg-white rounded-3xl p-8 max-w-md w-full shadow-2xl" onClick={(e) => e.stopPropagation()}>
                        <div className="flex justify-between items-center mb-6">
                            <h2 className="text-2xl font-serif text-slate-900">Heart Rate Zones</h2>
                            <button onClick={() => setActiveCalculator({ type: null })} className="p-2 hover:bg-slate-100 rounded-full">
                                <X className="w-5 h-5" />
                            </button>
                        </div>

                        <div className="space-y-4">
                            <div>
                                <label className="block text-sm font-medium text-slate-700 mb-2">Age</label>
                                <input
                                    type="number"
                                    value={hrInputs.age}
                                    onChange={(e) => setHrInputs({ ...hrInputs, age: e.target.value })}
                                    placeholder="30"
                                    className="w-full p-3 border border-slate-200 rounded-xl focus:ring-2 focus:ring-red-500 outline-none"
                                />
                            </div>

                            <div>
                                <label className="block text-sm font-medium text-slate-700 mb-2">Resting Heart Rate (bpm)</label>
                                <input
                                    type="number"
                                    value={hrInputs.restingHR}
                                    onChange={(e) => setHrInputs({ ...hrInputs, restingHR: e.target.value })}
                                    placeholder="60"
                                    className="w-full p-3 border border-slate-200 rounded-xl focus:ring-2 focus:ring-red-500 outline-none"
                                />
                            </div>

                            <button
                                onClick={calculateHRZones}
                                className="w-full bg-gradient-to-r from-red-500 to-red-600 text-white py-3 rounded-xl font-medium shadow-lg hover:from-red-600 hover:to-red-700 transition-all"
                            >
                                Calculate Zones
                            </button>

                            {hrZones && (
                                <div className="mt-6 space-y-2">
                                    {Object.entries(hrZones).map(([key, zone]: [string, any]) => (
                                        <div key={key} className="p-3 bg-gradient-to-r from-slate-50 to-red-50 rounded-xl border border-red-100">
                                            <div className="flex justify-between items-center">
                                                <div>
                                                    <div className="text-sm font-semibold text-slate-900">{zone.name}</div>
                                                    <div className="text-xs text-slate-500">Zone {key.slice(-1)}</div>
                                                </div>
                                                <div className="text-right">
                                                    <div className="text-lg font-bold text-red-600">{zone.min} - {zone.max}</div>
                                                    <div className="text-xs text-slate-500">bpm</div>
                                                </div>
                                            </div>
                                        </div>
                                    ))}
                                </div>
                            )}
                        </div>
                    </div>
                </div>
            )}

            {/* Placeholder for other calculators */}
            {(activeCalculator.type === 'bodyfat' || activeCalculator.type === 'bmr' || activeCalculator.type === 'water') && (
                <div className="fixed inset-0 bg-black/50 backdrop-blur-sm z-50 flex items-center justify-center p-4" onClick={() => setActiveCalculator({ type: null })}>
                    <div className="bg-white rounded-3xl p-8 max-w-md w-full shadow-2xl text-center" onClick={(e) => e.stopPropagation()}>
                        <div className="flex justify-end mb-4">
                            <button onClick={() => setActiveCalculator({ type: null })} className="p-2 hover:bg-slate-100 rounded-full">
                                <X className="w-5 h-5" />
                            </button>
                        </div>
                        <div className="mb-6">
                            <Calculator className="w-16 h-16 mx-auto text-emerald-500 mb-4" />
                            <h3 className="text-xl font-serif text-slate-900 mb-2">Coming Soon</h3>
                            <p className="text-slate-600">This calculator is under development and will be available soon.</p>
                        </div>
                    </div>
                </div>
            )}

            {/* Featured Tool */}
            <div className="bg-brand-dark rounded-3xl p-8 shadow-glow relative overflow-hidden text-white">
                <div className="relative z-10 flex flex-col md:flex-row items-center justify-between gap-8">
                    <div className="max-w-lg">
                        <div className="inline-block px-3 py-1 rounded-full bg-brand-sageDark/20 text-brand-sageDark text-xs font-bold mb-4 border border-brand-sageDark/30">
                            NEW FEATURE
                        </div>
                        <h2 className="text-2xl font-bold mb-3">Longevity Predictor</h2>
                        <p className="text-slate-300 mb-6">
                            Use our advanced AI model to estimate your lifespan based on your current biomarkers and lifestyle habits.
                        </p>
                        <button
                            onClick={() => alert('Longevity Predictor will be available soon!')}
                            className="bg-white text-brand-dark px-6 py-3 rounded-xl font-semibold hover:bg-slate-100 transition-colors"
                        >
                            Try Predictor
                        </button>
                    </div>
                    <div className="relative w-40 h-40 flex-shrink-0">
                        <div className="absolute inset-0 bg-gradient-to-tr from-brand-sageDark to-zyndio-blue rounded-full opacity-50 blur-2xl animate-pulse"></div>
                        <div className="relative z-10 w-full h-full bg-slate-800/50 backdrop-blur-sm rounded-full border border-white/10 flex items-center justify-center">
                            <Activity className="w-16 h-16 text-white" />
                        </div>
                    </div>
                </div>
            </div>
        </div>
    );
};

export default Tools;
