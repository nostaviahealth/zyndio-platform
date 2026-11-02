#!/usr/bin/env python3
"""TC-032: fail if web HTML/CSS loads any script or style from another host.

The staff portal used to pull Tailwind from its Play CDN (unpinned) and carried
an esm.sh/aistudiocdn import map; the fonts came from fonts.googleapis.com.
Everything is now bundled, and this check keeps it that way.

Usage:
  python3 scripts/check-no-external-web-assets.py            # source: index.html, space/index.html
  python3 scripts/check-no-external-web-assets.py dist space/dist   # built output
Each argument is a file or a directory (scanned recursively for .html/.htm/.css).
A directory with no HTML file fails, so a missing build can't pass silently.

Fails on (case-insensitive, multi-line tags, HTML entities decoded):
  - <script src> pointing off-site, and any <script type="importmap">
  - static or dynamic `import ... 'https://...'` inside an inline <script>
  - <link href> pointing off-site (stylesheet, preload, modulepreload, ...)
  - <base href> pointing off-site (would make every relative URL external)
  - CSS (files, <style>, style="") with @import or url() pointing off-site
"Off-site" = any URL with a scheme other than data:/blob:, or a scheme-relative
//host (slashes or backslashes). Same-origin paths (/x, ./x, x) are fine.
"""
from __future__ import annotations

import re
import sys
from html.parser import HTMLParser
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
DEFAULT_TARGETS = ["index.html", "space/index.html"]

_SCHEME = re.compile(r"^[a-z][a-z0-9+.\-]*:", re.I)
_LOCAL_SCHEMES = ("data:", "blob:")


def is_external(url: str | None) -> bool:
    if url is None:
        return False
    # The URL parser drops tabs/newlines anywhere and trims C0 controls/space.
    u = re.sub(r"[\t\n\r]", "", url).strip("\x00\x01\x02\x03\x04\x05\x06\x07\x08\x0b\x0c\x0e\x0f"
                                         "\x10\x11\x12\x13\x14\x15\x16\x17\x18\x19\x1a\x1b\x1c\x1d\x1e\x1f ")
    u = u.strip("'\"").strip()
    if re.match(r"^[\\/]{2}", u):
        return True
    if _SCHEME.match(u):
        return not u.lower().startswith(_LOCAL_SCHEMES)
    return False


def _css_unescape(css: str) -> str:
    def rep(m: re.Match) -> str:
        if m.group(1):
            try:
                return chr(int(m.group(1), 16))
            except ValueError:
                return ""
        return m.group(2)
    return re.sub(r"\\([0-9a-fA-F]{1,6})\s?|\\(.)", rep, css)


_CSS_IMPORT = re.compile(r"@import\s+(?:url\(\s*)?(['\"]?)([^'\"\s)]+)\1", re.I)
_CSS_URL = re.compile(r"url\(\s*(['\"]?)(.*?)\1\s*\)", re.I | re.S)
_JS_IMPORT = re.compile(
    r"""(?:\bimport\s*\(\s*|\bfrom\s*|\bimport\s+)(['"`])\s*([^'"`]*)\1""", re.I)


def css_problems(css: str) -> list[str]:
    css = re.sub(r"/\*.*?\*/", "", css, flags=re.S)
    css = _css_unescape(css)
    out = []
    for m in _CSS_IMPORT.finditer(css):
        if is_external(m.group(2)):
            out.append(f"CSS @import of an external stylesheet: {m.group(2)}")
    for m in _CSS_URL.finditer(css):
        if is_external(m.group(2)):
            out.append(f"CSS url() pointing at an external host: {m.group(2).strip()}")
    return out


class _Scanner(HTMLParser):
    def __init__(self) -> None:
        super().__init__(convert_charrefs=True)
        self.problems: list[tuple[int, str]] = []
        self._in: str | None = None
        self._buf: list[str] = []
        self._start_line = 0

    def _add(self, msg: str, line: int | None = None) -> None:
        self.problems.append((line if line is not None else self.getpos()[0], msg))

    def handle_starttag(self, tag, attrs):
        self._tag(tag, attrs)

    def handle_startendtag(self, tag, attrs):
        self._tag(tag, attrs)

    def _tag(self, tag, attrs):
        a = {k.lower(): v for k, v in attrs}
        line = self.getpos()[0]
        if "style" in a and a["style"]:
            for p in css_problems(a["style"]):
                self._add(f"<{tag} style>: {p}", line)
        if tag == "script":
            if (a.get("type") or "").strip().lower() == "importmap":
                self._add("<script type=\"importmap\"> (bare imports must resolve to the bundle)", line)
            if is_external(a.get("src")):
                self._add(f"<script src> loads an external script: {a['src']}", line)
            self._in, self._buf, self._start_line = "script", [], line
        elif tag == "style":
            self._in, self._buf, self._start_line = "style", [], line
        elif tag == "link" and is_external(a.get("href")):
            self._add(f"<link rel=\"{a.get('rel') or ''}\"> loads an external resource: {a['href']}", line)
        elif tag == "link" and is_external(a.get("imagesrcset")):
            self._add(f"<link imagesrcset> points at an external host: {a['imagesrcset']}", line)
        elif tag == "base" and is_external(a.get("href")):
            self._add(f"<base href> points at an external host: {a['href']}", line)

    def handle_data(self, data):
        if self._in:
            self._buf.append(data)

    def handle_endtag(self, tag):
        if self._in and tag == self._in:
            body = "".join(self._buf)
            if tag == "style":
                for p in css_problems(body):
                    self._add(f"<style>: {p}", self._start_line)
            else:
                for m in _JS_IMPORT.finditer(body):
                    if is_external(m.group(2)):
                        self._add(f"inline <script> imports an external module: {m.group(2)}", self._start_line)
            self._in = None


def scan_file(path: Path) -> list[str]:
    text = path.read_text(encoding="utf-8", errors="replace")
    if path.suffix.lower() == ".css":
        return [f"{path}: {p}" for p in css_problems(text)]
    s = _Scanner()
    s.feed(text)
    s.close()
    if s._in:  # unterminated <script>/<style>: still check what's there
        s.handle_endtag(s._in)
    return [f"{path}:{line}: {msg}" for line, msg in s.problems]


def main(argv: list[str]) -> int:
    targets = argv or DEFAULT_TARGETS
    problems: list[str] = []
    scanned = 0
    for t in targets:
        p = Path(t)
        if not p.is_absolute():
            p = (Path.cwd() / p) if (Path.cwd() / p).exists() else (ROOT / p)
        if p.is_dir():
            files = sorted(f for f in p.rglob("*") if f.is_file() and f.suffix.lower() in (".html", ".htm", ".css"))
            if not any(f.suffix.lower() in (".html", ".htm") for f in files):
                problems.append(f"{p}: no HTML file found (missing build output?)")
        elif p.is_file():
            files = [p]
        else:
            problems.append(f"{p}: not found")
            files = []
        for f in files:
            scanned += 1
            problems.extend(scan_file(f))
    if problems:
        print("check-no-external-web-assets: FAIL")
        for pr in problems:
            print(f"  {pr}")
        print("Bundle the dependency instead (npm, exact version, lockfile); see TC-032.")
        return 1
    print(f"check-no-external-web-assets: OK ({scanned} file(s), no external script/style hosts)")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
