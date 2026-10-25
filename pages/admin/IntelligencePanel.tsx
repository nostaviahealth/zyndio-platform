import React, { useState, useEffect } from 'react';
import { Brain, Sparkles, CheckCircle, Lock, Unlock, Edit2, X, Plus, Trash2 } from 'lucide-react';
import { IntelligenceData } from '../../types';
import { supabase } from '../../lib/supabase';
import { getGradeFromScore } from '../../utils/grading';

interface IntelligencePanelProps {
    patientId: string;
    patientName: string;
    hasLabData: boolean;
}

const IntelligencePanel: React.FC<IntelligencePanelProps> = ({ patientId, patientName, hasLabData }) => {
    const [intelligence, setIntelligence] = useState<IntelligenceData | null>(null);
    const [isGenerating, setIsGenerating] = useState(false);
    const [showScoreEdit, setShowScoreEdit] = useState(false);
    const [showDomainEdit, setShowDomainEdit] = useState(false);
    const [showRiskEdit, setShowRiskEdit] = useState(false);
    const [editDomainIndex, setEditDomainIndex] = useState<number | null>(null);
    const [editRiskIndex, setEditRiskIndex] = useState<number | null>(null);

    useEffect(() => {
        loadIntelligence();
    }, [patientId]);

    const loadIntelligence = async () => {
        try {
            const { data, error } = await supabase
                .from('intelligence_data')
                .select('*')
                .eq('profile_id', patientId)
                .order('created_at', { ascending: false })
                .limit(1)
                .single();

            if (error && error.code !== 'PGRST116') {
                console.error('Error loading intelligence:', error);
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
                    generatedAt: data.generated_at,
                    publishedAt: data.published_at,
                    lastUpdated: data.updated_at
                };
                setIntelligence(intelligence);
            }
        } catch (error) {
            console.error('Error loading intelligence:', error);
        }
    };

    const saveIntelligence = async (data: IntelligenceData) => {
        try {
            const intelligenceRecord = {
                profile_id: patientId,
                longevity_score: data.overallScore,
                biomarker_summary: {
                    overall_score: data.biomarkersScore,
                    lifestyle_score: data.lifestyleScore,
                    risk_score: data.riskFactorsScore
                },
                key_insights: {
                    health_domains: data.healthDomains
                },
                disease_risks: data.diseaseRisks,
                approved: data.approved || false,
                published: data.published || false,
                generated_at: data.generatedAt || new Date().toISOString(),
                updated_at: new Date().toISOString()
            };

            // Check if record exists (use maybeSingle to avoid errors)
            const { data: existing } = await supabase
                .from('intelligence_data')
                .select('id')
                .eq('profile_id', patientId)
                .maybeSingle();

            let error;
            if (existing) {
                // Update existing
                const result = await supabase
                    .from('intelligence_data')
                    .update(intelligenceRecord)
                    .eq('id', existing.id);
                error = result.error;
            } else {
                // Create new with generated UUID
                const result = await supabase
                    .from('intelligence_data')
                    .insert([{
                        ...intelligenceRecord,
                        created_at: new Date().toISOString()
                    }]);
                error = result.error;
            }

            if (error) {
                console.error('Supabase error:', error);
                throw error;
            }

            // Update local state
            setIntelligence(data);
            console.log('✅ Intelligence saved successfully');
        } catch (error) {
            console.error('Error saving intelligence:', error);
            alert('Failed to save intelligence to database');
        }
    };

    const generateIntelligence = async () => {
        setIsGenerating(true);
        await new Promise(resolve => setTimeout(resolve, 5000));

        const newIntelligence: IntelligenceData = {
            overallScore: 82,
            biomarkersScore: 89,
            lifestyleScore: 75,
            riskFactorsScore: 68,
            healthDomains: [
                { name: 'Heart', score: 60, target: 70 },
                { name: 'Metabolic', score: 75, target: 80 },
                { name: 'Respiratory', score: 85, target: 80 },
                { name: 'Immune', score: 90, target: 85 },
                { name: 'Cognitive', score: 80, target: 75 },
            ],
            diseaseRisks: [
                { condition: 'Type 2 Diabetes', probability: 12, level: 'Moderate', drivers: ['Elevated HbA1c', 'Family history'] },
                { condition: 'Cardiovascular Disease', probability: 18, level: 'Moderate', drivers: ['High LDL', 'Sedentary lifestyle'] },
                { condition: 'Osteoporosis', probability: 8, level: 'Low', drivers: ['Family history'] }
            ],
            approved: false,
            published: false,
            generatedAt: new Date().toISOString()
        };

        await saveIntelligence(newIntelligence);
        setIsGenerating(false);
    };

    if (!hasLabData) {
        return (
            <div className="bg-purple-50/50 border-2 border-purple-200 rounded-3xl p-8">
                <div className="text-center">
                    <Brain className="w-16 h-16 text-purple-300 mx-auto mb-4" />
                    <h3 className="text-xl font-serif text-slate-900 mb-2">Intelligence Analysis Unavailable</h3>
                    <p className="text-slate-600">Upload lab data first to generate AI health scores.</p>
                </div>
            </div>
        );
    }

    return (
        <div className="space-y-6">
            <div className="bg-gradient-to-r from-purple-600 to-blue-600 rounded-3xl p-8 text-white">
                <div className="flex items-center justify-between">
                    <div>
                        <div className="flex items-center gap-3 mb-2">
                            <Brain className="w-8 h-8" />
                            <h2 className="text-2xl font-serif">Intelligence Analysis</h2>
                        </div>
                        <p className="text-purple-100">AI health scores and disease risk for {patientName}</p>
                    </div>
                    {!intelligence && (
                        <button
                            onClick={generateIntelligence}
                            disabled={isGenerating}
                            className="bg-white text-purple-600 px-6 py-3 rounded-xl font-semibold hover:bg-purple-50 transition-colors flex items-center gap-2 disabled:bg-purple-200"
                        >
                            <Sparkles className={`w-5 h-5 ${isGenerating ? 'animate-spin' : ''}`} />
                            {isGenerating ? 'Generating...' : 'Generate Intelligence'}
                        </button>
                    )}
                </div>
            </div>

            {intelligence && (
                <>
                    <div className="bg-white rounded-3xl p-6 shadow-soft">
                        <div className="flex items-center justify-between mb-4">
                            <h3 className="text-lg font-semibold">Overall AI Health Score</h3>
                            <div className="flex gap-2">
                                <button onClick={() => setShowScoreEdit(true)} className="p-2 hover:bg-slate-100 rounded-lg">
                                    <Edit2 className="w-4 h-4" />
                                </button>
                                {intelligence.approved ? (
                                    <span className="px-3 py-1 bg-blue-100 text-blue-700 rounded-full text-xs font-bold">Approved</span>
                                ) : (
                                    <span className="px-3 py-1 bg-amber-100 text-amber-700 rounded-full text-xs font-bold">Pending</span>
                                )}
                                {intelligence.published && (
                                    <span className="px-3 py-1 bg-emerald-100 text-emerald-700 rounded-full text-xs font-bold">Published</span>
                                )}
                            </div>
                        </div>
                        <div className="grid grid-cols-4 gap-4">
                            <div className="p-4 rounded-2xl bg-gradient-to-br from-emerald-50 to-emerald-100">
                                <div className="text-4xl font-bold text-emerald-700">{intelligence.overallScore}</div>
                                <div className="text-sm text-emerald-600">Overall</div>
                            </div>
                            <div className="p-4 rounded-2xl bg-slate-50">
                                <div className="text-2xl font-bold text-slate-700">{intelligence.biomarkersScore}</div>
                                <div className="text-xs text-slate-500">Biomarkers</div>
                            </div>
                            <div className="p-4 rounded-2xl bg-slate-50">
                                <div className="text-2xl font-bold text-slate-700">{intelligence.lifestyleScore}</div>
                                <div className="text-xs text-slate-500">Lifestyle</div>
                            </div>
                            <div className="p-4 rounded-2xl bg-slate-50">
                                <div className="text-2xl font-bold text-slate-700">{intelligence.riskFactorsScore}</div>
                                <div className="text-xs text-slate-500">Risk Factors</div>
                            </div>
                        </div>
                    </div>

                    <div className="bg-white rounded-3xl p-6 shadow-soft">
                        <h3 className="text-lg font-semibold mb-4">Health Domains</h3>
                        <div className="grid grid-cols-5 gap-4">
                            {intelligence.healthDomains.map((domain, idx) => {
                                const gradeInfo = getGradeFromScore(domain.score);
                                return (
                                    <div key={idx} className={`p-4 rounded-2xl text-center hover:opacity-90 cursor-pointer group relative ${gradeInfo.bgColor} border ${gradeInfo.borderColor}`} onClick={() => { setEditDomainIndex(idx); setShowDomainEdit(true); }}>
                                        <div className="absolute top-2 right-2 opacity-0 group-hover:opacity-100">
                                            <Edit2 className="w-3 h-3 text-slate-400" />
                                        </div>
                                        <div className={`text-3xl font-bold ${gradeInfo.textColor}`}>{gradeInfo.grade}</div>
                                        <div className="text-xs font-medium text-slate-700 mt-1">{domain.name}</div>
                                        <div className={`text-[10px] ${gradeInfo.textColor}`}>{gradeInfo.label}</div>
                                    </div>
                                );
                            })}
                        </div>
                    </div>

                    <div className="bg-white rounded-3xl p-6 shadow-soft">
                        <div className="flex justify-between items-center mb-4">
                            <h3 className="text-lg font-semibold">Disease Risk Predictions</h3>
                            <button onClick={() => { setEditRiskIndex(-1); setShowRiskEdit(true); }} className="flex items-center gap-2 px-4 py-2 bg-purple-100 text-purple-700 rounded-xl hover:bg-purple-200">
                                <Plus className="w-4 h-4" />
                                Add Risk
                            </button>
                        </div>
                        <div className="space-y-3">
                            {intelligence.diseaseRisks.map((risk, idx) => (
                                <div key={idx} className="p-4 rounded-2xl bg-slate-50 flex justify-between group">
                                    <div>
                                        <div className="flex items-center gap-2 mb-2">
                                            <h4 className="font-bold">{risk.condition}</h4>
                                            <span className={`px-2 py-0.5 rounded-full text-[10px] font-bold uppercase ${risk.level === 'High' ? 'bg-red-100 text-red-600' :
                                                risk.level === 'Moderate' ? 'bg-amber-100 text-amber-600' :
                                                    'bg-emerald-100 text-emerald-600'
                                                }`}>
                                                {risk.level}
                                            </span>
                                            <span className="text-lg font-bold">{risk.probability}%</span>
                                        </div>
                                        <div className="flex gap-2">
                                            {risk.drivers.map((driver, i) => (
                                                <span key={i} className="px-2 py-1 bg-white border rounded text-[10px]">{driver}</span>
                                            ))}
                                        </div>
                                    </div>
                                    <button onClick={() => { setEditRiskIndex(idx); setShowRiskEdit(true); }} className="p-2 opacity-0 group-hover:opacity-100 hover:bg-slate-200 rounded-lg h-fit">
                                        <Edit2 className="w-4 h-4" />
                                    </button>
                                </div>
                            ))}
                        </div>
                    </div>

                    <div className="flex gap-4">
                        {!intelligence.approved && (
                            <button
                                onClick={() => saveIntelligence({ ...intelligence, approved: true })}
                                className="flex-1 bg-blue-100 text-blue-700 px-6 py-4 rounded-xl font-semibold hover:bg-blue-200 flex items-center justify-center gap-2"
                            >
                                <CheckCircle className="w-5 h-5" />
                                Approve Intelligence
                            </button>
                        )}
                        {intelligence.approved && !intelligence.published && (
                            <button
                                onClick={() => saveIntelligence({ ...intelligence, published: true, publishedAt: new Date().toLocaleString() })}
                                className="flex-1 bg-gradient-to-r from-purple-600 to-purple-700 text-white px-6 py-4 rounded-xl font-semibold hover:shadow-xl flex items-center justify-center gap-2"
                            >
                                <Unlock className="w-5 h-5" />
                                Publish to User
                            </button>
                        )}
                        {intelligence.published && (
                            <button
                                onClick={() => {
                                    saveIntelligence({ ...intelligence, published: false });
                                    localStorage.removeItem(`user_${patientId}_intelligence`);
                                }}
                                className="flex-1 bg-red-100 text-red-700 px-6 py-4 rounded-xl font-semibold hover:bg-red-200 flex items-center justify-center gap-2"
                            >
                                <Lock className="w-5 h-5" />
                                Revoke Access
                            </button>
                        )}
                    </div>

                    {/* Edit Modals */}
                    {showScoreEdit && <ScoreEditModal intelligence={intelligence} onSave={(updated) => { saveIntelligence(updated); setShowScoreEdit(false); }} onClose={() => setShowScoreEdit(false)} />}
                    {showDomainEdit && editDomainIndex !== null && (
                        <DomainEditModal
                            domain={intelligence.healthDomains[editDomainIndex]}
                            onSave={(updated) => {
                                const newDomains = [...intelligence.healthDomains];
                                newDomains[editDomainIndex] = updated;
                                saveIntelligence({ ...intelligence, healthDomains: newDomains });
                                setShowDomainEdit(false);
                            }}
                            onClose={() => setShowDomainEdit(false)}
                        />
                    )}
                    {showRiskEdit && (
                        <RiskEditModal
                            risk={editRiskIndex !== null && editRiskIndex >= 0 ? intelligence.diseaseRisks[editRiskIndex] : null}
                            onSave={(updated) => {
                                let newRisks = [...intelligence.diseaseRisks];
                                if (editRiskIndex === -1) {
                                    newRisks.push(updated);
                                } else if (editRiskIndex !== null && editRiskIndex >= 0) {
                                    newRisks[editRiskIndex] = updated;
                                }
                                saveIntelligence({ ...intelligence, diseaseRisks: newRisks });
                                setShowRiskEdit(false);
                            }}
                            onDelete={editRiskIndex !== null && editRiskIndex >= 0 ? () => {
                                const newRisks = intelligence.diseaseRisks.filter((_, i) => i !== editRiskIndex);
                                saveIntelligence({ ...intelligence, diseaseRisks: newRisks });
                                setShowRiskEdit(false);
                            } : undefined}
                            onClose={() => setShowRiskEdit(false)}
                        />
                    )}
                </>
            )}
        </div>
    );
};

