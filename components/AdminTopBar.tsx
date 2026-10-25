import React, { useState } from 'react';
import { Search, Bell, User, Settings as SettingsIcon, LogOut, Command } from 'lucide-react';
import { useNavigate } from 'react-router-dom';

interface AdminTopBarProps {
    onSearch?: (query: string) => void;
}

const AdminTopBar: React.FC<AdminTopBarProps> = ({ onSearch }) => {
    const [searchQuery, setSearchQuery] = useState('');
    const [showNotifications, setShowNotifications] = useState(false);
    const [showProfile, setShowProfile] = useState(false);
    const navigate = useNavigate();

    const handleSearch = (e: React.ChangeEvent<HTMLInputElement>) => {
        setSearchQuery(e.target.value);
        if (onSearch) {
            onSearch(e.target.value);
        }
    };

    const mockNotifications = [
        { id: '1', text: 'New lab results for Sarah Chen', time: '5m ago', unread: true },
        { id: '2', text: 'Diet plan approved for James Liu', time: '1h ago', unread: true },
        { id: '3', text: 'Emma Wilson scheduled consultation', time: '2h ago', unread: false },
    ];

    return (
        <div className="h-16 bg-white border-b border-stone-200 flex items-center justify-between px-6 sticky top-0 z-20">
            {/* Search Bar */}
            <div className="flex-1 max-w-2xl">
                <div className="relative group">
                    <Search className="absolute left-4 top-1/2 -translate-y-1/2 w-4 h-4 text-stone-400 transition-colors group-focus-within:text-brand-gold" />
                    <input
                        type="text"
                        value={searchQuery}
                        onChange={handleSearch}
                        placeholder="Search patients..."
                        className="w-full pl-11 pr-20 py-2.5 bg-stone-50 border border-stone-200 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-brand-gold/20 focus:border-brand-gold transition-all"
                    />
                    <div className="absolute right-3 top-1/2 -translate-y-1/2 flex items-center gap-1 text-xs text-stone-400">
                        <Command className="w-3 h-3" />
                        <span>K</span>
                    </div>
                </div>
            </div>

            {/* Right Section */}
            <div className="flex items-center gap-3 ml-6">
                {/* Notifications */}
                <div className="relative">
                    <button
                        onClick={() => setShowNotifications(!showNotifications)}
                        className="relative p-2 hover:bg-stone-100 rounded-xl transition-colors"
                    >
                        <Bell className="w-5 h-5 text-stone-600" />
                        <div className="absolute top-1 right-1 w-2 h-2 bg-rose-500 rounded-full"></div>
                    </button>

                    {/* Notifications Dropdown */}
                    {showNotifications && (
                        <div className="absolute right-0 top-full mt-2 w-80 bg-white border border-stone-200 rounded-xl shadow-2xl shadow-stone-900/10 overflow-hidden">
                            <div className="p-4 border-b border-stone-100 flex justify-between items-center">
                                <h3 className="font-bold text-stone-900">Notifications</h3>
                                <span className="text-xs text-stone-500">3 new</span>
                            </div>
                            <div className="max-h-96 overflow-y-auto">
                                {mockNotifications.map((notif) => (
                                    <div
                                        key={notif.id}
                                        className={`p-4 border-b border-stone-100 hover:bg-stone-50 cursor-pointer transition-colors ${notif.unread ? 'bg-amber-50/50' : ''
                                            }`}
                                    >
                                        <p className="text-sm text-stone-900">{notif.text}</p>
                                        <span className="text-xs text-stone-500 mt-1">{notif.time}</span>
                                    </div>
                                ))}
                            </div>
                            <div className="p-3 text-center border-t border-stone-100">
                                <button className="text-sm text-brand-gold hover:underline font-medium">
                                    View all notifications
                                </button>
                            </div>
                        </div>
                    )}
                </div>

                {/* Profile */}
                <div className="relative">
                    <button
                        onClick={() => setShowProfile(!showProfile)}
                        className="flex items-center gap-3 pl-3 pr-2 py-2 hover:bg-stone-100 rounded-xl transition-colors"
                    >
                        <div className="text-right hidden md:block">
                            <p className="text-sm font-medium text-stone-900">Dr. Admin</p>
                            <p className="text-xs text-stone-500">Administrator</p>
                        </div>
                        <div className="w-9 h-9 bg-gradient-to-br from-brand-dark to-stone-700 rounded-lg flex items-center justify-center text-white font-medium">
                            A
                        </div>
                    </button>

                    {/* Profile Dropdown */}
                    {showProfile && (
                        <div className="absolute right-0 top-full mt-2 w-56 bg-white border border-stone-200 rounded-xl shadow-2xl shadow-stone-900/10 overflow-hidden">
                            <div className="p-4 border-b border-stone-100">
                                <p className="font-bold text-stone-900">Dr. Admin</p>
                                <p className="text-sm text-stone-500">support@zyndio.example</p>
                            </div>
                            <div className="p-2">
                                <button className="w-full flex items-center gap-3 px-4 py-2.5 hover:bg-stone-50 rounded-lg text-sm text-stone-700 transition-colors">
                                    <User className="w-4 h-4" />
                                    Profile Settings
                                </button>
                                <button className="w-full flex items-center gap-3 px-4 py-2.5 hover:bg-stone-50 rounded-lg text-sm text-stone-700 transition-colors">
                                    <SettingsIcon className="w-4 h-4" />
                                    Preferences
                                </button>
                            </div>
                            <div className="p-2 border-t border-stone-100">
                                <button
                                    onClick={() => navigate('/')}
                                    className="w-full flex items-center gap-3 px-4 py-2.5 hover:bg-rose-50 rounded-lg text-sm text-rose-600 transition-colors"
                                >
                                    <LogOut className="w-4 h-4" />
                                    Sign Out
                                </button>
                            </div>
                        </div>
                    )}
                </div>
            </div>
        </div>
    );
};

export default AdminTopBar;
