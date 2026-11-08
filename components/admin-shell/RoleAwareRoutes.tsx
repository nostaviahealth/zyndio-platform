import React from 'react';
import { usePortalAuth } from '../../contexts/PortalAuthContext';
import PhysicianPatientDetail from '../../pages/admin/clinic/PhysicianPatientDetail';
import ReferenceRanges from '../../pages/admin/clinic/ReferenceRanges';

// The clinical pages take the viewer's role as a prop (so tests and the
// /__preview harness can render them without an auth provider); these route
// elements read it from PortalAuth. The role only decides what the UI offers -
// every action is re-checked server-side.
export const PatientDetailRoute: React.FC = () => {
  const { role } = usePortalAuth();
  return <PhysicianPatientDetail viewerRole={role} />;
};

export const ReferenceRangesRoute: React.FC = () => {
  const { role } = usePortalAuth();
  return <ReferenceRanges viewerRole={role} />;
};
