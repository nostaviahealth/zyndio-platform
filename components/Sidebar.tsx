import React from 'react';
import { NavLink } from 'react-router-dom';
import { Home, FileText, Activity, Sparkles, Settings, Calculator, ChevronLeft, ChevronRight, FolderOpen } from 'lucide-react';
import { CURRENT_USER } from '../constants';
import { useUser } from '../contexts/UserContext';
import { useSidebar } from '../contexts/SidebarContext';
import { useAuth } from '../contexts/AuthContext';

const Sidebar: React.FC = () => {
    const { isCollapsed, toggleSidebar } = useSidebar();
    const { user } = useAuth();
    const { patientProfile } = useUser();

    const navItems = [
        { name: 'Home', icon: Home, path: '/' },
        { name: 'Protocol', icon: FileText, path: '/protocol' },
        { name: 'Health Vault', icon: FolderOpen, path: '/health-vault' },
        { name: 'Intelligence', icon: Sparkles, path: '/intelligence' },
        { name: 'Tools', icon: Calculator, path: '/tools' },
        { name: 'Settings', icon: Settings, path: '/settings' },
    ];

    return (
        <div className={`${isCollapsed ? 'w-20' : 'w-64'} h-screen bg-white border-r border-slate-200 flex flex-col fixed left-0 top-0 z-10 hidden md:flex transition-all duration-300`}>
            {/* Logo */}
            <div className="px-6 py-8">
                {!isCollapsed ? (
                    <img
                        src="/zyndio-logo.png"
                        alt="Zyndio"
                        className="h-12 w-auto object-contain"
                    />
                ) : (
                    <div className="flex justify-center">
                        <img
                            src="/zyndio-icon.png"
                            alt="Zyndio"
                            className="w-10 h-10 object-contain"
                        />
                    </div>
                )}
            </div>

            {/* Navigation */}
            <nav className="flex-1 px-4 space-y-2 mt-2">
                {navItems.map((item) => (
                    <NavLink
                        key={item.name}
                        to={item.path}
                        className={({ isActive }) =>
                            `flex items-center ${isCollapsed ? 'justify-center px-3' : 'px-4'} py-3 text-sm font-medium rounded-xl transition-all duration-200 ${isActive
                                ? 'bg-brand-dark text-white shadow-glow'
                                : 'text-slate-500 hover:bg-slate-100 hover:text-brand-dark'
                            }`
                        }
                        title={isCollapsed ? item.name : undefined}
                    >
                        <item.icon className={`w-5 h-5 ${isCollapsed ? '' : 'mr-3'}`} />
                        {!isCollapsed && item.name}
                    </NavLink>
                ))}
            </nav>

            {/* Collapse Button */}
            <div className="px-4 pb-4 mb-2 border-t border-slate-100 pt-4">
                <button
                    onClick={toggleSidebar}
                    className={`w-full flex items-center ${isCollapsed ? 'justify-center px-3' : 'px-4'} py-3 text-sm font-medium text-slate-600 bg-slate-50 hover:bg-slate-100 border border-slate-200 rounded-xl transition-all duration-200 shadow-sm hover:shadow`}
                    aria-label={isCollapsed ? 'Expand sidebar' : 'Collapse sidebar'}
                >
                    {isCollapsed ? (
                        <ChevronRight className="w-4 h-4" />
                    ) : (
                        <>
                            <ChevronLeft className="w-4 h-4 mr-2" />
                            <span>Collapse</span>
                        </>
                    )}
                </button>
            </div>

            {/* User Profile - Click to go to Settings */}
            {!isCollapsed ? (
                <NavLink
                    to="/settings"
                    className="p-4 m-4 bg-brand-bg rounded-2xl flex items-center gap-3 border border-slate-200 hover:border-brand-dark hover:shadow-md transition-all cursor-pointer"
                >
                    <img
                        src={patientProfile?.avatarUrl || CURRENT_USER.avatarUrl}
                        alt="User"
                        className="w-10 h-10 rounded-full object-cover border-2 border-white shadow-sm"
                    />
                    <div className="flex-1 min-h-0">
                        <p className="text-sm font-semibold text-brand-dark truncate">{patientProfile?.name || user?.name || CURRENT_USER.name}</p>
                        <p className="text-xs text-slate-500 truncate">Premium Member</p>
                    </div>
                </NavLink>
            ) : (
                <NavLink
                    to="/settings"
                    className="p-4 m-2 flex justify-center hover:opacity-80 transition-opacity"
                >
                    <img
                        src={patientProfile?.avatarUrl || CURRENT_USER.avatarUrl}
                        alt="User"
                        className="w-10 h-10 rounded-full object-cover border-2 border-brand-dark shadow-sm"
                    />
                </NavLink>
            )}
        </div>
    );
};

export default Sidebar;