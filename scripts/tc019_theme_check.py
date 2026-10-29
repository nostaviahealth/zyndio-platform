#!/usr/bin/env python3
"""TC-019 real-app theme/focus/layout/axe check.

Exercises the REAL admin app (not the /__preview harness), signed in for
real against the already-running local Supabase stack `zyndio-local`
(API http://127.0.0.1:54321). Asserts the dark-mode bootstrap, shell/sidebar/
access-denied/toast dark tokens, the focus.ring token on buttons and the
row-actions trigger, the 1024px layout fix, and zero axe-core (wcag2a/2aa)
violations in both themes. Prints one PASS/FAIL line per check and exits
non-zero if anything fails.

Usage:
    python3 scripts/tc019_theme_check.py [--screenshots before|after]

Local Supabase only. Never runs `supabase start/stop/db reset`. Starts
`supabase functions serve` itself (PID file /tmp/tc019-fn.pid, killed by PID
at the end) and serves a production build via a background HTTP server.
Generated passwords/TOTP secrets live only in /tmp/tc019-creds.json (0600).
"""
from __future__ import annotations

import argparse
import functools
import http.server
import os
import re
import signal
import socket
import subprocess
import sys
import threading
import time
from pathlib import Path

from playwright.sync_api import sync_playwright, Page, BrowserContext

REPO_ROOT = Path(__file__).resolve().parent.parent
DIST_DIR = REPO_ROOT / "dist"
AXE_PATH = REPO_ROOT / "node_modules" / "axe-core" / "axe.min.js"
FN_PID_FILE = Path("/tmp/tc019-fn.pid")
CREDS_PATH = Path("/tmp/tc019-creds.json")
SCREENSHOT_ROOT = REPO_ROOT / "docs" / "screenshots" / "tc-019"

FOCUS_LIGHT = "rgb(35, 70, 221)"  # #2346DD
FOCUS_DARK = "rgb(175, 195, 255)"  # #AFC3FF
OLD_RING = "rgb(44, 92, 242)"  # #2C5CF2

RESULTS: list[tuple[bool, str]] = []


def check(ok: bool, label: str) -> bool:
    RESULTS.append((ok, label))
    print(f"{'PASS' if ok else 'FAIL'}: {label}")
    return ok


# ---------------------------------------------------------------------------
# Supabase env + process plumbing
# ---------------------------------------------------------------------------


def supabase_env() -> dict[str, str]:
    out = subprocess.run(["supabase", "status", "-o", "env"], capture_output=True, text=True, check=True).stdout
    env: dict[str, str] = {}
    for line in out.splitlines():
        m = re.match(r'^([A-Z_]+)="(.*)"$', line)
        if m:
            env[m.group(1)] = m.group(2)
    for required in ("API_URL", "ANON_KEY", "SERVICE_ROLE_KEY"):
        if required not in env:
            raise SystemExit(f"supabase status -o env missing {required}")
    return env


def free_port() -> int:
    with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as s:
        s.bind(("127.0.0.1", 0))
        return s.getsockname()[1]


def start_static_server(directory: Path, port: int) -> http.server.ThreadingHTTPServer:
    handler = functools.partial(http.server.SimpleHTTPRequestHandler, directory=str(directory))
    server = http.server.ThreadingHTTPServer(("127.0.0.1", port), handler)
    thread = threading.Thread(target=server.serve_forever, daemon=True)
    thread.start()
    return server


def build_app(env: dict[str, str]) -> None:
    full_env = {
        **os.environ,
        "VITE_SUPABASE_URL": env["API_URL"],
        "VITE_SUPABASE_ANON_KEY": env["ANON_KEY"],
    }
    subprocess.run(["npm", "run", "build"], cwd=REPO_ROOT, env=full_env, check=True)


