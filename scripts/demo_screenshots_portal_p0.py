#!/usr/bin/env python3
"""Physician-portal P0 (POR-03..06, PP-01) preview screenshots.

Reuses the TC-015 harness driver (scripts/demo_screenshots_tc015.py: serves the
`npm run build:preview` bundle, drives headless Chromium to
`#/__preview?screen=...&state=...&mode=...`, light + dark, desktop + tablet)
with this PR's screens and states.

Output:
    docs/screenshots/portal-p0/<screen>/<state>--<mode>.png          (desktop)
    docs/screenshots/portal-p0/<screen>/tablet/<state>--<mode>.png   (tablet)
    docs/screenshots/portal-p0/INDEX.md

Usage:
    npm run build:preview
    python3 scripts/demo_screenshots_portal_p0.py [--screen NAME ...] [--state NAME ...]
"""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import demo_screenshots_tc015 as harness  # noqa: E402

harness.OUT_DIR = harness.REPO_ROOT / "docs" / "screenshots" / "portal-p0"
harness.MANIFEST = {
    # POR-03 / POR-04 / POR-05 caveat / POR-06 read-only export block
    "02-patient-detail": ["timeline", "timeline-empty", "brief", "approved-ranges", "read-only"],
    # POR-05 range sets: live only, live + draft, none yet, read-only viewer
    "08-reference-ranges": ["default", "draft", "none", "read-only"],
    # PP-01 plan and modules
    "09-plan-modules": ["default"],
}


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--screen", action="append", help="Capture only this screen folder (repeatable). Default: all.")
    parser.add_argument("--state", action="append", help="Capture only this state (repeatable). Default: all.")
    args = parser.parse_args()

    written = harness.capture(args.screen, args.state)
    index_path = harness.write_index(written)
    index_path.write_text(
        index_path.read_text().replace("# TC-015 physician-portal screenshots", "# Physician portal P0 screenshots (POR-03..06, PP-01)", 1)
    )
    print(f"\n{len(written)} PNG(s) written to {harness.OUT_DIR.relative_to(harness.REPO_ROOT)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
