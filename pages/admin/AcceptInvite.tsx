import React, { useRef, useState } from 'react';
import { useNavigate, useParams } from 'react-router-dom';
import AuthCard from '../../components/admin-auth/AuthCard';
import TextField from '../../components/admin-auth/TextField';
import Button from '../../components/admin-auth/Button';
import PasswordRules, { allClientRulesMet, checkPasswordRules } from '../../components/admin-auth/PasswordRules';
import { usePortalAuth } from '../../contexts/PortalAuthContext';

const ERROR_COPY: Record<string, string> = {
  password_too_short: 'At least 12 characters.',
  password_too_common: 'This password is too common. Choose another one.',
  password_too_weak: 'Your password needs an uppercase and a lowercase letter, a number and a symbol.',
  invalid_or_expired_invite: 'This invite link is no longer valid. Ask your Zyndio admin to send a new one.',
  internal_error: "We can't reach the portal right now. Check your connection and try again.",
};

const AcceptInvite: React.FC = () => {
  const { token } = useParams<{ token: string }>();
  const { acceptInvite } = usePortalAuth();
  const navigate = useNavigate();
  const [password, setPassword] = useState('');
  const [submitting, setSubmitting] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [submitted, setSubmitted] = useState(false);
  const [tooCommon, setTooCommon] = useState(false);
  const passwordRef = useRef<HTMLInputElement>(null);

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!token) return;
    setError(null);
    setSubmitted(true);

    // Rules 1-4 (length, case, digit, symbol) are checked client-side. The
    // button stays enabled even when they're unmet (M8/Ava) - on submit,
    // unmet rules turn red and focus returns to the password field instead
    // of a server round trip.
    if (!allClientRulesMet(checkPasswordRules(password))) {
      passwordRef.current?.focus();
      return;
    }

    setTooCommon(false);
    setSubmitting(true);
    try {
      const result = await acceptInvite(token, password);
      if (!result.ok) {
        if (result.error === 'password_too_common') {
          setTooCommon(true);
        }
        setError(ERROR_COPY[result.error ?? 'internal_error'] ?? ERROR_COPY.internal_error);
        passwordRef.current?.focus();
        return;
      }
      navigate('/admin/login');
    } finally {
      setSubmitting(false);
    }
  };

  return (
    <AuthCard>
      <h1 className="text-2xl font-bold text-slate-900">Set up your account</h1>
      <p className="mt-2 text-sm text-slate-600">
        You&apos;ve been invited to the Zyndio care portal. Create a password to continue.
      </p>

      {error && (
        <div role="alert" className="mt-4 rounded-xl border border-red-300 bg-red-50 p-3 text-sm text-red-700">
          {error}
        </div>
      )}

      <form onSubmit={handleSubmit} className="mt-6 space-y-4" noValidate>
        <TextField
          ref={passwordRef}
          label="Create a password"
          type="password"
          value={password}
          onChange={(e) => {
            setPassword(e.target.value);
            setTooCommon(false);
          }}
          autoComplete="new-password"
          required
          disabled={submitting}
        />
        <PasswordRules password={password} submitted={submitted} tooCommon={tooCommon} />

        <Button type="submit" className="w-full" busy={submitting}>
          Create password and continue
        </Button>
      </form>

      <p className="mt-6 text-xs text-slate-500">Next, you&apos;ll set up two-factor sign-in.</p>
    </AuthCard>
  );
};

export default AcceptInvite;
