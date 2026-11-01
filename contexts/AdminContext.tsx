import React, { createContext, useContext, ReactNode, useCallback, useState, useEffect } from 'react';
import { supabase } from '../lib/supabase';
import { PatientProfile, WeeklyDietPlan, OnboardingStage } from '../types';

interface AdminContextType {
    // Patients
    patients: PatientProfile[];
    loading: boolean;
    getPatient: (id: string) => PatientProfile | undefined;
    updatePatient: (id: string, updates: Partial<PatientProfile>) => Promise<void>;
    deletePatient: (id: string) => Promise<void>;
    advanceStage: (id: string) => Promise<void>;

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
    // TC-022 #3: nothing loads the patient list here any more (see below), so
    // there is no loading phase.
    const [loading] = useState(false);
    const [toast, setToast] = React.useState<{ message: string; type: 'success' | 'error' | 'info' } | null>(null);

    // TC-022 #3: the old mount-time fetch of the removed `profiles` table is
    // gone. AdminProvider wraps every route (sign-in, 2FA, not-found too), and
    // that failing fetch put a "Failed to load patients" toast on all of them.
    // The clinician roster reads its own data (pages/admin/clinic).

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

    // Load diet plans on mount. Preview builds (__PREVIEW_BUILD__) serve the
    // /__preview harness for Ava screenshots with no live Supabase, so skip
    // the fetch there.
    useEffect(() => {
        if (typeof __PREVIEW_BUILD__ !== 'undefined' && __PREVIEW_BUILD__) {
            return;
        }
        fetchDietPlans();
    }, [fetchDietPlans]);

    // Patient operations
    const getPatient = useCallback((id: string) => {
        return patients.find(p => p.id === id);
    }, [patients]);

    // TC-018 (Henry add-on, Create Patient): the real patient-creation path
    // is pages/admin/CreatePatient.tsx -> lib/patientsApi.createPatient ->
    // the create-patient Edge Function -> create_patient_record() (real
    // patients table, existing RLS + audit path, no shadow table) - not
    // this context, which has no real patients backing store to add to.

    // TC-018 (29 Oct, Clara #16): these used to write to the removed
    // `profiles` table. patients is local-only state now (nothing populates
    // it from a backing store either - see the fetch removal note above),
    // so there is no real table to round-trip through; update/delete act on
    // that local state directly instead of a dead network call.
    const updatePatient = useCallback(async (id: string, updates: Partial<PatientProfile>) => {
        setPatients(prev => prev.map(p =>
            p.id === id ? { ...p, ...updates } : p
        ));
        showToast('Patient updated successfully', 'success');
    }, []);

    const deletePatient = useCallback(async (id: string) => {
        setPatients(prev => prev.filter(p => p.id !== id));
        showToast('Patient deleted successfully', 'success');
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
        updatePatient,
        deletePatient,
        advanceStage,
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
                // TC-021 item 13: bottom-centre (like components/ui/Toast), not
                // bottom-right, where it covered the pinned row-actions column.
                <div className={`fixed bottom-6 left-1/2 -translate-x-1/2 px-6 py-4 rounded-xl shadow-2xl flex items-center gap-3 transition-all duration-500 z-50 ${toast.type === 'success' ? 'bg-emerald-600 text-white' :
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
