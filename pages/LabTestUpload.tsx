import React, { useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { ChevronRight, Activity, Heart, Calendar } from 'lucide-react';
import { useUser } from '../contexts/UserContext';
import { supabase } from '../lib/supabase';

interface LabQuestionnaireData {
    // Basic Health Info
    age: string;
    gender: string;
    height: string;
    weight: string;

    // Current Symptoms
    symptoms: string[];
    energyLevel: string;
    sleepQuality: string;

    // Medical History
    chronicConditions: string[];
    currentMedications: string;
    allergies: string;

    // Lifestyle
    exerciseFrequency: string;
    dietType: string;
    stressLevel: string;

    // Lab Preferences
    preferredLabDate: string;
    additionalNotes: string;
}

const LabTestUpload: React.FC = () => {
    const navigate = useNavigate();
    const { patientProfile, refreshProfile } = useUser();
    const [isSubmitting, setIsSubmitting] = useState(false);
    const [formData, setFormData] = useState<LabQuestionnaireData>({
        age: '',
        gender: '',
        height: '',
        weight: '',
        symptoms: [],
        energyLevel: '',
        sleepQuality: '',
        chronicConditions: [],
        currentMedications: '',
        allergies: '',
        exerciseFrequency: '',
        dietType: '',
        stressLevel: '',
        preferredLabDate: '',
        additionalNotes: ''
    });

    const handleSubmit = async () => {
        if (!patientProfile) return;

        setIsSubmitting(true);
        try {
            const { error } = await supabase
                .from('profiles')
                .update({
                    questionnaire_data: formData,
                    stage: 'lab_processing',
                    lab_test_date: formData.preferredLabDate,
                    updated_at: new Date().toISOString()
                })
                .eq('id', patientProfile.id);

            if (error) throw error;

            await refreshProfile();
            navigate('/');
        } catch (error) {
            console.error('Failed to save questionnaire:', error);
            alert('Failed to save. Please try again.');
        } finally {
            setIsSubmitting(false);
        }
    };

    const toggleArrayItem = (array: string[], item: string) => {
        return array.includes(item)
            ? array.filter(i => i !== item)
            : [...array, item];
    };

    const symptomsOptions = ['Fatigue', 'Headaches', 'Digestive Issues', 'Joint Pain', 'Anxiety', 'Insomnia'];
    const conditionsOptions = ['Diabetes', 'Hypertension', 'Heart Disease', 'Thyroid Issues', 'Asthma', 'None'];

    return (
        <div className="min-h-screen bg-slate-50 py-8 px-4">
            <div className="max-w-3xl mx-auto">
                {/* Header */}
                <div className="bg-white rounded-2xl shadow-sm border border-slate-200 p-6 mb-6">
                    <h1 className="text-2xl font-bold text-slate-900 mb-2">Lab Test Questionnaire</h1>
                    <p className="text-slate-600">Help us prepare for your comprehensive lab analysis</p>
                </div>

                {/* Form */}
                <div className="bg-white rounded-2xl shadow-sm border border-slate-200 p-6 md:p-8">
                    <div className="space-y-8">
                        {/* Basic Info Section */}
                        <div>
                            <h2 className="text-lg font-bold text-slate-900 mb-4 flex items-center gap-2">
                                <Activity className="w-5 h-5 text-brand-gold" />
                                Basic Information
                            </h2>
                            <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
                                <div>
                                    <label className="block text-sm font-medium text-slate-700 mb-2">Age</label>
                                    <input
                                        type="number"
                                        value={formData.age}
                                        onChange={(e) => setFormData({ ...formData, age: e.target.value })}
                                        placeholder="Enter your age"
                                        className="w-full px-4 py-3 border border-slate-300 rounded-xl focus:ring-2 focus:ring-brand-dark focus:border-transparent outline-none"
                                    />
                                </div>
                                <div>
                                    <label className="block text-sm font-medium text-slate-700 mb-2">Gender</label>
                                    <select
                                        value={formData.gender}
                                        onChange={(e) => setFormData({ ...formData, gender: e.target.value })}
                                        className="w-full px-4 py-3 border border-slate-300 rounded-xl focus:ring-2 focus:ring-brand-dark focus:border-transparent outline-none"
                                    >
                                        <option value="">Select gender</option>
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
                                        placeholder="170"
                                        className="w-full px-4 py-3 border border-slate-300 rounded-xl focus:ring-2 focus:ring-brand-dark focus:border-transparent outline-none"
                                    />
                                </div>
                                <div>
                                    <label className="block text-sm font-medium text-slate-700 mb-2">Weight (kg)</label>
                                    <input
                                        type="number"
                                        value={formData.weight}
                                        onChange={(e) => setFormData({ ...formData, weight: e.target.value })}
                                        placeholder="70"
                                        className="w-full px-4 py-3 border border-slate-300 rounded-xl focus:ring-2 focus:ring-brand-dark focus:border-transparent outline-none"
                                    />
                                </div>
                            </div>
                        </div>

                        {/* Current Symptoms */}
                        <div>
                            <h2 className="text-lg font-bold text-slate-900 mb-4 flex items-center gap-2">
                                <Heart className="w-5 h-5 text-red-500" />
                                Current Symptoms
                            </h2>
                            <div className="grid grid-cols-2 md:grid-cols-3 gap-3">
                                {symptomsOptions.map(symptom => (
                                    <button
                                        key={symptom}
                                        type="button"
                                        onClick={() => setFormData({
                                            ...formData,
                                            symptoms: toggleArrayItem(formData.symptoms, symptom)
                                        })}
                                        className={`px-4 py-3 rounded-xl text-sm font-medium transition-all ${formData.symptoms.includes(symptom)
                                            ? 'bg-brand-dark text-white'
                                            : 'bg-slate-100 text-slate-700 hover:bg-slate-200'
                                            }`}
                                    >
                                        {symptom}
                                    </button>
                                ))}
                            </div>

                            <div className="grid grid-cols-1 md:grid-cols-2 gap-4 mt-4">
                                <div>
                                    <label className="block text-sm font-medium text-slate-700 mb-2">Energy Level</label>
                                    <select
                                        value={formData.energyLevel}
                                        onChange={(e) => setFormData({ ...formData, energyLevel: e.target.value })}
                                        className="w-full px-4 py-3 border border-slate-300 rounded-xl focus:ring-2 focus:ring-brand-dark focus:border-transparent outline-none"
                                    >
                                        <option value="">Select level</option>
                                        <option value="low">Low</option>
                                        <option value="moderate">Moderate</option>
                                        <option value="high">High</option>
                                    </select>
                                </div>
                                <div>
                                    <label className="block text-sm font-medium text-slate-700 mb-2">Sleep Quality</label>
                                    <select
                                        value={formData.sleepQuality}
                                        onChange={(e) => setFormData({ ...formData, sleepQuality: e.target.value })}
                                        className="w-full px-4 py-3 border border-slate-300 rounded-xl focus:ring-2 focus:ring-brand-dark focus:border-transparent outline-none"
                                    >
                                        <option value="">Select quality</option>
                                        <option value="poor">Poor</option>
                                        <option value="fair">Fair</option>
                                        <option value="good">Good</option>
                                        <option value="excellent">Excellent</option>
                                    </select>
                                </div>
                            </div>
                        </div>

                        {/* Health History Section */}
                        <div>
                            <h2 className="text-lg font-bold text-slate-900 mb-4">Health History</h2>

                            <div className="mb-4">
                                <label className="block text-sm font-medium text-slate-700 mb-2">Chronic Conditions</label>
                                <div className="grid grid-cols-2 md:grid-cols-3 gap-3">
                                    {conditionsOptions.map(condition => (
                                        <button
                                            key={condition}
                                            type="button"
                                            onClick={() => setFormData({
                                                ...formData,
                                                chronicConditions: toggleArrayItem(formData.chronicConditions, condition)
                                            })}
                                            className={`px-4 py-3 rounded-xl text-sm font-medium transition-all ${formData.chronicConditions.includes(condition)
                                                ? 'bg-brand-dark text-white'
                                                : 'bg-slate-100 text-slate-700 hover:bg-slate-200'
                                                }`}
                                        >
                                            {condition}
                                        </button>
                                    ))}
                                </div>
                            </div>

                            <div className="grid grid-cols-1 gap-4">
                                <div>
                                    <label className="block text-sm font-medium text-slate-700 mb-2">Current Medications</label>
                                    <textarea
                                        value={formData.currentMedications}
                                        onChange={(e) => setFormData({ ...formData, currentMedications: e.target.value })}
                                        placeholder="List any medications you're currently taking..."
                                        rows={3}
                                        className="w-full px-4 py-3 border border-slate-300 rounded-xl focus:ring-2 focus:ring-brand-dark focus:border-transparent outline-none"
                                    />
                                </div>
                                <div>
                                    <label className="block text-sm font-medium text-slate-700 mb-2">Allergies</label>
                                    <input
                                        type="text"
                                        value={formData.allergies}
                                        onChange={(e) => setFormData({ ...formData, allergies: e.target.value })}
                                        placeholder="Any known allergies"
                                        className="w-full px-4 py-3 border border-slate-300 rounded-xl focus:ring-2 focus:ring-brand-dark focus:border-transparent outline-none"
                                    />
                                </div>
                            </div>
                        </div>

                        {/* Lifestyle */}
                        <div>
                            <h2 className="text-lg font-bold text-slate-900 mb-4">Lifestyle</h2>
                            <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
                                <div>
                                    <label className="block text-sm font-medium text-slate-700 mb-2">Exercise Frequency</label>
                                    <select
                                        value={formData.exerciseFrequency}
                                        onChange={(e) => setFormData({ ...formData, exerciseFrequency: e.target.value })}
                                        className="w-full px-4 py-3 border border-slate-300 rounded-xl focus:ring-2 focus:ring-brand-dark focus:border-transparent outline-none"
                                    >
                                        <option value="">Select frequency</option>
                                        <option value="never">Never</option>
                                        <option value="1-2">1-2 times/week</option>
                                        <option value="3-4">3-4 times/week</option>
                                        <option value="5+">5+ times/week</option>
                                    </select>
                                </div>
                                <div>
                                    <label className="block text-sm font-medium text-slate-700 mb-2">Diet Type</label>
                                    <select
                                        value={formData.dietType}
                                        onChange={(e) => setFormData({ ...formData, dietType: e.target.value })}
                                        className="w-full px-4 py-3 border border-slate-300 rounded-xl focus:ring-2 focus:ring-brand-dark focus:border-transparent outline-none"
                                    >
                                        <option value="">Select diet</option>
                                        <option value="omnivore">Omnivore</option>
                                        <option value="vegetarian">Vegetarian</option>
                                        <option value="vegan">Vegan</option>
                                        <option value="keto">Keto</option>
                                        <option value="paleo">Paleo</option>
                                    </select>
                                </div>
                                <div>
                                    <label className="block text-sm font-medium text-slate-700 mb-2">Stress Level</label>
                                    <select
                                        value={formData.stressLevel}
                                        onChange={(e) => setFormData({ ...formData, stressLevel: e.target.value })}
                                        className="w-full px-4 py-3 border border-slate-300 rounded-xl focus:ring-2 focus:ring-brand-dark focus:border-transparent outline-none"
                                    >
                                        <option value="">Select level</option>
                                        <option value="low">Low</option>
                                        <option value="moderate">Moderate</option>
                                        <option value="high">High</option>
                                    </select>
                                </div>
                            </div>
                        </div>

                        {/* Lab Preferences */}
                        <div>
                            <h2 className="text-lg font-bold text-slate-900 mb-4 flex items-center gap-2">
                                <Calendar className="w-5 h-5 text-blue-500" />
                                Lab Preferences
                            </h2>
                            <div className="space-y-4">
                                <div>
                                    <label className="block text-sm font-medium text-slate-700 mb-2">
                                        Preferred Test Date
                                    </label>
                                    <input
                                        type="date"
                                        value={formData.preferredLabDate}
                                        onChange={(e) => setFormData({ ...formData, preferredLabDate: e.target.value })}
                                        min={new Date().toISOString().split('T')[0]}
                                        className="w-full px-4 py-3 border border-slate-300 rounded-xl focus:ring-2 focus:ring-brand-dark focus:border-transparent outline-none"
                                    />
                                </div>
                                <div>
                                    <label className="block text-sm font-medium text-slate-700 mb-2">
                                        Additional Notes
                                    </label>
                                    <textarea
                                        value={formData.additionalNotes}
                                        onChange={(e) => setFormData({ ...formData, additionalNotes: e.target.value })}
                                        placeholder="Any additional information you'd like to share..."
                                        rows={4}
                                        className="w-full px-4 py-3 border border-slate-300 rounded-xl focus:ring-2 focus:ring-brand-dark focus:border-transparent outline-none"
                                    />
                                </div>
                            </div>
                        </div>

                        {/* Submit Button */}
                        <button
                            onClick={handleSubmit}
                            disabled={isSubmitting || !formData.age || !formData.gender || !formData.preferredLabDate}
                            className="w-full bg-brand-dark text-white py-4 px-6 rounded-xl font-medium hover:bg-slate-800 transition-all shadow-lg disabled:bg-slate-300 disabled:cursor-not-allowed flex items-center justify-center gap-2"
                        >
                            {isSubmitting ? (
                                <>
                                    <div className="w-5 h-5 border-2 border-white border-t-transparent rounded-full animate-spin" />
                                    Submitting...
                                </>
                            ) : (
                                <>
                                    Submit Questionnaire
                                    <ChevronRight className="w-5 h-5" />
                                </>
                            )}
                        </button>

                        <p className="text-xs text-slate-500 text-center">
                            Your responses will help our team create a personalized health protocol for you
                        </p>
                    </div>
                </div>

                {/* Back Button */}
                <div className="mt-6 text-center">
                    <button
                        onClick={() => navigate('/')}
                        className="text-sm text-slate-600 hover:text-slate-900 font-medium"
                    >
                        Back to Dashboard
                    </button>
                </div>
            </div>
        </div>
    );
};

export default LabTestUpload;
