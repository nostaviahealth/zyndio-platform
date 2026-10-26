#!/usr/bin/env tsx
/**
 * TC-005 step 2 live checks against local GoTrue, using node's built-in
 * fetch (never curl). Reads SUPABASE_URL/ANON/SERVICE_ROLE keys from
 * `supabase status -o env` into the process env only - never written to a
 * file. Local Supabase only; this script never touches a hosted project.
 *
 * This is the basis for step 4's vitest integration tests. Run with:
 *   npx tsx scripts/tc005-auth-hooks-live-check.ts
 *
 * Checks (plan Section F.2):
 *  (a) POST /auth/v1/signup with the anon key is refused (disable_signup).
 *  (b) An admin-created fictional user (example.test) signs in with a password.
 *  (c) The access token's top-level `aal` claim is "aal1" (closes plan risk 3).
 *  (d) Enumeration-safety: (locked real + wrong password) vs (unknown email +
 *      any password) are byte-for-byte identical after normalizing volatile
 *      timestamp fields.
 *  (e) (locked real + CORRECT password) diverges from (d) - the one
 *      deliberately distinguishable response.
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

function decodeJwtPayload(token: string): Record<string, unknown> {
  const parts = token.split(".");
  if (parts.length !== 3) throw new Error("not a JWT");
  const payload = Buffer.from(
    parts[1].replace(/-/g, "+").replace(/_/g, "/"),
    "base64"
  ).toString("utf8");
  return JSON.parse(payload);
}

// Normalizes volatile fields (timestamps, request ids) so two otherwise
// byte-identical GoTrue error bodies compare equal.
function normalizeBody(body: string): string {
  return body
    .replace(/"error_id":"[^"]*"/g, '"error_id":"<normalized>"')
    .replace(/\d{4}-\d{2}-\d{2}T[\d:.]+Z/g, "<normalized-timestamp>");
}

async function main() {
  console.log("== TC-005 step 2 live auth-hook checks ==\n");

  const env = loadSupabaseEnv();
  const API_URL = env.API_URL;
  const ANON_KEY = env.ANON_KEY;
  const SERVICE_ROLE_KEY = env.SERVICE_ROLE_KEY;

  if (!API_URL || !ANON_KEY || !SERVICE_ROLE_KEY) {
    console.error(
      "Missing API_URL/ANON_KEY/SERVICE_ROLE_KEY from `supabase status -o env` - is local Supabase running?"
    );
    process.exit(1);
  }

  const results: { name: string; pass: boolean; detail?: string }[] = [];
  const record = (name: string, pass: boolean, detail?: string) => {
    results.push({ name, pass, detail });
    console.log(`${pass ? "PASS" : "FAIL"} - ${name}${detail ? ` (${detail})` : ""}`);
  };

  // ---------------------------------------------------------------------
  // Setup: an admin-created fictional user (service role, since
  // disable_signup=false... wait, closed self-signup - admin API only).
  // ---------------------------------------------------------------------
  const suffix = Math.random().toString(36).slice(2, 10);
  const email = `tc005-livecheck-${suffix}@example.test`;
  const password = "Correct-Horse-Battery-99!";

  const createRes = await fetch(`${API_URL}/auth/v1/admin/users`, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      apikey: SERVICE_ROLE_KEY,
      Authorization: `Bearer ${SERVICE_ROLE_KEY}`,
    },
    body: JSON.stringify({ email, password, email_confirm: true }),
  });
  if (!createRes.ok) {
    console.error(`Could not create live-check fictional user: ${createRes.status} ${await createRes.text()}`);
    process.exit(1);
  }
  const created = (await createRes.json()) as { id: string };
  console.log(`Created fictional admin-created user ${email} (${created.id})\n`);

  // ---------------------------------------------------------------------
  // (a) signup is refused
  // ---------------------------------------------------------------------
  const signupRes = await fetch(`${API_URL}/auth/v1/signup`, {
    method: "POST",
    headers: { "Content-Type": "application/json", apikey: ANON_KEY },
    body: JSON.stringify({ email: `tc005-signup-${suffix}@example.test`, password }),
  });
  record(
    "(a) POST /auth/v1/signup with anon key is refused",
    signupRes.status === 422 || signupRes.status === 400 || signupRes.status === 403,
    `status=${signupRes.status}`
  );

  // ---------------------------------------------------------------------
  // (b) admin-created user signs in with password
  // ---------------------------------------------------------------------
  const signInOnce = () =>
    fetch(`${API_URL}/auth/v1/token?grant_type=password`, {
      method: "POST",
      headers: { "Content-Type": "application/json", apikey: ANON_KEY },
      body: JSON.stringify({ email, password }),
    });

  const signInRes = await signInOnce();
  const signInBody = (await signInRes.json()) as { access_token?: string };
  record("(b) admin-created user signs in with password", signInRes.status === 200 && !!signInBody.access_token, `status=${signInRes.status}`);

  // ---------------------------------------------------------------------
  // (c) access token's top-level `aal` claim is "aal1"
  // ---------------------------------------------------------------------
  if (signInBody.access_token) {
    const claims = decodeJwtPayload(signInBody.access_token);
    record("(c) access token top-level aal claim is aal1", claims.aal === "aal1", `aal=${String(claims.aal)}`);
  } else {
    record("(c) access token top-level aal claim is aal1", false, "no access_token from (b)");
  }

  // ---------------------------------------------------------------------
  // (d)/(e) enumeration safety: lock the real account with 5 wrong
  // passwords, then compare (locked real + wrong password) vs (unknown
  // email + any password), and check (locked real + correct password)
  // diverges.
  // ---------------------------------------------------------------------
  const wrongSignIn = (targetEmail: string) =>
    fetch(`${API_URL}/auth/v1/token?grant_type=password`, {
      method: "POST",
      headers: { "Content-Type": "application/json", apikey: ANON_KEY },
      body: JSON.stringify({ email: targetEmail, password: "definitely-wrong-password" }),
    });

  for (let i = 0; i < 5; i++) {
    await wrongSignIn(email);
  }

  const lockedWrongRes = await wrongSignIn(email);
  const lockedWrongBody = normalizeBody(await lockedWrongRes.text());

  const unknownEmail = `tc005-unknown-${suffix}@example.test`;
  const unknownRes = await wrongSignIn(unknownEmail);
  const unknownBody = normalizeBody(await unknownRes.text());

  const byteIdentical =
    lockedWrongRes.status === unknownRes.status &&
    lockedWrongBody === unknownBody &&
    lockedWrongBody.length === unknownBody.length;

  record(
    "(d) locked-real+wrong-password vs unknown-email+any-password are byte-identical",
    byteIdentical,
    `locked=${lockedWrongRes.status}/${lockedWrongBody.length}B unknown=${unknownRes.status}/${unknownBody.length}B`
  );

  const lockedCorrectRes = await fetch(`${API_URL}/auth/v1/token?grant_type=password`, {
    method: "POST",
    headers: { "Content-Type": "application/json", apikey: ANON_KEY },
    body: JSON.stringify({ email, password }),
  });
  const lockedCorrectBody = normalizeBody(await lockedCorrectRes.text());

  const diverges =
    lockedCorrectRes.status !== lockedWrongRes.status || lockedCorrectBody !== lockedWrongBody;

  record(
    "(e) locked-real+correct-password diverges from (d)",
    diverges,
    `correct=${lockedCorrectRes.status}/${lockedCorrectBody.length}B wrong=${lockedWrongRes.status}/${lockedWrongBody.length}B`
  );

  console.log("\n-- raw bodies for the record --");
  console.log("locked+wrong:  ", lockedWrongRes.status, lockedWrongBody);
  console.log("unknown+any:   ", unknownRes.status, unknownBody);
  console.log("locked+correct:", lockedCorrectRes.status, lockedCorrectBody);

  // cleanup: delete the fictional live-check user.
  await fetch(`${API_URL}/auth/v1/admin/users/${created.id}`, {
    method: "DELETE",
    headers: { apikey: SERVICE_ROLE_KEY, Authorization: `Bearer ${SERVICE_ROLE_KEY}` },
  });

  const allPass = results.every((r) => r.pass);
  console.log(`\n${allPass ? "ALL CHECKS PASSED" : "SOME CHECKS FAILED"}`);
  process.exit(allPass ? 0 : 1);
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
