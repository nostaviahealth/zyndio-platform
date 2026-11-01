import React, { useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { ChevronRight, ChevronLeft, Check, Activity, Heart, Target, Calendar, Coffee, Moon } from 'lucide-react';
import { useUser } from '../contexts/UserContext';
import { validateAge, validateHeight, validateWeight, validateRequired, validateForm } from '../utils/validation';

interface QuestionnaireData {
    // Personal Info
    age: string;
    gender: string;
    height: string;
    weight: string;

    // Health History
    chronicConditions: string[];
    medications: string[];
    allergies: string[];
    familyHistory: string[];

    // Lifestyle
    sleepHours: string;
    exerciseFrequency: string;
    dietType: string;
    stressLevel: string;
    alcoholConsumption: string;
    smokingStatus: string;

    // Goals
    primaryGoals: string[];
    timeline: string;
    concernAreas: string[];
}

const HealthQuestionnaire: React.FC = () => {
    const navigate = useNavigate();
    const { patientProfile, refreshProfile } = useUser();
    const [currentStep, setCurrentStep] = useState(1);
    const [formData, setFormData] = useState<QuestionnaireData>({
        age: '',
        gender: '',
        height: '',
        weight: '',
        chronicConditions: [],
        medications: [],
        allergies: [],
        familyHistory: [],
        sleepHours: '',
        exerciseFrequency: '',
        dietType: '',
        stressLevel: '',
        alcoholConsumption: '',
        smokingStatus: '',
        primaryGoals: [],
        timeline: '',
        concernAreas: []
    });

    const totalSteps = 4;

    const handleSubmit = async () => {
        try {
            if (!patientProfile) return;

            // Comprehensive validation
            const validationErrors = validateForm({
                age: [
                    validateRequired(formData.age, 'Age'),
                    validateAge(formData.age, 'Age')
                ],
                gender: [validateRequired(formData.gender, 'Gender')],
                height: [validateHeight(formData.height, 'Height')],
                weight: [validateWeight(formData.weight, 'Weight')]
            });

            // Show validation errors
            if (Object.keys(validationErrors).length > 0) {
                const errorMessages = Object.values(validationErrors).join('\n');
                alert(`Please fix the following errors:\n\n${errorMessages}`);
                return;
            }

            // Refresh user profile to update UI
            await refreshProfile();

            // Navigate back to home
            navigate('/');
        } catch (error) {
            console.error('Failed to save questionnaire:', error);
            alert('Failed to save questionnaire. Please try again.');
        }
    };

    const toggleArrayItem = (array: string[], item: string) => {
        return array.includes(item)
            ? array.filter(i => i !== item)
            : [...array, item];
    };

    return (
        <div className="min-h-screen bg-slate-50 py-8 px-4">
            <div className="max-w-3xl mx-auto">
                {/* Header */}
                <div className="bg-white rounded-2xl shadow-sm border border-slate-200 p-6 mb-6">
                    <h1 className="text-2xl font-bold text-slate-900 mb-2">Health Questionnaire</h1>
                    <p className="text-slate-600">Help us understand your health journey better</p>

                    {/* Progress Bar */}
                    <div className="mt-6">
                        <div className="flex items-center justify-between mb-2">
                            <span className="text-sm font-medium text-slate-700">Step {currentStep} of {totalSteps}</span>
                            <span className="text-sm text-slate-500">{Math.round((currentStep / totalSteps) * 100)}% Complete</span>
                        </div>
                        <div className="h-2 bg-slate-100 rounded-full overflow-hidden">
                            <div
                                className="h-full bg-brand-dark transition-all duration-300"
                                style={{ width: `${(currentStep / totalSteps) * 100}%` }}
                            />
                        </div>
                    </div>
                </div>

                {/* Form Content */}
                <div className="bg-white rounded-2xl shadow-sm border border-slate-200 p-6 md:p-8">
                    {/* Step 1: Basic Info */}
                    {currentStep === 1 && (
                        <div className="space-y-6">
                            <div className="flex items-center gap-3 mb-6">
                                <div className="w-12 h-12 bg-blue-50 rounded-xl flex items-center justify-center">
                                    <Activity className="w-6 h-6 text-blue-600" />
                                </div>
                                <div>
                                    <h2 className="text-xl font-bold text-slate-900">Basic Information</h2>
                                    <p className="text-sm text-slate-500">Tell us about yourself</p>
                                </div>
                            </div>

                            <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
                                <div>
                                    <label className="block text-sm font-medium text-slate-700 mb-2">Age</label>
                                    <input
                                        type="number"
                                        value={formData.age}
                                        onChange={(e) => setFormData({ ...formData, age: e.target.value })}
                                        className="w-full px-4 py-2 border border-slate-300 rounded-xl focus:ring-2 focus:ring-brand-dark focus:border-transparent outline-none"
                                        placeholder="30"
                                    />
                                </div>

                                <div>
                                    <label className="block text-sm font-medium text-slate-700 mb-2">Gender</label>
                                    <select
                                        value={formData.gender}
                                        onChange={(e) => setFormData({ ...formData, gender: e.target.value })}
                                        className="w-full px-4 py-2 border border-slate-300 rounded-xl focus:ring-2 focus:ring-brand-dark focus:border-transparent outline-none"
                                    >
                                        <option value="">Select...</option>
                                        <option value="male">Male</option>
                                        <option value="female">Female</option>
                                        <option value="other">Other</option>
                                    </select>
                                </div>

                                <div>
                                    <label className="block text-sm font-medium text-slate-700 mb-2">Height (cm)</label>
                                    <input
                                        type="number"
                                        value={formData.height}
                                        onChange={(e) => setFormData({ ...formData, height: e.target.value })}
                                        className="w-full px-4 py-2 border border-slate-300 rounded-xl focus:ring-2 focus:ring-brand-dark focus:border-transparent outline-none"
                                        placeholder="175"
                                    />
                                </div>

                                <div>
                                    <label className="block text-sm font-medium text-slate-700 mb-2">Weight (kg)</label>
                                    <input
                                        type="number"
                                        value={formData.weight}
                                        onChange={(e) => setFormData({ ...formData, weight: e.target.value })}
                                        className="w-full px-4 py-2 border border-slate-300 rounded-xl focus:ring-2 focus:ring-brand-dark focus:border-transparent outline-none"
                                        placeholder="70"
                                    />
                                </div>
                            </div>
                        </div>
                    )}

                    {/* Step 2: Health History */}
                    {currentStep === 2 && (
                        <div className="space-y-6">
                            <div className="flex items-center gap-3 mb-6">
                                <div className="w-12 h-12 bg-red-50 rounded-xl flex items-center justify-center">
                                    <Heart className="w-6 h-6 text-red-600" />
                                </div>
                                <div>
                                    <h2 className="text-xl font-bold text-slate-900">Health History</h2>
                                    <p className="text-sm text-slate-500">Your health background</p>
                                </div>
                            </div>

                            <div>
                                <label className="block text-sm font-medium text-slate-700 mb-3">Do you have any chronic conditions?</label>
                                <div className="grid grid-cols-2 md:grid-cols-3 gap-3">
                                    {['Diabetes', 'Hypertension', 'Heart Disease', 'Asthma', 'Thyroid', 'None'].map(condition => (
                                        <button
                                            key={condition}
                                            onClick={() => setFormData({
                                                ...formData,
                                                chronicConditions: toggleArrayItem(formData.chronicConditions, condition)
                                            })}
                                            className={`px-4 py-2 rounded-xl text-sm font-medium transition-all ${formData.chronicConditions.includes(condition)
                                                ? 'bg-brand-dark text-white'
                                                : 'bg-slate-100 text-slate-700 hover:bg-slate-200'
                                                }`}
                                        >
                                            {condition}
                                        </button>
                                    ))}
                                </div>
                            </div>

                            <div>
                                <label className="block text-sm font-medium text-slate-700 mb-3">Family History (Select all that apply)</label>
                                <div className="grid grid-cols-2 md:grid-cols-3 gap-3">
                                    {['Heart Disease', 'Cancer', 'Diabetes', 'Alzheimer\'s', 'Obesity', 'None'].map(condition => (
                                        <button
                                            key={condition}
                                            onClick={() => setFormData({
                                                ...formData,
                                                familyHistory: toggleArrayItem(formData.familyHistory, condition)
                                            })}
                                            className={`px-4 py-2 rounded-xl text-sm font-medium transition-all ${formData.familyHistory.includes(condition)
                                                ? 'bg-brand-dark text-white'
                                                : 'bg-slate-100 text-slate-700 hover:bg-slate-200'
                                                }`}
                                        >
                                            {condition}
                                        </button>
                                    ))}
                                </div>
                            </div>
                        </div>
                    )}

                    {/* Step 3: Lifestyle */}
                    {currentStep === 3 && (
                        <div className="space-y-6">
                            <div className="flex items-center gap-3 mb-6">
                                <div className="w-12 h-12 bg-green-50 rounded-xl flex items-center justify-center">
                                    <Coffee className="w-6 h-6 text-green-600" />
                                </div>
                                <div>
                                    <h2 className="text-xl font-bold text-slate-900">Lifestyle</h2>
                                    <p className="text-sm text-slate-500">Your daily habits</p>
                                </div>
                            </div>

                            <div>
                                <label className="block text-sm font-medium text-slate-700 mb-2">Average Sleep Hours</label>
                                <select
                                    value={formData.sleepHours}
                                    onChange={(e) => setFormData({ ...formData, sleepHours: e.target.value })}
                                    className="w-full px-4 py-2 border border-slate-300 rounded-xl focus:ring-2 focus:ring-brand-dark focus:border-transparent outline-none"
                                >
                                    <option value="">Select...</option>
                                    <option value="<5">Less than 5 hours</option>
                                    <option value="5-6">5-6 hours</option>
                                    <option value="7-8">7-8 hours</option>
                                    <option value=">8">More than 8 hours</option>
                                </select>
                            </div>

                            <div>
                                <label className="block text-sm font-medium text-slate-700 mb-2">Exercise Frequency</label>
                                <select
                                    value={formData.exerciseFrequency}
                                    onChange={(e) => setFormData({ ...formData, exerciseFrequency: e.target.value })}
                                    className="w-full px-4 py-2 border border-slate-300 rounded-xl focus:ring-2 focus:ring-brand-dark focus:border-transparent outline-none"
                                >
                                    <option value="">Select...</option>
                                    <option value="none">Rarely/Never</option>
                                    <option value="1-2">1-2 times per week</option>
                                    <option value="3-4">3-4 times per week</option>
                                    <option value="5+">5+ times per week</option>
                                </select>
                            </div>

                            <div>
                                <label className="block text-sm font-medium text-slate-700 mb-2">Diet Type</label>
                                <select
                                    value={formData.dietType}
                                    onChange={(e) => setFormData({ ...formData, dietType: e.target.value })}
                                    className="w-full px-4 py-2 border border-slate-300 rounded-xl focus:ring-2 focus:ring-brand-dark focus:border-transparent outline-none"
                                >
                                    <option value="">Select...</option>
                                    <option value="standard">Standard</option>
                                    <option value="vegetarian">Vegetarian</option>
                                    <option value="vegan">Vegan</option>
                                    <option value="keto">Keto</option>
                                    <option value="paleo">Paleo</option>
                                </select>
                            </div>

                            <div>
                                <label className="block text-sm font-medium text-slate-700 mb-2">Stress Level</label>
                                <div className="flex gap-2">
                                    {[1, 2, 3, 4, 5].map(level => (
                                        <button
                                            key={level}
                                            onClick={() => setFormData({ ...formData, stressLevel: level.toString() })}
                                            className={`flex-1 py-3 rounded-xl font-medium transition-all ${formData.stressLevel === level.toString()
                                                ? 'bg-brand-dark text-white'
                                                : 'bg-slate-100 text-slate-700 hover:bg-slate-200'
                                                }`}
                                        >
                                            {level}
                                        </button>
                                    ))}
                                </div>
                                <div className="flex justify-between text-xs text-slate-500 mt-2">
                                    <span>Low</span>
                                    <span>High</span>
                                </div>
                            </div>
                        </div>
                    )}

                    {/* Step 4: Goals */}
                    {currentStep === 4 && (
                        <div className="space-y-6">
                            <div className="flex items-center gap-3 mb-6">
                                <div className="w-12 h-12 bg-purple-50 rounded-xl flex items-center justify-center">
                                    <Target className="w-6 h-6 text-purple-600" />
                                </div>
                                <div>
                                    <h2 className="text-xl font-bold text-slate-900">Your Goals</h2>
                                    <p className="text-sm text-slate-500">What brings you here?</p>
                                </div>
                            </div>

                            <div>
                                <label className="block text-sm font-medium text-slate-700 mb-3">Primary Health Goals (Select all that apply)</label>
                                <div className="grid grid-cols-1 md:grid-cols-2 gap-3">
                                    {[
                                        'Increase Longevity',
                                        'Improve Energy',
                                        'Better Sleep',
                                        'Weight Management',
                                        'Stress Reduction',
                                        'Athletic Performance',
                                        'Disease Prevention',
                                        'Mental Clarity'
                                    ].map(goal => (
                                        <button
                                            key={goal}
                                            onClick={() => setFormData({
                                                ...formData,
                                                primaryGoals: toggleArrayItem(formData.primaryGoals, goal)
                                            })}
                                            className={`px-4 py-3 rounded-xl text-sm font-medium transition-all text-left ${formData.primaryGoals.includes(goal)
                                                ? 'bg-brand-dark text-white'
                                                : 'bg-slate-100 text-slate-700 hover:bg-slate-200'
                                                }`}
                                        >
                                            {goal}
                                        </button>
                                    ))}
                                </div>
                            </div>

                            <div>
                                <label className="block text-sm font-medium text-slate-700 mb-2">Timeline for Results</label>
                                <select
                                    value={formData.timeline}
                                    onChange={(e) => setFormData({ ...formData, timeline: e.target.value })}
                                    className="w-full px-4 py-2 border border-slate-300 rounded-xl focus:ring-2 focus:ring-brand-dark focus:border-transparent outline-none"
                                >
                                    <option value="">Select...</option>
                                    <option value="1-3months">1-3 months</option>
                                    <option value="3-6months">3-6 months</option>
                                    <option value="6-12months">6-12 months</option>
                                    <option value="1year+">1 year+</option>
                                </select>
                            </div>
                        </div>
                    )}

                    {/* Navigation Buttons */}
                    <div className="flex items-center justify-between mt-8 pt-6 border-t border-slate-200">
                        <button
                            onClick={() => currentStep > 1 ? setCurrentStep(currentStep - 1) : navigate('/')}
                            className="flex items-center gap-2 px-6 py-2 text-slate-600 hover:text-slate-900 font-medium transition-colors"
                        >
                            <ChevronLeft className="w-4 h-4" />
                            {currentStep === 1 ? 'Cancel' : 'Previous'}
                        </button>

                        {currentStep < totalSteps ? (
                            <button
                                onClick={() => setCurrentStep(currentStep + 1)}
                                className="flex items-center gap-2 px-6 py-3 bg-brand-dark text-white rounded-xl font-medium hover:bg-slate-800 transition-colors shadow-lg"
                            >
                                Next Step
                                <ChevronRight className="w-4 h-4" />
                            </button>
                        ) : (
                            <button
                                onClick={handleSubmit}
                                className="flex items-center gap-2 px-6 py-3 bg-emerald-600 text-white rounded-xl font-medium hover:bg-emerald-700 transition-colors shadow-lg"
                            >
                                <Check className="w-4 h-4" />
                                Submit
                            </button>
                        )}
                    </div>
                </div>
            </div>
        </div>
    );
};

export default HealthQuestionnaire;
