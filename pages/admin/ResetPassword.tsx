import React, { useRef, useState } from 'react';
import { useNavigate } from 'react-router-dom';
import AuthCard from '../../components/admin-auth/AuthCard';
import TextField from '../../components/admin-auth/TextField';
import Button from '../../components/admin-auth/Button';
import PasswordRules, { allClientRulesMet, checkPasswordRules } from '../../components/admin-auth/PasswordRules';
import { usePortalAuth } from '../../contexts/PortalAuthContext';
import { supabase } from '../../lib/supabase';

// Rule 7: same five live rules as invite (copy-deck.md 01-sign-in/invite),
// applied to reset and change too (admin README "Password rules copy").
const ERROR_COPY: Record<string, string> = {
  password_too_short: 'At least 12 characters.',
  password_too_common: 'This password is too common. Choose another one.',
  internal_error: "We can't reach the portal right now. Check your connection and try again.",
};

// Lands on the reset link's redirectTo (PortalAuthContext.requestPasswordReset).
// supabase-js's detectSessionInUrl consumes the recovery tokens from the URL
// hash and turns them into a real (aal1) session before this mounts, so
// "status" alone tells us whether the link was valid.
const ResetPassword: React.FC = () => {
  const { status, changePassword } = usePortalAuth();
  const navigate = useNavigate();
  const [password, setPassword] = useState('');
  const [submitting, setSubmitting] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [submitted, setSubmitted] = useState(false);
  const [tooCommon, setTooCommon] = useState(false);
  const passwordRef = useRef<HTMLInputElement>(null);

  if (status === 'loading') {
    return <AuthCard>{null}</AuthCard>;
  }

  if (status === 'signed_out') {
    return (
      <AuthCard>
        <h1 className="text-2xl font-bold text-slate-900">This link is no longer valid</h1>
        <p className="mt-2 text-sm text-slate-600">
          Reset links work once and expire after 30 minutes. Ask for a new one from the sign-in page.
        </p>
        <Button variant="outline" className="mt-6 w-full" onClick={() => navigate('/admin/login')}>
          Back to sign-in
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
      // The recovery session is single-purpose - sign out so the person
      // signs in fresh (and completes 2FA) rather than being left aal1 on
      // the public /admin/login route.
      await supabase.auth.signOut();
      navigate('/admin/login');
    } finally {
      setSubmitting(false);
    }
  };

  return (
    <AuthCard>
      <h1 className="text-2xl font-bold text-slate-900">Reset your password</h1>
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
          Reset password
        </Button>
      </form>
    </AuthCard>
  );
};

export default ResetPassword;
