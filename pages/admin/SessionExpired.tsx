import React from 'react';
import { useNavigate } from 'react-router-dom';
import AuthCard from '../../components/admin-auth/AuthCard';
import Button from '../../components/admin-auth/Button';

// 05-session/expired: 15 minutes idle. Unsaved typing is not kept (the
// warning dialog is the only chance to save work - not drawn per specs.md).
const SessionExpired: React.FC = () => {
  const navigate = useNavigate();
  return (
    <AuthCard>
      <h1 className="text-xl font-bold text-[#030616]">You&apos;ve been signed out</h1>
      <p className="mt-2 text-sm text-slate-600">
        For patient privacy, we sign you out after 15 minutes without activity.
      </p>
      <Button className="mt-6 w-full" onClick={() => navigate('/admin/login')}>
        Sign in again
      </Button>
    </AuthCard>
  );
};

export default SessionExpired;
