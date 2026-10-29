import React, { useMemo } from 'react';
import { useNavigate } from 'react-router-dom';
import { Lock } from 'lucide-react';
import { usePortalAuth } from '../../contexts/PortalAuthContext';
import Button from '../../components/admin-auth/Button';

const ROLE_LABELS: Record<string, string> = {
  org_admin: 'Admin',
  physician: 'Physician',
  care_coordinator: 'Care coordinator',
  read_only: 'Read-only',
};

interface AccessDeniedProps {
  pageLabel?: string;
}

// 06-access-denied: rendered in place inside the app shell (not a route) so
// the person keeps their navigation. Doesn't reveal what the page contains.
const AccessDenied: React.FC<AccessDeniedProps> = ({ pageLabel = 'This page' }) => {
  const { role } = usePortalAuth();
  const navigate = useNavigate();
  const roleLabel = (role && ROLE_LABELS[role]) || 'your role';
  const isOrgAdmin = role === 'org_admin';
  // Fictional per-attempt reference shown to the user; the actual audit_log
  // write for this event is not wired up in this step (deferred - see
  // step7-summary.md).
  const requestRef = useMemo(() => `req_${Math.random().toString(16).slice(2, 10)}`, []);

  return (
    <div className="flex min-h-[60vh] flex-col items-center justify-center px-4 text-center">
      <div className="flex h-12 w-12 items-center justify-center rounded-full bg-slate-100 dark:bg-[#18224A]">
        <Lock className="h-5 w-5 text-slate-500 dark:text-[#AFC3FF]" aria-hidden="true" />
      </div>
      <h1 className="mt-4 text-xl font-bold text-[#030616] dark:text-[#EEF1F8]">You don&apos;t have access to this page</h1>
      <p className="mt-2 max-w-md text-sm text-slate-600 dark:text-[#A6B0C3]">
        {pageLabel} is only for some roles. Your role is <strong>{roleLabel}</strong>. If you need access
        for your work, ask a Zyndio admin to change your role.
      </p>
      <Button className="mt-6" onClick={() => navigate(isOrgAdmin ? '/admin/users' : '/admin')}>
        {isOrgAdmin ? 'Go to users and roles' : 'Go to patients'}
      </Button>
      <p className="mt-4 text-xs text-[#48556A] dark:text-[#8F9AAF]">
        Reference {requestRef}. This attempt was recorded in the audit log.
      </p>
    </div>
  );
};

export default AccessDenied;
