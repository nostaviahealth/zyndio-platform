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


def run_seed(env: dict[str, str], last: str = "invited") -> dict:
    import json

    full_env = {
        **os.environ,
        "SUPABASE_URL": env["API_URL"],
        "SUPABASE_ANON_KEY": env["ANON_KEY"],
        "SUPABASE_SERVICE_ROLE_KEY": env["SERVICE_ROLE_KEY"],
    }
    result = subprocess.run(
        ["npx", "tsx", "scripts/tc019_seed_local.mts", "--last", last],
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
    # Settle first: the Tailwind CDN runtime generates CSS for a class the
    # first time it appears in the DOM (MutationObserver, async), and Button
    # has transition-colors (150ms). Without this, a dialog opened for the
    # first time is sampled mid-transition with its light-mode colours.
    # TC-021 item 7: wait for the colours to settle instead of a fixed 400ms.
    wait_for_colours_settled(page, context_selector)
    run_js = """
      async (sel) => {
        const opts = { runOnly: { type: 'tag', values: ['wcag2a', 'wcag2aa'] } };
        const target = sel ? document.querySelector(sel) : document;
        const results = await axe.run(target || document, opts);
        return results.violations.map(v => ({
          id: v.id, impact: v.impact, nodes: v.nodes.length,
          summary: v.nodes.slice(0, 2).map(n => n.target.join(' ')),
          details: v.nodes.map(n => (n.html || '').slice(0, 600) + ' :: ' + ((n.any[0] && n.any[0].message) || '')),
        }));
      }
    """
    violations = page.evaluate(run_js, context_selector)
    ok = len(violations) == 0
    if not ok:
        for v in violations:
            print(f"    axe violation [{label}] {v['id']} ({v['impact']}) x{v['nodes']}: {v['summary']}")
            if os.environ.get("TC019_AXE_DETAILS"):
                for d in v.get("details", []):
                    print(f"      - {d}")
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


def box_shadow_layers_full(box_shadow: str) -> list[tuple[str, int, bool]]:
    """[(rgb_color, spread_px, inset), ...] for every layer of a computed box-shadow."""
    layers = []
    for part in re.split(r",(?![^()]*\))", box_shadow or ""):
        m = re.search(r"(rgba?\([^)]+\))\s+((?:[\d.-]+px\s*){2,4})", part)
        if not m:
            continue
        px = re.findall(r"([\d.-]+)px", m.group(2))
        spread = int(float(px[3])) if len(px) >= 4 else 0
        layers.append((m.group(1), spread, "inset" in part))
    return layers


def assert_inset_focus_ring(page: Page, locator, label: str, mode: str) -> bool:
    """TC-021 item 21: a 3px INSET ring in the focus token colour, nothing drawn
    outside the element (no offset layer, no outer ring), and the ring >= 3:1
    against the element's own background (or the nearest opaque one)."""
    locator.focus()
    handle = locator.element_handle()
    box_shadow = page.evaluate("el => getComputedStyle(el).boxShadow", handle)
    expected_ring = FOCUS_DARK if mode == "dark" else FOCUS_LIGHT
    layers = box_shadow_layers_full(box_shadow)
    has_inset_ring = any(inset and spread == 3 and expected_ring in color for color, spread, inset in layers)
    outer = [(c, s) for c, s, inset in layers if not inset and s > 0 and "rgba(0, 0, 0, 0)" not in c]
    bg = parse_rgb(page.evaluate("""el => { let n = el;
      while (n) { const c = getComputedStyle(n).backgroundColor;
        if (c && c !== 'rgba(0, 0, 0, 0)' && c !== 'transparent') return c; n = n.parentElement; }
      return getComputedStyle(document.body).backgroundColor; }""", handle))
    ratio = contrast_ratio(parse_rgb(expected_ring), bg)
    ok = has_inset_ring and not outer and ratio >= 3
    if not ok:
        print(f"    {label} box-shadow: {box_shadow}")
    return check(ok, f"item 21 inset focus ring on {label} ({mode}): 3px inset {expected_ring}, nothing outside the item (outer layers={outer}), ring vs bg {bg} = {ratio:.2f}:1 (>= 3)")


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
    root = REPO_ROOT / "docs" / "screenshots" / "tc-021" if folder.startswith("tc021r2-") else SCREENSHOT_ROOT
    out_dir = root / folder.removeprefix("tc021r2-")
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

            # Card M5: the actions column stays fully visible at 1024. A
            # trigger clipped by an overflow container is not visible even if
            # its rect is inside the viewport, so hit-test its centre and its
            # right edge (elementFromPoint must land on the trigger itself).
            triggers = page.locator("button[aria-haspopup='menu']")
            t_n = triggers.count()
            hidden = []
            for i in range(t_n):
                ok_vis = triggers.nth(i).evaluate(
                    """el => { const r = el.getBoundingClientRect();
                      const pts = [[r.left + r.width / 2, r.top + r.height / 2], [r.right - 2, r.top + r.height / 2]];
                      return r.right <= window.innerWidth && pts.every(([x, y]) => { const h = document.elementFromPoint(x, y); return !!h && (h === el || el.contains(h)); }); }"""
                )
                if not ok_vis:
                    hidden.append(i)
            check(t_n > 0 and not hidden, f"row actions (⋯) column fully visible at 1024 {mode} ({t_n} triggers, hidden={hidden})")

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



# ---------------------------------------------------------------------------
# Fix round (Ava's review of a0e5ddd): F1 last-row menu, F4 auth buttons
# ---------------------------------------------------------------------------

# Menu item hit-test: the item's box is inside the viewport and
# elementFromPoint at its centre and near both ends lands on the item itself
# (nothing paints over it, no ancestor clips it).
HIT_TEST_JS = """el => { const r = el.getBoundingClientRect();
  const inView = r.width > 0 && r.height > 0 && r.left >= 0 && r.top >= 0 &&
    r.right <= window.innerWidth && r.bottom <= window.innerHeight;
  const y = r.top + r.height / 2;
  const pts = [[r.left + r.width / 2, y], [r.left + 6, y], [r.right - 6, y]];
  const hits = pts.map(([x, yy]) => { const h = document.elementFromPoint(x, yy); return !!h && (h === el || el.contains(h)); });
  return { inView, hits, box: [Math.round(r.left), Math.round(r.top), Math.round(r.right), Math.round(r.bottom)],
           vw: window.innerWidth, vh: window.innerHeight }; }"""

# (seed --last key, row email key, menu item to click, how to confirm the click landed)
LAST_ROW_ACTIONS = [
    ("invited", "invited", "Cancel invite"),
    ("lastActive", "lastActive", "Request two-factor reset"),
    ("lastActive", "lastActive", "Deactivate"),
    ("deactivated", "deactivated", "Reactivate"),
]


def check_last_row_menu(browser, base_url: str, creds: dict, env: dict[str, str], mode: str,
                        screenshots: str | None) -> None:
    """F1: open the LAST row's ⋯ menu and click every action from it.

    Each action is opened from the last row of the full list (the seed moves
    the row that has that action to the end). Every menu item must hit-test
    as visible inside the viewport, and the chosen item is clicked with a
    real mouse click at its on-screen centre (no auto-scroll), and the result
    of that click must appear.
    """
    ctx = browser.new_context(viewport={"width": 1440, "height": 900}, color_scheme=mode)
    page = ctx.new_page()
    sign_in(page, base_url, creds["orgAdmin"]["email"], creds["orgAdmin"]["password"], creds["orgAdmin"]["totpSecret"])
    for width in (1024, 1440):
        height = 768 if width == 1024 else 900
        page.set_viewport_size({"width": width, "height": height})
        shot_done = False
        for seed_key, row_key, item_label in LAST_ROW_ACTIONS:
            creds = run_seed(env, last=seed_key)
            email = creds[row_key]["email"]
            label = f"F1 last-row menu {mode}@{width}: {item_label} ({email})"
            goto_hash(page, base_url, "/admin/users")
            page.reload(wait_until="domcontentloaded")
            page.wait_for_selector("table tbody tr", timeout=15_000)
            page.locator("tbody tr", has_text=email).wait_for(timeout=15_000)
            page.wait_for_timeout(300)
            # TC-021 item 13: the old "Failed to load patients" toast used to be
            # waited out here (it covered the last row's trigger at 1024). It
            # is gone (TC-022 #3) and AdminContext toasts now sit bottom-centre,
            # so nothing is waited out: the trigger and menu must hit-test.
            last_row = page.locator("tbody tr").last
            if not check(email in last_row.inner_text(), f"{label}: row is the last row"):
                continue
            trigger = last_row.get_by_role("button", name=re.compile("More actions"))
            trigger.scroll_into_view_if_needed()
            tb = trigger.bounding_box()
            page.mouse.click(tb["x"] + tb["width"] / 2, tb["y"] + tb["height"] / 2)
            menu = page.get_by_role("menu")
            try:
                menu.wait_for(state="attached", timeout=3_000)
            except Exception:
                diag = page.evaluate(
                    """([x, y]) => { const h = document.elementFromPoint(x, y);
                      const t = [...document.querySelectorAll("tbody tr")].pop().querySelector("button[aria-haspopup='menu']");
                      return { hit: h ? h.outerHTML.slice(0, 120) : null, expanded: t && t.getAttribute('aria-expanded'),
                               scrollY: window.scrollY }; }""",
                    [tb["x"] + tb["width"] / 2, tb["y"] + tb["height"] / 2],
                )
                check(False, f"{label}: menu opened (click at trigger centre {diag})")
                continue
            page.wait_for_timeout(250)
            if not shot_done:
                screenshot(page, screenshots, "07-last-row-menu-open", width, mode)
                shot_done = True
            items = menu.get_by_role("menuitem")
            n = items.count()
            bad = []
            for i in range(n):
                res = items.nth(i).evaluate(HIT_TEST_JS)
                if not (res["inView"] and all(res["hits"])):
                    bad.append((items.nth(i).inner_text(), res))
            check(n > 0 and not bad, f"{label}: all {n} menu items visible and unobstructed {bad if bad else ''}")
            target = menu.get_by_role("menuitem", name=item_label, exact=True)
            if target.count() != 1:
                check(False, f"{label}: item present in menu")
                continue
            r = target.evaluate("el => { const b = el.getBoundingClientRect(); return [b.left + b.width / 2, b.top + b.height / 2]; }")
            page.mouse.click(r[0], r[1])
            try:
                if item_label == "Cancel invite":
                    page.wait_for_selector("text=Cancel the invite", timeout=4_000)
                    page.get_by_role("button", name="Keep invite").click()
                elif item_label == "Request two-factor reset":
                    page.get_by_role("alertdialog").or_(page.get_by_role("dialog")).first.wait_for(timeout=4_000)
                    page.get_by_text(re.compile(f"two-factor reset for {re.escape(email)}")).first.wait_for(timeout=4_000)
                    page.keyboard.press("Escape")
                elif item_label == "Deactivate":
                    page.get_by_text(f"Deactivate {email}?").wait_for(timeout=4_000)
                    page.get_by_role("button", name="Cancel").click()
                elif item_label == "Reactivate":
                    page.locator("tbody tr", has_text=email).get_by_text("Active", exact=True).wait_for(timeout=8_000)
                check(True, f"{label}: clicking the item worked")
            except Exception as exc:  # noqa: BLE001 - recorded as a FAIL, run continues
                check(False, f"{label}: clicking the item worked ({type(exc).__name__})")
                page.keyboard.press("Escape")
        # Keyboard + Escape on the real page (last row).
        creds = run_seed(env, last="lastActive")
        goto_hash(page, base_url, "/admin/users")
        page.reload(wait_until="domcontentloaded")
        page.wait_for_selector("table tbody tr", timeout=15_000)
        page.wait_for_timeout(300)
        trigger = page.locator("tbody tr").last.get_by_role("button", name=re.compile("More actions"))
        trigger.focus()
        page.keyboard.press("Enter")
        page.wait_for_timeout(200)
        focused_item = page.evaluate("document.activeElement && document.activeElement.getAttribute('role')")
        check(focused_item == "menuitem", f"F1 keyboard {mode}@{width}: Enter opens the menu and focuses the first item (focus role={focused_item})")
        page.keyboard.press("Escape")
        page.wait_for_timeout(150)
        closed = page.get_by_role("menu").count() == 0
        back = page.evaluate("document.activeElement && document.activeElement.getAttribute('aria-haspopup')")
        check(closed and back == "menu", f"F1 keyboard {mode}@{width}: Escape closes the menu and returns focus to ⋯ (closed={closed})")
    run_seed(env)  # leave the default order (invited last) for the other checks
    ctx.close()


def nearest_bg_js() -> str:
    return """el => { let n = el.parentElement;
      while (n) { const c = getComputedStyle(n).backgroundColor;
        if (c && c !== 'rgba(0, 0, 0, 0)' && c !== 'transparent') return c; n = n.parentElement; }
      return getComputedStyle(document.body).backgroundColor; }"""


def check_auth_button(page: Page, name: str, label: str) -> None:
    btn = page.get_by_role("button", name=name, exact=True)
    btn.wait_for(timeout=10_000)
    wait_for_colours_settled(page)  # TC-021 item 7: Tailwind CDN tick + transition-colors
    bg = parse_rgb(btn.evaluate("el => getComputedStyle(el).backgroundColor"))
    fg = parse_rgb(btn.evaluate("el => getComputedStyle(el).color"))
    surface = parse_rgb(btn.evaluate(nearest_bg_js()))
    text_ratio = contrast_ratio(fg, bg)
    edge_ratio = contrast_ratio(bg, surface)
    check(text_ratio >= 4.5, f"F4 {label}: '{name}' label vs button >= 4.5:1 (got {text_ratio:.2f}, fg={fg} bg={bg})")
    check(edge_ratio >= 3.0, f"F4 {label}: '{name}' button vs surrounding surface >= 3:1 (got {edge_ratio:.2f}, bg={bg} surface={surface})")


def check_auth_pages(browser, base_url: str, creds: dict, mode: str, screenshots: str | None) -> None:
    """F4: sign-in and 2FA with the OS theme set; buttons must match their surface."""
    ctx = browser.new_context(viewport={"width": 1440, "height": 900}, color_scheme=mode)
    page = ctx.new_page()
    goto_hash(page, base_url, "/admin/login")
    page.get_by_label("Work email").wait_for(timeout=15_000)
    inject_axe(page)
    check_auth_button(page, "Continue", f"sign-in {mode}")
    screenshot(page, screenshots, "00a-sign-in", 1440, mode)
    run_axe(page, f"sign-in {mode}")
    page.get_by_label("Work email").fill(creds["orgAdmin"]["email"])
    page.get_by_label("Password", exact=True).fill(creds["orgAdmin"]["password"])
    page.get_by_role("button", name="Continue").click()
    page.wait_for_url("**/#/admin/2fa/challenge", timeout=15_000)
    page.locator("#code-input").wait_for(state="attached", timeout=10_000)
    inject_axe(page)
    check_auth_button(page, "Verify", f"2FA {mode}")
    screenshot(page, screenshots, "00b-2fa", 1440, mode)
    run_axe(page, f"2FA challenge {mode}")
    ctx.close()


# ---------------------------------------------------------------------------
# TC-021 round 2 (items 6, 7, 10, 13, 14): real-app checks, both themes
# ---------------------------------------------------------------------------

SURFACE = {"dark": (16, 20, 31), "light": (255, 255, 255)}       # bg.surface
SIDEBAR = {"dark": (11, 15, 25), "light": (255, 255, 255)}       # sidebar bg
EDGE = {"dark": "rgb(34, 40, 56)", "light": "rgb(226, 232, 240)"}  # pinned-column edge
THUMB = {"dark": (108, 118, 144), "light": (203, 213, 225)}      # #6C7690 / #CBD5E1


def rgb_str(rgb: tuple[int, int, int]) -> str:
    return f"rgb({rgb[0]}, {rgb[1]}, {rgb[2]})"


def wait_for_colours_settled(page: Page, selector: str | None = None, timeout_ms: int = 5_000) -> None:
    """Item 7: replaces the fixed 400 ms wait. Resolves once no CSS
    transition/animation is running and the computed colours of the target
    (and its descendants) are identical over 3 consecutive animation frames,
    i.e. the Tailwind CDN has generated the classes and transitions are done."""
    settled = page.evaluate(
        """([sel, timeoutMs]) => new Promise((resolve) => {
          const root = (sel && document.querySelector(sel)) || document.body;
          const snap = () => [root, ...root.querySelectorAll('*')].slice(0, 400).map((el) => {
            const s = getComputedStyle(el);
            return s.color + '|' + s.backgroundColor + '|' + s.borderTopColor + '|' + s.boxShadow;
          }).join(';');
          // Finite transitions/animations only (a spinner never "finishes").
          const busy = () => document.getAnimations().some((a) => a.playState === 'running' &&
            !(a.effect && a.effect.getTiming && a.effect.getTiming().iterations === Infinity));
          const deadline = performance.now() + timeoutMs;
          let last = null, same = 0;
          const step = () => {
            const now = snap();
            same = !busy() && now === last ? same + 1 : 0;
            last = now;
            if (same >= 3) resolve(true);
            else if (performance.now() > deadline) resolve(false);
            else requestAnimationFrame(step);
          };
          requestAnimationFrame(step);
        })""",
        [selector, timeout_ms],
    )
    if not settled:
        raise RuntimeError(f"colours did not settle within {timeout_ms} ms ({selector or 'body'})")


def computed(locator, prop: str) -> str:
    return locator.evaluate(f"el => getComputedStyle(el).{prop}")


def thumb_pixels(page: Page, box: dict, rgb: tuple[int, int, int], tol: int = 6) -> int:
    from io import BytesIO
    from PIL import Image

    png = page.screenshot(clip=box)
    img = Image.open(BytesIO(png)).convert("RGB")
    return sum(1 for px in img.getdata() if all(abs(a - b) <= tol for a, b in zip(px, rgb)))


def check_tc021_round2(browser, scrollbar_browser, base_url: str, creds: dict, mode: str, screenshots: str | None) -> None:
    oa = creds["orgAdmin"]
    shots = f"tc021r2-{screenshots}" if screenshots else None
    ctx = browser.new_context(viewport={"width": 1024, "height": 768}, color_scheme=mode)
    page = ctx.new_page()
    sign_in(page, base_url, oa["email"], oa["password"], oa["totpSecret"])
    goto_hash(page, base_url, "/admin/users")
    page.wait_for_selector("table tbody tr", timeout=15_000)
    wait_for_colours_settled(page)
    inject_axe(page)

    # Item 13: the "Failed to load patients" toast (TC-022 #3 removed its
    # fetch) never appears, so nothing is waited out before the clicks below.
    check(page.get_by_text("Failed to load patients").count() == 0, f"item 13 {mode}@1024: no 'Failed to load patients' toast on the users page")

    # Item 10 F2: the table scrolls inside its card at 1024 and the pinned
    # actions column has an edge.
    scroller = page.locator("table").locator("xpath=..")
    sw, cw = scroller.evaluate("el => [el.scrollWidth, el.clientWidth]")
    check(sw > cw, f"item 10 F2 {mode}@1024: the users table scrolls sideways in its card (scrollWidth={sw} > clientWidth={cw})")
    screenshot(page, shots, "10-table-scroll-start", 1024, mode)
    scroller.evaluate("el => { el.scrollLeft = el.scrollWidth; }")
    moved = scroller.evaluate("el => el.scrollLeft")
    check(moved > 0, f"item 10 F2 {mode}@1024: table scrolled to the end (scrollLeft={moved})")
    wait_for_colours_settled(page)
    screenshot(page, shots, "10-table-scroll-end", 1024, mode)
    pinned_th = page.locator("thead th").last
    pinned_td = page.locator("tbody tr").first.locator("td").last
    for label, cell in (("header", pinned_th), ("cell", pinned_td)):
        shadow = computed(cell, "boxShadow")
        check(EDGE[mode] in shadow and "inset" in shadow, f"item 10 F2 {mode}@1024: pinned actions {label} has a 1px left edge {EDGE[mode]} (box-shadow={shadow})")
    scroller.evaluate("el => { el.scrollLeft = 0; }")
    # Item 25: where the pinned ⋯ column starts at 1024 (used by the toast check below).
    actions_left = pinned_th.evaluate("el => el.getBoundingClientRect().left")

    # Item 10 F5: sidebar link focus ring (offset = sidebar surface).
    link = page.locator("nav[aria-label='Main'] a").first
    assert_focus_ring(page, link, "sidebar link", mode, rgb_str(SIDEBAR[mode]))
    # Item 20: the sidebar sign-out button gets the same ring as the links.
    sign_out = page.locator("nav[aria-label='Main']").get_by_role("button", name="Sign out")
    assert_focus_ring(page, sign_out, "sidebar sign-out button", mode, rgb_str(SIDEBAR[mode]))
    screenshot(page, shots, "20-sidebar-sign-out-focus", 1024, mode)
    link.focus()

    # Items 6 + 7: last row's ⋯ menu - dark tokens, focus on open, arrows,
    # menu-item focus ring.
    last_row = page.locator("tbody tr").last
    trigger = last_row.get_by_role("button", name=re.compile("More actions"))
    trigger.scroll_into_view_if_needed()
    tb = trigger.bounding_box()
    page.mouse.click(tb["x"] + tb["width"] / 2, tb["y"] + tb["height"] / 2)
    menu = page.get_by_role("menu")
    menu.wait_for(state="visible", timeout=3_000)
    wait_for_colours_settled(page, "[role='menu']")
    panel_bg = parse_rgb(computed(menu, "backgroundColor"))
    check(panel_bg == SURFACE[mode], f"item 6 {mode}: ⋯ menu panel bg = bg.surface {SURFACE[mode]} (got {panel_bg})")
    items = menu.get_by_role("menuitem")
    n = items.count()
    worst = min(contrast_ratio(parse_rgb(computed(items.nth(i), "color")), panel_bg) for i in range(n)) if n else 0
    check(n > 0 and worst >= 4.5, f"item 6 {mode}: every ⋯ menu item label >= 4.5:1 on the panel (min {worst:.2f})")
    screenshot(page, shots, "06-last-row-menu-open", 1024, mode)
    run_axe(page, f"item 6 ⋯ menu open {mode}@1024", context_selector="[role='menu']")
    focused = page.evaluate("document.activeElement && document.activeElement.getAttribute('role')")
    check(focused == "menuitem", f"item 7 {mode}: opening the menu by click moves focus to the first item (focus role={focused})")
    first_label = items.nth(0).inner_text()
    page.keyboard.press("ArrowDown")
    second = page.evaluate("document.activeElement && document.activeElement.textContent")
    check(n < 2 or (second and second.strip() == items.nth(1).inner_text().strip()), f"item 7 {mode}: ArrowDown on the last row's {n}-item menu moves from '{first_label}' to the next item (now {second!r})" + (" [1 item: wraps to itself; see the >= 2-item check below]" if n < 2 else ""))
    page.keyboard.press("ArrowUp")
    focused_item = page.locator("[role='menuitem']:focus")
    assert_inset_focus_ring(page, focused_item, "⋯ menu item", mode)
    screenshot(page, shots, "07-menu-item-focus", 1024, mode)
    page.keyboard.press("Escape")

    # Item 7: the last row's menu can have a single item (an invite), which
    # makes the ArrowDown check above vacuous. Repeat it on the last row whose
    # menu has at least two items; fail if no such row exists.
    rows = page.locator("tbody tr")
    arrow_checked = False
    for r in range(rows.count() - 1, -1, -1):
        trig = rows.nth(r).get_by_role("button", name=re.compile("More actions"))
        if trig.count() == 0:
            continue
        trig.scroll_into_view_if_needed()
        trig.click()
        m = page.get_by_role("menu")
        m.wait_for(state="visible", timeout=3_000)
        its = m.get_by_role("menuitem")
        if its.count() < 2:
            page.keyboard.press("Escape")
            continue
        labels = [its.nth(i).inner_text().strip() for i in range(its.count())]
        page.keyboard.press("ArrowDown")
        now = (page.evaluate("document.activeElement && document.activeElement.textContent") or "").strip()
        check(now == labels[1], f"item 7 {mode}: ArrowDown on a {len(labels)}-item menu moves '{labels[0]}' -> '{labels[1]}' (now {now!r})")
        page.keyboard.press("ArrowUp")
        now = (page.evaluate("document.activeElement && document.activeElement.textContent") or "").strip()
        check(now == labels[0], f"item 7 {mode}: ArrowUp moves back to '{labels[0]}' (now {now!r})")
        page.keyboard.press("Escape")
        arrow_checked = True
        break
    check(arrow_checked, f"item 7 {mode}: found a row whose ⋯ menu has >= 2 items for the arrow-key check")

    # Item 14: scroll the users page to the bottom; the sidebar background
    # must still fill the viewport from top to bottom.
    page.set_viewport_size({"width": 1024, "height": 600})
    page.evaluate("window.scrollTo(0, document.documentElement.scrollHeight)")
    page.wait_for_timeout(50)
    scroll_y = page.evaluate("window.scrollY")
    check(scroll_y > 0, f"item 14 {mode}@1024x600: the users page scrolls (scrollY={scroll_y})")
    nav_box = page.evaluate("(() => { const r = document.querySelector(\"nav[aria-label='Main']\").getBoundingClientRect(); return [r.top, r.bottom, window.innerHeight]; })()")
    bottom_hit = page.evaluate(
        "(() => { const h = document.elementFromPoint(20, window.innerHeight - 3); return !!h && !!h.closest(\"nav[aria-label='Main']\"); })()"
    )
    check(nav_box[0] <= 0.5 and nav_box[1] >= nav_box[2] - 0.5 and bottom_hit,
          f"item 14 {mode}@1024x600 scrolled: sidebar covers the full viewport height (top={nav_box[0]:.0f}, bottom={nav_box[1]:.0f}, vh={nav_box[2]}, bottom-left pixel in sidebar={bottom_hit})")
    screenshot(page, shots, "14-sidebar-scrolled", 1024, mode)
    ctx.close()

    # Item 7: the scrollbar thumb follows the theme. Needs a browser that
    # draws scrollbars (Playwright hides them by default in headless).
    sctx = scrollbar_browser.new_context(viewport={"width": 1024, "height": 768}, color_scheme=mode)
    spage = sctx.new_page()
    sign_in(spage, base_url, oa["email"], oa["password"], oa["totpSecret"])
    goto_hash(spage, base_url, "/admin/users")
    spage.wait_for_selector("table tbody tr", timeout=15_000)
    wait_for_colours_settled(spage)
    sbox = spage.locator("table").locator("xpath=..").evaluate(
        "el => { el.scrollIntoView({ block: 'end' }); const r = el.getBoundingClientRect(); return { x: r.left, y: r.bottom - 6, width: r.width, height: 6 }; }"
    )
    own = thumb_pixels(spage, sbox, THUMB[mode])
    other = thumb_pixels(spage, sbox, THUMB["light" if mode == "dark" else "dark"])
    check(own > 20 and other == 0, f"item 7 {mode}: table scrollbar thumb is {THUMB[mode]} ({own} px), none in the other theme's colour ({other} px)")
    screenshot(spage, shots, "07-scrollbar", 1024, mode)
    sctx.close()

    # Item 13: IdleWarningDialog colours in this theme (clock fast-forwarded
    # past the 13 min warning; the session stays valid).
    ictx = browser.new_context(viewport={"width": 1024, "height": 768}, color_scheme=mode)
    ipage = ictx.new_page()
    ipage.clock.install()
    sign_in(ipage, base_url, oa["email"], oa["password"], oa["totpSecret"])
    goto_hash(ipage, base_url, "/admin/users")
    ipage.wait_for_selector("table tbody tr", timeout=15_000)
    ipage.clock.fast_forward("13:01")
    dialog = ipage.get_by_role("alertdialog")
    dialog.wait_for(state="visible", timeout=5_000)
    wait_for_colours_settled(ipage, "[role='alertdialog']")
    d_bg = parse_rgb(computed(dialog, "backgroundColor"))
    check(d_bg == SURFACE[mode], f"item 13 {mode}: IdleWarningDialog bg = bg.surface {SURFACE[mode]} (got {d_bg})")
    for sel, what in (("#idle-warning-title", "title"), ("#idle-warning-body", "body"), ("[role='timer']", "countdown")):
        fg = parse_rgb(computed(dialog.locator(sel), "color"))
        ratio = contrast_ratio(fg, d_bg)
        check(ratio >= 4.5, f"item 13 {mode}: IdleWarningDialog {what} >= 4.5:1 (got {ratio:.2f}, fg={fg})")
    inject_axe(ipage)
    run_axe(ipage, f"item 13 IdleWarningDialog {mode}@1024", context_selector="[role='alertdialog']")
    screenshot(ipage, shots, "13-idle-warning", 1024, mode)
    ipage.get_by_role("button", name="Stay signed in").click()
    ictx.close()

    # Item 25 (Clara, #21; CI fix round 1, 1 Nov 2026): item 13's toast fix
    # must be checked on the real toast, raised by a REAL successful submit -
    # a check that also passed on a failure toast could never actually catch
    # Create Patient breaking. The regex this used to wait on (either the old
    # failure copy or the success copy) matched neither: TC-018's rewrite
    # (b741c04) dropped the AdminContext toast entirely on success, showing
    # only a full-page "Patient Created Successfully!" card, so the check
    # always timed out regardless of pass/fail. Fixed by restoring the
    # showToast('Patient created successfully', ...) call in
    # CreatePatient.tsx (see docs/tasks/TC-018.md, Henry's calls 1 Nov 2026).
    # Email is unique per mode (dark/light) so the two passes don't collide
    # on the same patient account.
    tctx = browser.new_context(viewport={"width": 1024, "height": 768}, color_scheme=mode)
    tpage = tctx.new_page()
    ph = creds["physician"]
    sign_in(tpage, base_url, ph["email"], ph["password"], ph["totpSecret"])
    goto_hash(tpage, base_url, "/admin/patients/create")
    # TC-018 (Create Patient add-on) pointed this form at the real patients
    # table and dropped every field without a real column - name/email
    # placeholders changed ("Jane Doe" / "jane@example.com") and age (was
    # "35") has no column to hold it, so it's gone rather than renamed.
    tpage.get_by_placeholder("Jane Doe").fill("Fictional Rowan Testcase")
    tpage.get_by_placeholder("jane@example.com").fill(f"tc021-item25-{mode}@example.test")
    with tpage.expect_response(lambda r: "/functions/v1/create-patient" in r.url) as resp_info:
        tpage.get_by_role("button", name="Create Patient").click()
    response = resp_info.value
    check(
        response.status == 200,
        f"item 25 {mode}@1024: Create Patient's submit reaches the server and succeeds (got {response.status})",
    )
    toast_text = tpage.get_by_text("Patient created successfully", exact=True)
    shown = True
    try:
        toast_text.wait_for(state="visible", timeout=10_000)
    except Exception:
        shown = False
    if check(shown, f"item 25 {mode}@1024: Create Patient raises the AdminContext success toast"):
        box = toast_text.evaluate(
            "el => { const t = el.closest('.fixed') || el; const r = t.getBoundingClientRect();"
            " return { left: r.left, right: r.right, bottom: r.bottom, vw: window.innerWidth, vh: window.innerHeight }; }"
        )
        centre_off = abs((box["left"] + box["right"]) / 2 - box["vw"] / 2)
        check(centre_off <= 2, f"item 25 {mode}@1024: AdminContext toast is bottom-centre (centre off by {centre_off:.1f}px, box={box})")
        check(box["right"] <= actions_left, f"item 25 {mode}@1024: AdminContext toast (right={box['right']:.0f}) is clear of the pinned ⋯ column (left={actions_left:.0f})")
        screenshot(tpage, shots, "25-admin-toast", 1024, mode)
    tctx.close()


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--screenshots", choices=["before", "after", "fixround-before", "fixround-after", "round2-before", "round2-after", "round2-ci"], default=None)
    parser.add_argument("--only", choices=["fixround", "tc021r2"], default=None,
                        help="run only the fix-round checks (F1 last-row menu, F4 auth buttons) or only the TC-021 round-2 checks")
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
            # TC-021 item 7: a second browser that draws scrollbars (Playwright
            # passes --hide-scrollbars in headless by default).
            scrollbar_browser = p.chromium.launch(ignore_default_args=["--hide-scrollbars"])
            round2_shots = None
            if args.screenshots in ("round2-before", "round2-after", "round2-ci"):
                round2_shots, args.screenshots = args.screenshots, None
            try:
                if args.only is None:
                    check_first_paint_and_flip(browser, base_url)
                for mode in ("dark", "light"):
                    if args.only in (None, "tc021r2"):
                        check_tc021_round2(browser, scrollbar_browser, base_url, creds, mode, round2_shots)
                    if args.only == "tc021r2":
                        continue
                    check_auth_pages(browser, base_url, creds, mode, args.screenshots)
                    check_last_row_menu(browser, base_url, creds, env, mode, args.screenshots)
                    if args.only is None:
                        check_authenticated(browser, base_url, creds, mode, args.screenshots)
                        check_access_denied(browser, base_url, creds, mode, args.screenshots)
            finally:
                scrollbar_browser.close()
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
