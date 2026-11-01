import React from 'react';
import { Navigate } from 'react-router-dom';
import { usePortalAuth } from '../../contexts/PortalAuthContext';
import RequireRole from './RequireRole';
import AdminDashboard from '../../pages/admin/AdminDashboard';

// TC-018 item 3 (L35): #/admin is the app shell's index route. AdminDashboard
// is gated to physician/care_coordinator/read_only, so an org admin landed
// on 06-access-denied from every sign-in instead of their real home. Resolve
// by role before any gate runs, so a clinic's own admin never sees "You
// don't have access" just from signing in.
const AdminIndex: React.FC = () => {
  const { role } = usePortalAuth();
  if (role === 'org_admin') return <Navigate to="/admin/users" replace />;
  return (
    <RequireRole roles={['physician', 'care_coordinator', 'read_only']}>
      <AdminDashboard />
    </RequireRole>
  );
};

export default AdminIndex;
