import React, { createContext, useCallback, useContext, useEffect, useState } from 'react';
import { supabase } from '../lib/supabase';

export type PortalStatus = 'loading' | 'signed_out' | 'aal1' | 'aal2';

export interface PortalAuthState {
  status: PortalStatus;
  email: string | null;
  role: string | null;
  orgId: string | null;
  hasFactor: boolean;
}

interface SignInResult {
  ok: boolean;
  locked?: boolean;
  unlocksAt?: string | null;
  error?: 'invalid_credentials' | 'network_error';
}

interface ChallengeResult {
  ok: boolean;
  error?: 'wrong_code' | 'locked' | 'challenge_expired' | 'network_error';
  attemptsRemaining?: number;
}

interface PortalAuthContextType extends PortalAuthState {
  refresh: () => Promise<void>;
  signIn: (email: string, password: string) => Promise<SignInResult>;
  requestPasswordReset: (email: string) => Promise<{ ok: boolean; networkError?: boolean }>;
  acceptInvite: (token: string, password: string) => Promise<{ ok: boolean; error?: string }>;
  enrollTotp: () => Promise<{ factorId: string; qrCode: string; secret: string }>;
  verifyTotpEnrollment: (factorId: string, code: string) => Promise<ChallengeResult>;
  challengeTotp: (factorId: string) => Promise<{ challengeId: string }>;
  verifyTotpChallenge: (factorId: string, challengeId: string, code: string) => Promise<ChallengeResult>;
  verifyRecoveryCode: (code: string) => Promise<ChallengeResult>;
  generateRecoveryCodes: () => Promise<string[]>;
  signOut: () => Promise<void>;
}

const PortalAuthContext = createContext<PortalAuthContextType | undefined>(undefined);

// A wrong password/code and an unknown email must never be distinguishable
// (OVERRIDES #5) - this is the single generic message used everywhere on
// 01-sign-in and 03-2fa-challenge for anything that isn't the one
// deliberately-distinguishable "locked" response.
export const GENERIC_SIGNIN_ERROR = "That email and password don't match. Check both and try again.";
export const NETWORK_ERROR_MESSAGE =
  "We can't reach the portal right now. Check your connection and try again. Nothing you typed was sent.";

function isNetworkError(err: unknown): boolean {
  return err instanceof TypeError || (err instanceof Error && /fetch|network/i.test(err.message));
}

