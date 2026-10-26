import React from 'react';
import { Plus, X } from 'lucide-react';
import { useAdmin } from '../contexts/AdminContext';
import { PatientProfile } from '../types';

interface CreatePatientModalProps {
    isOpen: boolean;
    onClose: () => void;
}

const CreatePatientModal: React.FC<CreatePatientModalProps> = ({ isOpen, onClose }) => {
    const { createPatient } = useAdmin();
    const [formData, setFormData] = React.useState({
        name: '',
        email: '',
        phone: '',
        age: '',
        gender: 'Male' as 'Male' | 'Female' | 'Other',
        primaryGoal: ''
    });

    const handleSubmit = (e: React.FormEvent) => {
        e.preventDefault();

        const newPatient: Omit<PatientProfile, 'id'> = {
            name: formData.name,
            email: formData.email,
            phone: formData.phone,
            role: 'user',
            stage: 'profile_creation',
            avatarUrl: `https://ui-avatars.com/api/?name=${encodeURIComponent(formData.name)}&background=D4AF37&color=fff`,
            age: parseInt(formData.age),
            bioAge: parseInt(formData.age), // Default to same as age
            healthGrade: 'N/A',
            primaryGoal: formData.primaryGoal,
            isPremium: true, // Default new patients to premium
            paceOfAging: 1.0, // Default pace of aging
            joinedDate: new Date().toISOString().split('T')[0],
            preferences: {
                theme: 'light',
                notifications: true
            },
            isIntelligenceVerified: false,
            isDietPlanCreated: false,
            isProtocolPublished: false
        };

        createPatient(newPatient);
        onClose();

        // Reset form
        setFormData({
            name: '',
            email: '',
            phone: '',
            age: '',
            gender: 'Male',
            primaryGoal: ''
        });
    };

    if (!isOpen) return null;

    return (
        <div className="fixed inset-0 bg-black/50 backdrop-blur-sm flex items-center justify-center z-50 p-4">
            <div className="bg-white rounded-2xl shadow-2xl w-full max-w-2xl max-h-[90vh] overflow-y-auto">
                {/* Header */}
                <div className="flex items-center justify-between p-6 border-b border-stone-200">
                    <div>
                        <h2 className="text-2xl font-serif font-bold text-stone-900">Create New Patient</h2>
                        <p className="text-sm text-stone-500 mt-1">Add a new patient to the registry</p>
                    </div>
                    <button
                        onClick={onClose}
                        className="p-2 hover:bg-stone-100 rounded-lg transition-colors"
                    >
                        <X className="w-5 h-5 text-stone-500" />
                    </button>
                </div>

                {/* Form */}
                <form onSubmit={handleSubmit} className="p-6 space-y-6">
                    {/* Name & Email */}
                    <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
                        <div>
                            <label className="block text-sm font-medium text-stone-700 mb-2">
                                Full Name <span className="text-rose-500">*</span>
                            </label>
                            <input
                                type="text"
                                required
                                value={formData.name}
                                onChange={(e) => setFormData({ ...formData, name: e.target.value })}
                                className="w-full px-4 py-2.5 border border-stone-200 rounded-xl focus:ring-2 focus:ring-brand-gold/20 focus:border-brand-gold outline-none transition-all"
                                placeholder="John Doe"
                            />
                        </div>
                        <div>
                            <label className="block text-sm font-medium text-stone-700 mb-2">
                                Email <span className="text-rose-500">*</span>
                            </label>
                            <input
                                type="email"
                                required
                                value={formData.email}
                                onChange={(e) => setFormData({ ...formData, email: e.target.value })}
                                className="w-full px-4 py-2.5 border border-stone-200 rounded-xl focus:ring-2 focus:ring-brand-gold/20 focus:border-brand-gold outline-none transition-all"
                                placeholder="john.doe@example.com"
                            />
                        </div>
                    </div>

                    {/* Phone & Age */}
                    <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
                        <div>
                            <label className="block text-sm font-medium text-stone-700 mb-2">
                                Phone <span className="text-rose-500">*</span>
                            </label>
                            <input
                                type="tel"
                                required
                                value={formData.phone}
                                onChange={(e) => setFormData({ ...formData, phone: e.target.value })}
                                className="w-full px-4 py-2.5 border border-stone-200 rounded-xl focus:ring-2 focus:ring-brand-gold/20 focus:border-brand-gold outline-none transition-all"
                                placeholder="+1 (555) 123-4567"
                            />
                        </div>
                        <div>
                            <label className="block text-sm font-medium text-stone-700 mb-2">
                                Age <span className="text-rose-500">*</span>
                            </label>
                            <input
                                type="number"
                                required
                                min="1"
                                max="120"
                                value={formData.age}
                                onChange={(e) => setFormData({ ...formData, age: e.target.value })}
                                className="w-full px-4 py-2.5 border border-stone-200 rounded-xl focus:ring-2 focus:ring-brand-gold/20 focus:border-brand-gold outline-none transition-all"
                                placeholder="35"
                            />
                        </div>
                    </div>

                    {/* Gender & Primary Goal */}
                    <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
                        <div>
                            <label className="block text-sm font-medium text-stone-700 mb-2">
                                Gender <span className="text-rose-500">*</span>
                            </label>
                            <select
                                required
                                value={formData.gender}
                                onChange={(e) => setFormData({ ...formData, gender: e.target.value as any })}
                                className="w-full px-4 py-2.5 border border-stone-200 rounded-xl focus:ring-2 focus:ring-brand-gold/20 focus:border-brand-gold outline-none transition-all"
                            >
                                <option value="Male">Male</option>
                                <option value="Female">Female</option>
                                <option value="Other">Other</option>
                            </select>
                        </div>
                        <div>
                            <label className="block text-sm font-medium text-stone-700 mb-2">
                                Primary Goal <span className="text-rose-500">*</span>
                            </label>
                            <input
                                type="text"
                                required
                                value={formData.primaryGoal}
                                onChange={(e) => setFormData({ ...formData, primaryGoal: e.target.value })}
                                className="w-full px-4 py-2.5 border border-stone-200 rounded-xl focus:ring-2 focus:ring-brand-gold/20 focus:border-brand-gold outline-none transition-all"
                                placeholder="e.g., Weight Loss, Longevity"
                            />
                        </div>
                    </div>

                    {/* Buttons */}
                    <div className="flex gap-3 pt-4">
                        <button
                            type="button"
                            onClick={onClose}
                            className="flex-1 px-6 py-3 border border-stone-200 rounded-xl text-stone-700 font-medium hover:bg-stone-50 transition-all"
                        >
                            Cancel
                        </button>
                        <button
                            type="submit"
                            className="flex-1 px-6 py-3 bg-brand-dark text-white rounded-xl font-medium hover:bg-stone-800 transition-all shadow-lg shadow-stone-900/20 flex items-center justify-center gap-2"
                        >
                            <Plus className="w-4 h-4" />
                            Create Patient
                        </button>
                    </div>
                </form>
            </div>
        </div>
    );
};

export default CreatePatientModal;
