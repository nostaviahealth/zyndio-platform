import React, { useState, useEffect } from 'react';
import { useParams, useNavigate } from 'react-router-dom';
import {
    ArrowLeft, FileText, Upload, CheckCircle, X,
    Stethoscope, Apple, Route, User, Brain, Lock, Unlock, BookOpen, Activity
} from 'lucide-react';
import { useAdmin } from '../../contexts/AdminContext';
import { PatientProfile } from '../../types';
import HealthJourneyPanel from './HealthJourneyPanel';
import IntelligencePanel from './IntelligencePanel';
import { supabase } from '../../lib/supabase';

const PatientDetail: React.FC = () => {
    const { id } = useParams<{ id: string }>();
    const navigate = useNavigate();
    const { getPatient } = useAdmin();

    const [patient, setPatient] = useState<PatientProfile | null>(null);
    const [activeTab, setActiveTab] = useState<'status' | 'journey' | 'logs'>('status');
    const [activeModal, setActiveModal] = useState<string | null>(null);

    // File trackers
    const [labUploaded, setLabUploaded] = useState(false);
    const [questionnaireUploaded, setQuestionnaireUploaded] = useState(false);
    const [doctorNotes, setDoctorNotes] = useState('');
    const [nutritionistNotes, setNutritionistNotes] = useState('');

    // User logs data
    const [bioLogs, setBioLogs] = useState<any[]>([]);
    const [journals, setJournals] = useState<any[]>([]);
    const [logsLoading, setLogsLoading] = useState(false);

    useEffect(() => {
        if (id) {
            // Get patient from AdminContext (Supabase)
            const foundPatient = getPatient(id);
            if (foundPatient) {
                setPatient(foundPatient);

                // Load saved data from localStorage
                const savedData = localStorage.getItem(`patient_${id}_admin`);
                if (savedData) {
                    const data = JSON.parse(savedData);
                    setLabUploaded(data.labUploaded || false);
                    setQuestionnaireUploaded(data.questionnaireUploaded || false);
                    setDoctorNotes(data.doctorNotes || '');
                    setNutritionistNotes(data.nutritionistNotes || '');
                }
            }
        }
    }, [id, getPatient]);

    // Fetch user logs when 'logs' tab is active
    useEffect(() => {
        if (activeTab === 'logs' && patient?.id) {
            setLogsLoading(true);
            Promise.all([
                supabase
                    .from('daily_bio_logs')
                    .select('*')
                    .eq('profile_id', patient.id)
                    .order('logged_at', { ascending: false }),
                supabase
                    .from('daily_journals')
                    .select('*')
                    .eq('profile_id', patient.id)
                    .order('logged_at', { ascending: false })
            ]).then(([bioLogsRes, journalsRes]) => {
                if (!bioLogsRes.error) setBioLogs(bioLogsRes.data || []);
                if (!journalsRes.error) setJournals(journalsRes.data || []);
                setLogsLoading(false);
            });
        }
    }, [activeTab, patient?.id]);

    const saveAllData = () => {
        if (!id) return;

        const dataToSave = {
            labUploaded,
            questionnaireUploaded,
            doctorNotes,
            nutritionistNotes
        };

        localStorage.setItem(`patient_${id}_admin`, JSON.stringify(dataToSave));
    };

    if (!patient) {
        return (
            <div className="p-8 text-center">
                <p className="text-slate-600">Patient not found</p>
                <button onClick={() => navigate('/admin')} className="mt-4 px-6 py-2 bg-emerald-500 text-white rounded-xl">
                    Back to Dashboard
                </button>
            </div>
        );
    }

    const statusItems = [
        {
            id: 'lab',
            label: 'Lab Report',
            icon: FileText,
            status: labUploaded ? 'completed' : 'pending',
            action: () => setActiveModal('lab'),
            color: 'blue'
        },
        {
            id: 'questionnaire',
            label: 'Questionnaire',
            icon: CheckCircle,
            status: questionnaireUploaded ? 'completed' : 'pending',
            action: () => setActiveModal('questionnaire'),
            color: 'purple'
        },
        {
            id: 'doctor',
            label: "Doctor's Notes",
            icon: Stethoscope,
            status: doctorNotes.trim() ? 'completed' : 'pending',
            action: () => setActiveModal('doctor'),
            color: 'red'
        },
        {
            id: 'nutritionist',
            label: "Nutritionist's Notes",
            icon: Apple,
            status: nutritionistNotes.trim() ? 'completed' : 'pending',
            action: () => setActiveModal('nutritionist'),
            color: 'green'
        }
    ];

    const getStatusBadge = (status: string) => {
        const colors = {
            pending: 'bg-amber-100 text-amber-700',
            completed: 'bg-emerald-100 text-emerald-700'
        };

        return (
            <span className={`px-2 py-1 rounded-full text-xs font-semibold ${colors[status as keyof typeof colors]}`}>
                {status.charAt(0).toUpperCase() + status.slice(1)}
            </span>
        );
    };

    return (
        <div className="p-6 max-w-7xl mx-auto space-y-6">
            {/* Header */}
            <div className="bg-white rounded-3xl p-6 shadow-soft border border-slate-100">
                <div className="flex items-center justify-between">
                    <div className="flex items-center gap-4">
                        <button
                            onClick={() => navigate('/admin')}
                            className="p-2 hover:bg-slate-100 rounded-xl transition-colors"
                        >
                            <ArrowLeft className="w-5 h-5" />
                        </button>
                        <div>
                            <h1 className="text-2xl font-serif text-slate-900">{patient.name}</h1>
                            <p className="text-sm text-slate-500">{patient.email}</p>
                        </div>
                    </div>
                </div>
            </div>

            {/* Tab Navigation */}
            <div className="bg-white rounded-2xl p-2 shadow-soft border border-slate-100 flex gap-2">
                <button
                    onClick={() => setActiveTab('status')}
                    className={`flex-1 flex items-center justify-center gap-2 px-6 py-3 rounded-xl font-medium transition-all ${activeTab === 'status'
                        ? 'bg-emerald-500 text-white shadow-lg'
                        : 'text-slate-600 hover:bg-slate-50'
                        }`}
                >
                    <User className="w-5 h-5" />
                    Patient Data
                </button>
                <button
                    onClick={() => setActiveTab('journey')}
                    className={`flex-1 flex items-center justify-center gap-2 px-6 py-3 rounded-xl font-medium transition-all ${activeTab === 'journey'
                        ? 'bg-emerald-500 text-white shadow-lg'
                        : 'text-slate-600 hover:bg-slate-50'
                        }`}
                >
                    <Route className="w-5 h-5" />
                    Health Journey
                </button>
                <button
                    onClick={() => setActiveTab('logs')}
                    className={`flex-1 flex items-center justify-center gap-2 px-6 py-3 rounded-xl font-medium transition-all ${activeTab === 'logs'
                        ? 'bg-emerald-500 text-white shadow-lg'
                        : 'text-slate-600 hover:bg-slate-50'
                        }`}
                >
                    <BookOpen className="w-5 h-5" />
                    User Logs
                </button>
            </div>

            {/* Patient Data Tab */}
            {activeTab === 'status' && (
                <div className="bg-white rounded-3xl p-8 shadow-soft border border-slate-100">
                    <h2 className="text-xl font-serif text-slate-900 mb-6">Patient Data Collection</h2>
                    <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-4">
                        {statusItems.map(item => (
                            <button
                                key={item.id}
                                onClick={item.action}
                                className="p-5 rounded-2xl border-2 border-slate-200 hover:border-emerald-300 hover:shadow-lg hover:scale-105 cursor-pointer transition-all text-left group"
                            >
                                <div className="flex items-start justify-between mb-3">
                                    <div className={`w-12 h-12 rounded-xl bg-${item.color}-100 flex items-center justify-center group-hover:scale-110 transition-transform`}>
                                        <item.icon className={`w-6 h-6 text-${item.color}-600`} />
                                    </div>
                                    {getStatusBadge(item.status)}
                                </div>

                                <h3 className="font-semibold text-slate-900 mb-1">{item.label}</h3>
                                <p className="text-xs text-slate-500">
                                    {item.status === 'pending' ? 'Not completed' : 'Click to view/edit'}
                                </p>
                            </button>
                        ))}
                    </div>
                </div>
            )}

            {/* Health Journey Tab */}
            {activeTab === 'journey' && (
                <>
                    <HealthJourneyPanel
                        patientId={id!}
                        patientName={patient.name}
                        hasAllData={labUploaded && questionnaireUploaded && !!doctorNotes && !!nutritionistNotes}
                    />

                    <div className="mt-8">
                        <IntelligencePanel
                            patientId={id!}
                            patientName={patient.name}
                            hasLabData={labUploaded}
                        />
                    </div>
                </>
            )}

            {/* User Logs Tab */}
            {activeTab === 'logs' && (
                <div className="bg-white rounded-3xl p-8 shadow-soft border border-slate-100 space-y-8">
                    <h2 className="text-xl font-serif text-slate-900">User Submitted Logs</h2>

                    {logsLoading ? (
                        <p className="text-slate-500">Loading...</p>
                    ) : (
                        <>
                            {/* Bio Logs Section */}
                            <div>
                                <h3 className="text-lg font-semibold text-slate-800 mb-4 flex items-center gap-2">
                                    <Activity className="w-5 h-5 text-emerald-600" /> Daily Bio Logs
                                </h3>
                                {bioLogs.length === 0 ? (
                                    <p className="text-slate-400 text-sm">No bio logs recorded yet.</p>
                                ) : (
                                    <div className="overflow-x-auto">
                                        <table className="w-full text-sm">
                                            <thead className="bg-slate-50">
                                                <tr>
                                                    <th className="text-left p-3 font-semibold text-slate-600">Date</th>
                                                    <th className="text-left p-3 font-semibold text-slate-600">Sleep</th>
                                                    <th className="text-left p-3 font-semibold text-slate-600">Stress</th>
                                                    <th className="text-left p-3 font-semibold text-slate-600">Energy</th>
                                                </tr>
                                            </thead>
                                            <tbody>
                                                {bioLogs.map((log) => (
                                                    <tr key={log.id} className="border-b border-slate-100">
                                                        <td className="p-3 text-slate-700">{new Date(log.logged_at).toLocaleDateString()}</td>
                                                        <td className="p-3 text-slate-700">{log.sleep_quality || '-'}</td>
                                                        <td className="p-3 text-slate-700">{log.stress_level || '-'}</td>
                                                        <td className="p-3 text-slate-700">{log.energy_level || '-'}</td>
                                                    </tr>
                                                ))}
                                            </tbody>
                                        </table>
                                    </div>
                                )}
                            </div>

                            {/* Journals Section */}
                            <div>
                                <h3 className="text-lg font-semibold text-slate-800 mb-4 flex items-center gap-2">
                                    <BookOpen className="w-5 h-5 text-purple-600" /> Daily Journals
                                </h3>
                                {journals.length === 0 ? (
                                    <p className="text-slate-400 text-sm">No journal entries yet.</p>
                                ) : (
                                    <div className="space-y-4">
                                        {journals.map((entry) => (
                                            <div key={entry.id} className="p-4 bg-slate-50 rounded-xl border border-slate-100">
                                                <p className="text-xs text-slate-400 mb-2">{new Date(entry.logged_at).toLocaleString()}</p>
                                                <p className="text-slate-700 whitespace-pre-wrap">{entry.content}</p>
                                            </div>
                                        ))}
                                    </div>
                                )}
                            </div>
                        </>
                    )}
                </div>
            )}

            {/* Modals */}
            {activeModal === 'lab' && (
                <FileUploadModal
                    title="Lab Report"
                    isUploaded={labUploaded}
                    onToggle={() => { setLabUploaded(!labUploaded); saveAllData(); }}
                    onClose={() => setActiveModal(null)}
                />
            )}

            {activeModal === 'questionnaire' && (
                <FileUploadModal
                    title="Health Questionnaire"
                    isUploaded={questionnaireUploaded}
                    onToggle={() => { setQuestionnaireUploaded(!questionnaireUploaded); saveAllData(); }}
                    onClose={() => setActiveModal(null)}
                />
            )}

            {activeModal === 'doctor' && (
                <NotesModal
                    title="Expert Wellness Insights"
                    value={doctorNotes}
                    onChange={setDoctorNotes}
                    onClose={() => { setActiveModal(null); saveAllData(); }}
                    placeholder="Enter wellness insights, health patterns, and recommendations..."
                />
            )}

            {activeModal === 'nutritionist' && (
                <NotesModal
                    title="Nutritionist's Assessment"
                    value={nutritionistNotes}
                    onChange={setNutritionistNotes}
                    onClose={() => { setActiveModal(null); saveAllData(); }}
                    placeholder="Enter dietary assessment and nutrition recommendations..."
                />
            )}
        </div>
    );
};