export const PortalAuthProvider: React.FC<{ children: React.ReactNode }> = ({ children }) => {
  const [state, setState] = useState<PortalAuthState>({
    status: 'loading',
    email: null,
    role: null,
    orgId: null,
    hasFactor: false,
  });

  const refresh = useCallback(async () => {
    const { data } = await supabase.auth.getSession();
    const session = data.session;
    if (!session) {
      setState({ status: 'signed_out', email: null, role: null, orgId: null, hasFactor: false });
      return;
    }

    const { data: aalData } = await supabase.auth.mfa.getAuthenticatorAssuranceLevel();
    const hasFactor = (aalData?.currentLevel === 'aal2' || aalData?.nextLevel === 'aal2') ?? false;
    const status: PortalStatus = aalData?.currentLevel === 'aal2' ? 'aal2' : 'aal1';

    const { data: member } = await supabase
      .from('org_members')
      .select('role, org_id')
      .eq('user_id', session.user.id)
      .maybeSingle();

    setState({
      status,
      email: session.user.email ?? null,
      role: (member?.role as string | undefined) ?? null,
      orgId: (member?.org_id as string | undefined) ?? null,
      hasFactor,
    });
  }, []);

  useEffect(() => {
    refresh();
    const { data: sub } = supabase.auth.onAuthStateChange(() => {
      refresh();
    });
    return () => sub.subscription.unsubscribe();
  }, [refresh]);

  const signIn = useCallback(async (email: string, password: string): Promise<SignInResult> => {
    try {
      const { error } = await supabase.auth.signInWithPassword({ email, password });
      if (error) {
        // The hook rejects with exactly "locked" only on a *correct*
        // password against an already-locked account - the one boundary
        // allowed to be distinguishable (OVERRIDES #5 / specs.md 03/locked).
        if (error.message === 'locked') {
          return { ok: false, locked: true };
        }
        return { ok: false, error: 'invalid_credentials' };
      }
      await refresh();
      return { ok: true };
    } catch (err) {
      if (isNetworkError(err)) return { ok: false, error: 'network_error' };
      return { ok: false, error: 'invalid_credentials' };
    }
  }, [refresh]);

  const requestPasswordReset = useCallback(async (email: string) => {
    try {
      // Response is intentionally ignored for success/failure branching -
      // the UI always shows the same "check your email" copy regardless of
      // whether the account exists (OVERRIDES #5).
      await supabase.auth.resetPasswordForEmail(email, {
        redirectTo: `${window.location.origin}/#/admin/reset-password`,
      });
      return { ok: true };
    } catch (err) {
      if (isNetworkError(err)) return { ok: false, networkError: true };
      return { ok: true };
    }
  }, []);

  const acceptInvite = useCallback(async (token: string, password: string) => {
    const { data, error } = await supabase.functions.invoke('accept-invite', {
      body: { token, password },
    });
    if (error) return { ok: false, error: 'internal_error' };
    if (data?.error) return { ok: false, error: data.error as string };
    return { ok: true };
  }, []);

  const enrollTotp = useCallback(async () => {
    const { data, error } = await supabase.auth.mfa.enroll({ factorType: 'totp', issuer: 'Zyndio' });
    if (error || !data) throw error ?? new Error('enroll failed');
    return { factorId: data.id, qrCode: data.totp.qr_code, secret: data.totp.secret };
  }, []);

  const challengeTotp = useCallback(async (factorId: string) => {
    const { data, error } = await supabase.auth.mfa.challenge({ factorId });
    if (error || !data) throw error ?? new Error('challenge failed');
    return { challengeId: data.id };
  }, []);

  const mapVerifyError = (message: string | undefined): ChallengeResult['error'] => {
    if (message === 'locked') return 'locked';
    if (message === 'challenge_expired') return 'challenge_expired';
    return 'wrong_code';
  };

  const verifyTotpEnrollment = useCallback(
    async (factorId: string, code: string): Promise<ChallengeResult> => {
      try {
        const { data: challenge, error: challengeError } = await supabase.auth.mfa.challenge({ factorId });
        if (challengeError || !challenge) return { ok: false, error: mapVerifyError(challengeError?.message) };
        const { error } = await supabase.auth.mfa.verify({ factorId, challengeId: challenge.id, code });
        if (error) return { ok: false, error: mapVerifyError(error.message) };
        await refresh();
        return { ok: true };
      } catch (err) {
        if (isNetworkError(err)) return { ok: false, error: 'wrong_code' };
        return { ok: false, error: 'wrong_code' };
      }
    },
    [refresh]
  );

  const verifyTotpChallenge = useCallback(
    async (factorId: string, challengeId: string, code: string): Promise<ChallengeResult> => {
      const { error } = await supabase.auth.mfa.verify({ factorId, challengeId, code });
      if (error) return { ok: false, error: mapVerifyError(error.message) };
      await refresh();
      return { ok: true };
    },
    [refresh]
  );

  const verifyRecoveryCode = useCallback(
    async (code: string): Promise<ChallengeResult> => {
      const { data, error } = await supabase.rpc('consume_recovery_code', { p_code: code });
      if (error) return { ok: false, error: 'wrong_code' };
      const result = data as { decision?: string } | null;
      if (result?.decision === 'locked') return { ok: false, error: 'locked' };
      if (result?.decision !== 'accepted') return { ok: false, error: 'wrong_code' };
      // Henry's ruling: a recovery code never grants aal2 by itself - the
      // caller must immediately re-enrol an authenticator (straight to
      // 02-2fa-setup, no "remind me later").
      await supabase.functions.invoke('recovery-reenrol', { body: {} });
      await refresh();
      return { ok: true };
    },
    [refresh]
  );

  const generateRecoveryCodes = useCallback(async () => {
    const { data, error } = await supabase.rpc('generate_recovery_codes');
    if (error || !data) throw error ?? new Error('could not generate recovery codes');
    return data as string[];
  }, []);

  const signOut = useCallback(async () => {
    await supabase.auth.signOut();
    await refresh();
  }, [refresh]);

  return (
    <PortalAuthContext.Provider
      value={{
        ...state,
        refresh,
        signIn,
        requestPasswordReset,
        acceptInvite,
        enrollTotp,
        verifyTotpEnrollment,
        challengeTotp,
        verifyTotpChallenge,
        verifyRecoveryCode,
        generateRecoveryCodes,
        signOut,
      }}
    >
      {children}
    </PortalAuthContext.Provider>
  );
};

export const usePortalAuth = () => {
  const ctx = useContext(PortalAuthContext);
  if (!ctx) throw new Error('usePortalAuth must be used within a PortalAuthProvider');
  return ctx;
};
