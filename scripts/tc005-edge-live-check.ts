#!/usr/bin/env tsx
/**
 * TC-005 step 3 live checks for the Edge Functions, using node's built-in
 * fetch. Reads SUPABASE_URL/ANON/SERVICE_ROLE/FUNCTIONS keys from
 * `supabase status -o env` into the process env only. Local Supabase +
 * `supabase functions serve` only - never touches a hosted project.
 *
 * Run with:
 *   supabase functions serve --no-verify-jwt &
 *   npx tsx scripts/tc005-edge-live-check.ts
 *
 * This is the basis for step 4's vitest integration tests (plan Section E).
 */

import { execFileSync } from "node:child_process";
import crypto from "node:crypto";

type EnvMap = Record<string, string>;

function loadSupabaseEnv(): EnvMap {
  const raw = execFileSync("supabase", ["status", "-o", "env"], { encoding: "utf8" });
  const env: EnvMap = {};
  for (const line of raw.split("\n")) {
    const match = line.match(/^([A-Z0-9_]+)="(.*)"$/);
    if (match) env[match[1]] = match[2];
  }
  return env;
}

function decodeJwtPayload(token: string): Record<string, unknown> {
  const parts = token.split(".");
  if (parts.length !== 3) throw new Error("not a JWT");
  const payload = Buffer.from(parts[1].replace(/-/g, "+").replace(/_/g, "/"), "base64").toString("utf8");
  return JSON.parse(payload);
}

// --- minimal RFC 6238 TOTP so this script can complete a real enrollment
// round-trip against local GoTrue without any extra dependency. ---
function base32Decode(input: string): Buffer {
  const alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZ234567";
  let bits = "";
  for (const char of input.toUpperCase().replace(/=+$/, "")) {
    const idx = alphabet.indexOf(char);
    if (idx === -1) continue;
    bits += idx.toString(2).padStart(5, "0");
  }
  const bytes: number[] = [];
  for (let i = 0; i + 8 <= bits.length; i += 8) bytes.push(parseInt(bits.slice(i, i + 8), 2));
  return Buffer.from(bytes);
}

function totpCode(base32Secret: string, atMs = Date.now()): string {
  const key = base32Decode(base32Secret);
  const counter = Math.floor(atMs / 1000 / 30);
  const counterBuffer = Buffer.alloc(8);
  counterBuffer.writeBigUInt64BE(BigInt(counter));
  const hmac = crypto.createHmac("sha1", key).update(counterBuffer).digest();
  const offset = hmac[hmac.length - 1] & 0xf;
  const binCode =
    ((hmac[offset] & 0x7f) << 24) |
    ((hmac[offset + 1] & 0xff) << 16) |
    ((hmac[offset + 2] & 0xff) << 8) |
    (hmac[offset + 3] & 0xff);
  return (binCode % 1_000_000).toString().padStart(6, "0");
}

