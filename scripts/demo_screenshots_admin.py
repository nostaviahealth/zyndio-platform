#!/usr/bin/env python3
"""TC-005 admin preview/screenshot harness.

Serves the already-built admin web preview bundle (built via
`npm run build:preview`, which gates the /__preview harness behind
__PREVIEW_BUILD__ - see vite.config.ts) and drives headless Chromium to the
HashRouter URL `#/__preview?screen=...&state=...&mode=...` for every
screen/state combination, capturing a 1440x900 PNG per state per mode
(light/dark).

Only 07-users-roles is wired into the harness this step (see
pages/preview/PreviewHarness.tsx for why 01-06 aren't yet) - MANIFEST below
reflects that, not the full 7-screen/40-state handoff list.

Usage:
    python3 scripts/demo_screenshots_admin.py [--screen NAME ...] [--state NAME ...]
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
OUT_DIR = REPO_ROOT / "docs" / "screenshots" / "tc-005"

# screen folder -> states. Source of truth: the handoff README's state list
# (low-codes already dropped there), filtered to the screen this step builds.
MANIFEST: dict[str, list[str]] = {
    "07-users-roles": [
        "default",
        "loading",
        "empty",
        "error",
        "invite",
        "invite-validation",
        "invite-sent",
        "cancel-invite-confirm",
        "role-confirm",
        "deactivate-confirm",
        "deactivated",
        "last-admin",
        "reset-2fa",
        "request-2fa-reset",
        "reset-requested",
    ],
}

MODES = ["light", "dark"]
VIEWPORT = {"width": 1440, "height": 900}


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
            context = browser.new_context(viewport=VIEWPORT)
            page = context.new_page()

            for screen, screen_states in manifest.items():
                screen_dir = OUT_DIR / screen
                screen_dir.mkdir(parents=True, exist_ok=True)
                for state in screen_states:
                    for mode in MODES:
                        url = f"{base_url}#/__preview?screen={screen}&state={state}&mode={mode}"
                        page.goto(url, wait_until="domcontentloaded")
                        page.wait_for_selector("[data-preview-marker]", timeout=10_000)
                        # Tailwind CDN generates dark: utilities after hydration;
                        # wait until a known dark surface rule exists so dialogs
                        # and buttons aren't shot mid-theme.
                        if mode == "dark":
                            page.wait_for_function(
                                """() => {
                                  for (const sheet of document.styleSheets) {
                                    let rules;
                                    try { rules = sheet.cssRules; } catch (e) { continue; }
                                    for (const r of rules) {
                                      if ((r.cssText || "").includes("10141F")) return true;
                                    }
                                  }
                                  return false;
                                }""",
                                timeout=10_000,
                            )
                            page.wait_for_timeout(150)
                        out_path = screen_dir / f"{state}--{mode}.png"
                        page.screenshot(path=str(out_path))
                        written.append(out_path)
                        print(f"wrote {out_path.relative_to(REPO_ROOT)}")

            browser.close()
    finally:
        server.shutdown()

    return written


def write_index(written: list[Path]) -> Path:
    index_path = OUT_DIR / "INDEX.md"
    lines = ["# TC-005 admin screenshots", "", "| Screen | State | Light | Dark |", "|---|---|---|---|"]
    by_screen_state: dict[tuple[str, str], dict[str, Path]] = {}
    for path in written:
        screen = path.parent.name
        state, mode_ext = path.name.split("--", 1)
        mode = mode_ext.removesuffix(".png")
        by_screen_state.setdefault((screen, state), {})[mode] = path
    for (screen, state), modes in sorted(by_screen_state.items()):
        light = modes.get("light")
        dark = modes.get("dark")
        light_link = f"[png]({light.relative_to(OUT_DIR)})" if light else "-"
        dark_link = f"[png]({dark.relative_to(OUT_DIR)})" if dark else "-"
        lines.append(f"| {screen} | {state} | {light_link} | {dark_link} |")
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