const ScoreEditModal: React.FC<{ intelligence: IntelligenceData; onSave: (data: IntelligenceData) => void; onClose: () => void }> = ({ intelligence, onSave, onClose }) => {
    const [overall, setOverall] = useState(intelligence.overallScore);
    const [biomarkers, setBiomarkers] = useState(intelligence.biomarkersScore);
    const [lifestyle, setLifestyle] = useState(intelligence.lifestyleScore);
    const [riskFactors, setRiskFactors] = useState(intelligence.riskFactorsScore);

    return (
        <div className="fixed inset-0 bg-black/50 z-50 flex items-center justify-center p-4" onClick={onClose}>
            <div className="bg-white rounded-3xl p-8 max-w-md w-full" onClick={(e) => e.stopPropagation()}>
                <div className="flex justify-between mb-6">
                    <h2 className="text-2xl font-serif">Edit Health Scores</h2>
                    <button onClick={onClose} className="p-2 hover:bg-slate-100 rounded-full"><X className="w-5 h-5" /></button>
                </div>
                <div className="space-y-4">
                    <div>
                        <label className="block text-sm font-medium mb-2">Overall Score (0-100)</label>
                        <input type="number" min="0" max="100" value={overall} onChange={(e) => setOverall(Number(e.target.value))} className="w-full px-4 py-3 border-2 rounded-xl focus:border-purple-500 outline-none" />
                    </div>
                    <div>
                        <label className="block text-sm font-medium mb-2">Biomarkers Score</label>
                        <input type="number" min="0" max="100" value={biomarkers} onChange={(e) => setBiomarkers(Number(e.target.value))} className="w-full px-4 py-3 border-2 rounded-xl focus:border-purple-500 outline-none" />
                    </div>
                    <div>
                        <label className="block text-sm font-medium mb-2">Lifestyle Score</label>
                        <input type="number" min="0" max="100" value={lifestyle} onChange={(e) => setLifestyle(Number(e.target.value))} className="w-full px-4 py-3 border-2 rounded-xl focus:border-purple-500 outline-none" />
                    </div>
                    <div>
                        <label className="block text-sm font-medium mb-2">Risk Factors Score</label>
                        <input type="number" min="0" max="100" value={riskFactors} onChange={(e) => setRiskFactors(Number(e.target.value))} className="w-full px-4 py-3 border-2 rounded-xl focus:border-purple-500 outline-none" />
                    </div>
                </div>
                <button onClick={() => onSave({ ...intelligence, overallScore: overall, biomarkersScore: biomarkers, lifestyleScore: lifestyle, riskFactorsScore: riskFactors })} className="w-full mt-6 bg-purple-600 text-white py-3 rounded-xl font-semibold hover:bg-purple-700">
                    Save Changes
                </button>
            </div>
        </div>
    );
};

