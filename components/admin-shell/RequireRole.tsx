import React from 'react';
import { usePortalAuth } from '../../contexts/PortalAuthContext';
import AccessDenied from '../../pages/admin/AccessDenied';

interface RequireRoleProps {
  children: React.ReactNode;
  roles: string[];
  pageLabel?: string;
}

// Role-gate for routes inside the app shell: renders 06-access-denied in
// place (not a redirect) so the person keeps their navigation.
const RequireRole: React.FC<RequireRoleProps> = ({ children, roles, pageLabel }) => {
  const { role } = usePortalAuth();
  if (!role || !roles.includes(role)) {
    return <AccessDenied pageLabel={pageLabel} />;
  }
  return <>{children}</>;
};

export default RequireRole;
