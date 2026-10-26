import React from 'react';
import { Navigate } from 'react-router-dom';
import { usePortalAuth } from '../../contexts/PortalAuthContext';

// aal-gate for the /admin/* tree (plan C) - status/aal/role are mirrored
// from the server on every check, never derived client-side.
const RequireSession: React.FC<{ children: React.ReactNode; requireAal2?: boolean }> = ({
  children,
  requireAal2 = true,
}) => {
  const { status } = usePortalAuth();

  if (status === 'loading') return null;
  if (status === 'signed_out') return <Navigate to="/admin/login" replace />;
  if (requireAal2 && status !== 'aal2') return <Navigate to="/admin/login" replace />;

  return <>{children}</>;
};

export default RequireSession;
