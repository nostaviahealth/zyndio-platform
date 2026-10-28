import React, { useRef, useState } from 'react';
import { useNavigate } from 'react-router-dom';
import AuthCard from '../../components/admin-auth/AuthCard';
import TextField from '../../components/admin-auth/TextField';
import Button from '../../components/admin-auth/Button';
import PasswordRules, { allClientRulesMet, checkPasswordRules } from '../../components/admin-auth/PasswordRules';
import { usePortalAuth } from '../../contexts/PortalAuthContext';

// Rule 7: same five live rules as invite (copy-deck.md 01-sign-in/invite),
// applied to reset and change too (admin README "Password rules copy").
const ERROR_COPY: Record<string, string> = {
  password_too_short: 'At least 12 characters.',
  password_too_common: 'This password is too common. Choose another one.',
  internal_error: "We can't reach the portal right now. Check your connection and try again.",
};

const ChangePassword: React.FC = () => {
  const { changePassword } = usePortalAuth();
  const navigate = useNavigate();
  const [password, setPassword] = useState('');
  const [submitting, setSubmitting] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [submitted, setSubmitted] = useState(false);
  const [tooCommon, setTooCommon] = useState(false);
  const [done, setDone] = useState(false);
  const passwordRef = useRef<HTMLInputElement>(null);

  if (done) {
    return (
      <AuthCard>
        <h1 className="text-2xl font-bold text-slate-900">Password changed</h1>
        <p className="mt-2 text-sm text-slate-600">Your password has been updated.</p>
        <Button variant="outline" className="mt-6 w-full" onClick={() => navigate('/admin')}>
          Back to dashboard
        </Button>
      </AuthCard>
    );
  }

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setError(null);
    setSubmitted(true);

    // Rules 1-4 are checked client-side. The button stays enabled even when
    // they're unmet (M8/Ava) - on submit, unmet rules turn red and focus
    // returns to the password field instead of a server round trip.
    if (!allClientRulesMet(checkPasswordRules(password))) {
      passwordRef.current?.focus();
      return;
    }

    setTooCommon(false);
    setSubmitting(true);
    try {
      const result = await changePassword(password);
      if (!result.ok) {
        if (result.error === 'password_too_common') {
          setTooCommon(true);
        }
        setError(ERROR_COPY[result.error ?? 'internal_error'] ?? ERROR_COPY.internal_error);
        passwordRef.current?.focus();
        return;
      }
      setDone(true);
    } finally {
      setSubmitting(false);
    }
  };

  return (
    <AuthCard>
      <h1 className="text-2xl font-bold text-slate-900">Change your password</h1>
      <p className="mt-2 text-sm text-slate-600">Create a new password for your Zyndio care portal account.</p>

      {error && (
        <div role="alert" className="mt-4 rounded-xl border border-red-300 bg-red-50 p-3 text-sm text-red-700">
          {error}
        </div>
      )}

      <form onSubmit={handleSubmit} className="mt-6 space-y-4" noValidate>
        <TextField
          ref={passwordRef}
          label="New password"
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
          Change password
        </Button>
      </form>
    </AuthCard>
  );
};

export default ChangePassword;
