#!/usr/bin/env bash
# TC-023: pin the Zyndio app icons installed from Ava's handoff
# (/workspace/design/team3/zyndio/handoff/icons). Fails CI when:
#   - any installed icon differs from the sha256 pinned in scripts/app-icons.sha256
#   - iOS has more than one app icon set, or the 1024 marketing icon has alpha
#   - an asset catalog Contents.json names a file that is missing
#   - Android still uses the old 16% inset / drawable foreground / #2C5CF2 background,
#     or an old drawable-*/ic_launcher_foreground.png comes back
#   - the flutter_launcher_icons generator (dependency or config) comes back
#   - index.html head icon lines or site.webmanifest icons point at missing files
#   - the old root favicon.png comes back
# TC-023 follow-up:
#   - the old in-app mark (assets/icons/app_icon*.png before Ava's handoff) is
#     anywhere under flutter_app/, or a Dart asset reference to it is missing
#   - the Android notification icon ic_stat_zyndio is missing in a density, is not
#     white-on-transparent, or Firebase's default_notification_icon does not use it
#   - <application> (and the default launcher alias) has no android:roundIcon
# Optional: ICON_HANDOFF_DIR=<handoff dir> also checks the pins against the handoff.
# Uses python3 standard library only.
set -euo pipefail
ROOT="$(git -C "$(dirname "${BASH_SOURCE[0]}")" rev-parse --show-toplevel)"
cd "$ROOT"
exec python3 - "$@" <<'PY'
import hashlib, json, os, re, struct, sys, glob, zlib
import xml.etree.ElementTree as ET

fail = 0
def err(msg):
    global fail
    print(f"FAIL: {msg}", file=sys.stderr); fail = 1
def ok(msg):
    print(f"OK: {msg}")

def sha(p):
    with open(p, 'rb') as f:
        return hashlib.sha256(f.read()).hexdigest()

def png_info(p):
    """Return (width, height, colour type, has tRNS) for a PNG, or None."""
    with open(p, 'rb') as f:
        data = f.read()
    if data[:8] != b'\x89PNG\r\n\x1a\n':
        return None
    w, h, _depth, ctype = struct.unpack('>IIBB', data[16:26])
    pos, trns = 8, False
    while pos + 8 <= len(data):
        ln, typ = struct.unpack('>I4s', data[pos:pos + 8])
        if typ == b'tRNS': trns = True
        if typ == b'IEND': break
        pos += 12 + ln
    return w, h, ctype, trns

# 1. Pinned hashes.
PIN = 'scripts/app-icons.sha256'
pins = []
for line in open(PIN):
    line = line.strip()
    if not line or line.startswith('#'): continue
    digest, repo_path, handoff_path = line.split()
    pins.append((digest, repo_path, handoff_path))
bad = 0
for digest, repo_path, _ in pins:
    if not os.path.isfile(repo_path):
        err(f"{repo_path} is missing"); bad += 1
    elif sha(repo_path) != digest:
        err(f"{repo_path} does not match Ava's handoff (sha256 differs from {PIN})"); bad += 1
if not bad: ok(f"{len(pins)} installed icon files match the pinned handoff hashes")

handoff = os.environ.get('ICON_HANDOFF_DIR')
if handoff:
    hb = 0
    for digest, repo_path, handoff_path in pins:
        hp = os.path.join(handoff, handoff_path)
        if not os.path.isfile(hp) or sha(hp) != digest:
            err(f"pin for {repo_path} does not match handoff {handoff_path}"); hb += 1
    if not hb: ok(f"all {len(pins)} pins match the handoff at {handoff}")

# 2. iOS: exactly one app icon set, every Contents.json file present, 1024 opaque.
XC = 'flutter_app/ios/Runner/Assets.xcassets'
sets = sorted(glob.glob(f'{XC}/*.appiconset'))
if [os.path.basename(s) for s in sets] == ['AppIcon.appiconset']:
    ok("iOS has exactly one app icon set (AppIcon.appiconset)")
else:
    err(f"iOS must have exactly one app icon set, AppIcon.appiconset (found: {sets})")
