import React, { useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { ArrowLeft, Save, User, Mail, CheckCircle, AlertCircle } from 'lucide-react';
import { createPatient } from '../../lib/patientsApi';

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
                <div className="bg-white p-12 rounded-3xl shadow-2xl text-center max-w-md">
                    <div className="w-20 h-20 bg-emerald-100 rounded-full flex items-center justify-center mx-auto mb-6">
                        <CheckCircle className="w-10 h-10 text-emerald-600" />
                    </div>
                    <h2 className="text-2xl font-serif text-slate-900 mb-3">Patient Created Successfully!</h2>
                    <p className="text-slate-600 mb-6">Account created for {formData.email}</p>
                    <div className="text-sm text-slate-500">Redirecting to patients...</div>
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
                    className="flex items-center gap-2 text-slate-600 hover:text-slate-900 mb-4 transition-colors"
                >
                    <ArrowLeft className="w-4 h-4" />
                    Back to Patients
                </button>
                <h1 className="text-2xl font-serif text-slate-900 mb-2">Create New Patient</h1>
                <p className="text-slate-600">Add a new patient to the Zyndio platform</p>
            </div>

            {/* Form */}
            <form onSubmit={handleSubmit} className="bg-white p-8 rounded-3xl shadow-soft space-y-6">
                {error && (
                    <div className="bg-rose-50 border border-rose-100 rounded-xl p-4 flex items-center gap-2 text-sm text-rose-700">
                        <AlertCircle className="w-4 h-4 shrink-0" />
                        {error}
                    </div>
                )}

                <div>
                    <h3 className="text-lg font-semibold text-slate-900 mb-4 flex items-center gap-2">
                        <User className="w-5 h-5" />
                        Patient Information
                    </h3>
                    <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
                        <div>
                            <label htmlFor="patient-name" className="block text-sm font-medium text-slate-700 mb-2">Full Name *</label>
                            <input
                                id="patient-name"
                                type="text"
                                required
                                value={formData.name}
                                onChange={(e) => setFormData({ ...formData, name: e.target.value })}
                                placeholder="Jane Doe"
                                className="w-full p-3 border border-slate-200 rounded-xl focus:ring-2 focus:ring-emerald-500 outline-none"
                            />
                        </div>

                        <div>
                            <label htmlFor="patient-mrn" className="block text-sm font-medium text-slate-700 mb-2">Medical record number</label>
                            <input
                                id="patient-mrn"
                                type="text"
                                value={formData.mrn}
                                onChange={(e) => setFormData({ ...formData, mrn: e.target.value })}
                                placeholder="MRN-0001"
                                className="w-full p-3 border border-slate-200 rounded-xl focus:ring-2 focus:ring-emerald-500 outline-none"
                            />
                        </div>
                    </div>
                </div>

                <div className="h-px bg-slate-200"></div>

                <div>
                    <h3 className="text-lg font-semibold text-slate-900 mb-4 flex items-center gap-2">
                        <Mail className="w-5 h-5" />
                        Contact Information
                    </h3>
                    <div>
                        <label htmlFor="patient-email" className="block text-sm font-medium text-slate-700 mb-2">Email Address *</label>
                        <input
                            id="patient-email"
                            type="email"
                            required
                            value={formData.email}
                            onChange={(e) => setFormData({ ...formData, email: e.target.value })}
                            placeholder="jane@example.com"
                            className="w-full p-3 border border-slate-200 rounded-xl focus:ring-2 focus:ring-emerald-500 outline-none"
                        />
                    </div>
                </div>

                {/* Submit Button */}
                <div className="flex gap-4">
                    <button
                        type="button"
                        onClick={() => navigate('/admin/patients')}
                        className="flex-1 py-3 px-6 border border-slate-200 rounded-xl font-medium text-slate-700 hover:bg-slate-50 transition-colors"
                    >
                        Cancel
                    </button>
                    <button
                        type="submit"
                        disabled={loading}
                        className="flex-1 py-3 px-6 bg-gradient-to-r from-emerald-500 to-emerald-600 text-white rounded-xl font-medium shadow-lg hover:from-emerald-600 hover:to-emerald-700 transition-all flex items-center justify-center gap-2 disabled:opacity-50 disabled:cursor-not-allowed"
                    >
                        {loading ? (
                            <>
                                <div className="w-5 h-5 border-2 border-white border-t-transparent rounded-full animate-spin"></div>
                                Creating...
                            </>
                        ) : (
                            <>
                                <Save className="w-5 h-5" />
                                Create Patient
                            </>
                        )}
                    </button>
                </div>
            </form>
        </div>
    );
};

export default CreatePatient;
