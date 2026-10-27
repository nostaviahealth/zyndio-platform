import { describe, it, expect } from 'vitest';
import { mapConsumeRecoveryCodeResult } from '../../lib/recoveryCodeResult';

describe('consume_recovery_code RPC contract (H-E2E-2)', () => {
  it('accepts the real RPC success payload { status: "ok", must_reenrol: true }', () => {
    // This is exactly what consume_recovery_code() returns on a valid unused code.
    // Before the fix, PortalAuthContext checked decision === 'accepted' and always rejected.
    expect(mapConsumeRecoveryCodeResult({ status: 'ok', must_reenrol: true })).toEqual({ ok: true });
  });

  it('maps status locked to locked', () => {
    expect(mapConsumeRecoveryCodeResult({ status: 'locked' })).toEqual({ ok: false, error: 'locked' });
  });

  it('maps status invalid (and anything else) to wrong_code', () => {
    expect(mapConsumeRecoveryCodeResult({ status: 'invalid' })).toEqual({ ok: false, error: 'wrong_code' });
    expect(mapConsumeRecoveryCodeResult({ decision: 'accepted' })).toEqual({ ok: false, error: 'wrong_code' });
    expect(mapConsumeRecoveryCodeResult(null)).toEqual({ ok: false, error: 'wrong_code' });
  });
});
