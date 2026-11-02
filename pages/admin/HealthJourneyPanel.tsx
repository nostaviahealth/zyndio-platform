import React, { useState, useEffect } from 'react';
import { useNavigate } from 'react-router-dom';
import {
    Sparkles, CheckCircle, Calendar, Target,
    Sunrise, Utensils, Dumbbell, Pill, Edit2, Plus, ArrowRight, Clock, Eye, X, Save
} from 'lucide-react';
import { HealthJourney, JourneyPhase } from '../../types';
import { supabase } from '../../lib/supabase';

interface HealthJourneyPanelProps {
    patientId: string;
    patientName: string;
    hasAllData: boolean;
}

const HealthJourneyPanel: React.FC<HealthJourneyPanelProps> = ({ patientId, patientName, hasAllData }) => {
    const navigate = useNavigate();
    const [journey, setJourney] = useState<HealthJourney | null>(null);
    const [isGenerating, setIsGenerating] = useState(false);
    const [activeModal, setActiveModal] = useState<{ phaseId: string; section: string } | null>(null);
    const [editMode, setEditMode] = useState(false);

    useEffect(() => {
        loadJourney();
    }, [patientId]);

    const loadJourney = async () => {
        try {
            const { data, error } = await supabase
                .from('health_journeys')
                .select('*')
                .eq('profile_id', patientId)
                .order('created_at', { ascending: false })
                .limit(1)
                .single();

            if (error && error.code !== 'PGRST116') {
                console.error('Error loading journey:', error);
                return;
            }

            if (data) {
                const healthJourney: HealthJourney = {
                    id: data.id,
                    patientId: data.profile_id,
                    title: data.title,
                    status: data.status,
                    phases: data.phases || [],
                    currentPhaseIndex: 0,
                    createdAt: data.created_at,
                    lastUpdated: data.updated_at,
                    generatedByAI: false
                };
                setJourney(healthJourney);
            }
        } catch (error) {
            console.error('Error loading journey:', error);
        }
    };

    const saveJourney = async (updatedJourney: HealthJourney) => {
        try {
            const journeyData = {
                profile_id: patientId,
                title: `Health Journey for Patient`,
                status: updatedJourney.status || 'draft',
                phases: updatedJourney.phases,
                updated_at: new Date().toISOString()
            };

            // Check if journey exists
            const { data: existing } = await supabase
                .from('health_journeys')
                .select('id')
                .eq('profile_id', patientId)
                .single();

            if (existing) {
                // Update existing
                const { error } = await supabase
                    .from('health_journeys')
                    .update(journeyData)
                    .eq('id', existing.id);

                if (error) throw error;
                updatedJourney.id = existing.id;
            } else {
                // Create new
                const { data, error } = await supabase
                    .from('health_journeys')
                    .insert([{
                        ...journeyData,
                        created_at: new Date().toISOString()
                    }])
                    .select()
                    .single();

                if (error) throw error;
                if (data) updatedJourney.id = data.id;
            }

            updatedJourney.lastUpdated = new Date().toISOString();
            setJourney(updatedJourney);
        } catch (error) {
            console.error('Error saving journey:', error);
            alert('Failed to save journey to database');
        }
    };

    const generateJourney = async () => {
        setIsGenerating(true);

        setTimeout(async () => {
            const newJourney: HealthJourney = {
                id: `journey-${Date.now()}`,
                patientId,
                title: `Health Journey for Patient`,
                status: 'draft',
                currentPhaseIndex: 0,
                createdAt: new Date().toISOString(),
                lastUpdated: new Date().toISOString(),
                generatedByAI: true,
                phases: [
                    {
                        id: `phase-${Date.now()}-1`,
                        phaseNumber: 1,
                        goal: {
                            type: 'disease_risk_reduction',
                            description: 'Reduce Cardiovascular Disease Risk',
                            targetDisease: 'Cardiovascular Disease',
                            targetMetrics: ['LDL Cholesterol', 'Blood Pressure', 'Triglycerides']
                        },
                        status: 'active',
                        durationWeeks: 12,
                        protocol: {
                            lifestyle: {
                                habits: [
                                    { name: 'Morning Sunlight', time: '07:00 AM', duration: '15 min', icon: 'Sun', desc: 'Morning light exposure for circadian rhythm' },
                                    { name: 'Meditation', time: '08:00 PM', duration: '20 min', icon: 'Brain', desc: 'Stress reduction practice' }
                                ],
                                approved: false,
                                published: false,
                                lastUpdated: new Date().toISOString()
                            },
                            diet: {
                                principles: ['Mediterranean Diet', 'Low Sodium', 'Heart-Healthy Fats'],
                                macros: { protein: '25%', fats: '35%', carbs: '40%' },
                                calories: 2000,
                                exclusions: ['Trans Fats', 'Processed Foods'],
                                approved: false,
                                published: false,
                                lastUpdated: new Date().toISOString()
                            },
                            fitness: {
                                pillars: [
                                    { title: 'Cardio Training', desc: 'Heart health focus', tag: '5x/week', icon: 'Activity' },
                                    { title: 'Resistance Training', desc: 'Muscle maintenance', tag: '2x/week', icon: 'Dumbbell' }
                                ],
                                approved: false,
                                published: false,
                                lastUpdated: new Date().toISOString()
                            },
                            supplements: {
                                items: [
                                    { name: 'Omega-3 Fish Oil', dosage: '2g', timing: 'With breakfast', purpose: 'Cardiovascular health' },
                                    { name: 'CoQ10', dosage: '200mg', timing: 'Morning', purpose: 'Heart function support' }
                                ],
                                approved: false,
                                published: false,
                                lastUpdated: new Date().toISOString()
                            },
                            allApproved: false
                        }
                    },
                    {
                        id: `phase-${Date.now()}-2`,
                        phaseNumber: 2,
                        goal: {
                            type: 'longevity',
                            description: 'Optimize Metabolic Health & Longevity',
                            targetMetrics: ['Glucose Control', 'Inflammation Markers']
                        },
                        status: 'draft',
                        durationWeeks: 16,
                        protocol: {
                            lifestyle: {
                                habits: [
                                    { name: 'Intermittent Fasting', time: '16:8', duration: 'Daily', icon: 'Clock', desc: 'Metabolic optimization' },
                                    { name: 'Cold Exposure', time: '07:30 AM', duration: '3 min', icon: 'Droplets', desc: 'Hormetic stress' }
                                ],
                                approved: false,
                                published: false,
                                lastUpdated: new Date().toISOString()
                            },
                            diet: {
                                principles: ['Time-Restricted Eating', 'Low Glycemic', 'Anti-Inflammatory'],
                                macros: { protein: '30%', fats: '40%', carbs: '30%' },
                                calories: 2200,
                                exclusions: ['Refined Sugar', 'Processed Carbs'],
                                approved: false,
                                published: false,
                                lastUpdated: new Date().toISOString()
                            },
                            fitness: {
                                pillars: [
                                    { title: 'Zone 2 Cardio', desc: 'Mitochondrial efficiency', tag: 'Daily', icon: 'Activity' },
                                    { title: 'Strength Training', desc: 'Muscle mass preservation', tag: '3x/week', icon: 'Dumbbell' }
                                ],
                                approved: false,
                                published: false,
                                lastUpdated: new Date().toISOString()
                            },
                            supplements: {
                                items: [
                                    { name: 'NMN', dosage: '500mg', timing: 'Morning', purpose: 'NAD+ optimization' },
                                    { name: 'Resveratrol', dosage: '500mg', timing: 'Morning with fat', purpose: 'Longevity pathways' }
                                ],
                                approved: false,
                                published: false,
                                lastUpdated: new Date().toISOString()
                            },
                            allApproved: false
                        }
                    }
                ]
            };

            await saveJourney(newJourney);
            setIsGenerating(false);
        }, 5000);
    };

    const handleApproveSection = (phaseId: string, section: 'lifestyle' | 'diet' | 'fitness' | 'supplements') => {
        if (!journey) return;

        const updatedJourney = { ...journey };
        const phase = updatedJourney.phases.find(p => p.id === phaseId);

        if (phase && phase.protocol[section]) {
            (phase.protocol[section] as any).approved = true;
            (phase.protocol[section] as any).lastUpdated = new Date().toLocaleString();

            const allApproved =
                (phase.protocol.lifestyle?.approved ?? false) &&
                (phase.protocol.diet?.approved ?? false) &&
                (phase.protocol.fitness?.approved ?? false) &&
                (phase.protocol.supplements?.approved ?? false);

            phase.protocol.allApproved = allApproved;

            if (allApproved && phase.status === 'draft') {
                phase.status = 'active';
            }
        }

        saveJourney(updatedJourney);
        setActiveModal(null);
    };

    const handlePublishSection = async (phaseId: string, section: 'lifestyle' | 'diet' | 'fitness' | 'supplements') => {
        if (!journey) return;

        const updatedJourney = { ...journey };
        const phase = updatedJourney.phases.find(p => p.id === phaseId);

        if (phase && phase.protocol[section]) {
            (phase.protocol[section] as any).published = true;
            (phase.protocol[section] as any).publishedAt = new Date().toISOString();
        }

        // Check if all sections are published
        const allPublished = phase &&
            ['lifestyle', 'diet', 'fitness', 'supplements'].every(s =>
                (phase.protocol[s as keyof typeof phase.protocol] as any)?.published === true
            );

        // If all sections published, update journey status and user profile
        if (allPublished) {
            updatedJourney.status = 'published';

            // Mark the patient's clinical profile as protocol_ready. The removed
            // `profiles` table is replaced by the org-scoped patient_profiles
            // (data jsonb, staff-write RLS). Merge into the existing row's data;
            // like the old write this only updates an existing row (a fresh
            // patient_profiles row requires org_id, which this panel doesn't hold).
            const { data: existingProfile } = await supabase
                .from('patient_profiles')
                .select('id, data')
                .eq('patient_id', patientId)
                .single();

            if (existingProfile) {
                await supabase
                    .from('patient_profiles')
                    .update({
                        data: {
                            ...(existingProfile.data || {}),
                            stage: 'protocol_ready',
                            is_protocol_published: true
                        },
                        updated_at: new Date().toISOString()
                    })
                    .eq('id', existingProfile.id);
            }
        }

        await saveJourney(updatedJourney);
    };

    const updateProtocolSection = (phaseId: string, section: string, data: any) => {
        if (!journey) return;

        const updatedJourney = { ...journey };
        const phase = updatedJourney.phases.find(p => p.id === phaseId);

        if (phase) {
            (phase.protocol as any)[section] = {
                ...data,
                approved: false,
                published: false,
                lastUpdated: new Date().toLocaleString()
            };
        }

        saveJourney(updatedJourney);
    };

    const getSectionIcon = (type: string) => {
        switch (type) {
            case 'lifestyle': return Sunrise;
            case 'diet': return Utensils;
            case 'fitness': return Dumbbell;
            case 'supplements': return Pill;
            default: return CheckCircle;
        }
    };

    const renderProtocolCard = (phase: JourneyPhase, sectionKey: 'lifestyle' | 'diet' | 'fitness' | 'supplements') => {
        const section = phase.protocol[sectionKey];
        const Icon = getSectionIcon(sectionKey);
        const label = sectionKey.charAt(0).toUpperCase() + sectionKey.slice(1);

        const getStatusColor = () => {
            if ((section as any)?.published) return 'emerald';
            if (section?.approved) return 'blue';
            return 'amber';
        };

        const color = getStatusColor();

        return (
            <div
                key={sectionKey}
                className={`p-6 rounded-2xl border-2 transition-all ${(section as any)?.published
                    ? 'border-emerald-300 bg-emerald-50/50'
                    : section?.approved
                        ? 'border-blue-300 bg-blue-50/50'
                        : 'border-slate-200 bg-white'
                    }`}
            >
                <div className="flex items-start justify-between mb-4">
                    <div className="flex items-center gap-3">
                        <div className={`w-12 h-12 rounded-xl bg-${color}-100 flex items-center justify-center`}>
                            <Icon className={`w-6 h-6 text-${color}-600`} />
                        </div>
                        <div>
                            <h4 className="font-semibold text-slate-900">{label}</h4>
                            {section?.lastUpdated && (
                                <p className="text-xs text-slate-500 mt-0.5">Updated {section.lastUpdated}</p>
                            )}
                        </div>
                    </div>

                    <div className="flex flex-col gap-1 items-end">
                        {(section as any)?.published && (
                            <div className="flex items-center gap-1 bg-emerald-100 text-emerald-700 px-3 py-1 rounded-full text-xs font-semibold">
                                <CheckCircle className="w-4 h-4" />
                                Published
                            </div>
                        )}
                        {section?.approved && !(section as any)?.published && (
                            <div className="flex items-center gap-1 bg-blue-100 text-blue-700 px-3 py-1 rounded-full text-xs font-semibold">
                                <CheckCircle className="w-4 h-4" />
                                Approved
                            </div>
                        )}
                        {!section?.approved && (
                            <div className="flex items-center gap-1 bg-amber-100 text-amber-700 px-3 py-1 rounded-full text-xs font-semibold">
                                Pending
                            </div>
                        )}
                    </div>
                </div>

                <div className="flex gap-2">
                    <button
                        onClick={() => {
                            setActiveModal({ phaseId: phase.id, section: sectionKey });
                            setEditMode(false);
                        }}
                        className="flex-1 flex items-center justify-center gap-2 px-4 py-2.5 bg-slate-100 hover:bg-slate-200 text-slate-700 rounded-lg font-medium transition-colors"
                    >
                        <Eye className="w-4 h-4" />
                        View
                    </button>

                    <button
                        onClick={() => {
                            setActiveModal({ phaseId: phase.id, section: sectionKey });
                            setEditMode(true);
                        }}
                        className="flex-1 flex items-center justify-center gap-2 px-4 py-2.5 bg-blue-100 hover:bg-blue-200 text-blue-700 rounded-lg font-medium transition-colors"
                    >
                        <Edit2 className="w-4 h-4" />
                        Edit
                    </button>

                    {!section?.approved && (
                        <button
                            onClick={() => handleApproveSection(phase.id, sectionKey)}
                            className="flex-1 flex items-center justify-center gap-2 px-4 py-2.5 bg-emerald-500 hover:bg-emerald-600 text-white rounded-lg font-medium transition-colors"
                        >
                            <CheckCircle className="w-4 h-4" />
                            Approve
                        </button>
                    )}
                </div>

                {section?.approved && !(section as any)?.published && (
                    <button
                        onClick={() => handlePublishSection(phase.id, sectionKey)}
                        className="w-full mt-2 flex items-center justify-center gap-2 px-4 py-2.5 bg-gradient-to-r from-purple-600 to-purple-700 text-white rounded-lg font-semibold shadow-lg hover:shadow-xl transition-all"
                    >
                        <Sparkles className="w-4 h-4" />
                        Publish to User
                    </button>
                )}
            </div>
        );
    };

    return (
        <div className="space-y-6">
            {!journey && (
                <div className={`p-8 rounded-3xl border-2 ${hasAllData
                    ? 'bg-gradient-to-br from-emerald-50 to-emerald-100/50 border-emerald-200'
                    : 'bg-gradient-to-br from-amber-50 to-amber-100/50 border-amber-200'
                    }`}>
                    <div className="flex items-center justify-between">
                        <div className="flex items-center gap-4">
                            <div className={`w-16 h-16 rounded-2xl flex items-center justify-center ${hasAllData ? 'bg-emerald-200' : 'bg-amber-200'
                                }`}>
                                <Sparkles className={`w-8 h-8 ${hasAllData ? 'text-emerald-700' : 'text-amber-700'}`} />
                            </div>
                            <div>
                                <h3 className="text-xl font-serif text-slate-900 mb-1">
                                    {hasAllData ? 'Ready to Generate Health Journey' : 'Complete Prerequisites First'}
                                </h3>
                                <p className="text-sm text-slate-600">
                                    {hasAllData
                                        ? 'AI will create a personalized multi-phase protocol based on patient data'
                                        : 'Upload lab report, questionnaire, and add wellness insights to proceed'}
                                </p>
                            </div>
                        </div>

                        <button
                            onClick={generateJourney}
                            disabled={!hasAllData || isGenerating}
                            className={`flex items-center gap-2 px-8 py-4 rounded-xl font-semibold text-lg transition-all ${hasAllData && !isGenerating
                                ? 'bg-gradient-to-r from-emerald-600 to-emerald-700 text-white shadow-xl hover:shadow-2xl hover:scale-105'
                                : 'bg-slate-200 text-slate-400 cursor-not-allowed'
                                }`}
                        >
                            {isGenerating ? (
                                <>
                                    <div className="w-6 h-6 border-2 border-white border-t-transparent rounded-full animate-spin" />
                                    Generating Journey...
                                </>
                            ) : (
                                <>
                                    <Sparkles className="w-6 h-6" />
                                    Generate Health Journey
                                </>
                            )}
                        </button>
                    </div>
                </div>
            )}

            {journey && (
                <div className="space-y-6">
                    <div className="bg-gradient-to-r from-slate-900 to-slate-800 rounded-3xl p-6 text-white">
                        <div className="flex items-center justify-between">
                            <div>
                                <h2 className="text-2xl font-serif mb-2">Health Journey for {patientName}</h2>
                                <p className="text-slate-300 text-sm">Created {journey.createdAt} • {journey.phases.length} Phases</p>
                            </div>
                            <div className="flex items-center gap-2 bg-white/10 px-4 py-2 rounded-xl">
                                <Clock className="w-5 h-5" />
                                <span className="text-sm">Phase {journey.currentPhaseIndex + 1} Active</span>
                            </div>
                        </div>
                    </div>

                    {journey.phases.map((phase) => (
                        <div
                            key={phase.id}
                            className={`rounded-3xl p-8 border-2 transition-all ${phase.status === 'active'
                                ? 'bg-gradient-to-br from-blue-50 to-blue-100/50 border-blue-300 shadow-xl'
                                : phase.status === 'completed'
                                    ? 'bg-gradient-to-br from-emerald-50 to-emerald-100/50 border-emerald-200'
                                    : 'bg-white border-slate-200'
                                }`}
                        >
                            <div className="flex items-start justify-between mb-6">
                                <div className="flex items-center gap-4">
                                    <div className={`w-16 h-16 rounded-2xl flex items-center justify-center font-bold text-2xl ${phase.status === 'active' ? 'bg-blue-200 text-blue-700' :
                                        phase.status === 'completed' ? 'bg-emerald-200 text-emerald-700' :
                                            'bg-slate-200 text-slate-600'
                                        }`}>
                                        {phase.phaseNumber}
                                    </div>
                                    <div>
                                        <div className="flex items-center gap-2 mb-1">
                                            <span className={`px-3 py-1 rounded-full text-xs font-bold ${phase.status === 'active' ? 'bg-blue-600 text-white' :
                                                phase.status === 'completed' ? 'bg-emerald-600 text-white' :
                                                    'bg-slate-300 text-slate-700'
                                                }`}>
                                                {phase.status.toUpperCase()}
                                            </span>
                                            <span className="text-xs text-slate-500">{phase.durationWeeks} weeks</span>
                                        </div>
                                        <h3 className="text-xl font-serif text-slate-900 mb-1">{phase.goal.description}</h3>
                                        <div className="flex items-center gap-2 text-sm text-slate-600">
                                            <Target className="w-4 h-4" />
                                            <span className="capitalize">{phase.goal.type.replace('_', ' ')}</span>
                                        </div>
                                    </div>
                                </div>

                                {phase.protocol.allApproved && (
                                    <div className="flex items-center gap-2 bg-emerald-100 text-emerald-700 px-4 py-2 rounded-xl">
                                        <CheckCircle className="w-5 h-5" />
                                        <span className="font-semibold">All Approved</span>
                                    </div>
                                )}
                            </div>

                            {phase.goal.targetMetrics && (
                                <div className="mb-6 p-4 bg-white/50 rounded-xl">
                                    <h4 className="text-sm font-semibold text-slate-700 mb-2">Target Metrics:</h4>
                                    <div className="flex flex-wrap gap-2">
                                        {phase.goal.targetMetrics.map((metric, i) => (
                                            <span key={i} className="px-3 py-1 bg-slate-100 text-slate-700 rounded-full text-sm">
                                                {metric}
                                            </span>
                                        ))}
                                    </div>
                                </div>
                            )}

                            <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
                                {renderProtocolCard(phase, 'lifestyle')}
                                {renderProtocolCard(phase, 'diet')}
                                {renderProtocolCard(phase, 'fitness')}
                                {renderProtocolCard(phase, 'supplements')}
                            </div>

                            {phase.protocol.diet?.approved && phase.status === 'active' && (
                                <div className="mt-6 p-4 bg-blue-50 border-2 border-blue-200 rounded-2xl">
                                    <div className="flex items-center justify-between">
                                        <div className="flex items-center gap-3">
                                            <Utensils className="w-6 h-6 text-blue-600" />
                                            <div>
                                                <p className="font-semibold text-slate-900">Weekly Meal Plan</p>
                                                <p className="text-sm text-slate-600">Create detailed diet plan for this phase</p>
                                            </div>
                                        </div>
                                        <button
                                            onClick={() => navigate(`/admin/nutrition-lab?patient=${patientId}&phase=${phase.id}`)}
                                            className="flex items-center gap-2 bg-blue-600 text-white px-6 py-3 rounded-xl font-medium hover:bg-blue-700 transition-all"
                                        >
                                            Open Nutrition Lab
                                            <ArrowRight className="w-4 h-4" />
                                        </button>
                                    </div>
                                </div>
                            )}
                        </div>
                    ))}
                </div>
            )}

            {activeModal && journey && (
                <ProtocolModal
                    phase={journey.phases.find(p => p.id === activeModal.phaseId)!}
                    section={activeModal.section}
                    editMode={editMode}
                    onClose={() => setActiveModal(null)}
                    onSave={(data) => {
                        updateProtocolSection(activeModal.phaseId, activeModal.section, data);
                        setActiveModal(null);
                    }}
                    onApprove={() => handleApproveSection(activeModal.phaseId, activeModal.section as any)}
                />
            )}
        </div>
    );
};

