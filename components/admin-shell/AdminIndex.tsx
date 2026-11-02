import React from 'react';
import { Navigate } from 'react-router-dom';
import { usePortalAuth } from '../../contexts/PortalAuthContext';
import AccessDenied from '../../pages/admin/AccessDenied';

// TC-029 (a): #/admin is the app shell's index route. It used to render the
// old "Patient Management" page (pages/admin/AdminDashboard) for clinical
// roles - an empty roster with zero counts and a stray "New Patient" button.
// The real roster lives at /admin/patients. The index now redirects each
// signed-in role to its own home (the same destinations the Sidebar nav
// links to), so nobody lands on the retired page:
//   org_admin        -> /admin/users    (Users and roles)
//   physician        -> /admin/patients (clinical roster)
//   care_coordinator -> /admin/patients
//   read_only        -> /admin/patients
// An unknown/absent role falls through to 06-access-denied rather than being
// routed into a page it can't open.
const HOME_BY_ROLE: Record<string, string> = {
  org_admin: '/admin/users',
  physician: '/admin/patients',
  care_coordinator: '/admin/patients',
  read_only: '/admin/patients',
};

const AdminIndex: React.FC = () => {
  const { role } = usePortalAuth();
  const home = role ? HOME_BY_ROLE[role] : undefined;
  if (home) return <Navigate to={home} replace />;
  return <AccessDenied />;
};

export default AdminIndex;
