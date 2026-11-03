import React, { useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { ArrowLeft, Save, User, Mail, CheckCircle, AlertCircle } from 'lucide-react';
import { createPatient } from '../../lib/patientsApi';

// Portal card token, taken verbatim from PhysicianRoster so Create Patient sits
// on the same surface in both light and dark (TC-030 item 6, Ava: the old
// serif/emerald/24px-card styling was off the design system and invisible in
// dark mode — the title was 1.11:1 and the green submit button 2.54:1).
const CARD =
    'rounded-2xl border border-slate-200 bg-white shadow-[0_1px_2px_#0306160A,0_8px_24px_#2C5CF214] dark:border-[#222838] dark:bg-[#10141F] dark:shadow-none';
const INPUT =
    'w-full rounded-xl border border-slate-300 bg-white p-3 text-[#030616] placeholder:text-slate-400 focus:outline-none focus-visible:ring-2 focus-visible:ring-[#2C5CF2] dark:border-[#6C7690] dark:bg-[#10141F] dark:text-[#EEF1F8] dark:placeholder:text-[#8F9AAF]';

const CreatePatient: React.FC = () => {
    const navigate = useNavigate();
    const [formData, setFormData] = useState({
        name: '',
        email: '',
        mrn: '',
    });

    const [submitted, setSubmitted] = useState(false);
    const [loading, setLoading] = useState(false);
    const [error, setError] = useState<string | null>(null);

    const handleSubmit = async (e: React.FormEvent) => {
        e.preventDefault();
        setLoading(true);
        setError(null);

        try {
            const result = await createPatient(formData.email, formData.name, formData.mrn);

            if (result.ok) {
                // TC-030 item 7 (Ava): one success message. The full-page card
                // below is the single confirmation now — the duplicate
                // AdminContext toast was dropped.
                setSubmitted(true);
                setTimeout(() => {
                    navigate('/admin/patients');
                }, 2000);
            } else {
                setError("We couldn't create the patient. Check the details and try again.");
            }
        } catch (err) {
            console.error('Error creating patient:', err);
            setError("We couldn't create the patient. Check the details and try again.");
        } finally {
            setLoading(false);
        }
    };

    if (submitted) {
        return (
            <div className="p-6 flex items-center justify-center min-h-screen">
                <div className={`${CARD} p-12 text-center max-w-md`}>
                    <div className="w-20 h-20 bg-emerald-100 dark:bg-emerald-900/30 rounded-full flex items-center justify-center mx-auto mb-6">
                        <CheckCircle className="w-10 h-10 text-emerald-600 dark:text-emerald-400" />
                    </div>
                    <h2 className="text-2xl font-bold text-[#030616] dark:text-[#EEF1F8] mb-3">Patient created</h2>
                    <p className="text-[#48556A] dark:text-[#A6B0C3] mb-6">Account created for {formData.email}</p>
                    <div className="text-sm text-slate-500 dark:text-[#8F9AAF]">Redirecting to patients...</div>
                </div>
            </div>
        );
    }

    return (
        <div className="p-6 max-w-3xl mx-auto">
            {/* Header */}
            <div className="mb-8">
                <button
                    onClick={() => navigate('/admin/patients')}
                    className="inline-flex min-h-[44px] items-center gap-2 text-[#48556A] hover:text-[#030616] mb-4 transition-colors dark:text-[#A6B0C3] dark:hover:text-[#EEF1F8]"
                >
                    <ArrowLeft className="w-4 h-4" />
                    Back to patients
                </button>
                <h1 className="text-[28px] font-bold leading-tight text-[#030616] dark:text-[#EEF1F8] mb-2">Add a patient</h1>
                <p className="text-sm text-[#48556A] dark:text-[#A6B0C3]">Add a new patient to the Zyndio platform</p>
            </div>

            {/* Form */}
            <form onSubmit={handleSubmit} className={`${CARD} p-8 space-y-6`}>
                {error && (
                    <div className="bg-rose-50 border border-rose-100 rounded-xl p-4 flex items-center gap-2 text-sm text-rose-700 dark:bg-rose-950/40 dark:border-rose-900 dark:text-rose-300">
                        <AlertCircle className="w-4 h-4 shrink-0" />
                        {error}
                    </div>
                )}

                <div>
                    <h3 className="text-lg font-semibold text-[#030616] dark:text-[#EEF1F8] mb-4 flex items-center gap-2">
                        <User className="w-5 h-5" />
                        Patient Information
                    </h3>
                    <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
                        <div>
                            <label htmlFor="patient-name" className="block text-sm font-medium text-slate-700 mb-2 dark:text-[#A6B0C3]">Full Name *</label>
                            <input
                                id="patient-name"
                                type="text"
                                required
                                value={formData.name}
                                onChange={(e) => setFormData({ ...formData, name: e.target.value })}
                                placeholder="Jane Doe"
                                className={INPUT}
                            />
                        </div>

                        <div>
                            <label htmlFor="patient-mrn" className="block text-sm font-medium text-slate-700 mb-2 dark:text-[#A6B0C3]">Medical record number</label>
                            <input
                                id="patient-mrn"
                                type="text"
                                value={formData.mrn}
                                onChange={(e) => setFormData({ ...formData, mrn: e.target.value })}
                                placeholder="MRN-0001"
                                className={INPUT}
                            />
                        </div>
                    </div>
                </div>

                <div className="h-px bg-slate-200 dark:bg-[#222838]"></div>

                <div>
                    <h3 className="text-lg font-semibold text-[#030616] dark:text-[#EEF1F8] mb-4 flex items-center gap-2">
                        <Mail className="w-5 h-5" />
                        Contact Information
                    </h3>
                    <div>
                        <label htmlFor="patient-email" className="block text-sm font-medium text-slate-700 mb-2 dark:text-[#A6B0C3]">Email Address *</label>
                        <input
                            id="patient-email"
                            type="email"
                            required
                            value={formData.email}
                            onChange={(e) => setFormData({ ...formData, email: e.target.value })}
                            placeholder="jane@example.com"
                            className={INPUT}
                        />
                    </div>
                </div>

                {/* Submit Button */}
                <div className="flex gap-4">
                    <button
                        type="button"
                        onClick={() => navigate('/admin/patients')}
                        className="flex-1 min-h-[44px] py-3 px-6 border border-slate-200 rounded-xl font-medium text-slate-700 hover:bg-slate-50 transition-colors dark:border-[#6C7690] dark:text-[#EEF1F8] dark:hover:bg-[#222838]"
                    >
                        Cancel
                    </button>
                    <button
                        type="submit"
                        disabled={loading}
                        className="flex-1 min-h-[44px] py-3 px-6 bg-[#2C5CF2] text-white rounded-xl font-medium shadow-sm hover:bg-[#2450D8] transition-colors flex items-center justify-center gap-2 focus:outline-none focus-visible:ring-2 focus-visible:ring-[#2C5CF2] focus-visible:ring-offset-2 disabled:opacity-50 disabled:cursor-not-allowed"
                    >
                        {loading ? (
                            <>
                                <div className="w-5 h-5 border-2 border-white border-t-transparent rounded-full animate-spin"></div>
                                Creating...
                            </>
                        ) : (
                            <>
                                <Save className="w-5 h-5" />
                                Create patient
                            </>
                        )}
                    </button>
                </div>
            </form>
        </div>
    );
};

export default CreatePatient;
