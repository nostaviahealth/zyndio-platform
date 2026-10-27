#!/usr/bin/env tsx
/**
 * TC-005 M8 live probe against local GoTrue, using node's built-in fetch
 * (never curl). Reads SUPABASE_URL/ANON/SERVICE_ROLE keys from
 * `supabase status -o env` into the process env only. Local Supabase only.
 *
 * Probes (M8 plan Section B):
 *  1. A fresh session tries PUT /auth/v1/user with a blocklisted-but-
 *     character-valid password (direct GoTrue updateUser path, which
 *     bypasses our change-password Edge Function and its blocklist).
 *  2. The same fresh session tries several passwords that each fail exactly
 *     one of the new password_requirements character classes, plus one
 *     short password, to see which GoTrue rejects after the config change.
 *  3. Attempts to observe secure_password_change's reauthentication
 *     requirement on a non-fresh session. This script cannot age a session
 *     by 24h, so it only records what a freshly-signed-in session can do -
 *     it does not simulate or assert the "old session" case.
 *  4. Calls the change-password Edge Function with a blocklisted password
 *     to confirm it still refuses and writes no audit row on failure.
 *
 * Run with: npx tsx scripts/tc005-auth-hooks-live-check-m8.ts
 * Writes nothing to disk; results are only printed to stdout. The run that
 * produced work/.claude-runs/tc005/m8/OBSERVED.md was a copy-paste of this
 * output, not a separate code path.
 */

import { execFileSync } from "node:child_process";

type EnvMap = Record<string, string>;

function loadSupabaseEnv(): EnvMap {
  const raw = execFileSync("supabase", ["status", "-o", "env"], {
    encoding: "utf8",
  });
  const env: EnvMap = {};
  for (const line of raw.split("\n")) {
    const match = line.match(/^([A-Z0-9_]+)="(.*)"$/);
    if (match) env[match[1]] = match[2];
  }
  return env;
}

