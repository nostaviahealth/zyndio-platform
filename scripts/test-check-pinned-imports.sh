#!/usr/bin/env bash
# TC-031 self-test for scripts/check-pinned-imports.sh: the check must pass on
# the current supabase/functions tree and fail on each unpinned sample below
# (each run in a scratch copy, so the real tree is never touched).
set -euo pipefail
ROOT="$(git -C "$(dirname "${BASH_SOURCE[0]}")" rev-parse --show-toplevel)"
CHECK="$ROOT/scripts/check-pinned-imports.sh"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
fail=0

fresh() { rm -rf "$TMP/fn"; cp -r "$ROOT/supabase/functions" "$TMP/fn"; }

expect() { # expect <pass|fail> <name> <pattern-in-output>
  local want="$1" name="$2" pat="$3" out rc=0
  out="$(bash "$CHECK" "$TMP/fn" 2>&1)" || rc=$?
  if [[ "$want" == pass && $rc -eq 0 ]] || [[ "$want" == fail && $rc -ne 0 && "$out" == *"$pat"* ]]; then
    echo "ok   - $name"
  else
    echo "FAIL - $name (exit $rc)"; echo "$out" | sed 's/^/       /'; fail=1
  fi
}

# add <file> <line>: write a sample file containing one import line.
add() { mkdir -p "$(dirname "$TMP/fn/$1")"; printf '%s\n' "$2" > "$TMP/fn/$1"; }

# --- the real tree passes, as is and when checked via the default path ---
fresh; expect pass "current supabase/functions passes" ""
out="$(bash "$CHECK" 2>&1)" && echo "ok   - default path (repo) passes" || { echo "FAIL - default path"; echo "$out"; fail=1; }

# --- the exact import that broke CI 41406347970 / PR #24 ---
fresh; add bad/index.ts "import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'"
expect fail "esm.sh with a major-only version" "on-the-fly CDN build"

fresh; add bad/index.ts "import { OpenAI } from \"https://esm.sh/openai@4.28.0\""
expect fail "esm.sh even at an exact version" "on-the-fly CDN build"

fresh; add bad/index.ts "import x from 'https://esm.sh/tslib@2.8.1?pin=v135'"
expect fail "esm.sh with ?pin= is still a CDN build" "on-the-fly CDN build"

fresh; add bad/index.ts "import x from 'https://cdn.skypack.dev/lodash'"
expect fail "skypack" "on-the-fly CDN build"

fresh; add bad/index.ts "import x from 'https://cdn.jsdelivr.net/npm/lodash@4.17.21/+esm'"
expect fail "jsdelivr +esm" "on-the-fly CDN build"

# --- npm: / jsr: must carry an exact version ---
fresh; add bad/index.ts "import { createClient } from 'npm:@supabase/supabase-js@2'"
expect fail "npm: major-only" "without an exact x.y.z"

fresh; add bad/index.ts "import { createClient } from 'npm:@supabase/supabase-js@^2.118.0'"
expect fail "npm: caret range" "without an exact x.y.z"

fresh; add bad/index.ts "import OpenAI from 'npm:openai'"
expect fail "npm: no version" "without an exact x.y.z"

fresh; add bad/index.ts "import { assert } from 'jsr:@std/assert@latest'"
expect fail "jsr: dist-tag" "without an exact x.y.z"

# --- other https hosts ---
fresh; add bad/index.ts "import { serve } from 'https://deno.land/std/http/server.ts'"
expect fail "deno.land/std without a version" "without an exact @x.y.z"

fresh; add bad/index.ts "import { serve } from 'https://deno.land/std@0.168/http/server.ts'"
expect fail "deno.land/std with a partial version" "without an exact @x.y.z"

fresh; add bad/index.ts "import x from 'https://raw.githubusercontent.com/acme/lib/main/mod.ts'"
expect fail "raw GitHub on a branch" "without an exact @x.y.z"

fresh; add bad/index.ts "import x from 'http://deno.land/std@0.168.0/http/server.ts'"
expect fail "plain http" "insecure http"

# --- every import form is scanned ---
fresh; add bad/index.ts "const m = await import('https://esm.sh/zod@3')"
expect fail "dynamic import()" "on-the-fly CDN build"

fresh; add bad/index.ts "export * from 'npm:zod'"
expect fail "re-export" "without an exact x.y.z"

fresh; printf '%s\n' "import {" "  a," "} from 'https://deno.land/x/foo/mod.ts'" > "$TMP/fn/_shared/multiline_sample.ts"
expect fail "multi-line import" "without an exact @x.y.z"

fresh; add bad/index.ts '/// <reference types="https://esm.sh/@types/node@18/index.d.ts" />'
expect fail "/// <reference types>" "on-the-fly CDN build"

fresh; add bad/index.ts "// @deno-types=\"npm:@types/node\""
expect fail "@deno-types" "without an exact x.y.z"

# --- import maps ---
fresh; printf '%s\n' '{ "imports": { "supabase": "npm:@supabase/supabase-js@2" } }' > "$TMP/fn/deno.json"
expect fail "deno.json import map range" "without an exact x.y.z"

fresh; add bad/import_map.json '{ "imports": { "zod": "https://esm.sh/zod@3.23.8" } }'
expect fail "import_map.json esm.sh" "on-the-fly CDN build"

# --- pinned forms are accepted (no false positives) ---
fresh; add ok/index.ts "import { createClient } from 'npm:@supabase/supabase-js@2.118.0'"
printf '%s\n' "import { assert } from 'jsr:@std/assert@1.0.13'" \
  "import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'" \
  "import x from 'https://deno.land/x/foo@v1.2.3/mod.ts'" \
  "import y from 'https://raw.githubusercontent.com/acme/lib/0123456789abcdef0123456789abcdef01234567/mod.ts'" \
  "import { h } from './local.ts'" "import { Buffer } from 'node:buffer'" \
  "const r = await fetch('https://example.com/api/v1/things')" >> "$TMP/fn/ok/index.ts"
expect pass "exact npm:/jsr:/deno.land/commit-SHA, relative, node: and fetch URLs pass" ""

# --- an empty or missing tree must not pass silently ---
rm -rf "$TMP/fn"; mkdir -p "$TMP/fn"
expect fail "empty directory" "no source files"
expect_missing_rc=0; bash "$CHECK" "$TMP/does-not-exist" >/dev/null 2>&1 || expect_missing_rc=$?
if [[ $expect_missing_rc -ne 0 ]]; then echo "ok   - missing directory fails"; else echo "FAIL - missing directory passed"; fail=1; fi

if [[ $fail -ne 0 ]]; then echo "test-check-pinned-imports: FAILED"; exit 1; fi
echo "test-check-pinned-imports: all cases passed"
