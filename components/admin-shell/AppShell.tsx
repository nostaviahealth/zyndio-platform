import React, { useCallback } from 'react';
import { Outlet, useNavigate } from 'react-router-dom';
import Sidebar from './Sidebar';
import IdleWarningDialog from './IdleWarningDialog';
import { useIdleTimer } from '../../hooks/useIdleTimer';
import { usePortalAuth } from '../../contexts/PortalAuthContext';
import { ToastProvider } from '../ui/Toast';

// Single app shell for every /admin/* page (clinical + users/roles) -
// AdminLayout/AdminTopBar are retired, replaced by Sidebar + this idle
// timeout wiring (OVERRIDES #14: warning 13 min, sign-out 15 min).
const AppShell: React.FC = () => {
  const { signOut } = usePortalAuth();
  const navigate = useNavigate();

  const handleExpire = useCallback(() => {
    signOut().finally(() => navigate('/admin/session-expired', { replace: true }));
  }, [signOut, navigate]);

  const { state, secondsUntilExpire, reset } = useIdleTimer({ onExpire: handleExpire });

  const handleManualSignOut = useCallback(() => {
    signOut().finally(() => navigate('/admin/login', { replace: true }));
  }, [signOut, navigate]);

  return (
    <ToastProvider>
      <div className="flex min-h-screen bg-[#F2F4F7] dark:bg-[#070A14]">
        <Sidebar />
        <main className="min-w-0 flex-1 px-10 py-8">
          <Outlet />
        </main>
        {state === 'warning' && (
          <IdleWarningDialog
            secondsRemaining={secondsUntilExpire}
            onStaySignedIn={reset}
            onSignOut={handleManualSignOut}
          />
        )}
      </div>
    </ToastProvider>
  );
};

export default AppShell;