// File Upload Modal
const FileUploadModal: React.FC<{ title: string; isUploaded: boolean; onToggle: () => void; onClose: () => void }> = ({ title, isUploaded, onToggle, onClose }) => {
    return (
        <div className="fixed inset-0 bg-black/50 backdrop-blur-sm z-50 flex items-center justify-center p-4" onClick={onClose}>
            <div className="bg-white rounded-3xl p-8 max-w-md w-full shadow-2xl" onClick={(e) => e.stopPropagation()}>
                <div className="flex justify-between items-center mb-6">
                    <h2 className="text-2xl font-serif text-slate-900">{title}</h2>
                    <button onClick={onClose} className="p-2 hover:bg-slate-100 rounded-full">
                        <X className="w-5 h-5" />
                    </button>
                </div>

                <div className="space-y-4">
                    <div className="p-6 border-2 border-dashed border-slate-300 rounded-2xl text-center">
                        <Upload className="w-12 h-12 text-slate-400 mx-auto mb-3" />
                        <p className="text-sm text-slate-600 mb-4">Upload {title}</p>
                        <label className="px-6 py-3 bg-emerald-500 text-white rounded-xl font-medium cursor-pointer hover:bg-emerald-600 transition-colors inline-block">
                            Choose File
                            <input type="file" className="hidden" />
                        </label>
                    </div>

                    <button
                        onClick={onToggle}
                        className={`w-full py-3 rounded-xl font-semibold transition-all ${isUploaded
                            ? 'bg-red-100 text-red-700 hover:bg-red-200'
                            : 'bg-emerald-500 text-white hover:bg-emerald-600'
                            }`}
                    >
                        {isUploaded ? 'Mark as Not Uploaded' : 'Mark as Uploaded'}
                    </button>
                </div>
            </div>
        </div>
    );
};

