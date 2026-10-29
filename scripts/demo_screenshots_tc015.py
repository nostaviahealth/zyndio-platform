#!/usr/bin/env python3
"""TC-015 physician-portal preview/screenshot harness.

Serves the already-built preview bundle (`npm run build:preview`, which gates
the /__preview harness behind __PREVIEW_BUILD__ - see vite.config.ts) and
drives headless Chromium to the HashRouter URL
`#/__preview?screen=...&state=...&mode=...` for the two TC-015 screens
(01-patient-list: 6 states; 02-patient-detail: 7 states, incl. not-found),
light + dark, at desktop (1440x900) and tablet (1024x768).

Output (52 PNGs):
    docs/screenshots/tc-015/<screen>/<state>--<mode>.png          (desktop)
    docs/screenshots/tc-015/<screen>/tablet/<state>--<mode>.png   (tablet)

Usage:
    python3 scripts/demo_screenshots_tc015.py [--screen NAME ...] [--state NAME ...]
"""

from __future__ import annotations

import argparse
import functools
import http.server
import socket
import sys
import threading
from pathlib import Path

from playwright.sync_api import sync_playwright

REPO_ROOT = Path(__file__).resolve().parent.parent
BUILD_DIR = REPO_ROOT / "dist"
OUT_DIR = REPO_ROOT / "docs" / "screenshots" / "tc-015"

# Source of truth: the handoff README state list for 01 and 02 (6 each).
MANIFEST: dict[str, list[str]] = {
    "01-patient-list": ["default", "loading", "empty", "no-results", "filtered", "error"],
    "02-patient-detail": ["default", "loading", "empty", "single", "needs-review", "error", "not-found"],
}

MODES = ["light", "dark"]
# (label, viewport, output subdir). "" = screen root (desktop); "tablet" nests.
VIEWPORTS = [
    ("desktop", {"width": 1440, "height": 900}, ""),
    ("tablet", {"width": 1024, "height": 768}, "tablet"),
]


def _free_port() -> int:
    with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as s:
        s.bind(("127.0.0.1", 0))
        return s.getsockname()[1]


def _start_server(build_dir: Path, port: int) -> http.server.ThreadingHTTPServer:
    handler = functools.partial(http.server.SimpleHTTPRequestHandler, directory=str(build_dir))
    server = http.server.ThreadingHTTPServer(("127.0.0.1", port), handler)
    thread = threading.Thread(target=server.serve_forever, daemon=True)
    thread.start()
    return server


def _filtered_manifest(screens: list[str] | None, states: list[str] | None) -> dict[str, list[str]]:
    manifest = MANIFEST
    if screens:
        unknown = sorted(set(screens) - set(manifest))
        if unknown:
            raise SystemExit(f"Unknown screen(s): {', '.join(unknown)}")
        manifest = {k: v for k, v in manifest.items() if k in screens}
    if states:
        manifest = {k: [s for s in v if s in states] for k, v in manifest.items()}
        manifest = {k: v for k, v in manifest.items() if v}
    return manifest


def _wait_ready(page, mode: str) -> None:
    page.wait_for_selector("[data-preview-marker]", timeout=10_000)
    # Tailwind's CDN JIT generates utilities after hydration; wait until a
    # theme token exists in a stylesheet so colours have painted.
    token = "10141F" if mode == "dark" else "2C5CF2"
    page.wait_for_function(
        """(token) => {
          for (const sheet of document.styleSheets) {
            let rules;
            try { rules = sheet.cssRules; } catch (e) { continue; }
            for (const r of rules) {
              if ((r.cssText || "").includes(token)) return true;
            }
          }
          return false;
        }""",
        arg=token,
        timeout=10_000,
    )
    # Let fonts + the recharts SVG settle before capturing.
    page.wait_for_timeout(450)


def capture(screens: list[str] | None, states: list[str] | None) -> list[Path]:
    if not BUILD_DIR.exists() or not (BUILD_DIR / "index.html").exists():
        raise SystemExit(f"{BUILD_DIR} not found. Run `npm run build:preview` first.")

    manifest = _filtered_manifest(screens, states)
    if not manifest:
        raise SystemExit("Nothing to capture after filtering.")

    port = _free_port()
    server = _start_server(BUILD_DIR, port)
    base_url = f"http://127.0.0.1:{port}/"

    written: list[Path] = []
    try:
        with sync_playwright() as p:
            browser = p.chromium.launch()
            for _label, viewport, subdir in VIEWPORTS:
                context = browser.new_context(viewport=viewport)
                page = context.new_page()
                for screen, screen_states in manifest.items():
                    out = OUT_DIR / screen / subdir if subdir else OUT_DIR / screen
                    out.mkdir(parents=True, exist_ok=True)
                    for state in screen_states:
                        for mode in MODES:
                            # Cache-buster in the REAL query (before the hash) so
                            # each capture is a full document reload. Without it,
                            # hash-only navigation wouldn't remount the stateful
                            # clinical pages and later states would show stale
                            # (first-captured) content.
                            bust = f"{screen}-{state}-{mode}"
                            url = f"{base_url}?s={bust}#/__preview?screen={screen}&state={state}&mode={mode}"
                            page.goto(url, wait_until="domcontentloaded")
                            _wait_ready(page, mode)
                            out_path = out / f"{state}--{mode}.png"
                            page.screenshot(path=str(out_path))
                            written.append(out_path)
                            print(f"wrote {out_path.relative_to(REPO_ROOT)}")
                context.close()
            browser.close()
    finally:
        server.shutdown()

    return written


def write_index(written: list[Path]) -> Path:
    index_path = OUT_DIR / "INDEX.md"
    lines = ["# TC-015 physician-portal screenshots", "", "| Screen | Viewport | State | Light | Dark |", "|---|---|---|---|---|"]
    rows: dict[tuple[str, str, str], dict[str, Path]] = {}
    for path in written:
        viewport = "tablet" if path.parent.name == "tablet" else "desktop"
        screen = path.parent.parent.name if viewport == "tablet" else path.parent.name
        state, mode_ext = path.name.split("--", 1)
        mode = mode_ext.removesuffix(".png")
        rows.setdefault((screen, viewport, state), {})[mode] = path
    for (screen, viewport, state), modes in sorted(rows.items()):
        light = modes.get("light")
        dark = modes.get("dark")
        light_link = f"[png]({light.relative_to(OUT_DIR)})" if light else "-"
        dark_link = f"[png]({dark.relative_to(OUT_DIR)})" if dark else "-"
        lines.append(f"| {screen} | {viewport} | {state} | {light_link} | {dark_link} |")
    index_path.write_text("\n".join(lines) + "\n")
    return index_path


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--screen", action="append", help="Capture only this screen folder (repeatable). Default: all.")
    parser.add_argument("--state", action="append", help="Capture only this state (repeatable). Default: all.")
    args = parser.parse_args()

    written = capture(args.screen, args.state)
    index_path = write_index(written)
    print(f"\n{len(written)} PNG(s) written to {OUT_DIR.relative_to(REPO_ROOT)}")
    print(f"wrote {index_path.relative_to(REPO_ROOT)}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