const DomainEditModal: React.FC<{ domain: { name: string; score: number; target: number }; onSave: (domain: { name: string; score: number; target: number }) => void; onClose: () => void }> = ({ domain, onSave, onClose }) => {
    const [score, setScore] = useState(domain.score);
    const [target, setTarget] = useState(domain.target);

    return (
        <div className="fixed inset-0 bg-black/50 z-50 flex items-center justify-center p-4" onClick={onClose}>
            <div className="bg-white rounded-3xl p-8 max-w-md w-full" onClick={(e) => e.stopPropagation()}>
                <div className="flex justify-between mb-6">
                    <h2 className="text-2xl font-serif">Edit {domain.name}</h2>
                    <button onClick={onClose} className="p-2 hover:bg-slate-100 rounded-full"><X className="w-5 h-5" /></button>
                </div>
                <div className="space-y-4">
                    <div>
                        <label className="block text-sm font-medium mb-2">Current Score (0-100)</label>
                        <input type="number" min="0" max="100" value={score} onChange={(e) => setScore(Number(e.target.value))} className="w-full px-4 py-3 border-2 rounded-xl focus:border-purple-500 outline-none" />
                    </div>
                    <div>
                        <label className="block text-sm font-medium mb-2">Target Score (0-100)</label>
                        <input type="number" min="0" max="100" value={target} onChange={(e) => setTarget(Number(e.target.value))} className="w-full px-4 py-3 border-2 rounded-xl focus:border-purple-500 outline-none" />
                    </div>
                </div>
                <button onClick={() => onSave({ ...domain, score, target })} className="w-full mt-6 bg-purple-600 text-white py-3 rounded-xl font-semibold hover:bg-purple-700">
                    Save Changes
                </button>
            </div>
        </div>
    );
};

