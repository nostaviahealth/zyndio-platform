import React, { useEffect, useState } from 'react';
import { useLocation, useNavigate } from 'react-router-dom';
import { supabase } from '../../lib/supabase';
import AuthCard from '../../components/admin-auth/AuthCard';
import CodeInput from '../../components/admin-auth/CodeInput';
import Button from '../../components/admin-auth/Button';
import { usePortalAuth } from '../../contexts/PortalAuthContext';

type View = 'challenge' | 'locked' | 'expired';

const TwoFactorChallenge: React.FC = () => {
  const { challengeTotp, verifyTotpChallenge, email } = usePortalAuth();
  const navigate = useNavigate();
  const location = useLocation() as { state?: { locked?: boolean } };
  const [view, setView] = useState<View>(location.state?.locked ? 'locked' : 'challenge');
  const [factorId, setFactorId] = useState<string | null>(null);
  const [challengeId, setChallengeId] = useState<string | null>(null);
  const [code, setCode] = useState('');
  const [verifying, setVerifying] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [attemptsRemaining, setAttemptsRemaining] = useState<number | null>(null);

  useEffect(() => {
    if (view !== 'challenge') return;
    supabase.auth.mfa.listFactors().then(async ({ data }) => {
      const totp = data?.totp?.[0];
      if (!totp) return;
      setFactorId(totp.id);
      const { challengeId: cid } = await challengeTotp(totp.id);
      setChallengeId(cid);
    });
  }, [view, challengeTotp]);

  const handleVerify = async (value: string) => {
    if (!factorId || !challengeId) return;
    setVerifying(true);
    setError(null);
    try {
      const result = await verifyTotpChallenge(factorId, challengeId, value);
      if (result.ok) {
        navigate('/admin');
        return;
      }
      if (result.error === 'locked') {
        setView('locked');
        return;
      }
      if (result.error === 'challenge_expired') {
        setView('expired');
        return;
      }
      setCode('');
      setError("That code didn't work. Try again.");
    } finally {
      setVerifying(false);
    }
  };

  if (view === 'locked') {
    return (
      <AuthCard>
        <h1 className="text-2xl font-bold text-slate-900">Sign-in is paused</h1>
        <p className="mt-2 text-sm text-slate-600">
          Too many wrong codes. To protect patient information, sign-in for this account is paused for 15 minutes.
        </p>
        <p className="mt-2 text-sm text-slate-600">
          If you need access sooner, ask your Zyndio admin.
        </p>
        <p className="mt-2 text-sm text-slate-600">Recovery codes are paused too, so nobody can keep guessing.</p>
        <Button variant="outline" className="mt-6 w-full" onClick={() => navigate('/admin/login')}>
          Back to sign-in
        </Button>
      </AuthCard>
    );
  }

  if (view === 'expired') {
    return (
      <AuthCard>
        <h1 className="text-2xl font-bold text-slate-900">Please start again</h1>
        <p className="mt-2 text-sm text-slate-600">
          You need to enter your code within 10 minutes of entering your password. For your security, we&apos;ve
          cleared this attempt.
        </p>
        <Button className="mt-6 w-full" onClick={() => navigate('/admin/login')}>
          Sign in again
        </Button>
      </AuthCard>
    );
  }

  return (
    <AuthCard>
      <h1 className="text-2xl font-bold text-slate-900">Enter your verification code</h1>
      <p className="mt-2 text-sm text-slate-600">
        Open your authenticator app and enter the 6-digit code for Zyndio {email ? `(${email})` : ''}.
      </p>
      <div className="mt-6">
        <CodeInput
          label="6-digit code"
          value={code}
          onChange={setCode}
          onComplete={handleVerify}
          error={!!error}
          disabled={verifying}
          autoFocus
        />
      </div>
      {error && (
        <p role="alert" className="mt-3 text-sm text-red-600">
          {error}
          {attemptsRemaining != null && ` You have ${attemptsRemaining} attempts left before sign-in pauses for 15 minutes.`}
        </p>
      )}
      <p className="mt-3 text-xs text-slate-500">Paste works. You have 10 minutes to finish signing in.</p>
      <Button className="mt-6 w-full" busy={verifying} busyLabel="Verifying" onClick={() => handleVerify(code)}>
        Verify
      </Button>
      <div className="mt-4 flex justify-between text-sm">
        <button type="button" className="min-h-[44px] text-[#2C5CF2]" onClick={() => navigate('/admin/2fa/recovery')}>
          Use a recovery code
        </button>
        <button type="button" className="min-h-[44px] text-[#2C5CF2]" onClick={() => navigate('/admin/login')}>
          Sign in as someone else
        </button>
      </div>
    </AuthCard>
  );
};

export default TwoFactorChallenge;