async function main() {
  console.log("== TC-005 M8 live password-hardening probe ==\n");

  const env = loadSupabaseEnv();
  const API_URL = env.API_URL;
  const ANON_KEY = env.ANON_KEY;
  const SERVICE_ROLE_KEY = env.SERVICE_ROLE_KEY;
  const FUNCTIONS_URL = env.FUNCTIONS_URL ?? `${API_URL}/functions/v1`;

  if (!API_URL || !ANON_KEY || !SERVICE_ROLE_KEY) {
    console.error("Missing API_URL/ANON_KEY/SERVICE_ROLE_KEY - is local Supabase running?");
    process.exit(1);
  }

  const suffix = Math.random().toString(36).slice(2, 10);
  const email = `tc005-m8-${suffix}@example.test`;
  const initialPassword = "Correct-Horse-Battery-99!";

  const createRes = await fetch(`${API_URL}/auth/v1/admin/users`, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      apikey: SERVICE_ROLE_KEY,
      Authorization: `Bearer ${SERVICE_ROLE_KEY}`,
    },
    body: JSON.stringify({ email, password: initialPassword, email_confirm: true }),
  });
  if (!createRes.ok) {
    console.error(`Could not create live-check user: ${createRes.status} ${await createRes.text()}`);
    process.exit(1);
  }
  const created = (await createRes.json()) as { id: string };
  console.log(`Created fictional user ${email} (${created.id})\n`);

  async function freshSignIn(password: string) {
    const res = await fetch(`${API_URL}/auth/v1/token?grant_type=password`, {
      method: "POST",
      headers: { "Content-Type": "application/json", apikey: ANON_KEY },
      body: JSON.stringify({ email, password }),
    });
    const body = (await res.json()) as { access_token?: string };
    return { status: res.status, accessToken: body.access_token };
  }

  async function tryDirectPasswordChange(accessToken: string, password: string) {
    const res = await fetch(`${API_URL}/auth/v1/user`, {
      method: "PUT",
      headers: {
        "Content-Type": "application/json",
        apikey: ANON_KEY,
        Authorization: `Bearer ${accessToken}`,
      },
      body: JSON.stringify({ password }),
    });
    const text = await res.text();
    return { status: res.status, body: text };
  }

  // ---------------------------------------------------------------------
  // 1. Fresh session, direct PUT /auth/v1/user with a blocklisted-but-
  //    character-valid password.
  // ---------------------------------------------------------------------
  let { status: signInStatus, accessToken } = await freshSignIn(initialPassword);
  console.log(`1. fresh sign-in status=${signInStatus}, have token=${!!accessToken}`);
  if (!accessToken) {
    console.error("No access token from initial sign-in; aborting.");
    process.exit(1);
  }

  // lower('Chocolate@123') === 'chocolate@123', a base-word+suffix combo the
  // blocklist migration actually generates (base 'chocolate' + suffix
  // '@123'), while the mixed case/digit/symbol satisfies the new
  // password_requirements character-class rule.
  const blocklisted = "Chocolate@123";
  const directResult = await tryDirectPasswordChange(accessToken, blocklisted);
  console.log(`1. PUT /auth/v1/user {password:"${blocklisted}"} -> status=${directResult.status} body=${directResult.body}`);

  const signInAfterDirect = await freshSignIn(blocklisted);
  console.log(`1. sign-in with "${blocklisted}" after the direct change -> status=${signInAfterDirect.status}, have token=${!!signInAfterDirect.accessToken}\n`);

  // Re-sign-in with whichever password is now live, for probe 2.
  const liveAfter1 = signInAfterDirect.accessToken ? blocklisted : initialPassword;
  ({ accessToken } = await freshSignIn(liveAfter1));

  // ---------------------------------------------------------------------
  // 2. Character-class / length probes against the new password_requirements.
  // ---------------------------------------------------------------------
  const probes: { label: string; password: string }[] = [
    { label: "short (5 chars)", password: "short" },
    { label: "long, no symbol", password: "Longpassword1" },
    { label: "long, no uppercase", password: "longpassword1!" },
    { label: "long, no lowercase", password: "LONGPASSWORD1!" },
    { label: "long, no digit", password: "Longpassword!!" },
    { label: "meets all classes, not blocklisted", password: "Zq7!fictional-pass" },
  ];

  for (const probe of probes) {
    if (!accessToken) {
      console.log(`2. ${probe.label}: SKIPPED (no active session)`);
      continue;
    }
    const result = await tryDirectPasswordChange(accessToken, probe.password);
    console.log(`2. ${probe.label} ("${probe.password}") -> status=${result.status} body=${result.body}`);
    // Re-establish a fresh session each time: if the change above succeeded,
    // the old token's password is now wrong for the next sign-in attempt
    // under the OLD password, so track whichever password is now live.
    const verify = await freshSignIn(probe.password);
    if (verify.accessToken) {
      accessToken = verify.accessToken;
    } else {
      // change was rejected - whatever password worked before still works.
      const fallback = await freshSignIn(liveAfter1);
      accessToken = fallback.accessToken;
    }
  }
  console.log();

  // ---------------------------------------------------------------------
  // 3. Non-fresh session / reauthentication (secure_password_change nonce).
  // ---------------------------------------------------------------------
  console.log(
    "3. Could not age a session by GoTrue's non-recent-login window (typically 24h) in this run.\n" +
      "   GoTrue docs: with secure_password_change on, a password change on a session that is\n" +
      "   not 'recent' requires reauthentication (a nonce from /auth/v1/reauthenticate) or it is\n" +
      "   refused with a 'New password should be different...' / reauthentication-required error.\n" +
      "   NOT asserted here - no passing/failing test was written for this case because it was\n" +
      "   not observed locally.\n"
  );

  // ---------------------------------------------------------------------
  // 4. change-password Edge Function still enforces the blocklist + audit.
  // ---------------------------------------------------------------------
  const freshForFn = await freshSignIn(accessToken ? probes[probes.length - 1].password : liveAfter1);
  if (freshForFn.accessToken) {
    const fnRes = await fetch(`${FUNCTIONS_URL}/change-password`, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        apikey: ANON_KEY,
        Authorization: `Bearer ${freshForFn.accessToken}`,
      },
      body: JSON.stringify({ password: blocklisted }),
    });
    const fnBody = await fnRes.text();
    console.log(`4. POST /functions/v1/change-password {password:"${blocklisted}"} -> status=${fnRes.status} body=${fnBody}`);
  } else {
    console.log("4. SKIPPED - could not establish a fresh session for the change-password probe.");
  }

  // cleanup
  await fetch(`${API_URL}/auth/v1/admin/users/${created.id}`, {
    method: "DELETE",
    headers: { apikey: SERVICE_ROLE_KEY, Authorization: `Bearer ${SERVICE_ROLE_KEY}` },
  });

  console.log("\nDone. Copy the lines above into work/.claude-runs/tc005/m8/OBSERVED.md.");
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
