import React from 'react';
import { Outlet } from 'react-router-dom';

const AdminLayout: React.FC = () => {
    return (
        <div className="min-h-screen bg-brand-bg font-sans text-slate-800">
            <div className="p-4">
                <h1 className="text-xl font-bold mb-4">Admin Portal</h1>
                <Outlet />
            </div>
        </div>
    );
};

export default AdminLayout;
