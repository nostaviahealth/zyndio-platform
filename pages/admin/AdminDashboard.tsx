import React, { useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { Users, Plus, Search, Trash2, Clock, CheckCircle, AlertCircle, FileText, Activity } from 'lucide-react';
import { useAdmin } from '../../contexts/AdminContext';
import { usePortalAuth } from '../../contexts/PortalAuthContext';
import { OnboardingStage } from '../../types';

const AdminDashboard: React.FC = () => {
    const navigate = useNavigate();
    const { patients, deletePatient, loading } = useAdmin();
    const { role } = usePortalAuth();
    // OVERRIDES #11 / Henry: read_only has no patient detail pages, so rows
    // aren't links for them (and there's nothing destructive to offer either).
    const canManagePatients = role === 'physician' || role === 'care_coordinator';
    const [searchQuery, setSearchQuery] = useState('');
    const [filterStatus, setFilterStatus] = useState<string>('all');
    const [deleteConfirm, setDeleteConfirm] = useState<string | null>(null);

    const getStatusInfo = (stage: OnboardingStage) => {
        const statusMap = {
            'payment_pending': { label: 'Payment Pending', color: 'bg-amber-100 text-amber-700', icon: Clock },
            'questionnaire_pending': { label: 'Questionnaire Pending', color: 'bg-blue-100 text-blue-700', icon: FileText },
            'lab_test_scheduled': { label: 'Lab Test Scheduled', color: 'bg-indigo-100 text-indigo-700', icon: Activity },
            'lab_processing': { label: 'Lab Processing', color: 'bg-purple-100 text-purple-700', icon: Activity },
            'doctor_verification': { label: 'Doctor Review', color: 'bg-orange-100 text-orange-700', icon: AlertCircle },
            'protocol_ready': { label: 'Protocol Ready', color: 'bg-emerald-100 text-emerald-700', icon: CheckCircle },
        };
        return statusMap[stage] || { label: stage, color: 'bg-slate-100 text-slate-700', icon: Clock };
    };

    const filteredPatients = patients.filter(patient => {
        const name = patient.name || '';
        const email = patient.email || '';
        const matchesSearch = name.toLowerCase().includes(searchQuery.toLowerCase()) ||
            email.toLowerCase().includes(searchQuery.toLowerCase());
        const matchesFilter = filterStatus === 'all' || patient.stage === filterStatus;
        return matchesSearch && matchesFilter;
    });

    const statusCounts = {
        all: patients.length,
        payment_pending: patients.filter(p => p.stage === 'payment_pending').length,
        questionnaire_pending: patients.filter(p => p.stage === 'questionnaire_pending').length,
        lab_processing: patients.filter(p => p.stage === 'lab_processing').length,
        doctor_verification: patients.filter(p => p.stage === 'doctor_verification').length,
        protocol_ready: patients.filter(p => p.stage === 'protocol_ready').length,
    };

    return (
        <div className="p-6 space-y-6">
            {/* Header */}
            <div className="flex justify-between items-center">
                <div>
                    <h1 className="text-2xl font-serif text-slate-900 mb-2">Patient Management</h1>
                    <p className="text-slate-600">Monitor and manage patient onboarding journey</p>
                </div>
                <button
                    onClick={() => navigate('/admin/patients/create')}
                    className="flex items-center gap-2 bg-gradient-to-r from-emerald-500 to-emerald-600 text-white px-6 py-3 rounded-xl font-medium shadow-lg hover:from-emerald-600 hover:to-emerald-700 transition-all"
                >
                    <Plus className="w-5 h-5" />
                    New Patient
                </button>
            </div>

            {/* Stats Cards */}
            <div className="grid grid-cols-2 md:grid-cols-3 lg:grid-cols-6 gap-4">
                <div
                    onClick={() => setFilterStatus('all')}
                    className={`p-4 rounded-2xl cursor-pointer transition-all ${filterStatus === 'all' ? 'bg-slate-900 text-white shadow-lg' : 'bg-white hover:shadow-md'}`}
                >
                    <div className="text-3xl font-bold mb-1">{statusCounts.all}</div>
                    <div className={`text-sm ${filterStatus === 'all' ? 'text-slate-300' : 'text-slate-600'}`}>All Patients</div>
                </div>
                <div
                    onClick={() => setFilterStatus('payment_pending')}
                    className={`p-4 rounded-2xl cursor-pointer transition-all ${filterStatus === 'payment_pending' ? 'bg-amber-500 text-white shadow-lg' : 'bg-white hover:shadow-md'}`}
                >
                    <div className="text-3xl font-bold mb-1">{statusCounts.payment_pending}</div>
                    <div className={`text-sm ${filterStatus === 'payment_pending' ? 'text-amber-100' : 'text-slate-600'}`}>Payment</div>
                </div>
                <div
                    onClick={() => setFilterStatus('questionnaire_pending')}
                    className={`p-4 rounded-2xl cursor-pointer transition-all ${filterStatus === 'questionnaire_pending' ? 'bg-blue-500 text-white shadow-lg' : 'bg-white hover:shadow-md'}`}
                >
                    <div className="text-3xl font-bold mb-1">{statusCounts.questionnaire_pending}</div>
                    <div className={`text-sm ${filterStatus === 'questionnaire_pending' ? 'text-blue-100' : 'text-slate-600'}`}>Questionnaire</div>
                </div>
                <div
                    onClick={() => setFilterStatus('lab_processing')}
                    className={`p-4 rounded-2xl cursor-pointer transition-all ${filterStatus === 'lab_processing' ? 'bg-purple-500 text-white shadow-lg' : 'bg-white hover:shadow-md'}`}
                >
                    <div className="text-3xl font-bold mb-1">{statusCounts.lab_processing}</div>
                    <div className={`text-sm ${filterStatus === 'lab_processing' ? 'text-purple-100' : 'text-slate-600'}`}>Lab Review</div>
                </div>
                <div
                    onClick={() => setFilterStatus('doctor_verification')}
                    className={`p-4 rounded-2xl cursor-pointer transition-all ${filterStatus === 'doctor_verification' ? 'bg-orange-500 text-white shadow-lg' : 'bg-white hover:shadow-md'}`}
                >
                    <div className="text-3xl font-bold mb-1">{statusCounts.doctor_verification}</div>
                    <div className={`text-sm ${filterStatus === 'doctor_verification' ? 'text-orange-100' : 'text-slate-600'}`}>Doctor Review</div>
                </div>
                <div
                    onClick={() => setFilterStatus('protocol_ready')}
                    className={`p-4 rounded-2xl cursor-pointer transition-all ${filterStatus === 'protocol_ready' ? 'bg-emerald-500 text-white shadow-lg' : 'bg-white hover:shadow-md'}`}
                >
                    <div className="text-3xl font-bold mb-1">{statusCounts.protocol_ready}</div>
                    <div className={`text-sm ${filterStatus === 'protocol_ready' ? 'text-emerald-100' : 'text-slate-600'}`}>Ready</div>
                </div>
            </div>

            {/* Search and Filter */}
            <div className="bg-white p-4 rounded-2xl shadow-soft flex gap-4 items-center">
                <div className="flex-1 flex items-center gap-2 bg-slate-50 px-4 py-2 rounded-xl">
                    <Search className="w-5 h-5 text-slate-400" />
                    <input
                        type="text"
                        placeholder="Search patients by name or email..."
                        value={searchQuery}
                        onChange={(e) => setSearchQuery(e.target.value)}
                        className="flex-1 bg-transparent border-none outline-none text-slate-900 placeholder:text-slate-400"
                    />
                </div>
            </div>

            {/* Patient List */}
            <div className="bg-white rounded-2xl shadow-soft overflow-hidden">
                <div className="overflow-x-auto">
                    <table className="w-full">
                        <thead className="bg-slate-50 border-b border-slate-200">
                            <tr>
                                <th className="px-6 py-4 text-left text-xs font-semibold text-slate-600 uppercase tracking-wider">Patient</th>
                                <th className="px-6 py-4 text-left text-xs font-semibold text-slate-600 uppercase tracking-wider">Contact</th>
                                <th className="px-6 py-4 text-left text-xs font-semibold text-slate-600 uppercase tracking-wider">Status</th>
                                <th className="px-6 py-4 text-left text-xs font-semibold text-slate-600 uppercase tracking-wider">Age</th>
                                <th className="px-6 py-4 text-left text-xs font-semibold text-slate-600 uppercase tracking-wider">Actions</th>
                            </tr>
                        </thead>
                        <tbody className="divide-y divide-slate-100">
                            {filteredPatients.map((patient) => {
                                const statusInfo = getStatusInfo(patient.stage);
                                const StatusIcon = statusInfo.icon;

                                return (
                                    <tr key={patient.id} className="hover:bg-slate-50 transition-colors">
                                        <td className="px-6 py-4">
                                            <div>
                                                <div className="font-medium text-slate-900">{patient.name}</div>
                                                <div className="text-sm text-slate-500">ID: {patient.id}</div>
                                            </div>
                                        </td>
                                        <td className="px-6 py-4">
                                            <div className="text-sm text-slate-900">{patient.email}</div>
                                            <div className="text-sm text-slate-500">{patient.phone || 'N/A'}</div>
                                        </td>
                                        <td className="px-6 py-4">
                                            <span className={`inline-flex items-center gap-2 px-3 py-1 rounded-full text-xs font-medium ${statusInfo.color}`}>
                                                <StatusIcon className="w-3 h-3" />
                                                {statusInfo.label}
                                            </span>
                                        </td>
                                        <td className="px-6 py-4">
                                            <div className="text-sm text-slate-900">{patient.age} years</div>
                                            <div className="text-sm text-slate-500">Bio: {patient.bioAge}</div>
                                        </td>
                                        <td className="px-6 py-4">
                                            {canManagePatients ? (
                                                <div className="flex items-center gap-2">
                                                    <button
                                                        onClick={() => navigate(`/admin/patient/${patient.id}`)}
                                                        className="text-emerald-600 hover:text-emerald-700 font-medium text-sm transition-colors"
                                                    >
                                                        View Details →
                                                    </button>
                                                    <button
                                                        onClick={() => setDeleteConfirm(patient.id)}
                                                        className="p-2 text-rose-600 hover:bg-rose-50 rounded-lg transition-colors"
                                                        title="Delete patient"
                                                    >
                                                        <Trash2 className="w-4 h-4" />
                                                    </button>
                                                </div>
                                            ) : (
                                                <span className="text-sm text-slate-400">View only</span>
                                            )}
                                        </td>
                                    </tr>
                                );
                            })}
                        </tbody>
                    </table>
                </div>

                {filteredPatients.length === 0 && (
                    <div className="text-center py-12">
                        <Users className="w-12 h-12 text-slate-300 mx-auto mb-4" />
                        <p className="text-slate-500">No patients found matching your criteria</p>
                    </div>
                )}
            </div>

            {/* Delete Confirmation Modal */}
            {deleteConfirm && (
                <div className="fixed inset-0 bg-black/50 flex items-center justify-center z-50 p-4">
                    <div className="bg-white rounded-2xl p-6 max-w-md w-full shadow-2xl">
                        <h3 className="text-xl font-bold text-slate-900 mb-2">Delete Patient?</h3>
                        <p className="text-slate-600 mb-6">
                            Are you sure you want to delete this patient? This action cannot be undone and will remove all associated data.
                        </p>
                        <div className="flex gap-3">
                            <button
                                onClick={() => setDeleteConfirm(null)}
                                className="flex-1 px-4 py-2 border border-slate-300 rounded-xl font-medium text-slate-700 hover:bg-slate-50 transition-colors"
                            >
                                Cancel
                            </button>
                            <button
                                onClick={async () => {
                                    await deletePatient(deleteConfirm);
                                    setDeleteConfirm(null);
                                }}
                                className="flex-1 px-4 py-2 bg-rose-600 text-white rounded-xl font-medium hover:bg-rose-700 transition-colors"
                            >
                                Delete
                            </button>
                        </div>
                    </div>
                </div>
            )}
        </div>
    );
};

export default AdminDashboard;
