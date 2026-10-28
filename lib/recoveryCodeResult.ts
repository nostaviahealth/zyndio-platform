// Maps consume_recovery_code() RPC payload to the client ChallengeResult shape.
// RPC contract (migrations 20261026130000 / …60300):
//   { status: 'ok', must_reenrol: true } | { status: 'locked' } | { status: 'invalid' }
// The client historically checked `decision === 'accepted'` (H-E2E-2) — that
// never matched the RPC, so every valid recovery code was rejected in the UI.

export type RecoveryCodeClientResult =
  | { ok: true }
  | { ok: false; error: 'wrong_code' | 'locked' };

export function mapConsumeRecoveryCodeResult(data: unknown): RecoveryCodeClientResult {
  if (!data || typeof data !== 'object') return { ok: false, error: 'wrong_code' };
  const status = (data as { status?: unknown }).status;
  if (status === 'locked') return { ok: false, error: 'locked' };
  if (status === 'ok') return { ok: true };
  return { ok: false, error: 'wrong_code' };
}
