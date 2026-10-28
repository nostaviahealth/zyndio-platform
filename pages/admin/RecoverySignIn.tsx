import React, { useState } from 'react';
import { useNavigate } from 'react-router-dom';
import AuthCard from '../../components/admin-auth/AuthCard';
import TextField from '../../components/admin-auth/TextField';
import Button from '../../components/admin-auth/Button';
import { usePortalAuth } from '../../contexts/PortalAuthContext';

type View = 'default' | 'no-access';

const RecoverySignIn: React.FC = () => {
  const { verifyRecoveryCode } = usePortalAuth();
  const navigate = useNavigate();
  const [code, setCode] = useState('');
  const [submitting, setSubmitting] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [view, setView] = useState<View>('default');

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setError(null);
    setSubmitting(true);
    try {
      const result = await verifyRecoveryCode(code);
      if (result.ok) {
        // Henry's ruling: straight to authenticator setup, no low-codes
        // screen, success copy exactly as specified.
        navigate('/admin/2fa/setup', {
          state: { banner: "Code accepted. Set up your authenticator again to finish signing in." },
        });
        return;
      }
      if (result.error === 'locked') {
        navigate('/admin/2fa/challenge', { state: { locked: true } });
        return;
      }
      setError("That code isn't valid or has already been used. Wrong codes count toward the 5-attempt limit.");
    } finally {
      setSubmitting(false);
    }
  };

  if (view === 'no-access') {
    return (
      <AuthCard>
        <h1 className="text-2xl font-bold text-slate-900">Can&apos;t use your app or codes?</h1>
        <p className="mt-2 text-sm text-slate-600">
          Ask a Zyndio admin to reset two-factor sign-in for your account. They&apos;ll confirm it&apos;s really you
          first, for example on a video call.
        </p>
        <p className="mt-2 text-sm text-slate-600">
          Contact your Zyndio admin directly. Don&apos;t send passwords or codes by email.
        </p>
        <p className="mt-2 text-sm text-slate-600">After the reset, sign in with your password.</p>
        <p className="mt-2 text-sm text-slate-600">Set up your authenticator app and save new recovery codes.</p>
        <Button variant="outline" className="mt-6 w-full" onClick={() => navigate('/admin/login')}>
          Back to sign-in
        </Button>
      </AuthCard>
    );
  }

  return (
    <AuthCard>
      <h1 className="text-2xl font-bold text-slate-900">Use a recovery code</h1>
      <p className="mt-2 text-sm text-slate-600">
        Enter one of the 10 codes you saved when you set up two-factor sign-in.
      </p>
      {error && (
        <p role="alert" className="mt-4 text-sm text-red-600">
          {error}
        </p>
      )}
      <form onSubmit={handleSubmit} className="mt-6 space-y-2" noValidate>
        <TextField
          label="Recovery code"
          value={code}
          onChange={(e) => setCode(e.target.value)}
          placeholder="XXXX-XXXX"
          className="font-mono"
          error={!!error}
          disabled={submitting}
          required
        />
        <p className="text-xs text-slate-500">Format XXXX-XXXX. Each code works once.</p>
        <Button type="submit" className="mt-4 w-full" busy={submitting}>
          Sign in
        </Button>
      </form>
      <div className="mt-4 flex justify-between text-sm">
        <button type="button" className="min-h-[44px] text-[#2C5CF2]" onClick={() => navigate('/admin/2fa/challenge')}>
          Use authenticator app
        </button>
        <button type="button" className="min-h-[44px] text-[#2C5CF2]" onClick={() => setView('no-access')}>
          Lost your codes too?
        </button>
      </div>
    </AuthCard>
  );
};

export default RecoverySignIn;
