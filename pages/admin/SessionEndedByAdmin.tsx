import React from 'react';
import { useNavigate } from 'react-router-dom';
import AuthCard from '../../components/admin-auth/AuthCard';
import Button from '../../components/admin-auth/Button';

// 05-session/ended-by-admin: a token refresh failure after deactivation,
// a role change or a 2FA reset lands here instead of session-expired.
const SessionEndedByAdmin: React.FC = () => {
  const navigate = useNavigate();
  return (
    <AuthCard>
      <h1 className="text-xl font-bold text-[#030616]">You&apos;ve been signed out</h1>
      <p className="mt-2 text-sm text-slate-600">
        A Zyndio admin made a change to your account (for example, deactivation, a role change or a
        two-factor reset) and signed you out everywhere.
      </p>
      <Button className="mt-6 w-full" onClick={() => navigate('/admin/login')}>
        Sign in again
      </Button>
      <p className="mt-4 text-center text-sm text-slate-500">
        If this wasn&apos;t expected, contact a Zyndio admin.
      </p>
    </AuthCard>
  );
};

export default SessionEndedByAdmin;