for s in sets:
    contents = json.load(open(f'{s}/Contents.json'))
    names = [i['filename'] for i in contents.get('images', []) if 'filename' in i]
    missing = [n for n in names if not os.path.isfile(f'{s}/{n}')]
    if missing: err(f"{s}/Contents.json names missing files: {missing}")
    else: ok(f"{s}/Contents.json: all {len(names)} files present")
    if any(i.get('appearances') for i in contents.get('images', [])):
        err(f"{s}/Contents.json has a dark/tinted appearance entry (TC-023: no dark variant)")
    big = [i['filename'] for i in contents.get('images', [])
           if i.get('size') == '1024x1024' and 'filename' in i]
    if not big: err(f"{s} has no 1024x1024 icon")
    for n in big:
        p = f'{s}/{n}'
        if not os.path.isfile(p): continue
        info = png_info(p)
        if info is None:
            err(f"{p} is not a PNG"); continue
        w, h, ctype, trns = info
        if (w, h) != (1024, 1024): err(f"{p} is {w}x{h}, expected 1024x1024")
        if ctype in (4, 6) or trns:
            err(f"{p} has an alpha channel (colour type {ctype}, tRNS={trns}); App Store rejects it")
        else:
            ok(f"{p} is 1024x1024 with no alpha (colour type {ctype})")

# 3. Android adaptive icon.
RES = 'flutter_app/android/app/src/main/res'
for name in ('ic_launcher.xml', 'ic_launcher_round.xml'):
    p = f'{RES}/mipmap-anydpi-v26/{name}'
    if not os.path.isfile(p): err(f"{p} missing"); continue
    x = open(p).read()
    probs = []
    if 'inset' in x: probs.append('uses an inset')
    if '@drawable/ic_launcher_foreground' in x: probs.append('uses the old drawable foreground')
    if '@mipmap/ic_launcher_foreground' not in x: probs.append('no mipmap foreground')
    if '@mipmap/ic_launcher_monochrome' not in x: probs.append('no monochrome layer')
    if probs: err(f"{p}: {', '.join(probs)}")
    else: ok(f"{p}: mipmap foreground + monochrome, no inset")
colors = open(f'{RES}/values/colors.xml').read()
m = re.search(r'<color name="ic_launcher_background">\s*([^<\s]+)\s*</color>', colors)
if m and m.group(1).upper() == '#FFFFFF':
    ok("ic_launcher_background = #FFFFFF")
else:
    err(f"ic_launcher_background must be #FFFFFF (got {m.group(1) if m else 'missing'})")
dupes = [p for p in glob.glob(f'{RES}/values*/*.xml')
         if p != f'{RES}/values/colors.xml' and 'name="ic_launcher_background"' in open(p).read()]
if dupes: err(f"duplicate ic_launcher_background resource in {dupes}")
old_fg = sorted(glob.glob(f'{RES}/drawable*/ic_launcher_foreground.png'))
if old_fg: err(f"old drawable foregrounds are back: {old_fg}")
else: ok("no old drawable-*/ic_launcher_foreground.png")
for d in ('mdpi', 'hdpi', 'xhdpi', 'xxhdpi', 'xxxhdpi'):
    for n in ('ic_launcher', 'ic_launcher_round', 'ic_launcher_foreground', 'ic_launcher_monochrome'):
        if not os.path.isfile(f'{RES}/mipmap-{d}/{n}.png'):
            err(f"{RES}/mipmap-{d}/{n}.png missing")

# 4. The icon generator must not come back.
gen = []
pub = open('flutter_app/pubspec.yaml').read()
if re.search(r'^\s*flutter_launcher_icons\s*:', pub, re.M): gen.append('flutter_app/pubspec.yaml')
lock = open('flutter_app/pubspec.lock').read()
if re.search(r'^\s*flutter_launcher_icons\s*:', lock, re.M): gen.append('flutter_app/pubspec.lock')
for p in glob.glob('flutter_app/flutter_launcher_icons*.yaml'): gen.append(p)
if gen: err(f"flutter_launcher_icons generator is back in {gen}; it would overwrite the handoff icons")
else: ok("no flutter_launcher_icons dependency or config")

