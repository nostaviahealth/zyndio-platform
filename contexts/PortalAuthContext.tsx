import React, { createContext, useCallback, useContext, useEffect, useRef, useState } from 'react';
import { supabase } from '../lib/supabase';
import { mapConsumeRecoveryCodeResult } from '../lib/recoveryCodeResult';

export type PortalStatus = 'loading' | 'signed_out' | 'aal1' | 'aal2';

export interface PortalAuthState {
  status: PortalStatus;
  email: string | null;
  role: string | null;
  orgId: string | null;
  hasFactor: boolean;
  // Set when a SIGNED_OUT event arrives that wasn't preceded by this tab's
  // own signOut() call - i.e. an admin deactivated/reset/role-changed the
  // account (or another tab signed out globally) and a token refresh then
  // failed. Drives the session-expired vs session-ended-by-admin fork.
  endedByAdmin: boolean;
}

interface SignInResult {
  ok: boolean;
  locked?: boolean;
  unlocksAt?: string | null;
  error?: 'invalid_credentials' | 'network_error';
  // Present when ok: true. Drives post-password routing to challenge vs setup (H-E2E-1).
  hasFactor?: boolean;
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
  changePassword: (password: string) => Promise<{ ok: boolean; error?: string }>;
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
    endedByAdmin: false,
  });
  const explicitSignOutRef = useRef(false);

  // Reads the session, AAL and the caller's ACTIVE staff membership, sets
  // state, and returns what it set so signIn can act on it (TC-022 #1).
  const load = useCallback(async (): Promise<{ signedIn: boolean; role: string | null }> => {
    const { data } = await supabase.auth.getSession();
    const session = data.session;
    if (!session) {
      setState((prev) => ({
        status: 'signed_out',
        email: null,
        role: null,
        orgId: null,
        hasFactor: false,
        endedByAdmin: prev.endedByAdmin,
      }));
      return { signedIn: false, role: null };
    }

    const { data: aalData } = await supabase.auth.mfa.getAuthenticatorAssuranceLevel();
    const hasFactor = (aalData?.currentLevel === 'aal2' || aalData?.nextLevel === 'aal2') ?? false;
    const status: PortalStatus = aalData?.currentLevel === 'aal2' ? 'aal2' : 'aal1';

    // TC-018 (29 Oct): a staff member can hold more than one active
    // membership. .maybeSingle() errors on 2+ rows, so list and order
    // instead; the earliest-created membership is the default until a
    // clinic picker ships as a follow-up.
    const { data: members } = await supabase
      .from('org_members')
      .select('role, org_id')
      .eq('user_id', session.user.id)
      // TC-022 #1: an invited or deactivated row is not staff access.
      .eq('status', 'active')
      .order('created_at', { ascending: true });

    const member = (members as { role: string; org_id: string }[] | null)?.[0];
    const role = (member?.role as string | undefined) ?? null;
    setState({
      status,
      email: session.user.email ?? null,
      role,
      orgId: (member?.org_id as string | undefined) ?? null,
      hasFactor,
      endedByAdmin: false,
    });
    return { signedIn: true, role };
  }, []);

  const refresh = useCallback(async () => {
    await load();
  }, [load]);

  useEffect(() => {
    refresh();
    const { data: sub } = supabase.auth.onAuthStateChange((event) => {
      if (event === 'SIGNED_OUT' && !explicitSignOutRef.current) {
        setState((prev) => ({ ...prev, endedByAdmin: true }));
      }
      explicitSignOutRef.current = false;
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
      const loaded = await load();
      if (!loaded.role) {
        // TC-022 #1: correct password but no ACTIVE staff membership (a
        // deactivated member, or a patient account on the staff portal).
        // End the half-open session and answer exactly like a wrong
        // password, so membership status can't be probed (OVERRIDES #5).
        explicitSignOutRef.current = true;
        await supabase.auth.signOut();
        await load();
        return { ok: false, error: 'invalid_credentials' };
      }
      const { data: aalData } = await supabase.auth.mfa.getAuthenticatorAssuranceLevel();
      const hasFactor = (aalData?.currentLevel === 'aal2' || aalData?.nextLevel === 'aal2') ?? false;
      return { ok: true, hasFactor };
    } catch (err) {
      if (isNetworkError(err)) return { ok: false, error: 'network_error' };
      return { ok: false, error: 'invalid_credentials' };
    }
  }, [load]);

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

  // B2 (M3)/rule 7: the only sanctioned self-service password-set path once
  // a session exists (recovery link or already signed in) - shared by
  // reset-password and change-password so both get the blocklist check and
  // audit log that only the change-password edge function provides.
  const changePassword = useCallback(async (password: string) => {
    const { data, error } = await supabase.functions.invoke('change-password', {
      body: { password },
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
      // H-E2E-2: RPC returns { status: 'ok' | 'locked' | 'invalid' }, not decision.
      const mapped = mapConsumeRecoveryCodeResult(data);
      if (!mapped.ok) return { ok: false, error: mapped.error };
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
    explicitSignOutRef.current = true;
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
        changePassword,
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
