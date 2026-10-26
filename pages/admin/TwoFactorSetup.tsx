import React, { useEffect, useState } from 'react';
import { useNavigate } from 'react-router-dom';
import AuthCard from '../../components/admin-auth/AuthCard';
import StepIndicator from '../../components/admin-auth/StepIndicator';
import QrTile from '../../components/admin-auth/QrTile';
import CodeInput from '../../components/admin-auth/CodeInput';
import RecoveryCodeGrid from '../../components/admin-auth/RecoveryCodeGrid';
import Button from '../../components/admin-auth/Button';
import { usePortalAuth } from '../../contexts/PortalAuthContext';

type Step = 'scan' | 'manual-key' | 'verify' | 'recovery-codes' | 'complete';

const TwoFactorSetup: React.FC = () => {
  const { enrollTotp, verifyTotpEnrollment, generateRecoveryCodes } = usePortalAuth();
  const navigate = useNavigate();
  const [step, setStep] = useState<Step>('scan');
  const [enrollment, setEnrollment] = useState<{ factorId: string; qrCode: string; secret: string } | null>(null);
  const [code, setCode] = useState('');
  const [verifyError, setVerifyError] = useState<string | null>(null);
  const [verifying, setVerifying] = useState(false);
  const [codes, setCodes] = useState<string[]>([]);
  const [confirmedSaved, setConfirmedSaved] = useState(false);
  const [confirmError, setConfirmError] = useState(false);

  useEffect(() => {
    enrollTotp().then(setEnrollment).catch(() => setVerifyError('internal_error'));
  }, [enrollTotp]);

  const handleVerify = async (value: string) => {
    if (!enrollment) return;
    setVerifying(true);
    setVerifyError(null);
    try {
      const result = await verifyTotpEnrollment(enrollment.factorId, value);
      if (!result.ok) {
        setVerifyError(
          "That code didn't match. Wait for the next code in your app and try again. If it keeps failing, check your phone sets its time automatically."
        );
        setCode('');
        return;
      }
      const newCodes = await generateRecoveryCodes();
      setCodes(newCodes);
      setStep('recovery-codes');
    } finally {
      setVerifying(false);
    }
  };

  const handleFinish = () => {
    if (!confirmedSaved) {
      setConfirmError(true);
      return;
    }
    setStep('complete');
  };

  if (step === 'complete') {
    return (
      <AuthCard>
        <h1 className="text-2xl font-bold text-slate-900">Two-factor sign-in is on</h1>
        <p className="mt-2 text-sm text-slate-600">
          From now on you&apos;ll enter a code from your authenticator app each time you sign in. Keep your recovery
          codes somewhere safe.
        </p>
        <Button className="mt-6 w-full" onClick={() => navigate('/admin')}>
          Go to the portal
        </Button>
      </AuthCard>
    );
  }

  if (step === 'recovery-codes') {
    return (
      <AuthCard>
        <StepIndicator step={3} total={3} />
        <h1 className="text-2xl font-bold text-slate-900">Save your recovery codes</h1>
        <p className="mt-2 text-sm text-slate-600">
          If you lose your phone, each code lets you sign in once. We&apos;ll only show these codes now.
        </p>
        <div className="mt-4">
          <RecoveryCodeGrid codes={codes} />
        </div>
        <label className="mt-4 flex items-start gap-2 text-sm text-slate-700">
          <input
            type="checkbox"
            checked={confirmedSaved}
            onChange={(e) => {
              setConfirmedSaved(e.target.checked);
              if (e.target.checked) setConfirmError(false);
            }}
            className="mt-0.5 h-5 w-5"
          />
          I&apos;ve saved these codes somewhere safe
        </label>
        {confirmError && (
          <p role="alert" className="mt-2 text-sm text-red-600">
            Confirm you&apos;ve saved your codes to finish.
          </p>
        )}
        <Button className="mt-6 w-full" onClick={handleFinish}>
          Finish setup
        </Button>
      </AuthCard>
    );
  }

  if (step === 'verify') {
    return (
      <AuthCard>
        <StepIndicator step={2} total={3} />
        <h1 className="text-2xl font-bold text-slate-900">Enter the code from your app</h1>
        <p className="mt-2 text-sm text-slate-600">This confirms your app is set up correctly.</p>
        <div className="mt-6">
          <CodeInput
            label="6-digit code"
            value={code}
            onChange={setCode}
            onComplete={handleVerify}
            error={!!verifyError}
            disabled={verifying}
            autoFocus
          />
        </div>
        {verifyError && (
          <p role="alert" className="mt-3 text-sm text-red-600">
            {verifyError}
          </p>
        )}
        <p className="mt-3 text-xs text-slate-500">The code changes every 30 seconds. Enter the one showing now.</p>
        <Button className="mt-6 w-full" busy={verifying} onClick={() => handleVerify(code)}>
          Verify
        </Button>
        <button type="button" className="mt-3 min-h-[44px] text-sm text-[#2C5CF2]" onClick={() => setStep('scan')}>
          Back to QR code
        </button>
      </AuthCard>
    );
  }

  // scan / manual-key
  return (
    <AuthCard>
      <StepIndicator step={1} total={3} />
      <h1 className="text-2xl font-bold text-slate-900">Add Zyndio to your authenticator app</h1>
      <p className="mt-2 text-sm text-slate-600">
        Two-factor sign-in is required for everyone who can see patient information.
      </p>
      {step === 'scan' && enrollment && (
        <>
          <p className="mt-4 text-sm text-slate-600">Add an account and scan this code.</p>
          <div className="mt-4 flex justify-center">
            <QrTile qrCode={enrollment.qrCode} />
          </div>
          <button
            type="button"
            className="mt-4 min-h-[44px] text-sm text-[#2C5CF2]"
            onClick={() => setStep('manual-key')}
          >
            Can&apos;t scan? Enter a setup key instead
          </button>
        </>
      )}
      {step === 'manual-key' && enrollment && (
        <>
          <p className="mt-4 text-sm text-slate-600">
            In your authenticator app, choose to enter a key, then type these details.
          </p>
          <p className="mt-3 font-mono text-sm text-slate-900">{enrollment.secret}</p>
          <p className="mt-2 text-xs text-slate-500">
            Spaces don&apos;t matter. Keep this key private: anyone with it can make your codes.
          </p>
          <button type="button" className="mt-4 min-h-[44px] text-sm text-[#2C5CF2]" onClick={() => setStep('scan')}>
            Scan a QR code instead
          </button>
        </>
      )}
      <Button className="mt-6 w-full" onClick={() => setStep('verify')} disabled={!enrollment}>
        Next
      </Button>
    </AuthCard>
  );
};

export default TwoFactorSetup;
