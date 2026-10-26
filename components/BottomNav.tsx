import React from 'react';
import { useNavigate, useLocation } from 'react-router-dom';
import { Home, Activity, FileText, Sparkles, Settings, Calculator, Radio } from 'lucide-react';

const BottomNav: React.FC = () => {
    const navigate = useNavigate();
    const location = useLocation();

    const navItems = [
        { name: 'Home', icon: Home, path: '/' },
        { name: 'Protocol', icon: FileText, path: '/protocol' },
        { name: 'Tools', icon: Calculator, path: '/tools' },
        { name: 'Intelligence', icon: Sparkles, path: '/intelligence' },
    ];

    return (
        <div
            className="fixed bottom-0 left-0 right-0 bg-white border-t border-slate-200 px-6 py-3 md:hidden z-50 shadow-lg"
            style={{ paddingBottom: 'max(12px, env(safe-area-inset-bottom))' }}
        >
            <div className="flex justify-between items-center">
                {navItems.map((item) => {
                    const isActive = location.pathname === item.path;
                    return (
                        <button
                            key={item.name}
                            onClick={() => navigate(item.path)}
                            className={`flex flex-col items-center gap-1 transition-colors ${isActive ? 'text-brand-sageDark' : 'text-slate-400 hover:text-slate-600'
                                }`}
                        >
                            <item.icon className={`w-6 h-6 ${isActive ? 'fill-current' : ''}`} />
                            <span className="text-[10px] font-medium">{item.name}</span>
                        </button>
                    );
                })}
            </div>
        </div>
    );
};

export default BottomNav;