// Notes Modal
const NotesModal: React.FC<{ title: string; value: string; onChange: (val: string) => void; onClose: () => void; placeholder: string }> = ({ title, value, onChange, onClose, placeholder }) => {
    return (
        <div className="fixed inset-0 bg-black/50 backdrop-blur-sm z-50 flex items-center justify-center p-4" onClick={onClose}>
            <div className="bg-white rounded-3xl p-8 max-w-2xl w-full shadow-2xl max-h-[90vh] overflow-y-auto" onClick={(e) => e.stopPropagation()}>
                <div className="flex justify-between items-center mb-6">
                    <h2 className="text-2xl font-serif text-slate-900">{title}</h2>
                    <button onClick={onClose} className="p-2 hover:bg-slate-100 rounded-full">
                        <X className="w-5 h-5" />
                    </button>
                </div>

                <textarea
                    value={value}
                    onChange={(e) => onChange(e.target.value)}
                    placeholder={placeholder}
                    className="w-full h-64 p-4 border-2 border-slate-200 rounded-2xl resize-none focus:border-emerald-500 focus:ring-2 focus:ring-emerald-200 outline-none transition-all"
                />

                <button
                    onClick={onClose}
                    className="w-full mt-4 bg-emerald-500 text-white py-3 rounded-xl font-semibold hover:bg-emerald-600 transition-colors"
                >
                    Save & Close
                </button>
            </div>
        </div>
    );
};

export default PatientDetail;
