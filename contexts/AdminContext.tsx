import React, { createContext, useContext, ReactNode, useCallback, useState, useEffect } from 'react';
import { supabase } from '../lib/supabase';
import { PatientProfile, WeeklyDietPlan, OnboardingStage } from '../types';

interface AdminContextType {
    // Patients
    patients: PatientProfile[];
    loading: boolean;
    getPatient: (id: string) => PatientProfile | undefined;
    createPatient: (patient: Omit<PatientProfile, 'id'>) => Promise<PatientProfile | null>;
    updatePatient: (id: string, updates: Partial<PatientProfile>) => Promise<void>;
    deletePatient: (id: string) => Promise<void>;
    advanceStage: (id: string) => Promise<void>;
    refreshPatients: () => Promise<void>;

    // Diet Plans
    dietPlans: WeeklyDietPlan[];
    getDietPlan: (patientId: string) => WeeklyDietPlan | undefined;
    saveDietPlan: (plan: WeeklyDietPlan) => Promise<void>;
    deleteDietPlan: (id: string) => Promise<void>;

    // Toast notifications
    showToast: (message: string, type: 'success' | 'error' | 'info') => void;
}

const AdminContext = createContext<AdminContextType | undefined>(undefined);

export const useAdmin = () => {
    const context = useContext(AdminContext);
    if (!context) {
        throw new Error('useAdmin must be used within AdminProvider');
    }
    return context;
};

interface AdminProviderProps {
    children: ReactNode;
}

