import React, { useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { ArrowLeft, Save, User, Mail, Phone, Calendar, CheckCircle, Crown } from 'lucide-react';
import { useAdmin } from '../../contexts/AdminContext';
import { SubscriptionPlan } from '../../types';

const CreatePatient: React.FC = () => {
    const navigate = useNavigate();
    const { createPatient } = useAdmin();
    const [formData, setFormData] = useState({
        name: '',
        email: '',
        phone: '',
        age: '',
        gender: 'male',
        bloodTestDate: '',
        paymentConfirmed: false,
        subscriptionPlan: 'pro' as SubscriptionPlan
    });

    const [submitted, setSubmitted] = useState(false);
    const [loading, setLoading] = useState(false);

    const handleSubmit = async (e: React.FormEvent) => {
        e.preventDefault();
        setLoading(true);

        try {
            // Create patient using AdminContext (saves to Supabase)
            const newPatient = await createPatient({
                name: formData.name,
                email: formData.email,
                phone: formData.phone,
                age: parseInt(formData.age),
                bioAge: parseInt(formData.age) - 2, // Estimated
                stage: formData.paymentConfirmed ? 'lab_test_scheduled' : 'payment_pending',
                role: 'user',
                healthGrade: 'B',
                primaryGoal: 'Longevity',
                isPremium: formData.subscriptionPlan === 'ultimate',
                paceOfAging: 1.0,
                joinedDate: new Date().toISOString(),
                avatarUrl: `https://ui-avatars.com/api/?name=${encodeURIComponent(formData.name)}&background=1e293b&color=fff`,
                isIntelligenceVerified: false,
                isProtocolPublished: false,
                subscriptionPlan: formData.subscriptionPlan
            });

            if (newPatient) {
                setSubmitted(true);
                // Redirect after 2 seconds
                setTimeout(() => {
                    navigate('/admin');
                }, 2000);
            }
        } catch (error) {
            console.error('Error creating patient:', error);
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
                    <p className="text-slate-600 mb-6">Welcome email sent to {formData.email}</p>
                    <div className="text-sm text-slate-500">Redirecting to dashboard...</div>
                </div>
            </div>
        );
    }

    return (
        <div className="p-6 max-w-3xl mx-auto">
            {/* Header */}
            <div className="mb-8">
                <button
                    onClick={() => navigate('/admin')}
                    className="flex items-center gap-2 text-slate-600 hover:text-slate-900 mb-4 transition-colors"
                >
                    <ArrowLeft className="w-4 h-4" />
                    Back to Dashboard
                </button>
                <h1 className="text-2xl font-serif text-slate-900 mb-2">Create New Patient</h1>
                <p className="text-slate-600">Add a new patient to the Zyndio platform</p>
            </div>

            {/* Form */}
            <form onSubmit={handleSubmit} className="bg-white p-8 rounded-3xl shadow-soft space-y-6">
                {/* Personal Information */}
                <div>
                    <h3 className="text-lg font-semibold text-slate-900 mb-4 flex items-center gap-2">
                        <User className="w-5 h-5" />
                        Personal Information
                    </h3>
                    <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
                        <div>
                            <label className="block text-sm font-medium text-slate-700 mb-2">Full Name *</label>
                            <input
                                type="text"
                                required
                                value={formData.name}
                                onChange={(e) => setFormData({ ...formData, name: e.target.value })}
                                placeholder="John Doe"
                                className="w-full p-3 border border-slate-200 rounded-xl focus:ring-2 focus:ring-emerald-500 outline-none"
                            />
                        </div>

                        <div>
                            <label className="block text-sm font-medium text-slate-700 mb-2">Age *</label>
                            <input
                                type="number"
                                required
                                min="18"
                                max="120"
                                value={formData.age}
                                onChange={(e) => setFormData({ ...formData, age: e.target.value })}
                                placeholder="35"
                                className="w-full p-3 border border-slate-200 rounded-xl focus:ring-2 focus:ring-emerald-500 outline-none"
                            />
                        </div>

                        <div>
                            <label className="block text-sm font-medium text-slate-700 mb-2">Gender *</label>
                            <select
                                required
                                value={formData.gender}
                                onChange={(e) => setFormData({ ...formData, gender: e.target.value })}
                                className="w-full p-3 border border-slate-200 rounded-xl focus:ring-2 focus:ring-emerald-500 outline-none"
                            >
                                <option value="male">Male</option>
                                <option value="female">Female</option>
                                <option value="other">Other</option>
                            </select>
                        </div>

                        <div>
                            <label className="block text-sm font-medium text-slate-700 mb-2">Subscription Plan *</label>
                            <select
                                required
                                value={formData.subscriptionPlan}
                                onChange={(e) => setFormData({ ...formData, subscriptionPlan: e.target.value as SubscriptionPlan })}
                                className="w-full p-3 border border-slate-200 rounded-xl focus:ring-2 focus:ring-emerald-500 outline-none"
                            >
                                <option value="baseline">Baseline</option>
                                <option value="plus">Plus</option>
                                <option value="pro">Pro</option>
                                <option value="ultimate">Ultimate</option>
                            </select>
                            <p className="text-xs text-slate-500 mt-1">
                                {formData.subscriptionPlan === 'ultimate'
                                    ? '✨ Includes: Dynamic protocols, weekly meal plans, AI concierge'
                                    : formData.subscriptionPlan === 'plus'
                                    ? '⚡ Includes: Enhanced health coaching, monthly meal plans'
                                    : formData.subscriptionPlan === 'baseline'
                                    ? '🌱 Includes: Basic longevity assessment, standard protocols'
                                    : '📋 Includes: Static protocol, one-time meal plan'}
                            </p>
                        </div>
                    </div>
                </div>

                <div className="h-px bg-slate-200"></div>

                {/* Contact Information */}
                <div>
                    <h3 className="text-lg font-semibold text-slate-900 mb-4 flex items-center gap-2">
                        <Mail className="w-5 h-5" />
                        Contact Information
                    </h3>
                    <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
                        <div>
                            <label className="block text-sm font-medium text-slate-700 mb-2">Email Address *</label>
                            <input
                                type="email"
                                required
                                value={formData.email}
                                onChange={(e) => setFormData({ ...formData, email: e.target.value })}
                                placeholder="john@example.com"
                                className="w-full p-3 border border-slate-200 rounded-xl focus:ring-2 focus:ring-emerald-500 outline-none"
                            />
                        </div>

                        <div>
                            <label className="block text-sm font-medium text-slate-700 mb-2">Phone Number</label>
                            <input
                                type="tel"
                                value={formData.phone}
                                onChange={(e) => setFormData({ ...formData, phone: e.target.value })}
                                placeholder="+1 (555) 123-4567"
                                className="w-full p-3 border border-slate-200 rounded-xl focus:ring-2 focus:ring-emerald-500 outline-none"
                            />
                        </div>
                    </div>
                </div>

                <div className="h-px bg-slate-200"></div>

                {/* Onboarding Details */}
                <div>
                    <h3 className="text-lg font-semibold text-slate-900 mb-4 flex items-center gap-2">
                        <Calendar className="w-5 h-5" />
                        Onboarding Details
                    </h3>
                    <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
                        <div>
                            <label className="block text-sm font-medium text-slate-700 mb-2">Blood Test Date</label>
                            <input
                                type="date"
                                value={formData.bloodTestDate}
                                onChange={(e) => setFormData({ ...formData, bloodTestDate: e.target.value })}
                                className="w-full p-3 border border-slate-200 rounded-xl focus:ring-2 focus:ring-emerald-500 outline-none"
                            />
                        </div>

                        <div className="flex items-center">
                            <label className="flex items-center gap-3 cursor-pointer">
                                <input
                                    type="checkbox"
                                    checked={formData.paymentConfirmed}
                                    onChange={(e) => setFormData({ ...formData, paymentConfirmed: e.target.checked })}
                                    className="w-5 h-5 rounded border-slate-300 text-emerald-600 focus:ring-emerald-500"
                                />
                                <span className="text-sm font-medium text-slate-700">Payment Confirmed</span>
                            </label>
                        </div>
                    </div>
                </div>

                {/* Info Box */}
                <div className="bg-blue-50 border border-blue-100 rounded-xl p-4">
                    <p className="text-sm text-blue-900">
                        <strong>Next Steps:</strong> After creating the patient, you'll need to:
                        <br />1. Upload lab report
                        <br />2. Send questionnaire link
                        <br />3. Monitor AI analysis progress
                    </p>
                </div>

                {/* Submit Button */}
                <div className="flex gap-4">
                    <button
                        type="button"
                        onClick={() => navigate('/admin')}
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