def start_functions_serve(env: dict[str, str]) -> subprocess.Popen:
    fn_env_file = Path("/tmp/tc019-fn.env")
    fn_env_file.write_text(
        f"JWT_SECRET={env['JWT_SECRET']}\nSUPABASE_URL={env['API_URL']}\nAPI_URL={env['API_URL']}\n"
    )
    os.chmod(fn_env_file, 0o600)
    log = open("/tmp/tc019-functions-serve.log", "w")
    proc = subprocess.Popen(
        ["supabase", "functions", "serve", "--no-verify-jwt", "--env-file", str(fn_env_file)],
        cwd=REPO_ROOT,
        stdout=log,
        stderr=subprocess.STDOUT,
    )
    FN_PID_FILE.write_text(str(proc.pid))
    return proc


def wait_for_functions(env: dict[str, str], timeout_s: int = 60) -> bool:
    import urllib.request

    url = f"{env['API_URL']}/functions/v1/invite-user"
    deadline = time.time() + timeout_s
    while time.time() < deadline:
        try:
            req = urllib.request.Request(url, method="OPTIONS")
            urllib.request.urlopen(req, timeout=2)
            return True
        except Exception:
            time.sleep(0.5)
    return False


def run_seed(env: dict[str, str]) -> dict:
    import json

    full_env = {
        **os.environ,
        "SUPABASE_URL": env["API_URL"],
        "SUPABASE_ANON_KEY": env["ANON_KEY"],
        "SUPABASE_SERVICE_ROLE_KEY": env["SERVICE_ROLE_KEY"],
    }
    result = subprocess.run(
        ["npx", "tsx", "scripts/tc019_seed_local.mts"],
        cwd=REPO_ROOT,
        env=full_env,
        capture_output=True,
        text=True,
    )
    if result.returncode != 0:
        print(result.stdout)
        print(result.stderr, file=sys.stderr)
        raise SystemExit("seed script failed")
    last_line = [l for l in result.stdout.splitlines() if l.strip()][-1]
    json.loads(last_line)  # validate
    if not CREDS_PATH.exists():
        raise SystemExit(f"{CREDS_PATH} missing after seed")
    return json.loads(CREDS_PATH.read_text())


# ---------------------------------------------------------------------------
# TOTP (RFC 6238), no extra dependency
# ---------------------------------------------------------------------------