const ProtocolModal: React.FC<{
    phase: JourneyPhase;
    section: string;
    editMode: boolean;
    onClose: () => void;
    onSave: (data: any) => void;
    onApprove: () => void;
}> = ({ phase, section, editMode, onClose, onSave, onApprove }) => {
    const sectionData = (phase.protocol as any)[section];
    const [data, setData] = useState(JSON.parse(JSON.stringify(sectionData)));
    const [isEditing, setIsEditing] = useState(editMode);
    const title = section.charAt(0).toUpperCase() + section.slice(1);

    const handleSave = () => {
        onSave(data);
        setIsEditing(false);
    };

    const addNewItem = () => {
        switch (section) {
            case 'lifestyle':
                setData({
                    ...data,
                    habits: [...data.habits, { name: 'New Habit', time: '09:00 AM', duration: '10 min', icon: 'Sun', desc: 'Description' }]
                });
                break;
            case 'supplements':
                setData({
                    ...data,
                    items: [...data.items, { name: 'New Supplement', dosage: '100mg', timing: 'Morning', purpose: 'Purpose' }]
                });
                break;
            case 'fitness':
                setData({
                    ...data,
                    pillars: [...data.pillars, { title: 'New Exercise', desc: 'Description', tag: '3x/week', icon: 'Activity' }]
                });
                break;
        }
    };

    const renderContent = () => {
        switch (section) {
            case 'lifestyle':
                return (
                    <div className="space-y-4">
                        <div className="flex items-center justify-between">
                            <h3 className="font-semibold text-lg">Daily Habits</h3>
                            {isEditing && (
                                <button onClick={addNewItem} className="flex items-center gap-1 px-3 py-1.5 bg-blue-500 text-white rounded-lg text-sm hover:bg-blue-600">
                                    <Plus className="w-4 h-4" />
                                    Add Habit
                                </button>
                            )}
                        </div>
                        {data.habits.map((habit: any, idx: number) => (
                            <div key={idx} className="p-4 bg-slate-50 rounded-xl">
                                {isEditing ? (
                                    <div className="space-y-2">
                                        <input value={habit.name} onChange={(e) => {
                                            const newHabits = [...data.habits];
                                            newHabits[idx].name = e.target.value;
                                            setData({ ...data, habits: newHabits });
                                        }} className="w-full px-3 py-2 border border-slate-300 rounded-lg" placeholder="Habit name" />
                                        <div className="grid grid-cols-2 gap-2">
                                            <input value={habit.time} onChange={(e) => {
                                                const newHabits = [...data.habits];
                                                newHabits[idx].time = e.target.value;
                                                setData({ ...data, habits: newHabits });
                                            }} className="px-3 py-2 border border-slate-300 rounded-lg" placeholder="Time" />
                                            <input value={habit.duration} onChange={(e) => {
                                                const newHabits = [...data.habits];
                                                newHabits[idx].duration = e.target.value;
                                                setData({ ...data, habits: newHabits });
                                            }} className="px-3 py-2 border border-slate-300 rounded-lg" placeholder="Duration" />
                                        </div>
                                        <textarea value={habit.desc} onChange={(e) => {
                                            const newHabits = [...data.habits];
                                            newHabits[idx].desc = e.target.value;
                                            setData({ ...data, habits: newHabits });
                                        }} className="w-full px-3 py-2 border border-slate-300 rounded-lg resize-none" rows={2} placeholder="Description" />
                                        <button onClick={() => {
                                            const newHabits = data.habits.filter((_: any, i: number) => i !== idx);
                                            setData({ ...data, habits: newHabits });
                                        }} className="text-red-600 text-sm hover:text-red-700">Remove</button>
                                    </div>
                                ) : (
                                    <>
                                        <h4 className="font-semibold">{habit.name}</h4>
                                        <p className="text-sm text-slate-600 mt-1">{habit.time} • {habit.duration}</p>
                                        <p className="text-sm text-slate-700 mt-2">{habit.desc}</p>
                                    </>
                                )}
                            </div>
                        ))}
                    </div>
                );

            case 'diet':
                return (
                    <div className="space-y-4">
                        <div>
                            <h3 className="font-semibold text-lg mb-2">Dietary Principles</h3>
                            {isEditing ? (
                                <div className="space-y-2">
                                    {data.principles.map((p: string, i: number) => (
                                        <input key={i} value={p} onChange={(e) => {
                                            const newPrinciples = [...data.principles];
                                            newPrinciples[i] = e.target.value;
                                            setData({ ...data, principles: newPrinciples });
                                        }} className="w-full px-3 py-2 border border-slate-300 rounded-lg" />
                                    ))}
                                </div>
                            ) : (
                                <div className="flex flex-wrap gap-2">
                                    {data.principles.map((p: string, i: number) => (
                                        <span key={i} className="px-3 py-1 bg-emerald-100 text-emerald-700 rounded-full text-sm">{p}</span>
                                    ))}
                                </div>
                            )}
                        </div>

                        <div className="p-4 bg-slate-50 rounded-xl">
                            <h4 className="font-semibold mb-3">Daily Targets</h4>
                            {isEditing ? (
                                <div className="grid grid-cols-2 gap-3">
                                    <div>
                                        <label className="text-xs text-slate-600 block mb-1">Calories</label>
                                        <input type="number" value={data.calories} onChange={(e) => setData({ ...data, calories: parseInt(e.target.value) })} className="w-full px-3 py-2 border border-slate-300 rounded-lg" />
                                    </div>
                                    <div>
                                        <label className="text-xs text-slate-600 block mb-1">Protein</label>
                                        <input value={data.macros.protein} onChange={(e) => setData({ ...data, macros: { ...data.macros, protein: e.target.value } })} className="w-full px-3 py-2 border border-slate-300 rounded-lg" />
                                    </div>
                                    <div>
                                        <label className="text-xs text-slate-600 block mb-1">Carbs</label>
                                        <input value={data.macros.carbs} onChange={(e) => setData({ ...data, macros: { ...data.macros, carbs: e.target.value } })} className="w-full px-3 py-2 border border-slate-300 rounded-lg" />
                                    </div>
                                    <div>
                                        <label className="text-xs text-slate-600 block mb-1">Fats</label>
                                        <input value={data.macros.fats} onChange={(e) => setData({ ...data, macros: { ...data.macros, fats: e.target.value } })} className="w-full px-3 py-2 border border-slate-300 rounded-lg" />
                                    </div>
                                </div>
                            ) : (
                                <div className="grid grid-cols-4 gap-4">
                                    <div><p className="text-xs text-slate-600">Calories</p><p className="text-lg font-bold">{data.calories}</p></div>
                                    <div><p className="text-xs text-slate-600">Protein</p><p className="text-lg font-bold text-blue-600">{data.macros.protein}</p></div>
                                    <div><p className="text-xs text-slate-600">Carbs</p><p className="text-lg font-bold text-purple-600">{data.macros.carbs}</p></div>
                                    <div><p className="text-xs text-slate-600">Fats</p><p className="text-lg font-bold text-amber-600">{data.macros.fats}</p></div>
                                </div>
                            )}
                        </div>
                    </div>
                );

            case 'fitness':
                return (
                    <div className="space-y-4">
                        <div className="flex items-center justify-between">
                            <h3 className="font-semibold text-lg">Fitness Pillars</h3>
                            {isEditing && (
                                <button onClick={addNewItem} className="flex items-center gap-1 px-3 py-1.5 bg-blue-500 text-white rounded-lg text-sm hover:bg-blue-600">
                                    <Plus className="w-4 h-4" />
                                    Add Pillar
                                </button>
                            )}
                        </div>
                        {data.pillars.map((pillar: any, idx: number) => (
                            <div key={idx} className="p-4 bg-slate-50 rounded-xl">
                                {isEditing ? (
                                    <div className="space-y-2">
                                        <input value={pillar.title} onChange={(e) => {
                                            const newPillars = [...data.pillars];
                                            newPillars[idx].title = e.target.value;
                                            setData({ ...data, pillars: newPillars });
                                        }} className="w-full px-3 py-2 border border-slate-300 rounded-lg" placeholder="Title" />
                                        <input value={pillar.tag} onChange={(e) => {
                                            const newPillars = [...data.pillars];
                                            newPillars[idx].tag = e.target.value;
                                            setData({ ...data, pillars: newPillars });
                                        }} className="w-full px-3 py-2 border border-slate-300 rounded-lg" placeholder="Frequency" />
                                        <textarea value={pillar.desc} onChange={(e) => {
                                            const newPillars = [...data.pillars];
                                            newPillars[idx].desc = e.target.value;
                                            setData({ ...data, pillars: newPillars });
                                        }} className="w-full px-3 py-2 border border-slate-300 rounded-lg resize-none" rows={2} placeholder="Description" />
                                        <button onClick={() => {
                                            const newPillars = data.pillars.filter((_: any, i: number) => i !== idx);
                                            setData({ ...data, pillars: newPillars });
                                        }} className="text-red-600 text-sm hover:text-red-700">Remove</button>
                                    </div>
                                ) : (
                                    <div className="flex items-start justify-between">
                                        <div className="flex-1">
                                            <h4 className="font-semibold">{pillar.title}</h4>
                                            <p className="text-sm text-slate-600 mt-1">{pillar.desc}</p>
                                        </div>
                                        <span className="px-3 py-1 bg-blue-100 text-blue-700 rounded-full text-sm font-medium">{pillar.tag}</span>
                                    </div>
                                )}
                            </div>
                        ))}
                    </div>
                );

            case 'supplements':
                return (
                    <div className="space-y-4">
                        <div className="flex items-center justify-between">
                            <h3 className="font-semibold text-lg">Supplements</h3>
                            {isEditing && (
                                <button onClick={addNewItem} className="flex items-center gap-1 px-3 py-1.5 bg-blue-500 text-white rounded-lg text-sm hover:bg-blue-600">
                                    <Plus className="w-4 h-4" />
                                    Add Supplement
                                </button>
                            )}
                        </div>
                        {data.items.map((item: any, idx: number) => (
                            <div key={idx} className="p-4 bg-slate-50 rounded-xl">
                                {isEditing ? (
                                    <div className="space-y-2">
                                        <input value={item.name} onChange={(e) => {
                                            const newItems = [...data.items];
                                            newItems[idx].name = e.target.value;
                                            setData({ ...data, items: newItems });
                                        }} className="w-full px-3 py-2 border border-slate-300 rounded-lg" placeholder="Supplement name" />
                                        <div className="grid grid-cols-2 gap-2">
                                            <input value={item.dosage} onChange={(e) => {
                                                const newItems = [...data.items];
                                                newItems[idx].dosage = e.target.value;
                                                setData({ ...data, items: newItems });
                                            }} className="px-3 py-2 border border-slate-300 rounded-lg" placeholder="Dosage" />
                                            <input value={item.timing} onChange={(e) => {
                                                const newItems = [...data.items];
                                                newItems[idx].timing = e.target.value;
                                                setData({ ...data, items: newItems });
                                            }} className="px-3 py-2 border border-slate-300 rounded-lg" placeholder="Timing" />
                                        </div>
                                        <textarea value={item.purpose} onChange={(e) => {
                                            const newItems = [...data.items];
                                            newItems[idx].purpose = e.target.value;
                                            setData({ ...data, items: newItems });
                                        }} className="w-full px-3 py-2 border border-slate-300 rounded-lg resize-none" rows={2} placeholder="Purpose" />
                                        <button onClick={() => {
                                            const newItems = data.items.filter((_: any, i: number) => i !== idx);
                                            setData({ ...data, items: newItems });
                                        }} className="text-red-600 text-sm hover:text-red-700">Remove</button>
                                    </div>
                                ) : (
                                    <>
                                        <div className="flex items-start justify-between mb-2">
                                            <h4 className="font-semibold">{item.name}</h4>
                                            <span className="px-3 py-1 bg-purple-100 text-purple-700 rounded-full text-sm font-medium">{item.dosage}</span>
                                        </div>
                                        <p className="text-sm text-slate-600">{item.timing}</p>
                                        <p className="text-sm text-slate-700 mt-1">{item.purpose}</p>
                                    </>
                                )}
                            </div>
                        ))}
                    </div>
                );

            default:
                return null;
        }
    };

    return (
        <div className="fixed inset-0 bg-black/ 50 backdrop-blur-sm z-50 flex items-center justify-center p-4" onClick={onClose}>
            <div className="bg-white rounded-3xl p-8 max-w-3xl w-full shadow-2xl max-h-[90vh] overflow-y-auto" onClick={(e) => e.stopPropagation()}>
                <div className="flex justify-between items-center mb-6">
                    <div>
                        <h2 className="text-2xl font-serif text-slate-900">{title} Protocol</h2>
                        <p className="text-sm text-slate-500">Phase {phase.phaseNumber} • {phase.goal.description}</p>
                    </div>
                    <div className="flex items-center gap-2">
                        {!isEditing && (
                            <button onClick={() => setIsEditing(true)} className="p-2 hover:bg-blue-100 rounded-full text-blue-600">
                                <Edit2 className="w-5 h-5" />
                            </button>
                        )}
                        <button onClick={onClose} className="p-2 hover:bg-slate-100 rounded-full">
                            <X className="w-5 h-5" />
                        </button>
                    </div>
                </div>

                {renderContent()}

                <div className="flex gap-3 mt-6">
                    {isEditing && (
                        <>
                            <button onClick={() => {
                                setData(JSON.parse(JSON.stringify(sectionData)));
                                setIsEditing(false);
                            }} className="flex-1 flex items-center justify-center gap-2 bg-slate-200 text-slate-700 py-3 rounded-xl font-semibold hover:bg-slate-300 transition-colors">
                                Cancel
                            </button>
                            <button onClick={handleSave} className="flex-1 flex items-center justify-center gap-2 bg-blue-600 text-white py-3 rounded-xl font-semibold hover:bg-blue-700 transition-colors">
                                <Save className="w-5 h-5" />
                                Save Changes
                            </button>
                        </>
                    )}

                    {!isEditing && !sectionData.approved && (
                        <button onClick={onApprove} className="flex-1 flex items-center justify-center gap-2 bg-emerald-600 text-white py-3 rounded-xl font-semibold hover:bg-emerald-700 transition-colors">
                            <CheckCircle className="w-5 h-5" />
                            Approve {title}
                        </button>
                    )}

                    {!isEditing && sectionData.approved && (
                        <div className="flex-1 flex items-center justify-center gap-2 bg-emerald-100 text-emerald-700 py-3 rounded-xl font-semibold">
                            <CheckCircle className="w-5 h-5" />
                            Approved {sectionData.published && '& Published'}
                        </div>
                    )}
                </div>
            </div>
        </div>
    );
};

export default HealthJourneyPanel;
