import React, { useState } from 'react';
import { useNavigate } from 'react-router-dom';
import AuthCard from '../../components/admin-auth/AuthCard';
import TextField from '../../components/admin-auth/TextField';
import Button from '../../components/admin-auth/Button';
import { GENERIC_SIGNIN_ERROR, NETWORK_ERROR_MESSAGE, usePortalAuth } from '../../contexts/PortalAuthContext';

type ViewState = 'form' | 'reset-sent';

const SignIn: React.FC = () => {
  const { signIn, requestPasswordReset } = usePortalAuth();
  const navigate = useNavigate();
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [showPassword, setShowPassword] = useState(false);
  const [submitting, setSubmitting] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [view, setView] = useState<ViewState>('form');

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setError(null);
    setSubmitting(true);
    try {
      const result = await signIn(email, password);
      if (result.ok) {
        // H-E2E-1: never send aal1 into /admin (RequireSession would bounce to login).
        // Route to challenge when a TOTP factor exists, otherwise to setup.
        navigate(result.hasFactor ? '/admin/2fa/challenge' : '/admin/2fa/setup');
        return;
      }
      if (result.locked) {
        navigate('/admin/2fa/challenge', { state: { locked: true } });
        return;
      }
      setError(result.error === 'network_error' ? NETWORK_ERROR_MESSAGE : GENERIC_SIGNIN_ERROR);
    } finally {
      setSubmitting(false);
    }
  };

  const handleForgotPassword = async () => {
    await requestPasswordReset(email);
    setView('reset-sent');
  };

  if (view === 'reset-sent') {
    return (
      <AuthCard>
        <h1 className="text-2xl font-bold text-slate-900">Check your email</h1>
        <p className="mt-2 text-sm text-slate-600">
          If {email || 'that email'} has a portal account, we&apos;ve sent a link to reset your password. The link
          works once and expires after 30 minutes.
        </p>
        <p className="mt-4 text-sm text-slate-600">
          Didn&apos;t get it? Check spam, or ask your Zyndio admin to confirm the email on your account.
        </p>
        <Button variant="outline" className="mt-6 w-full" onClick={() => setView('form')}>
          Back to sign-in
        </Button>
      </AuthCard>
    );
  }

  return (
    <AuthCard>
      <h1 className="text-2xl font-bold text-slate-900">Sign in to the care portal</h1>
      <p className="mt-2 text-sm text-slate-600">
        For Zyndio clinicians and staff. Patients sign in with the Zyndio app.
      </p>

      {error && (
        <div role="alert" tabIndex={-1} className="mt-4 rounded-xl border border-red-300 bg-red-50 p-3 text-sm text-red-700">
          {error}
        </div>
      )}

      <form onSubmit={handleSubmit} className="mt-6 space-y-4" noValidate>
        <TextField
          label="Work email"
          type="email"
          value={email}
          onChange={(e) => setEmail(e.target.value)}
          placeholder="morgan.ellis@example.test"
          autoComplete="username"
          error={!!error}
          required
          disabled={submitting}
        />
        <div>
          <TextField
            label="Password"
            type={showPassword ? 'text' : 'password'}
            value={password}
            onChange={(e) => setPassword(e.target.value)}
            autoComplete="current-password"
            error={!!error}
            required
            disabled={submitting}
          />
          <div className="mt-1 flex items-center justify-between">
            <button
              type="button"
              className="min-h-[44px] text-sm font-medium text-[#2C5CF2]"
              onClick={() => setShowPassword((s) => !s)}
            >
              {showPassword ? 'Hide' : 'Show'}
            </button>
            <button
              type="button"
              className="min-h-[44px] text-sm font-medium text-[#2C5CF2]"
              onClick={handleForgotPassword}
              disabled={submitting}
            >
              Forgot password?
            </button>
          </div>
        </div>

        <Button type="submit" className="w-full" busy={submitting} busyLabel="Checking">
          Continue
        </Button>
      </form>

      <p className="mt-6 text-xs text-slate-500">
        Next you&apos;ll confirm it&apos;s you with your authenticator app. Accounts are created by your Zyndio
        admin.
      </p>
    </AuthCard>
  );
};

export default SignIn;
