import React from 'react';
import { Navigate } from 'react-router-dom';
import { usePortalAuth } from '../../contexts/PortalAuthContext';

// aal-gate for the /admin/* tree (plan C) - status/aal/role are mirrored
// from the server on every check, never derived client-side.
const RequireSession: React.FC<{ children: React.ReactNode; requireAal2?: boolean }> = ({
  children,
  requireAal2 = true,
}) => {
  const { status, endedByAdmin, hasFactor } = usePortalAuth();

  if (status === 'loading') return null;
  if (status === 'signed_out') {
    return <Navigate to={endedByAdmin ? '/admin/session-ended' : '/admin/login'} replace />;
  }
  // H-E2E-1: an aal1 session must continue the MFA journey, not bounce to login.
  if (requireAal2 && status !== 'aal2') {
    if (status === 'aal1') {
      return <Navigate to={hasFactor ? '/admin/2fa/challenge' : '/admin/2fa/setup'} replace />;
    }
    return <Navigate to="/admin/login" replace />;
  }

  return <>{children}</>;
};

export default RequireSession;