def totp_code(secret: str, at: float | None = None) -> str:
    import base64
    import hmac
    import struct

    at = at if at is not None else time.time()
    pad = secret + "=" * ((8 - len(secret) % 8) % 8)
    key = base64.b32decode(pad.upper())
    counter = struct.pack(">Q", int(at // 30))
    digest = hmac.new(key, counter, "sha1").digest()
    offset = digest[-1] & 0x0F
    code = (int.from_bytes(digest[offset : offset + 4], "big") & 0x7FFFFFFF) % 1_000_000
    return str(code).zfill(6)


# ---------------------------------------------------------------------------
# App-level helpers
# ---------------------------------------------------------------------------


def goto_hash(page: Page, base_url: str, route: str) -> None:
    page.goto(f"{base_url}#{route}", wait_until="domcontentloaded")


def sign_in(page: Page, base_url: str, email: str, password: str, totp_secret: str) -> None:
    goto_hash(page, base_url, "/admin/login")
    page.get_by_label("Work email").fill(email)
    page.get_by_label("Password", exact=True).fill(password)
    page.get_by_role("button", name="Continue").click()
    page.wait_for_url("**/#/admin/2fa/challenge", timeout=15_000)
    code_input = page.locator("#code-input")
    code_input.wait_for(state="attached", timeout=10_000)
    for attempt in range(2):
        code_input.fill(totp_code(totp_secret))
        try:
            page.wait_for_url("**/#/admin", timeout=8_000)
            return
        except Exception:
            if attempt == 0:
                code_input.fill("")
                continue
            raise
    page.wait_for_url("**/#/admin", timeout=5_000)


def inject_axe(page: Page) -> None:
    page.add_script_tag(path=str(AXE_PATH))


def run_axe(page: Page, label: str, context_selector: str | None = None) -> bool:
    run_js = """
      async (sel) => {
        const opts = { runOnly: { type: 'tag', values: ['wcag2a', 'wcag2aa'] } };
        const target = sel ? document.querySelector(sel) : document;
        const results = await axe.run(target || document, opts);
        return results.violations.map(v => ({
          id: v.id, impact: v.impact, nodes: v.nodes.length,
          summary: v.nodes.slice(0, 2).map(n => n.target.join(' ')),
        }));
      }
    """
    violations = page.evaluate(run_js, context_selector)
    ok = len(violations) == 0
    if not ok:
        for v in violations:
            print(f"    axe violation [{label}] {v['id']} ({v['impact']}) x{v['nodes']}: {v['summary']}")
    return check(ok, f"axe wcag2a/2aa zero violations: {label}")


def parse_box_shadow_layers(box_shadow: str) -> list[tuple[str, int]]:
    """Returns [(rgb_color, spread_px), ...] parsed from a computed box-shadow."""
    layers = []
    for part in re.findall(r"(rgba?\([^)]+\))\s+([\d.-]+px\s+){2,3}([\d.]+)px", box_shadow):
        color, _, spread = part
        layers.append((color, int(float(spread))))
    return layers


def assert_focus_ring(page: Page, locator, label: str, mode: str, surface_rgb: str) -> bool:
    locator.focus()
    box_shadow = page.evaluate("el => getComputedStyle(el).boxShadow", locator.element_handle())
    expected_ring = FOCUS_DARK if mode == "dark" else FOCUS_LIGHT
    has_old_ring = OLD_RING in box_shadow
    layers = parse_box_shadow_layers(box_shadow)
    has_offset = any(spread == 2 and surface_rgb in color for color, spread in layers)
    has_ring = any(spread == 5 and expected_ring in color for color, spread in layers)
    ok = has_ring and has_offset and not has_old_ring
    if not ok:
        print(f"    {label} box-shadow: {box_shadow}")
    return check(ok, f"focus ring token on {label} ({mode}): 3px {expected_ring} / 2px offset, no old ring")


def relative_luminance(rgb: tuple[int, int, int]) -> float:
    def lin(c: int) -> float:
        c = c / 255
        return c / 12.92 if c <= 0.03928 else ((c + 0.055) / 1.055) ** 2.4

    r, g, b = rgb
    return 0.2126 * lin(r) + 0.7152 * lin(g) + 0.0722 * lin(b)


def contrast_ratio(fg: tuple[int, int, int], bg: tuple[int, int, int]) -> float:
    l1, l2 = relative_luminance(fg), relative_luminance(bg)
    hi, lo = max(l1, l2), min(l1, l2)
    return (hi + 0.05) / (lo + 0.05)


def parse_rgb(s: str) -> tuple[int, int, int]:
    m = re.search(r"rgba?\((\d+),\s*(\d+),\s*(\d+)", s)
    if not m:
        raise ValueError(f"not an rgb() colour: {s}")
    return tuple(int(x) for x in m.groups())  # type: ignore[return-value]


def screenshot(page: Page, folder: str | None, name: str, width: int, mode: str) -> None:
    if not folder:
        return
    out_dir = SCREENSHOT_ROOT / folder
    out_dir.mkdir(parents=True, exist_ok=True)
    page.wait_for_timeout(150)
    page.screenshot(path=str(out_dir / f"{name}--{width}--{mode}.png"))


# ---------------------------------------------------------------------------
# Checks
# ---------------------------------------------------------------------------


def check_first_paint_and_flip(browser, base_url: str) -> None:
    for mode in ("dark", "light"):
        ctx = browser.new_context(viewport={"width": 1440, "height": 900}, color_scheme=mode)
        ctx.add_init_script(
            """
            window.__tc019_domReady = null;
            document.addEventListener('DOMContentLoaded', () => {
              window.__tc019_domReady = document.documentElement.className;
            });
            """
        )
        page = ctx.new_page()
        goto_hash(page, base_url, "/admin/login")
        page.wait_for_load_state("domcontentloaded")
        initial_class = page.evaluate("window.__tc019_domReady")
        has_dark = "dark" in (initial_class or "").split()
        check(
            has_dark == (mode == "dark"),
            f"<html> class 'dark' present at DOMContentLoaded iff dark scheme (scheme={mode}, class={initial_class!r})",
        )
        html_class = page.evaluate("document.documentElement.className")
        check(
            ("dark" in html_class.split()) == (mode == "dark"),
            f"<html> class after mount matches scheme ({mode})",
        )
        color_scheme = page.evaluate("getComputedStyle(document.documentElement).colorScheme")
        check(color_scheme == mode, f"computed color-scheme on root is {mode} (got {color_scheme})")

        other = "light" if mode == "dark" else "dark"
        page.emulate_media(color_scheme=other)
        page.wait_for_timeout(100)
        flipped_class = page.evaluate("document.documentElement.className")
        check(
            ("dark" in flipped_class.split()) == (other == "dark"),
            f"<html> class flips live on prefers-color-scheme change ({mode} -> {other})",
        )
        ctx.close()


def check_authenticated(browser, base_url: str, creds: dict, mode: str, screenshots: str | None) -> None:
    surface = "rgb(16, 20, 31)" if mode == "dark" else "rgb(255, 255, 255)"
    ctx = browser.new_context(viewport={"width": 1440, "height": 900}, color_scheme=mode)
    page = ctx.new_page()
    sign_in(page, base_url, creds["orgAdmin"]["email"], creds["orgAdmin"]["password"], creds["orgAdmin"]["totpSecret"])
    goto_hash(page, base_url, "/admin/users")
    page.wait_for_selector("table", timeout=15_000)
    inject_axe(page)

    for width in (1440, 1024):
        page.set_viewport_size({"width": width, "height": 900 if width == 1440 else 768})
        page.wait_for_timeout(150)

        shell_bg = page.evaluate("getComputedStyle(document.querySelector('main').parentElement).backgroundColor")
        expect_shell = "rgb(7, 10, 20)" if mode == "dark" else "rgb(242, 244, 247)"
        check(shell_bg == expect_shell, f"shell canvas bg {mode}@{width} = {expect_shell} (got {shell_bg})")

        sidebar = page.locator("nav[aria-label='Main']")
        sidebar_bg = page.evaluate("el => getComputedStyle(el).backgroundColor", sidebar.element_handle())
        expect_sidebar = "rgb(11, 15, 25)" if mode == "dark" else "rgb(255, 255, 255)"
        check(sidebar_bg == expect_sidebar, f"sidebar bg {mode}@{width} = {expect_sidebar} (got {sidebar_bg})")

        title = page.get_by_role("heading", name="Users and roles")
        title_color = page.evaluate("el => getComputedStyle(el).color", title.element_handle())
        title_bg = parse_rgb(shell_bg)
        title_fg = parse_rgb(title_color)
        ratio = contrast_ratio(title_fg, title_bg)
        check(ratio >= 4.5, f"page title contrast {mode}@{width} >= 4.5:1 (got {ratio:.2f}, fg={title_color})")

        screenshot(page, screenshots, "01-users-list", width, mode)
        run_axe(page, f"users list {mode}@{width}")

        if width == 1024:
            scroll_w = page.evaluate("document.documentElement.scrollWidth")
            inner_w = page.evaluate("window.innerWidth")
            check(scroll_w <= inner_w, f"no horizontal overflow at 1024 {mode} (scrollWidth={scroll_w} innerWidth={inner_w})")

            role_selects = page.locator("select[aria-label^='Change role for']")
            n = role_selects.count()
            min_w = min(role_selects.nth(i).evaluate("el => el.getBoundingClientRect().width") for i in range(n)) if n else 0
            check(n > 0 and min_w >= 150, f"role select width >= 150px at 1024 (min={min_w})")

            invite_btn = page.get_by_role("button", name="Invite user")
            invite_right = invite_btn.evaluate("el => el.getBoundingClientRect().right")
            check(invite_right <= inner_w, f"Invite user button right edge <= viewport at 1024 (right={invite_right}, vw={inner_w})")

            badges = page.locator("span:has-text('days left')")
            if badges.count() > 0:
                white_space = badges.first.evaluate("el => getComputedStyle(el).whiteSpace")
                height = badges.first.evaluate("el => el.getBoundingClientRect().height")
                check(white_space == "nowrap" and height < 30, f"'Invited N days left' badge one line at 1024 (white-space={white_space}, height={height:.0f})")

        if mode == "light":
            count_el = page.get_by_text(re.compile(r"^\d+ people$"))
            count_color = parse_rgb(count_el.evaluate("el => getComputedStyle(el).color"))
            count_bg = parse_rgb(shell_bg)
            ratio = contrast_ratio(count_color, count_bg)
            check(ratio >= 4.5, f"'N people' count contrast light@{width} >= 4.5:1 (got {ratio:.2f})")

            header = page.get_by_role("columnheader", name="Name")
            header_color = parse_rgb(header.evaluate("el => getComputedStyle(el).color"))
            header_row = page.locator("thead tr")
            header_bg = parse_rgb(header_row.evaluate("el => getComputedStyle(el).backgroundColor"))
            ratio = contrast_ratio(header_color, header_bg)
            check(ratio >= 4.5, f"table header text contrast light@{width} >= 4.5:1 (got {ratio:.2f})")

            search = page.get_by_label("Search by name or email")
            search_border = parse_rgb(search.evaluate("el => getComputedStyle(el).borderColor"))
            ratio = contrast_ratio(search_border, count_bg)
            check(ratio >= 3.0, f"search field border contrast light@{width} >= 3:1 vs canvas (got {ratio:.2f})")

        # Focus ring: Invite user button + row actions trigger.
        invite_btn = page.get_by_role("button", name="Invite user")
        assert_focus_ring(page, invite_btn, "Invite user button", mode, surface)
        more_btn = page.locator("button[aria-haspopup='menu']").first
        assert_focus_ring(page, more_btn, "row actions (⋯) trigger", mode, surface)

        # Invite dialog.
        invite_btn.click()
        page.wait_for_selector("#invite-full-name", timeout=5_000)
        screenshot(page, screenshots, "02-invite-dialog", width, mode)
        run_axe(page, f"invite dialog {mode}@{width}")
        if width == 1440:
            radio = page.locator("input[type=radio][name='invite-role']").first
            accent = radio.evaluate("el => getComputedStyle(el).accentColor")
            expect_accent = parse_rgb(FOCUS_DARK if mode == "dark" else FOCUS_LIGHT)
            ok = parse_rgb(accent) == expect_accent
            check(ok, f"invite role radio accent-color matches focus token {mode} (got {accent})")
        page.get_by_role("button", name="Cancel").click()
        page.wait_for_selector("#invite-full-name", state="detached", timeout=5_000)

        # Role-change confirm (coordinator row - not self, not invited/deactivated).
        coord_select = page.locator(f"select[aria-label='Change role for {creds['coordinator']['email']}']")
        current = coord_select.input_value()
        other_role = "read_only" if current != "read_only" else "physician"
        coord_select.select_option(other_role)
        page.wait_for_selector("#role-confirm-title", timeout=5_000)
        screenshot(page, screenshots, "03-role-change-confirm", width, mode)
        run_axe(page, f"role-change confirm {mode}@{width}")
        cancel_btn = page.get_by_role("button", name="Cancel")
        assert_focus_ring(page, cancel_btn, "dialog Cancel button", mode, surface)
        change_btn = page.get_by_role("button", name="Change role")
        assert_focus_ring(page, change_btn, "dialog Change role button", mode, surface)
        cancel_btn.click()
        page.wait_for_selector("[role='alertdialog']", state="detached", timeout=5_000)

        # Cancel-invite confirm (invited row).
        invited_row = page.locator("tr", has_text=creds["invited"]["email"])
        invited_row.get_by_role("button", name=re.compile("More actions")).click()
        page.get_by_role("menuitem", name="Cancel invite").click()
        page.wait_for_selector("text=Cancel the invite", timeout=5_000)
        screenshot(page, screenshots, "04-cancel-invite-confirm", width, mode)
        run_axe(page, f"cancel-invite confirm {mode}@{width}")
        page.get_by_role("button", name="Keep invite").click()
        page.wait_for_selector("[role='alertdialog']", state="detached", timeout=5_000)

        # Toast via Deactivate + Undo (read_only row) - reversible, no data drift.
        ro_row = page.locator("tr", has_text=creds["readOnly"]["email"])
        ro_row.get_by_role("button", name=re.compile("More actions")).click()
        page.get_by_role("menuitem", name="Deactivate").click()
        page.get_by_role("button", name="Deactivate", exact=True).click()
        toast = page.locator("[role='status']")
        toast.wait_for(state="visible", timeout=10_000)
        screenshot(page, screenshots, "05-toast", width, mode)
        run_axe(page, f"toast {mode}@{width}", context_selector="[role='status']")
        toast_bg = parse_rgb(toast.evaluate("el => getComputedStyle(el).backgroundColor"))
        expect_toast = (241, 244, 252) if mode == "dark" else (3, 6, 22)
        check(toast_bg == expect_toast, f"toast bg {mode}@{width} = {expect_toast} (got {toast_bg})")
        page.get_by_role("button", name="Undo").click()
        page.wait_for_selector("[role='status']", state="detached", timeout=10_000)
        # Undo fires reactivateUser() without awaiting it before dismissing
        # the toast - wait for the row to actually come back to 'Active'
        # before the next iteration touches this same fictional row again.
        ro_row.get_by_text("Active", exact=True).wait_for(state="visible", timeout=10_000)

    ctx.close()


def check_access_denied(browser, base_url: str, creds: dict, mode: str, screenshots: str | None) -> None:
    ctx = browser.new_context(viewport={"width": 1440, "height": 900}, color_scheme=mode)
    page = ctx.new_page()
    sign_in(page, base_url, creds["physician"]["email"], creds["physician"]["password"], creds["physician"]["totpSecret"])
    inject_axe(page)
    for width in (1440, 1024):
        page.set_viewport_size({"width": width, "height": 900 if width == 1440 else 768})
        goto_hash(page, base_url, "/admin/users")
        page.wait_for_selector("text=You don't have access", timeout=15_000)
        screenshot(page, screenshots, "06-access-denied", width, mode)
        run_axe(page, f"access-denied {mode}@{width}")
        heading = page.get_by_role("heading", name=re.compile("don't have access"))
        shell_bg = page.evaluate("getComputedStyle(document.querySelector('main').parentElement).backgroundColor")
        heading_color = parse_rgb(heading.evaluate("el => getComputedStyle(el).color"))
        ratio = contrast_ratio(heading_color, parse_rgb(shell_bg))
        check(ratio >= 4.5, f"access-denied heading contrast {mode}@{width} >= 4.5:1 (got {ratio:.2f})")
        expect_shell = "rgb(7, 10, 20)" if mode == "dark" else "rgb(242, 244, 247)"
        check(shell_bg == expect_shell, f"access-denied canvas bg {mode}@{width} = {expect_shell} (got {shell_bg})")
    ctx.close()


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--screenshots", choices=["before", "after"], default=None)
    args = parser.parse_args()

    env = supabase_env()
    print("Building app...")
    build_app(env)

    port = free_port()
    server = start_static_server(DIST_DIR, port)
    base_url = f"http://127.0.0.1:{port}/"

    fn_proc = start_functions_serve(env)
    try:
        if not wait_for_functions(env):
            raise SystemExit("supabase functions serve did not become ready in time")

        print("Seeding fictional local data...")
        creds = run_seed(env)

        with sync_playwright() as p:
            browser = p.chromium.launch()
            try:
                check_first_paint_and_flip(browser, base_url)
                for mode in ("dark", "light"):
                    check_authenticated(browser, base_url, creds, mode, args.screenshots)
                    check_access_denied(browser, base_url, creds, mode, args.screenshots)
            finally:
                browser.close()
    finally:
        if FN_PID_FILE.exists():
            try:
                os.kill(int(FN_PID_FILE.read_text().strip()), signal.SIGTERM)
            except ProcessLookupError:
                pass
            FN_PID_FILE.unlink(missing_ok=True)
        server.shutdown()

    total = len(RESULTS)
    failed = [label for ok, label in RESULTS if not ok]
    print(f"\n{total - len(failed)}/{total} checks passed.")
    if failed:
        print(f"{len(failed)} FAILED:")
        for label in failed:
            print(f"  - {label}")
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
