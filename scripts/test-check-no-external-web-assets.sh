#!/usr/bin/env bash
# TC-032 self-test for scripts/check-no-external-web-assets.py: the check must
# pass on the repo's index.html files and on clean samples, and fail on every
# external script/style sample below (written to a scratch dir).
set -euo pipefail
ROOT="$(git -C "$(dirname "${BASH_SOURCE[0]}")" rev-parse --show-toplevel)"
CHECK="$ROOT/scripts/check-no-external-web-assets.py"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
fail=0

expect() { # expect <pass|fail> <name> <pattern-in-output> <target...>
  local want="$1" name="$2" pat="$3" out rc=0
  shift 3
  out="$(python3 "$CHECK" "$@" 2>&1)" || rc=$?
  if [[ "$want" == pass && $rc -eq 0 ]] || [[ "$want" == fail && $rc -ne 0 && "$out" == *"$pat"* ]]; then
    echo "ok   - $name"
  else
    echo "FAIL - $name (exit $rc)"; echo "$out" | sed 's/^/       /'; fail=1
  fi
}

# page <name> <head-html>: an HTML page with the given markup in <head>.
n=0
page() { n=$((n+1)); local f="$TMP/s$n.html"; printf '<!doctype html><html><head>\n%s\n</head><body><div id="root"></div></body></html>\n' "$1" > "$f"; echo "$f"; }
css() { n=$((n+1)); local f="$TMP/s$n.css"; printf '%s\n' "$1" > "$f"; echo "$f"; }

# --- the repo passes (default targets: index.html, space/index.html) ---
out="$(cd "$ROOT" && python3 "$CHECK" 2>&1)" && echo "ok   - repo index.html files pass" || { echo "FAIL - repo"; echo "$out"; fail=1; }

# --- clean samples pass ---
expect pass "same-origin module script, local css, manifest, data: font" "" "$(page '<script type="module" src="/assets/index-abc.js"></script><link rel="stylesheet" href="./assets/index.css"><link rel="manifest" href="/site.webmanifest"><style>@font-face{src:url(data:font/woff2;base64,AAAA)} body{background:url("/bg.png")}</style>')"
expect pass "inline script with no imports, external <a> link is not a script/style" "" "$(page '<script>document.documentElement.classList.add("dark")</script></head><body><a href="https://example.com">x</a>')"
expect pass "external URL only inside a CSS comment" "" "$(page '<style>/* was @import url(https://fonts.googleapis.com/css2) */ body{margin:0}</style>')"
expect pass "local css file" "" "$(css '@import "./fonts.css"; .a{background:url(/x.png)}')"

# --- the exact markup TC-032 removed (index.html before 8c31249 -> TC-032) ---
expect fail "Tailwind Play CDN script" "external script: https://cdn.tailwindcss.com" "$(page '<script src="https://cdn.tailwindcss.com"></script>')"
expect fail "Google Fonts stylesheet" "external resource: https://fonts.googleapis.com" "$(page '<link href="https://fonts.googleapis.com/css2?family=Inter&display=swap" rel="stylesheet">')"
expect fail "esm.sh / aistudiocdn import map" 'type="importmap"' "$(page '<script type="importmap">{"imports":{"react":"https://esm.sh/react@18.2.0","react/":"https://aistudiocdn.com/react@^19.2.0/"}}</script>')"
expect fail "import map even with only local entries" 'type="importmap"' "$(page '<script type="importmap">{"imports":{"react":"/vendor/react.js"}}</script>')"

