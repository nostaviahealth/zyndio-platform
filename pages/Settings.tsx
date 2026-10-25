import React, { useState, useEffect } from 'react';
import { User, Bell, Shield, Smartphone, CreditCard, LogOut, ChevronRight, X, Check, Moon, Sun } from 'lucide-react';
import { useUser } from '../contexts/UserContext';
import { useAuth } from '../contexts/AuthContext';
import LoadingSkeleton from '../components/LoadingSkeleton';

interface ProfileData {
    name: string;
    email: string;
    phone: string;
}

const Settings: React.FC = () => {
    const { patientProfile, loading } = useUser();
    const { signOut } = useAuth();
    const [activeModal, setActiveModal] = useState<string | null>(null);
    const [notifications, setNotifications] = useState({
        email: true,
        push: true,
        sms: false,
        weeklyReport: true,
        urgentAlerts: true
    });
    const [theme, setTheme] = useState('light');
    const [profile, setProfile] = useState<ProfileData>({
        name: '',
        email: '',
        phone: ''
    });

    // Load real user data when patientProfile loads
    useEffect(() => {
        if (patientProfile) {
            setProfile({
                name: patientProfile.name,
                email: patientProfile.email,
                phone: patientProfile.phone || '+91 98765 43210'
            });
        }
    }, [patientProfile]);

    if (loading) {
        return (
            <div className="bg-white rounded-3xl shadow-sm border border-slate-200 overflow-hidden animate-pulse">
                <div className="h-48 bg-slate-100"></div>
                <div className="p-8 -mt-16 relative z-10">
                    <div className="flex flex-col md:flex-row items-end md:items-center gap-6 mb-8">
                        <div className="w-32 h-32 rounded-full bg-white p-1 shadow-md">
                            <div className="w-full h-full rounded-full bg-slate-200"></div>
                        </div>
                        <div className="mb-4 space-y-2">
                            <div className="h-8 w-48 bg-slate-100 rounded"></div>
                            <div className="h-4 w-32 bg-slate-100 rounded"></div>
                        </div>
                    </div>
                    <div className="space-y-6">
                        {[1, 2, 3].map(i => (
                            <div key={i} className="h-20 bg-slate-50 rounded-xl"></div>
                        ))}
                    </div>
                </div>
            </div>
        );
    }

    if (!patientProfile) {
        return (
            <div className="flex items-center justify-center h-64">
                <div className="text-slate-600">No profile data found</div>
            </div>
        );
    }

    const handleSaveProfile = () => {
        alert('Profile updated successfully!');
        setActiveModal(null);
    };

    const handleSignOut = async () => {
        if (confirm('Are you sure you want to sign out?')) {
            try {
                await signOut();
            } catch (error) {
                console.error('Sign out failed:', error);
                alert('Sign out failed. Please try again.');
            }
        }
    };

    const sections = [
        {
            title: 'Account',
            items: [
                { icon: User, label: 'Personal Information', value: 'Manage profile', action: 'profile' },
                { icon: Shield, label: 'Login & Security', value: 'Password, 2FA', action: 'security' },
                { icon: CreditCard, label: 'Membership & Billing', value: 'Premium Plan', action: 'billing' },
            ]
        },
        {
            title: 'Preferences',
            items: [
                { icon: Bell, label: 'Notifications', value: 'Manage alerts', action: 'notifications' },
                { icon: Smartphone, label: 'Connected Devices', value: 'Apple Watch, Oura', action: 'devices' },
                { icon: Moon, label: 'Theme', value: theme === 'light' ? 'Light Mode' : 'Dark Mode', action: 'theme' },
            ]
        }
    ];

    return (
        <div className="space-y-6">
            <h1 className="text-2xl font-serif text-slate-900">Settings</h1>

            <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
                {/* Profile Card */}
                <div className="lg:col-span-1">
                    <div className="bg-white p-6 rounded-3xl shadow-soft border-none flex flex-col items-center text-center">
                        <div className="relative mb-4">
                            <img
                                src={patientProfile.avatarUrl}
                                alt={patientProfile.name}
                                className="w-24 h-24 rounded-full object-cover border-4 border-slate-50"
                            />
                            <div className="absolute bottom-0 right-0 bg-brand-sageDark text-white p-1.5 rounded-full border-2 border-white">
                                <User className="w-4 h-4" />
                            </div>
                        </div>
                        <h2 className="text-xl font-bold text-slate-900">{profile.name}</h2>
                        <p className="text-slate-500 text-sm mb-6">{profile.email}</p>

                        <div className="w-full bg-slate-50 rounded-2xl p-4 mb-6">
                            <div className="flex justify-between items-center mb-2">
                                <span className="text-xs font-semibold text-slate-400 uppercase">Plan</span>
                                <span className="text-xs font-bold text-brand-sageDark bg-brand-sage/20 px-2 py-0.5 rounded-md">
                                    {patientProfile.isPremium ? 'PREMIUM' : 'PLAN'}
                                </span>
                            </div>
                            <div className="flex justify-between items-center">
                                <span className="text-xs font-semibold text-slate-400 uppercase">Member Since</span>
                                <span className="text-sm font-medium text-slate-700">
                                    {patientProfile.joinedDate ? new Date(patientProfile.joinedDate).toLocaleDateString('en-US', { month: 'short', year: 'numeric' }) : 'N/A'}
                                </span>
                            </div>
                        </div>

                        <button
                            onClick={handleSignOut}
                            className="w-full py-2.5 rounded-xl border border-slate-200 text-slate-600 font-medium hover:bg-red-50 hover:border-red-200 hover:text-red-600 transition-colors flex items-center justify-center gap-2"
                        >
                            <LogOut className="w-4 h-4" /> Sign Out
                        </button>
                    </div>
                </div>

                {/* Settings List */}
                <div className="lg:col-span-2 space-y-6">
                    {sections.map((section) => (
                        <div key={section.title} className="bg-white rounded-3xl shadow-soft border-none overflow-hidden">
                            <div className="px-6 py-4 border-b border-slate-100 bg-slate-50/50">
                                <h3 className="font-semibold text-slate-900">{section.title}</h3>
                            </div>
                            <div className="divide-y divide-slate-100">
                                {section.items.map((item) => (
                                    <button
                                        key={item.label}
                                        onClick={() => {
                                            if (item.action === 'billing') {
                                                window.location.href = 'https://member.zyndio.example/';
                                            } else {
                                                setActiveModal(item.action);
                                            }
                                        }}
                                        className="w-full px-6 py-4 flex items-center justify-between hover:bg-slate-50 transition-colors group"
                                    >
                                        <div className="flex items-center gap-4">
                                            <div className="w-10 h-10 rounded-full bg-slate-100 text-slate-500 flex items-center justify-center group-hover:bg-brand-sage/20 group-hover:text-brand-sageDark transition-colors">
                                                <item.icon className="w-5 h-5" />
                                            </div>
                                            <div className="text-left">
                                                <p className="font-medium text-slate-900">{item.label}</p>
                                                <p className="text-xs text-slate-500">{item.value}</p>
                                            </div>
                                        </div>
                                        <ChevronRight className="w-5 h-5 text-slate-300 group-hover:text-slate-500" />
                                    </button>
                                ))}
                            </div>
                        </div>
                    ))}
                </div>
            </div>

            {/* Profile Edit Modal */}
            {activeModal === 'profile' && (
                <div className="fixed inset-0 bg-black/50 backdrop-blur-sm z-50 flex items-center justify-center p-4" onClick={() => setActiveModal(null)}>
                    <div className="bg-white rounded-3xl p-8 max-w-md w-full shadow-2xl" onClick={(e) => e.stopPropagation()}>
                        <div className="flex justify-between items-center mb-6">
                            <h2 className="text-2xl font-serif text-slate-900">Edit Profile</h2>
                            <button onClick={() => setActiveModal(null)} className="p-2 hover:bg-slate-100 rounded-full">
                                <X className="w-5 h-5" />
                            </button>
                        </div>

                        <div className="space-y-4">
                            <div>
                                <label className="block text-sm font-medium text-slate-700 mb-2">Full Name</label>
                                <input
                                    type="text"
                                    value={profile.name}
                                    onChange={(e) => setProfile({ ...profile, name: e.target.value })}
                                    className="w-full p-3 border border-slate-200 rounded-xl focus:ring-2 focus:ring-emerald-500 outline-none"
                                />
                            </div>

                            <div>
                                <label className="block text-sm font-medium text-slate-700 mb-2">Email</label>
                                <input
                                    type="email"
                                    value={profile.email}
                                    onChange={(e) => setProfile({ ...profile, email: e.target.value })}
                                    className="w-full p-3 border border-slate-200 rounded-xl focus:ring-2 focus:ring-emerald-500 outline-none"
                                />
                            </div>

                            <div>
                                <label className="block text-sm font-medium text-slate-700 mb-2">Phone</label>
                                <input
                                    type="tel"
                                    value={profile.phone}
                                    onChange={(e) => setProfile({ ...profile, phone: e.target.value })}
                                    className="w-full p-3 border border-slate-200 rounded-xl focus:ring-2 focus:ring-emerald-500 outline-none"
                                />
                            </div>

                            <button
                                onClick={handleSaveProfile}
                                className="w-full bg-gradient-to-r from-emerald-500 to-emerald-600 text-white py-3 rounded-xl font-medium shadow-lg hover:from-emerald-600 hover:to-emerald-700 transition-all"
                            >
                                Save Changes
                            </button>
                        </div>
                    </div>
                </div>
            )}

            {/* Notifications Modal */}
            {activeModal === 'notifications' && (
                <div className="fixed inset-0 bg-black/50 backdrop-blur-sm z-50 flex items-center justify-center p-4" onClick={() => setActiveModal(null)}>
                    <div className="bg-white rounded-3xl p-8 max-w-md w-full shadow-2xl" onClick={(e) => e.stopPropagation()}>
                        <div className="flex justify-between items-center mb-6">
                            <h2 className="text-2xl font-serif text-slate-900">Notifications</h2>
                            <button onClick={() => setActiveModal(null)} className="p-2 hover:bg-slate-100 rounded-full">
                                <X className="w-5 h-5" />
                            </button>
                        </div>

                        <div className="space-y-4">
                            {Object.entries(notifications).map(([key, value]) => (
                                <div key={key} className="flex items-center justify-between p-4 bg-slate-50 rounded-xl">
                                    <span className="text-sm font-medium text-slate-900 capitalize">
                                        {key.replace(/([A-Z])/g, ' $1').trim()}
                                    </span>
                                    <button
                                        onClick={() => setNotifications({ ...notifications, [key]: !value })}
                                        className={`relative w-12 h-6 rounded-full transition-colors ${value ? 'bg-emerald-500' : 'bg-slate-300'}`}
                                    >
                                        <div className={`absolute top-0.5 w-5 h-5 bg-white rounded-full shadow-sm transition-transform ${value ? 'translate-x-6' : 'translate-x-0.5'}`} />
                                    </button>
                                </div>
                            ))}
                        </div>

                        <button
                            onClick={() => {
                                alert('Notification preferences saved!');
                                setActiveModal(null);
                            }}
                            className="w-full mt-6 bg-gradient-to-r from-emerald-500 to-emerald-600 text-white py-3 rounded-xl font-medium shadow-lg hover:from-emerald-600 hover:to-emerald-700 transition-all"
                        >
                            Save Preferences
                        </button>
                    </div>
                </div>
            )}

            {/* Theme Modal */}
            {activeModal === 'theme' && (
                <div className="fixed inset-0 bg-black/50 backdrop-blur-sm z-50 flex items-center justify-center p-4" onClick={() => setActiveModal(null)}>
                    <div className="bg-white rounded-3xl p-8 max-w-md w-full shadow-2xl" onClick={(e) => e.stopPropagation()}>
                        <div className="flex justify-between items-center mb-6">
                            <h2 className="text-2xl font-serif text-slate-900">Theme</h2>
                            <button onClick={() => setActiveModal(null)} className="p-2 hover:bg-slate-100 rounded-full">
                                <X className="w-5 h-5" />
                            </button>
                        </div>

                        <div className="space-y-3">
                            <button
                                onClick={() => setTheme('light')}
                                className={`w-full p-4 rounded-xl border-2 transition-all flex items-center gap-4 ${theme === 'light' ? 'border-emerald-500 bg-emerald-50' : 'border-slate-200 hover:border-slate-300'}`}
                            >
                                <Sun className="w-6 h-6 text-amber-500" />
                                <div className="flex-1 text-left">
                                    <div className="font-medium text-slate-900">Light Mode</div>
                                    <div className="text-xs text-slate-500">Classic bright theme</div>
                                </div>
                                {theme === 'light' && <Check className="w-5 h-5 text-emerald-600" />}
                            </button>

                            <button
                                onClick={() => setTheme('dark')}
                                className={`w-full p-4 rounded-xl border-2 transition-all flex items-center gap-4 ${theme === 'dark' ? 'border-emerald-500 bg-emerald-50' : 'border-slate-200 hover:border-slate-300'}`}
                            >
                                <Moon className="w-6 h-6 text-indigo-500" />
                                <div className="flex-1 text-left">
                                    <div className="font-medium text-slate-900">Dark Mode</div>
                                    <div className="text-xs text-slate-500">Easy on the eyes</div>
                                </div>
                                {theme === 'dark' && <Check className="w-5 h-5 text-emerald-600" />}
                            </button>
                        </div>

                        <button
                            onClick={() => {
                                alert(`Theme set to ${theme} mode!`);
                                setActiveModal(null);
                            }}
                            className="w-full mt-6 bg-gradient-to-r from-emerald-500 to-emerald-600 text-white py-3 rounded-xl font-medium shadow-lg hover:from-emerald-600 hover:to-emerald-700 transition-all"
                        >
                            Apply Theme
                        </button>
                    </div>
                </div>
            )}

            {/* Placeholder Modals */}
            {(activeModal === 'security' || activeModal === 'billing' || activeModal === 'devices') && (
                <div className="fixed inset-0 bg-black/50 backdrop-blur-sm z-50 flex items-center justify-center p-4" onClick={() => setActiveModal(null)}>
                    <div className="bg-white rounded-3xl p-8 max-w-md w-full shadow-2xl text-center" onClick={(e) => e.stopPropagation()}>
                        <div className="flex justify-end mb-4">
                            <button onClick={() => setActiveModal(null)} className="p-2 hover:bg-slate-100 rounded-full">
                                <X className="w-5 h-5" />
                            </button>
                        </div>
                        <div className="mb-6">
                            <Shield className="w-16 h-16 mx-auto text-emerald-500 mb-4" />
                            <h3 className="text-xl font-serif text-slate-900 mb-2">Coming Soon</h3>
                            <p className="text-slate-600">This feature is under development and will be available soon.</p>
                        </div>
                    </div>
                </div>
            )}
        </div>
    );
};

export default Settings;
