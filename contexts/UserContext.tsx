import React, { createContext, useContext, ReactNode, useState, useEffect, useCallback } from 'react';
import { HealthJourney, JourneyPhase, PatientProfile, IntelligenceData, SubscriptionPlan } from '../types';
import { useAuth } from './AuthContext';
import { supabase } from '../lib/supabase';

interface UserContextType {
    // User Info
    userId: string;
    patientProfile: PatientProfile | null;
    loading: boolean;

    // Subscription Plan Helpers
    subscriptionPlan: SubscriptionPlan;
    isPro: () => boolean;
    isUltimate: () => boolean;

    // Journey Data
    publishedJourney: HealthJourney | null;
    currentPhase: JourneyPhase | null;
    currentPhaseIndex: number;

    // Intelligence Data
    publishedIntelligence: IntelligenceData | null;

    // Journey Navigation
    setCurrentPhaseIndex: (index: number) => void;
    advanceToNextPhase: () => void;

    // Protocol Access
    getProtocolSection: (section: 'lifestyle' | 'diet' | 'fitness' | 'supplements') => any;
    isProtocolPublished: () => boolean;
    hasAnyPublishedContent: () => boolean;

    // Refresh
    refreshJourney: () => void;
    refreshProfile: () => Promise<void>;
    refreshIntelligence: () => void;
}

const UserContext = createContext<UserContextType | undefined>(undefined);

export const useUser = () => {
    const context = useContext(UserContext);
    if (!context) {
        throw new Error('useUser must be used within UserProvider');
    }
    return context;
};

interface UserProviderProps {
    children: ReactNode;
}