# 5. Web: head lines and manifest references resolve in public/.
html = open('index.html').read()
head = html.split('</head>')[0]
links = re.findall(r'<link\b[^>]*>', head)
want = {('icon', '/favicon.ico'), ('icon', '/favicon-32.png'), ('icon', '/favicon-16.png'),
        ('apple-touch-icon', '/apple-touch-icon.png'), ('manifest', '/site.webmanifest')}
found = set()
for l in links:
    rel = re.search(r'rel="([^"]+)"', l); href = re.search(r'href="([^"]+)"', l)
    if not rel or not href: continue
    if rel.group(1) in ('icon', 'apple-touch-icon', 'manifest', 'shortcut icon'):
        found.add((rel.group(1), href.group(1)))
        if not os.path.isfile('public' + href.group(1)):
            err(f"index.html {rel.group(1)} -> {href.group(1)} does not exist in public/")
if want - found: err(f"index.html is missing head lines: {sorted(want - found)}")
if found - want: err(f"index.html has unexpected icon links: {sorted(found - want)}")
if found == want: ok("index.html head has the 5 handoff icon/manifest lines, all resolve in public/")
if os.path.isfile('public/site.webmanifest'):
    man = json.load(open('public/site.webmanifest'))
    mb = 0
    for icon in man.get('icons', []):
        p = 'public' + icon['src']
        if not os.path.isfile(p): err(f"site.webmanifest icon {icon['src']} missing"); mb += 1; continue
        info = png_info(p)
        w, h = (info[0], info[1]) if info else (None, None)
        if icon.get('sizes') != f'{w}x{h}':
            err(f"site.webmanifest says {icon['src']} is {icon.get('sizes')}, file is {w}x{h}"); mb += 1
    if not man.get('icons'): err("site.webmanifest has no icons"); mb += 1
    if not mb: ok(f"site.webmanifest: {len(man['icons'])} icons resolve with matching sizes")
else:
    err("public/site.webmanifest missing")
if os.path.exists('favicon.png'): err("old root favicon.png is back (icons live in public/)")
else: ok("no root favicon.png")

# 6. TC-023 follow-up: in-app mark, notification icon, roundIcon.
# 6a. The old in-app mark must not come back under any name. These are the
#     sha256 of the pre-handoff assets/icons/app_icon.png (== app_icon_opaque.png)
#     and app_icon_foreground.png on main at 548d726.
OLD_MARKS = {
    'a87de688bc52b6902e2a682a95bf60ba8e5c89d779d3c70bfe6797c6234abb44': 'old app_icon.png / app_icon_opaque.png',
    '0515939f770c9b50a7b5621a8b25798e7fd356419108d722e3ebef41a0a82689': 'old app_icon_foreground.png',
}
old_hits = []
for dirpath, dirnames, files in os.walk('flutter_app'):
    dirnames[:] = [d for d in dirnames if d not in ('build', '.dart_tool', 'Pods', '.gradle')]
    for n in files:
        if n.lower().endswith('.png'):
            p = os.path.join(dirpath, n)
            if sha(p) in OLD_MARKS: old_hits.append(f"{p} ({OLD_MARKS[sha(p)]})")
if old_hits: err(f"the old in-app mark is back: {old_hits}")
else: ok("old in-app mark appears nowhere under flutter_app/")
refs = set()
for dirpath, _d, files in os.walk('flutter_app/lib'):
    for n in files:
        if n.endswith('.dart'):
            refs.update(re.findall(r"assets/icons/app_icon[A-Za-z0-9_]*\.png", open(os.path.join(dirpath, n)).read()))
missing_refs = sorted(r for r in refs if not os.path.isfile('flutter_app/' + r))
if missing_refs: err(f"Dart code references missing in-app icon assets: {missing_refs}")
elif refs: ok(f"Dart in-app icon references resolve: {sorted(refs)}")