# --- script variants ---
expect fail "uppercase tag/attr/scheme, tag split over lines" "external script" "$(page $'<SCRIPT\n  type="module"\n  SRC="HTTPS://unpkg.com/react@18/umd/react.js"></SCRIPT>')"
expect fail "scheme-relative //host" "external script: //cdn.jsdelivr.net" "$(page '<script src="//cdn.jsdelivr.net/npm/react@18"></script>')"
expect fail "backslash scheme-relative" "external script" "$(page '<script src="\\\\cdn.example.com/x.js"></script>')"
expect fail "entity-encoded scheme" "external script" "$(page '<script src="https&#58;//cdn.example.com/x.js"></script>')"
expect fail "unquoted src, http:" "external script: http://cdn.example.com/x.js" "$(page '<script src=http://cdn.example.com/x.js></script>')"
expect fail "tab inside the scheme" "external script" "$(page $'<script src="ht\ttps://cdn.example.com/x.js"></script>')"
expect fail "inline module static import" "inline <script> imports an external module: https://esm.sh/react@18.2.0" "$(page $'<script type="module">\nimport React\n  from "https://esm.sh/react@18.2.0";\n</script>')"
expect fail "inline dynamic import()" "imports an external module: https://esm.sh/zod@3" "$(page $'<script>import(\n  \'https://esm.sh/zod@3\'\n)</script>')"
expect fail "inline side-effect import" "imports an external module" "$(page '<script type="module">import "//cdn.example.com/x.js";</script>')"

# --- link variants ---
expect fail "modulepreload" "external resource" "$(page '<link rel="modulepreload" href="https://esm.sh/react@18.2.0">')"
expect fail "preload as=style" "external resource" "$(page '<link rel="preload" as="style" href="https://cdn.example.com/a.css">')"
expect fail "uppercase LINK/HREF" "external resource" "$(page '<LINK REL="STYLESHEET" HREF="HTTPS://cdn.example.com/a.css">')"
expect fail "base href off-site" "<base href> points at an external host" "$(page '<base href="https://cdn.example.com/"><script src="/x.js"></script>')"

# --- CSS variants ---
expect fail "<style> @import url()" "CSS @import of an external stylesheet" "$(page '<style>@import url(https://fonts.googleapis.com/css2?family=Inter);</style>')"
expect fail "<style> @import string, uppercase" "CSS @import of an external stylesheet" "$(page '<style>@IMPORT "https://cdn.example.com/a.css";</style>')"
expect fail "style attribute url(//host)" "CSS url() pointing at an external host" "$(page '</head><body style="background:url(//cdn.example.com/bg.png)">')"
expect fail "built css @import" "CSS @import of an external stylesheet" "$(css '@import url("https://fonts.googleapis.com/css2?family=Poppins");')"
expect fail "built css @font-face from fonts.gstatic.com" "CSS url() pointing at an external host" "$(css '@font-face{font-family:Inter;src:url(https://fonts.gstatic.com/s/inter/v1.woff2) format("woff2")}')"
expect fail "CSS-escaped scheme" "CSS @import of an external stylesheet" "$(css '@import url(h\74tps://cdn.example.com/a.css);')"
expect fail "multi-line url()" "CSS url() pointing at an external host" "$(css $'.a{background:url(\n  "https://cdn.example.com/a.png"\n)}')"

# --- directories (built output) ---
mkdir -p "$TMP/dist-ok/assets" "$TMP/dist-bad/assets" "$TMP/dist-empty/assets"
printf '<script type="module" src="/assets/i.js"></script><link rel="stylesheet" href="/assets/i.css">\n' > "$TMP/dist-ok/index.html"
printf '.a{color:red}\n' > "$TMP/dist-ok/assets/i.css"
cp "$TMP/dist-ok/index.html" "$TMP/dist-bad/index.html"
printf '@import url(https://cdn.example.com/x.css);\n' > "$TMP/dist-bad/assets/i.css"
printf '.a{color:red}\n' > "$TMP/dist-empty/assets/i.css"
expect pass "clean dist directory" "" "$TMP/dist-ok"
expect fail "dist directory with an external @import in nested css" "assets/i.css" "$TMP/dist-bad"
expect fail "dist directory with no HTML (missing build)" "no HTML file found" "$TMP/dist-empty"
expect fail "missing target" "not found" "$TMP/does-not-exist"

if [[ $fail -ne 0 ]]; then echo "test-check-no-external-web-assets: FAILED"; exit 1; fi
echo "test-check-no-external-web-assets: all cases behave as expected"