export const UserProvider: React.FC<UserProviderProps> = ({ children }) => {
    const { user } = useAuth();
    const [patientProfile, setPatientProfile] = useState<PatientProfile | null>(null);
    const [publishedJourney, setPublishedJourney] = useState<HealthJourney | null>(null);
    const [publishedIntelligence, setPublishedIntelligence] = useState<IntelligenceData | null>(null);
    const [currentPhaseIndex, setCurrentPhaseIndex] = useState(0);
    const [loading, setLoading] = useState(true);

    // TC-018 (29 Oct, Clara #16): this used to fetch/create a row in the
    // removed `profiles` table. There is no replacement patient-profile
    // table backing this legacy web portal (the real patient app is
    // flutter_app/ - see CLAUDE.md), so patientProfile stays null, same
    // observable result the dead query already produced (every call
    // errored against a table that doesn't exist), minus the wasted
    // request and the create-on-404 write attempt.
    const initializePatientProfile = useCallback(async () => {
        setPatientProfile(null);
        setLoading(false);
    }, [user]);

    // Initialize patient profile when auth user changes
    useEffect(() => {
        initializePatientProfile();
    }, [initializePatientProfile]);

    // Load published health journey from Supabase
    const loadJourney = useCallback(async () => {
        if (!patientProfile) {
            setPublishedJourney(null);
            return;
        }

        try {
            // Fetch journey for this patient (don't filter by status yet)
            const { data: journeys, error } = await supabase
                .from('health_journeys')
                .select('*')
                .eq('profile_id', patientProfile.id)
                .order('created_at', { ascending: false })
                .limit(1);

            console.log('Loading journey for user:', patientProfile.id);
            console.log('Found journeys:', journeys);

            if (error) {
                console.error('Error loading journey:', error);
                setPublishedJourney(null);
            } else if (journeys && journeys.length > 0) {
                const journey = journeys[0];
                console.log('Journey found:', journey);
                console.log('Journey status:', journey.status);
                console.log('Journey phases:', journey.phases);

                // Map database format to HealthJourney type
                const healthJourney: HealthJourney = {
                    id: journey.id,
                    patientId: journey.profile_id,
                    title: journey.title,
                    status: journey.status,
                    phases: journey.phases || [],
                    currentPhaseIndex: 0, // Default to first phase
                    createdAt: journey.created_at || new Date().toISOString(),
                    lastUpdated: journey.updated_at || new Date().toISOString(),
                    generatedByAI: false
                };

                console.log('Mapped journey:', healthJourney);
                setPublishedJourney(healthJourney);
            } else {
                console.log('No journey found for user');
                setPublishedJourney(null);
            }
        } catch (error) {
            console.error('Error loading journey:', error);
            setPublishedJourney(null);
        }
    }, [patientProfile]);

    useEffect(() => {
        if (patientProfile) {
            loadJourney();
        }
    }, [patientProfile, loadJourney]);

    // Load published intelligence data from Supabase
    const loadIntelligence = useCallback(async () => {
        if (!patientProfile) {
            setPublishedIntelligence(null);
            return;
        }

        try {
            const { data, error } = await supabase
                .from('intelligence_data')
                .select('*')
                .eq('profile_id', patientProfile.id)
                .eq('published', true)
                .order('created_at', { ascending: false })
                .limit(1)
                .maybeSingle();

            // Silently handle - no published intelligence is normal
            if (error || !data) {
                setPublishedIntelligence(null);
                return;
            }

            if (data) {
                const intelligence: IntelligenceData = {
                    overallScore: data.longevity_score || 75,
                    biomarkersScore: data.biomarker_summary?.overall_score || 82,
                    lifestyleScore: data.biomarker_summary?.lifestyle_score || 68,
                    riskFactorsScore: data.biomarker_summary?.risk_score || 71,
                    healthDomains: data.key_insights?.health_domains || [],
                    diseaseRisks: data.disease_risks || [],
                    approved: data.approved || false,
                    published: data.published || false,
                };
                setPublishedIntelligence(intelligence);
            } else {
                setPublishedIntelligence(null);
            }
        } catch (error) {
            console.error('Error loading intelligence:', error);
            setPublishedIntelligence(null);
        }
    }, [patientProfile]);

    useEffect(() => {
        if (patientProfile) {
            loadIntelligence();
        }
    }, [patientProfile, loadIntelligence]);

    const currentPhase = publishedJourney?.phases[currentPhaseIndex] || null;

    const advanceToNextPhase = useCallback(() => {
        if (publishedJourney && currentPhaseIndex < publishedJourney.phases.length - 1) {
            setCurrentPhaseIndex(currentPhaseIndex + 1);
        }
    }, [publishedJourney, currentPhaseIndex]);

    const getProtocolSection = useCallback((section: 'lifestyle' | 'diet' | 'fitness' | 'supplements') => {
        if (!currentPhase) return null;

        const sectionData = currentPhase.protocol[section];

        // Only return if published
        if (sectionData && (sectionData as any).published) {
            return sectionData;
        }

        return null;
    }, [currentPhase]);

    const isProtocolPublished = useCallback(() => {
        if (!currentPhase) return false;

        return ['lifestyle', 'diet', 'fitness', 'supplements'].every(section => {
            const sectionData = currentPhase.protocol[section as keyof typeof currentPhase.protocol];
            return sectionData && (sectionData as any).published === true;
        });
    }, [currentPhase]);

    const hasAnyPublishedContent = useCallback(() => {
        if (!publishedJourney) return false;

        return publishedJourney.phases.some(phase =>
            ['lifestyle', 'diet', 'fitness', 'supplements'].some(section => {
                const sectionData = phase.protocol[section as keyof typeof phase.protocol];
                return sectionData && (sectionData as any).published === true;
            })
        );
    }, [publishedJourney]);

    const refreshJourney = useCallback(() => {
        loadJourney();
    }, [loadJourney]);

    const refreshIntelligence = useCallback(() => {
        loadIntelligence();
    }, [loadIntelligence]);

    const value: UserContextType = {
        userId: patientProfile?.id || '',
        patientProfile,
        loading,
        subscriptionPlan: patientProfile?.subscriptionPlan || 'pro',
        isPro: () => (patientProfile?.subscriptionPlan || 'pro') === 'pro',
        isUltimate: () => patientProfile?.subscriptionPlan === 'ultimate',
        publishedJourney,
        currentPhase,
        currentPhaseIndex,
        publishedIntelligence,
        setCurrentPhaseIndex,
        advanceToNextPhase,
        getProtocolSection,
        isProtocolPublished,
        hasAnyPublishedContent,
        refreshJourney,
        refreshProfile: initializePatientProfile,
        refreshIntelligence
    };

    return (
        <UserContext.Provider value={value}>
            {children}
        </UserContext.Provider>
    );
};