const RiskEditModal: React.FC<{ risk: { condition: string; probability: number; level: 'Low' | 'Moderate' | 'High'; drivers: string[] } | null; onSave: (risk: { condition: string; probability: number; level: 'Low' | 'Moderate' | 'High'; drivers: string[] }) => void; onDelete?: () => void; onClose: () => void }> = ({ risk, onSave, onDelete, onClose }) => {
    const [condition, setCondition] = useState(risk?.condition || '');
    const [probability, setProbability] = useState(risk?.probability || 10);
    const [level, setLevel] = useState<'Low' | 'Moderate' | 'High'>(risk?.level || 'Low');
    const [drivers, setDrivers] = useState<string[]>(risk?.drivers || ['']);

    return (
        <div className="fixed inset-0 bg-black/50 z-50 flex items-center justify-center p-4" onClick={onClose}>
            <div className="bg-white rounded-3xl p-8 max-w-lg w-full max-h-[90vh] overflow-y-auto" onClick={(e) => e.stopPropagation()}>
                <div className="flex justify-between mb-6">
                    <h2 className="text-2xl font-serif">{risk ? 'Edit' : 'Add'} Disease Risk</h2>
                    <button onClick={onClose} className="p-2 hover:bg-slate-100 rounded-full"><X className="w-5 h-5" /></button>
                </div>
                <div className="space-y-4">
                    <div>
                        <label className="block text-sm font-medium mb-2">Condition Name</label>
                        <input type="text" value={condition} onChange={(e) => setCondition(e.target.value)} placeholder="e.g., Type 2 Diabetes" className="w-full px-4 py-3 border-2 rounded-xl focus:border-purple-500 outline-none" />
                    </div>
                    <div>
                        <label className="block text-sm font-medium mb-2">Probability (%)</label>
                        <input type="number" min="0" max="100" value={probability} onChange={(e) => setProbability(Number(e.target.value))} className="w-full px-4 py-3 border-2 rounded-xl focus:border-purple-500 outline-none" />
                    </div>
                    <div>
                        <label className="block text-sm font-medium mb-2">Risk Level</label>
                        <select value={level} onChange={(e) => setLevel(e.target.value as 'Low' | 'Moderate' | 'High')} className="w-full px-4 py-3 border-2 rounded-xl focus:border-purple-500 outline-none">
                            <option value="Low">Low</option>
                            <option value="Moderate">Moderate</option>
                            <option value="High">High</option>
                        </select>
                    </div>
                    <div>
                        <label className="block text-sm font-medium mb-2">Risk Drivers</label>
                        {drivers.map((driver, idx) => (
                            <div key={idx} className="flex gap-2 mb-2">
                                <input type="text" value={driver} onChange={(e) => { const newDrivers = [...drivers]; newDrivers[idx] = e.target.value; setDrivers(newDrivers); }} placeholder="e.g., Elevated HbA1c" className="flex-1 px-4 py-2 border-2 rounded-xl focus:border-purple-500 outline-none" />
                                {drivers.length > 1 && (
                                    <button onClick={() => setDrivers(drivers.filter((_, i) => i !== idx))} className="p-2 hover:bg-red-100 text-red-600 rounded-lg">
                                        <Trash2 className="w-4 h-4" />
                                    </button>
                                )}
                            </div>
                        ))}
                        <button onClick={() => setDrivers([...drivers, ''])} className="text-sm text-purple-600 font-medium flex items-center gap-1">
                            <Plus className="w-4 h-4" />
                            Add Driver
                        </button>
                    </div>
                </div>
                <div className="flex gap-3 mt-6">
                    {onDelete && (
                        <button onClick={onDelete} className="px-6 py-3 bg-red-100 text-red-700 rounded-xl font-semibold hover:bg-red-200">
                            Delete
                        </button>
                    )}
                    <button onClick={() => { if (condition && drivers.filter(d => d.trim()).length > 0) { onSave({ condition, probability, level, drivers: drivers.filter(d => d.trim()) }); } }} className="flex-1 bg-purple-600 text-white py-3 rounded-xl font-semibold hover:bg-purple-700">
                        Save Changes
                    </button>
                </div>
            </div>
        </div>
    );
};

export default IntelligencePanel;