export const AdminProvider: React.FC<AdminProviderProps> = ({ children }) => {
    const [patients, setPatients] = useState<PatientProfile[]>([]);
    const [dietPlans, setDietPlans] = useState<WeeklyDietPlan[]>([]);
    const [loading, setLoading] = useState(true);
    const [toast, setToast] = React.useState<{ message: string; type: 'success' | 'error' | 'info' } | null>(null);

    // Fetch patients from Supabase
    const fetchPatients = useCallback(async () => {
        try {
            setLoading(true);
            const { data, error } = await supabase
                .from('profiles')
                .select('*')
                .eq('role', 'user') // Only fetch users with role 'user' (not admins/doctors)
                .order('created_at', { ascending: false });

            if (error) throw error;

            setPatients(data || []);
        } catch (error: any) {
            console.error('Error fetching patients:', error);
            showToast('Failed to load patients', 'error');
        } finally {
            setLoading(false);
        }
    }, []);

    // Fetch diet plans
    const fetchDietPlans = useCallback(async () => {
        try {
            const { data, error } = await supabase
                .from('meal_plans')
                .select('*')
                .order('created_at', { ascending: false });

            if (error) throw error;

            // Transform to match WeeklyDietPlan structure
            setDietPlans(data || []);
        } catch (error: any) {
            console.error('Error fetching diet plans:', error);
        }
    }, []);

    // Load data on mount. Preview builds (__PREVIEW_BUILD__) serve the
    // /__preview harness for Ava screenshots with no live Supabase, so skip
    // the patients/diet fetches to avoid the stray "Failed to load patients"
    // toast covering dialog captures.
    useEffect(() => {
        if (typeof __PREVIEW_BUILD__ !== 'undefined' && __PREVIEW_BUILD__) {
            setLoading(false);
            return;
        }
        fetchPatients();
        fetchDietPlans();
    }, [fetchPatients, fetchDietPlans]);

    // Patient operations
    const getPatient = useCallback((id: string) => {
        return patients.find(p => p.id === id);
    }, [patients]);

    const createPatient = useCallback(async (patientData: Omit<PatientProfile, 'id'>): Promise<PatientProfile | null> => {
        try {
            const { data, error } = await supabase
                .from('profiles')
                .insert({
                    user_id: null, // Will be set when user actually signs up
                    name: patientData.name,
                    email: patientData.email,
                    phone: patientData.phone || '',
                    avatar_url: patientData.avatarUrl || `https://ui-avatars.com/api/?name=${encodeURIComponent(patientData.name)}&background=1e293b&color=fff`,
                    age: patientData.age,
                    bio_age: patientData.bioAge,
                    health_grade: patientData.healthGrade || 'B',
                    primary_goal: patientData.primaryGoal || 'Longevity',
                    stage: patientData.stage || 'payment_pending',
                    role: 'user', // Always user role for patients
                    is_premium: patientData.isPremium || false,
                    pace_of_aging: patientData.paceOfAging || 1.0,
                    joined_date: new Date().toISOString(),
                    subscription_plan: patientData.subscriptionPlan || 'pro'
                })
                .select()
                .single();

            if (error) throw error;

            // Add to local state
            setPatients(prev => [data, ...prev]);
            showToast('Patient created successfully', 'success');
            return data;
        } catch (error: any) {
            console.error('Error creating patient:', error);
            showToast('Failed to create patient', 'error');
            return null;
        }
    }, []);

    const updatePatient = useCallback(async (id: string, updates: Partial<PatientProfile>) => {
        try {
            // Map camelCase to snake_case for database
            const dbUpdates: any = {};
            if (updates.name) dbUpdates.name = updates.name;
            if (updates.email) dbUpdates.email = updates.email;
            if (updates.phone) dbUpdates.phone = updates.phone;
            if (updates.avatarUrl) dbUpdates.avatar_url = updates.avatarUrl;
            if (updates.age) dbUpdates.age = updates.age;
            if (updates.bioAge) dbUpdates.bio_age = updates.bioAge;
            if (updates.healthGrade) dbUpdates.health_grade = updates.healthGrade;
            if (updates.primaryGoal) dbUpdates.primary_goal = updates.primaryGoal;
            if (updates.stage) dbUpdates.stage = updates.stage;
            if (updates.role) dbUpdates.role = updates.role;
            if (updates.isPremium !== undefined) dbUpdates.is_premium = updates.isPremium;
            if (updates.paceOfAging) dbUpdates.pace_of_aging = updates.paceOfAging;
            if (updates.questionnaireData) dbUpdates.questionnaire_data = updates.questionnaireData;
            if (updates.labReportUrl) dbUpdates.lab_report_url = updates.labReportUrl;
            if (updates.isIntelligenceVerified !== undefined) dbUpdates.is_intelligence_verified = updates.isIntelligenceVerified;
            if (updates.isProtocolPublished !== undefined) dbUpdates.is_protocol_published = updates.isProtocolPublished;

            const { error } = await supabase
                .from('profiles')
                .update(dbUpdates)
                .eq('id', id);

            if (error) throw error;

            // Update local state
            setPatients(prev => prev.map(p =>
                p.id === id ? { ...p, ...updates } : p
            ));
            showToast('Patient updated successfully', 'success');
        } catch (error: any) {
            console.error('Error updating patient:', error);
            showToast('Failed to update patient', 'error');
        }
    }, []);

    const deletePatient = useCallback(async (id: string) => {
        try {
            const { error } = await supabase
                .from('profiles')
                .delete()
                .eq('id', id);

            if (error) throw error;

            setPatients(prev => prev.filter(p => p.id !== id));
            showToast('Patient deleted successfully', 'success');
        } catch (error: any) {
            console.error('Error deleting patient:', error);
            showToast('Failed to delete patient', 'error');
        }
    }, []);

    const getNextStage = (currentStage: OnboardingStage): OnboardingStage => {
        const stageFlow: OnboardingStage[] = [
            'payment_pending',
            'profile_creation',
            'lab_test_scheduled',
            'questionnaire_pending',
            'lab_processing',
            'intelligence_generation',
            'doctor_verification',
            'consultation_scheduled',
            'protocol_ready'
        ];
        const currentIndex = stageFlow.indexOf(currentStage);
        if (currentIndex < stageFlow.length - 1) {
            return stageFlow[currentIndex + 1];
        }
        return currentStage;
    };

    const advanceStage = useCallback(async (id: string) => {
        const patient = getPatient(id);
        if (patient) {
            const nextStage = getNextStage(patient.stage);
            await updatePatient(id, { stage: nextStage });
        }
    }, [getPatient, updatePatient]);

    // Diet Plan operations
    const getDietPlan = useCallback((patientId: string) => {
        return dietPlans.find(plan => plan.patientId === patientId);
    }, [dietPlans]);

    const saveDietPlan = useCallback(async (plan: WeeklyDietPlan) => {
        try {
            const { error } = await supabase
                .from('meal_plans')
                .upsert({
                    id: plan.id,
                    profile_id: plan.patientId,
                    week_number: plan.weekNumber || 1,
                    days: plan.days,
                    status: 'active'
                });

            if (error) throw error;

            // Update local state
            setDietPlans(prev => {
                const existingIndex = prev.findIndex(p => p.id === plan.id);
                if (existingIndex >= 0) {
                    const newPlans = [...prev];
                    newPlans[existingIndex] = plan;
                    return newPlans;
                } else {
                    return [...prev, plan];
                }
            });
            showToast('Diet plan saved successfully', 'success');
        } catch (error: any) {
            console.error('Error saving diet plan:', error);
            showToast('Failed to save diet plan', 'error');
        }
    }, []);

    const deleteDietPlan = useCallback(async (id: string) => {
        try {
            const { error } = await supabase
                .from('meal_plans')
                .delete()
                .eq('id', id);

            if (error) throw error;

            setDietPlans(prev => prev.filter(p => p.id !== id));
            showToast('Diet plan deleted successfully', 'success');
        } catch (error: any) {
            console.error('Error deleting diet plan:', error);
            showToast('Failed to delete diet plan', 'error');
        }
    }, []);

    // Toast notifications
    const showToast = useCallback((message: string, type: 'success' | 'error' | 'info') => {
        setToast({ message, type });
        setTimeout(() => setToast(null), 3000);
    }, []);

    const value: AdminContextType = {
        patients,
        loading,
        getPatient,
        createPatient,
        updatePatient,
        deletePatient,
        advanceStage,
        refreshPatients: fetchPatients,
        dietPlans,
        getDietPlan,
        saveDietPlan,
        deleteDietPlan,
        showToast
    };

    return (
        <AdminContext.Provider value={value}>
            {children}
            {/* Toast Component */}
            {toast && (
                <div className={`fixed bottom-8 right-8 px-6 py-4 rounded-xl shadow-2xl flex items-center gap-3 transition-all duration-500 z-50 ${toast.type === 'success' ? 'bg-emerald-600 text-white' :
                    toast.type === 'error' ? 'bg-rose-600 text-white' :
                        'bg-stone-900 text-white'
                    }`}>
                    <div className="w-2 h-2 bg-white rounded-full"></div>
                    <p className="font-medium text-sm">{toast.message}</p>
                </div>
            )}
        </AdminContext.Provider>
    );
};
