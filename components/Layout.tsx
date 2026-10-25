import React from 'react';
import { useLocation, Outlet } from 'react-router-dom';
import Sidebar from './Sidebar';
import Header from './Header';
import BottomNav from './BottomNav';
import { useSidebar } from '../contexts/SidebarContext';

const Layout: React.FC = () => {
    const location = useLocation();
    const { isCollapsed } = useSidebar();

    const getTitle = () => {
        switch (location.pathname) {
            case '/': return 'Dashboard';
            case '/protocol': return 'My Protocol';
            case '/health-data': return 'Health Data';
            case '/health-vault': return 'Health Vault';
            case '/insights': return 'Health Insights';
            case '/devices': return 'Connected Devices';
            case '/intelligence': return 'Intelligence';
            case '/tools': return 'Tools';
            case '/settings': return 'Settings';
            case '/chat': return 'AI Assistant';
            case '/profile': return 'My Profile';
            default:
                if (location.pathname.startsWith('/health-vault/')) return 'Health Vault';
                return 'Dashboard';
        }
    };

    const isImmersive = location.pathname === '/food-intelligence';

    return (
        <div className={`min-h-screen ${isImmersive ? 'bg-black' : 'bg-brand-bg'} flex font-sans text-slate-800`}>
            {!isImmersive && (
                <div className="hidden md:block">
                    <Sidebar />
                </div>
            )}
            <div className={`flex-1 ${!isImmersive ? (isCollapsed ? 'md:ml-20' : 'md:ml-64') : ''} flex flex-col min-h-screen ${!isImmersive ? 'pb-20 md:pb-0' : ''} transition-all duration-300`}>
                {!isImmersive && <Header title={getTitle()} />}
                <main className={`flex-1 ${!isImmersive ? 'p-4 md:p-8' : 'p-0'} overflow-y-auto`}>
                    <div className={`${!isImmersive ? 'max-w-7xl mx-auto' : ''} animate-fade-in`}>
                        <Outlet />
                    </div>
                </main>
                {!isImmersive && <BottomNav />}
            </div>
        </div>
    );
};

export default Layout;
