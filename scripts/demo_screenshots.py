#!/usr/bin/env python3
"""TC-008 demo screenshot harness.

Serves flutter_app/build/web (built via `flutter build web -t lib/main_demo.dart`)
on localhost and drives headless Chromium to capture every screen/state/mode
combination at 390x844, device pixel ratio 2. Waits for the deterministic
`window.flutterDemoReady` flag `DemoApp` sets after its first real frame
instead of a fixed sleep.

Usage:
    python3 scripts/demo_screenshots.py [--screen NAME ...] [--state NAME ...]
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
BUILD_DIR = REPO_ROOT / "flutter_app" / "build" / "web"
OUT_DIR = REPO_ROOT / "docs" / "screenshots" / "tc-008"

# screen folder -> states, per TC-008-plan.md's coverage table.
MANIFEST: dict[str, list[str]] = {
    "signin": ["default", "sending", "code", "error", "locked", "offline"],
    "consent": [
        "unchecked",
        "partner-on",
        "validation",
        "loading",
        "error",
        "complete",
    ],
    "lab-upload": ["empty", "default", "uploading", "duplicate", "offline", "error"],
    "lab-review": ["loading", "default", "mismatch", "empty", "error", "saved"],
    "lab-trends": ["loading", "default", "above", "single", "error"],
}

MODES = ["light", "dark"]
VIEWPORT = {"width": 390, "height": 844}
DEVICE_SCALE_FACTOR = 2
READY_TIMEOUT_MS = 30_000


def _free_port() -> int:
    with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as s:
        s.bind(("127.0.0.1", 0))
        return s.getsockname()[1]


def _start_server(build_dir: Path, port: int) -> http.server.ThreadingHTTPServer:
    handler = functools.partial(
        http.server.SimpleHTTPRequestHandler, directory=str(build_dir)
    )
    server = http.server.ThreadingHTTPServer(("127.0.0.1", port), handler)
    thread = threading.Thread(target=server.serve_forever, daemon=True)
    thread.start()
    return server


def _filtered_manifest(
    screens: list[str] | None, states: list[str] | None
) -> dict[str, list[str]]:
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
    if not BUILD_DIR.exists():
        raise SystemExit(
            f"{BUILD_DIR} not found. Run "
            "`flutter build web -t lib/main_demo.dart` first."
        )

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
            context = browser.new_context(
                viewport=VIEWPORT, device_scale_factor=DEVICE_SCALE_FACTOR
            )
            page = context.new_page()

            for screen, screen_states in manifest.items():
                screen_dir = OUT_DIR / screen
                screen_dir.mkdir(parents=True, exist_ok=True)
                for state in screen_states:
                    for mode in MODES:
                        url = f"{base_url}?screen={screen}&state={state}&mode={mode}"
                        page.goto(url, wait_until="domcontentloaded")
                        page.wait_for_function(
                            "() => window.flutterDemoReady === true",
                            timeout=READY_TIMEOUT_MS,
                        )
                        out_path = screen_dir / f"{state}--{mode}.png"
                        page.screenshot(path=str(out_path))
                        written.append(out_path)
                        print(f"wrote {out_path.relative_to(REPO_ROOT)}")

            browser.close()
    finally:
        server.shutdown()

    return written


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--screen",
        action="append",
        help="Capture only this screen folder (repeatable). Default: all.",
    )
    parser.add_argument(
        "--state",
        action="append",
        help="Capture only this state (repeatable). Default: all.",
    )
    args = parser.parse_args()

    written = capture(args.screen, args.state)
    print(f"\n{len(written)} PNG(s) written to {OUT_DIR.relative_to(REPO_ROOT)}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
