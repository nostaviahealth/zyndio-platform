#!/usr/bin/env bash
# TC-031: every remote import in the Edge Functions must be pinned to exact,
# immutable bytes, so `deno check` / `deno test` never depend on what a CDN
# happens to serve today. Fails (exit 1) on:
#   - any esm.sh / skypack / esm.run / jspm.dev / jsdelivr "+esm" import. These
#     CDNs build modules on the fly; even an exact version (tslib@2.8.1) changed
#     bytes under us and broke the deno.lock integrity check (CI 41406347970).
#     Use an exact npm: specifier instead (immutable registry tarball + sha512).
#   - npm: / jsr: specifiers without an exact x.y.z version (no ranges, no tags)
#   - other https:// imports without an exact @x.y.z / @vx.y.z version or a
#     40-hex commit SHA in the URL
#   - any http:// import
# Scans import/export statements, dynamic import(), /// <reference> and
# @deno-types in *.ts/*.tsx/*.js/*.jsx/*.mjs/*.mts, plus the "imports" maps of
# any deno.json / deno.jsonc / import_map.json.
# Usage: bash scripts/check-pinned-imports.sh [dir]   (default: supabase/functions)
set -euo pipefail
ROOT="$(git -C "$(dirname "${BASH_SOURCE[0]}")" rev-parse --show-toplevel)"
DIR="${1:-$ROOT/supabase/functions}"
if [[ ! -d "$DIR" ]]; then
  echo "check-pinned-imports: directory not found: $DIR" >&2
  exit 1
fi
exec python3 - "$DIR" <<'PY'
import json, os, re, sys

root = sys.argv[1]
CODE_EXT = (".ts", ".tsx", ".js", ".jsx", ".mjs", ".mts")
MAP_FILES = ("deno.json", "deno.jsonc", "import_map.json")

# Specifiers in import contexts only (so a fetch("https://...") URL is ignored).
IMPORT_RES = [
    re.compile(r"""\bfrom\s*['"]([^'"\n]+)['"]"""),
    re.compile(r"""\bimport\s*['"]([^'"\n]+)['"]"""),
    re.compile(r"""\bimport\s*\(\s*['"]([^'"\n]+)['"]"""),
    re.compile(r"""///\s*<reference\s+(?:types|path)\s*=\s*['"]([^'"\n]+)['"]"""),
    re.compile(r"""@deno-types\s*=\s*['"]([^'"\n]+)['"]"""),
]
ON_THE_FLY_CDN = re.compile(
    r"^https?://(esm\.sh|cdn\.esm\.sh|cdn\.skypack\.dev|esm\.run|jspm\.dev|ga\.jspm\.io)(/|$)"
    r"|^https?://cdn\.jsdelivr\.net/.*\+esm", re.I)
EXACT = r"\d+\.\d+\.\d+(?:-[0-9A-Za-z.-]+)?(?:\+[0-9A-Za-z.-]+)?"
PKG_EXACT = re.compile(r"^(npm|jsr):(@[^/@\s]+/)?[^/@\s]+@" + EXACT + r"(/.*)?$")
URL_EXACT = re.compile(r"@v?" + EXACT + r"(/|$|\?|#)")
URL_SHA = re.compile(r"/[0-9a-f]{40}(/|$)")

def problem(spec):
    s = spec.strip()
    if s.startswith("http://"):
        return "insecure http:// import"
    if ON_THE_FLY_CDN.search(s):
        return "on-the-fly CDN build (bytes can change even at an exact version); use an exact npm: specifier"
    if s.startswith(("npm:", "jsr:")):
        return None if PKG_EXACT.match(s) else "npm:/jsr: specifier without an exact x.y.z version"
    if s.startswith("https://"):
        if URL_EXACT.search(s) or URL_SHA.search(s):
            return None
        return "https:// import without an exact @x.y.z version or commit SHA"
    return None  # relative, node:, or bare (bare names are checked via the import map)

def strip_jsonc(text):
    text = re.sub(r"/\*.*?\*/", "", text, flags=re.S)
    return re.sub(r'(^|[^:"\\])//[^\n]*', r"\1", text)

bad = []
scanned = 0
for dirpath, dirnames, filenames in os.walk(root):
    dirnames[:] = [d for d in dirnames if d not in ("node_modules", ".git")]
    for name in sorted(filenames):
        path = os.path.join(dirpath, name)
        rel = os.path.relpath(path, root)
        if name.endswith(CODE_EXT):
            scanned += 1
            with open(path, encoding="utf-8", errors="replace") as fh:
                for lineno, line in enumerate(fh, 1):
                    for rx in IMPORT_RES:
                        for m in rx.finditer(line):
                            why = problem(m.group(1))
                            if why:
                                bad.append(f"{rel}:{lineno}: {m.group(1)} -> {why}")
        elif name in MAP_FILES:
            scanned += 1
            try:
                with open(path, encoding="utf-8") as fh:
                    data = json.loads(strip_jsonc(fh.read()))
            except Exception as e:  # unreadable config must not pass silently
                bad.append(f"{rel}: cannot parse ({e})")
                continue
            maps = [data.get("imports") or {}]
            maps += list((data.get("scopes") or {}).values())
            for mp in maps:
                for key, target in mp.items():
                    why = problem(str(target))
                    if why:
                        bad.append(f'{rel}: imports "{key}": {target} -> {why}')

if scanned == 0:
    print(f"check-pinned-imports: no source files found under {root}", file=sys.stderr)
    sys.exit(1)
if bad:
    print(f"check-pinned-imports: FAIL, {len(bad)} unpinned remote import(s):")
    for b in bad:
        print("  " + b)
    sys.exit(1)
print(f"check-pinned-imports: OK, {scanned} files, every remote import is pinned")
PY