def png_rgba_pixels(p):
    """Decode an 8-bit, non-interlaced RGBA PNG to a list of (r, g, b, a). None if not that format."""
    with open(p, 'rb') as f:
        data = f.read()
    if data[:8] != b'\x89PNG\r\n\x1a\n': return None
    pos, idat, hdr = 8, b'', None
    while pos + 8 <= len(data):
        ln, typ = struct.unpack('>I4s', data[pos:pos + 8])
        body = data[pos + 8:pos + 8 + ln]
        if typ == b'IHDR': hdr = struct.unpack('>IIBBBBB', body)
        elif typ == b'IDAT': idat += body
        elif typ == b'IEND': break
        pos += 12 + ln
    if not hdr: return None
    w, h, depth, ctype, _c, _f, interlace = hdr
    if depth != 8 or ctype != 6 or interlace: return None
    raw, bpp, stride = zlib.decompress(idat), 4, w * 4
    out, prev, i = [], bytearray(stride), 0
    for _ in range(h):
        ft, line = raw[i], bytearray(raw[i + 1:i + 1 + stride]); i += 1 + stride
        for x in range(stride):
            a = line[x - bpp] if x >= bpp else 0
            b = prev[x]; c = prev[x - bpp] if x >= bpp else 0
            if ft == 1: line[x] = (line[x] + a) & 255
            elif ft == 2: line[x] = (line[x] + b) & 255
            elif ft == 3: line[x] = (line[x] + ((a + b) >> 1)) & 255
            elif ft == 4:
                pa, pb, pc = abs(b - c), abs(a - c), abs(a + b - 2 * c)
                pr = a if pa <= pb and pa <= pc else (b if pb <= pc else c)
                line[x] = (line[x] + pr) & 255
        out.extend(tuple(line[x:x + 4]) for x in range(0, stride, 4))
        prev = line
    return out

# 6b. Notification icon: white on transparent, all five densities.
STAT = {'mdpi': 24, 'hdpi': 36, 'xhdpi': 48, 'xxhdpi': 72, 'xxxhdpi': 96}
sb = 0
for d, size in STAT.items():
    p = f'{RES}/drawable-{d}/ic_stat_zyndio.png'
    if not os.path.isfile(p): err(f"{p} missing (notification icon)"); sb += 1; continue
    info = png_info(p)
    if not info or (info[0], info[1]) != (size, size):
        err(f"{p} must be a {size}x{size} PNG (got {info[:2] if info else 'not a PNG'})"); sb += 1; continue
    px = png_rgba_pixels(p)
    if px is None: err(f"{p} must be an 8-bit RGBA PNG (white on transparent)"); sb += 1; continue
    coloured = sum(1 for r, g, b, a in px if a and (r, g, b) != (255, 255, 255))
    clear = sum(1 for *_rgb, a in px if a == 0)
    if coloured: err(f"{p} is not single-colour white: {coloured} visible non-white pixels"); sb += 1
    if not clear: err(f"{p} has no transparent pixels; Android would draw a solid square"); sb += 1
    if not any(a for *_rgb, a in px): err(f"{p} is empty (fully transparent)"); sb += 1
if not sb: ok("ic_stat_zyndio: 5 densities, white on transparent")

MANIFEST = 'flutter_app/android/app/src/main/AndroidManifest.xml'
A = '{http://schemas.android.com/apk/res/android}'
app = ET.parse(MANIFEST).getroot().find('application')
fcm = [m.get(A + 'resource') for m in app.findall('meta-data')
       if m.get(A + 'name') == 'com.google.firebase.messaging.default_notification_icon']
if fcm == ['@drawable/ic_stat_zyndio']:
    ok("Firebase default_notification_icon = @drawable/ic_stat_zyndio")
else:
    err(f"Firebase default_notification_icon must be exactly one meta-data = @drawable/ic_stat_zyndio (got {fcm})")

# 6c. roundIcon on the application and on every component that uses the launcher icon.
rb = 0
if app.get(A + 'roundIcon') != '@mipmap/ic_launcher_round':
    err(f"<application> android:roundIcon must be @mipmap/ic_launcher_round (got {app.get(A + 'roundIcon')})"); rb += 1
for comp in list(app.iter('activity')) + list(app.iter('activity-alias')):
    if comp.get(A + 'icon') == '@mipmap/ic_launcher' and comp.get(A + 'roundIcon') != '@mipmap/ic_launcher_round':
        err(f"{comp.get(A + 'name')} uses @mipmap/ic_launcher without android:roundIcon=@mipmap/ic_launcher_round"); rb += 1
if not rb: ok("android:roundIcon = @mipmap/ic_launcher_round on <application> and the default launcher alias")

sys.exit(fail)
PY