async function main() {
  console.log("== TC-005 step 3 live edge-function checks ==\n");

  const env = loadSupabaseEnv();
  const { API_URL, ANON_KEY, SERVICE_ROLE_KEY, FUNCTIONS_URL } = env;
  if (!API_URL || !ANON_KEY || !SERVICE_ROLE_KEY || !FUNCTIONS_URL) {
    console.error("Missing API_URL/ANON_KEY/SERVICE_ROLE_KEY/FUNCTIONS_URL - is local Supabase running?");
    process.exit(1);
  }

  const results: { name: string; pass: boolean; detail?: string }[] = [];
  const record = (name: string, pass: boolean, detail?: string) => {
    results.push({ name, pass, detail });
    console.log(`${pass ? "PASS" : "FAIL"} - ${name}${detail ? ` (${detail})` : ""}`);
  };

  const suffix = Math.random().toString(36).slice(2, 10);
  const cleanupUserIds: string[] = [];

  // ---------------------------------------------------------------------
  // helpers
  // ---------------------------------------------------------------------
  const adminFetch = (path: string, init: RequestInit = {}) =>
    fetch(`${API_URL}/auth/v1/${path}`, {
      ...init,
      headers: { "Content-Type": "application/json", apikey: SERVICE_ROLE_KEY, Authorization: `Bearer ${SERVICE_ROLE_KEY}`, ...init.headers },
    });

  const restAdmin = (path: string, init: RequestInit = {}) =>
    fetch(`${API_URL}/rest/v1/${path}`, {
      ...init,
      headers: {
        "Content-Type": "application/json",
        apikey: SERVICE_ROLE_KEY,
        Authorization: `Bearer ${SERVICE_ROLE_KEY}`,
        Prefer: "return=representation",
        ...init.headers,
      },
    });

  const callFn = (name: string, token: string, body?: unknown) =>
    fetch(`${FUNCTIONS_URL}/${name}`, {
      method: "POST",
      headers: { "Content-Type": "application/json", apikey: ANON_KEY, Authorization: `Bearer ${token}` },
      body: body === undefined ? undefined : JSON.stringify(body),
    });

  async function createOrgAndMember(role: string, status = "active") {
    const email = `tc005-live-${role}-${suffix}-${Math.random().toString(36).slice(2, 6)}@example.test`;
    const password = "Correct-Horse-Battery-99!";
    const createRes = await adminFetch("admin/users", {
      method: "POST",
      body: JSON.stringify({ email, password, email_confirm: true }),
    });
    const created = (await createRes.json()) as { id: string };
    cleanupUserIds.push(created.id);

    const orgRes = await restAdmin("organizations", {
      method: "POST",
      body: JSON.stringify({ name: `Live-check org ${suffix}-${role}` }),
    });
    const [org] = (await orgRes.json()) as { id: string }[];

    await restAdmin("org_members", {
      method: "POST",
      body: JSON.stringify({ user_id: created.id, org_id: org.id, role, status }),
    });

    return { userId: created.id, orgId: org.id, email, password };
  }

  async function signIn(email: string, password: string) {
    const res = await fetch(`${API_URL}/auth/v1/token?grant_type=password`, {
      method: "POST",
      headers: { "Content-Type": "application/json", apikey: ANON_KEY },
      body: JSON.stringify({ email, password }),
    });
    return (await res.json()) as { access_token?: string; refresh_token?: string };
  }

  // Enrolls + verifies a TOTP factor for an aal1 session, returning the
  // resulting aal2 access token and the factor's base32 secret.
  async function enrollAndVerifyTotp(aal1Token: string) {
    const enrollRes = await fetch(`${API_URL}/auth/v1/factors`, {
      method: "POST",
      headers: { "Content-Type": "application/json", apikey: ANON_KEY, Authorization: `Bearer ${aal1Token}` },
      body: JSON.stringify({ factor_type: "totp" }),
    });
    const enrolled = (await enrollRes.json()) as { id: string; totp: { secret: string } };

    const challengeRes = await fetch(`${API_URL}/auth/v1/factors/${enrolled.id}/challenge`, {
      method: "POST",
      headers: { "Content-Type": "application/json", apikey: ANON_KEY, Authorization: `Bearer ${aal1Token}` },
    });
    const challenge = (await challengeRes.json()) as { id: string };

    const code = totpCode(enrolled.totp.secret);
    const verifyRes = await fetch(`${API_URL}/auth/v1/factors/${enrolled.id}/verify`, {
      method: "POST",
      headers: { "Content-Type": "application/json", apikey: ANON_KEY, Authorization: `Bearer ${aal1Token}` },
      body: JSON.stringify({ challenge_id: challenge.id, code }),
    });
    const verified = (await verifyRes.json()) as { access_token?: string };
    return { aal2Token: verified.access_token, factorId: enrolled.id, secret: enrolled.totp.secret };
  }

  // ---------------------------------------------------------------------
  // Bootstrap: an org_admin, elevated to aal2.
  // ---------------------------------------------------------------------
  const admin = await createOrgAndMember("org_admin");
  const adminAal1 = await signIn(admin.email, admin.password);
  if (!adminAal1.access_token) {
    console.error("Could not sign in bootstrap org_admin");
    process.exit(1);
  }

  record("(a) admin_created org_admin signs in at aal1", decodeJwtPayload(adminAal1.access_token).aal === "aal1");

  const { aal2Token: adminAal2Token } = await enrollAndVerifyTotp(adminAal1.access_token);
  record("(b) org_admin reaches aal2 after real TOTP enroll+verify", !!adminAal2Token && decodeJwtPayload(adminAal2Token!).aal === "aal2");

  // ---------------------------------------------------------------------
  // (c) aal1 admin -> 403 on an admin function
  // ---------------------------------------------------------------------
  const aal1CallRes = await callFn("invite-user", adminAal1.access_token, {
    email: `tc005-live-invitee-${suffix}@example.test`,
    role: "physician",
  });
  record("(c) aal1 admin caller is rejected with 403", aal1CallRes.status === 403, `status=${aal1CallRes.status}`);

  // ---------------------------------------------------------------------
  // (d) non-admin caller -> 403
  // ---------------------------------------------------------------------
  const physician = await createOrgAndMember("physician");
  const physicianAal1 = await signIn(physician.email, physician.password);
  const { aal2Token: physicianAal2Token } = await enrollAndVerifyTotp(physicianAal1.access_token!);
  const nonAdminCallRes = await callFn("invite-user", physicianAal2Token!, {
    email: `tc005-live-invitee2-${suffix}@example.test`,
    role: "physician",
  });
  record("(d) non-admin (physician) caller is rejected with 403", nonAdminCallRes.status === 403, `status=${nonAdminCallRes.status}`);

  // ---------------------------------------------------------------------
  // (e)-(h) invite -> accept (bad password refused, good one accepted) -> sign in
  // ---------------------------------------------------------------------
  const inviteeEmail = `tc005-live-invitee-${suffix}@example.test`;
  const inviteRes = await callFn("invite-user", adminAal2Token!, { email: inviteeEmail, role: "physician" });
  const inviteBody = await inviteRes.json();
  record("(e) invite-user succeeds for org_admin caller", inviteRes.status === 200 && inviteBody.status === "ok", `status=${inviteRes.status}`);

  const notifRes = await restAdmin(
    `notification_outbox?type=eq.invite&payload->>email=eq.${encodeURIComponent(inviteeEmail)}&order=created_at.desc&limit=1`
  );
  const [notifRow] = (await notifRes.json()) as { payload: { token: string } }[];
  record("(f) invite-user wrote a notification_outbox row carrying the token", !!notifRow?.payload?.token);

  const auditInviteRes = await restAdmin(`audit_log?event_type=eq.invite_sent&metadata->>email=eq.${encodeURIComponent(inviteeEmail)}`);
  const auditInviteRows = (await auditInviteRes.json()) as unknown[];
  record("(g) invite-user wrote an audit_log row", Array.isArray(auditInviteRows) && auditInviteRows.length === 1);

  const token = notifRow?.payload?.token;
  const acceptBadRes = await fetch(`${FUNCTIONS_URL}/accept-invite`, {
    method: "POST",
    headers: { "Content-Type": "application/json", apikey: ANON_KEY },
    body: JSON.stringify({ token, password: "password1234" }), // >= 12 chars but on the common-password blocklist
  });
  const acceptBadBody = await acceptBadRes.json();
  record(
    "(h) accept-invite refuses a blocklisted password",
    acceptBadRes.status === 400 && acceptBadBody.error === "password_too_common",
    `status=${acceptBadRes.status} error=${acceptBadBody.error}`
  );

  const inviteePassword = "Zy-Live-Check-Strong-Pw-77!";
  const acceptGoodRes = await fetch(`${FUNCTIONS_URL}/accept-invite`, {
    method: "POST",
    headers: { "Content-Type": "application/json", apikey: ANON_KEY },
    body: JSON.stringify({ token, password: inviteePassword }),
  });
  const acceptGoodBody = await acceptGoodRes.json();
  record("(i) accept-invite accepts a good password", acceptGoodRes.status === 200 && acceptGoodBody.status === "ok", `status=${acceptGoodRes.status}`);

  const inviteeSignIn = await signIn(inviteeEmail, inviteePassword);
  record("(j) the invitee can sign in with their chosen password", !!inviteeSignIn.access_token);
  if (inviteeSignIn.access_token) cleanupUserIds.push(decodeJwtPayload(inviteeSignIn.access_token).sub as string);

  // ---------------------------------------------------------------------
  // (k) same email, already a member -> identical generic ok response
  // (enumeration-safety: inviting an already-invited/active address looks
  // the same as a brand-new invite).
  // ---------------------------------------------------------------------
  const reinviteRes = await callFn("invite-user", adminAal2Token!, { email: admin.email, role: "physician" });
  const reinviteBody = await reinviteRes.json();
  record(
    "(k) inviting an already-active email returns the same generic ok body",
    reinviteRes.status === 200 && reinviteBody.status === "ok",
    `status=${reinviteRes.status}`
  );

  // ---------------------------------------------------------------------
  // (l) reset-mfa self -> 403
  // ---------------------------------------------------------------------
  const selfResetRes = await callFn("reset-mfa", adminAal2Token!, { target_user_id: admin.userId });
  const selfResetBody = await selfResetRes.json();
  record(
    "(l) reset-mfa rejects the caller's own user id with 403",
    selfResetRes.status === 403 && selfResetBody.error === "cannot_reset_own_mfa",
    `status=${selfResetRes.status}`
  );

  // ---------------------------------------------------------------------
  // (m) reset-mfa on another active member: enroll them a factor first,
  // reset, then confirm factor gone + audit + outbox + forced sign-out.
  // ---------------------------------------------------------------------
  const target = await createOrgAndMember("care_coordinator");
  const targetAal1 = await signIn(target.email, target.password);
  await enrollAndVerifyTotp(targetAal1.access_token!);
  // Re-attach target to the SAME org as the admin so requireOrgAdminActor's
  // same-org check passes (createOrgAndMember made its own org above).
  await restAdmin(`org_members?user_id=eq.${target.userId}`, {
    method: "PATCH",
    body: JSON.stringify({ org_id: admin.orgId }),
  });

  const resetRes = await callFn("reset-mfa", adminAal2Token!, { target_user_id: target.userId });
  const resetBody = await resetRes.json();
  record("(m) reset-mfa succeeds for an org_admin acting on another member", resetRes.status === 200 && resetBody.status === "ok", `status=${resetRes.status}`);

  const factorsRes = await adminFetch(`admin/users/${target.userId}`);
  const factorsBody = (await factorsRes.json()) as { factors?: unknown[] };
  record("(n) the target's TOTP factor is gone after reset-mfa", (factorsBody.factors ?? []).length === 0);

  const auditResetRes = await restAdmin(`audit_log?event_type=eq.mfa_reset&target_user_id=eq.${target.userId}`);
  record("(o) reset-mfa wrote an audit_log row", ((await auditResetRes.json()) as unknown[]).length === 1);

  const outboxResetRes = await restAdmin(`notification_outbox?type=eq.mfa_reset&user_id=eq.${target.userId}`);
  record("(p) reset-mfa wrote a notification_outbox row", ((await outboxResetRes.json()) as unknown[]).length === 1);

  const targetRefreshAfterReset = await fetch(`${API_URL}/auth/v1/token?grant_type=refresh_token`, {
    method: "POST",
    headers: { "Content-Type": "application/json", apikey: ANON_KEY },
    body: JSON.stringify({ refresh_token: targetAal1.refresh_token }),
  });
  record(
    "(q) the target's pre-reset refresh token no longer works (forced sign-out)",
    targetRefreshAfterReset.status !== 200,
    `status=${targetRefreshAfterReset.status}`
  );

  // ---------------------------------------------------------------------
  // (r)-(s) deactivate -> refresh fails; reactivate -> membership active again
  // ---------------------------------------------------------------------
  const deactivateRes = await callFn("deactivate-user", adminAal2Token!, { target_user_id: target.userId });
  record("(r) deactivate-user succeeds", deactivateRes.status === 200, `status=${deactivateRes.status}`);

  const memberAfterDeactivateRes = await restAdmin(`org_members?user_id=eq.${target.userId}&select=status`);
  const [memberAfterDeactivate] = (await memberAfterDeactivateRes.json()) as { status: string }[];
  record("(s) org_members.status is deactivated", memberAfterDeactivate?.status === "deactivated");

  const reactivateRes = await callFn("reactivate-user", adminAal2Token!, { target_user_id: target.userId });
  record("(t) reactivate-user succeeds", reactivateRes.status === 200, `status=${reactivateRes.status}`);

  const memberAfterReactivateRes = await restAdmin(`org_members?user_id=eq.${target.userId}&select=status`);
  const [memberAfterReactivate] = (await memberAfterReactivateRes.json()) as { status: string }[];
  record("(u) org_members.status is active again after reactivate-user", memberAfterReactivate?.status === "active");

  // ---------------------------------------------------------------------
  // (v) recovery-reenrol: only acts when mfa_reenrollment_required has a
  // row for the caller; removes the factor and audits re_enrolment_started.
  // ---------------------------------------------------------------------
  const recoveryUser = await createOrgAndMember("read_only");
  const recoveryAal1 = await signIn(recoveryUser.email, recoveryUser.password);
  const { aal2Token: recoveryAal2Token } = await enrollAndVerifyTotp(recoveryAal1.access_token!);

  // No pending flag yet: recovery-reenrol is a no-op and leaves the factor alone.
  const reenrolNoopRes = await fetch(`${FUNCTIONS_URL}/recovery-reenrol`, {
    method: "POST",
    headers: { "Content-Type": "application/json", apikey: ANON_KEY, Authorization: `Bearer ${recoveryAal2Token}` },
  });
  const reenrolNoopBody = await reenrolNoopRes.json();
  record("(w) recovery-reenrol is a no-op with no pending flag", reenrolNoopRes.status === 200 && reenrolNoopBody.reenrollment_required === false);

  const factorsBeforeRes = await adminFetch(`admin/users/${recoveryUser.userId}`);
  const factorsBefore = (await factorsBeforeRes.json()) as { factors?: unknown[] };
  record("(x) the factor survives the no-op call", (factorsBefore.factors ?? []).length === 1);

  // Generate recovery codes (aal2, self), sign in fresh to get an aal1
  // session, consume a code (sets mfa_reenrollment_required).
  // generate_recovery_codes() is SECURITY DEFINER keyed off auth.uid(), so
  // it must run as the user (their own token + the anon apikey), not
  // service_role.
  const codesResUser = await fetch(`${API_URL}/rest/v1/rpc/generate_recovery_codes`, {
    method: "POST",
    headers: { "Content-Type": "application/json", apikey: ANON_KEY, Authorization: `Bearer ${recoveryAal2Token}` },
    body: "{}",
  });
  const codes = (await codesResUser.json()) as string[];

  const recoveryFreshSignIn = await signIn(recoveryUser.email, recoveryUser.password);
  const consumeRes = await fetch(`${API_URL}/rest/v1/rpc/consume_recovery_code`, {
    method: "POST",
    headers: { "Content-Type": "application/json", apikey: ANON_KEY, Authorization: `Bearer ${recoveryFreshSignIn.access_token}` },
    body: JSON.stringify({ p_code: codes[0] }),
  });
  const consumeBody = await consumeRes.json();
  record("(y) consume_recovery_code accepts a fresh, valid code", consumeBody.status === "ok" && consumeBody.must_reenrol === true);

  const reenrolRes = await fetch(`${FUNCTIONS_URL}/recovery-reenrol`, {
    method: "POST",
    headers: { "Content-Type": "application/json", apikey: ANON_KEY, Authorization: `Bearer ${recoveryFreshSignIn.access_token}` },
  });
  const reenrolBody = await reenrolRes.json();
  record("(z) recovery-reenrol removes the factor when the flag is set", reenrolRes.status === 200 && reenrolBody.reenrollment_required === true);

  const factorsAfterRes = await adminFetch(`admin/users/${recoveryUser.userId}`);
  const factorsAfter = (await factorsAfterRes.json()) as { factors?: unknown[] };
  record("(aa) the factor is actually gone after recovery-reenrol", (factorsAfter.factors ?? []).length === 0);

  const auditReenrolRes = await restAdmin(`audit_log?event_type=eq.re_enrolment_started&target_user_id=eq.${recoveryUser.userId}`);
  record("(ab) recovery-reenrol wrote a re_enrolment_started audit row", ((await auditReenrolRes.json()) as unknown[]).length === 1);

  // ---------------------------------------------------------------------
  // cleanup
  // ---------------------------------------------------------------------
  for (const id of cleanupUserIds) {
    await adminFetch(`admin/users/${id}`, { method: "DELETE" });
  }
  await adminFetch(`admin/users/${physician.userId}`, { method: "DELETE" });
  await adminFetch(`admin/users/${target.userId}`, { method: "DELETE" });
  await adminFetch(`admin/users/${recoveryUser.userId}`, { method: "DELETE" });

  const allPass = results.every((r) => r.pass);
  console.log(`\n${allPass ? "ALL CHECKS PASSED" : "SOME CHECKS FAILED"} (${results.filter((r) => r.pass).length}/${results.length})`);
  process.exit(allPass ? 0 : 1);
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
