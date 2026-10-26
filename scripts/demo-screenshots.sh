#!/usr/bin/env bash
# TC-008 demo screenshot harness: builds nothing itself, just serves the
# already-built flutter_app/build/web and drives headless Chromium via
# scripts/demo_screenshots.py. Run
# `flutter build web -t lib/main_demo.dart --dart-define=DEMO_BUILD=true`
# first (the dart-define is required or the demo auto-sign-in/debug code
# compiles out and the harness has nothing to screenshot). Accepts the same
# flags as the Python script, e.g. --screen signin.
set -euo pipefail

REPO_ROOT="$(git -C "$(dirname "${BASH_SOURCE[0]}")" rev-parse --show-toplevel)"
cd "$REPO_ROOT"

exec python3 scripts/demo_screenshots.py "$@"
