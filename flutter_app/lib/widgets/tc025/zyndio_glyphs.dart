import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:flutter/widgets.dart';

/// Zyndio's own icon set for the coloured app-icon tiles ([ZyndioIconTile]).
///
/// Drawn by hand on a 48 × 48 grid: bold two-tone shapes in white, with
/// cut-out details painted in the tile's own deep colour (the `TINT` token,
/// swapped in at render time) so each glyph reads as part of its tile rather
/// than a generic outline icon. Keep new glyphs inside the 7–41 live area,
/// round every join, and use three weights only: solid white, white at
/// 0.4–0.7 for the back layer, and TINT at 0.25–0.9 for details.
enum ZyndioGlyph {
  labReport,
  testTube,
  scan,
  injection,
  capsule,
  kettlebell,
  clipboard,
  goal,
  calendar,
  shield,
  book,
  bowl,
  sparkle,
  moon,
  heart,
  steps,
  activity,
  droplet,
  flame,
  molecule,
  sun,
  chat;

  /// SVG source with `TINT` replaced by [tint] (the tile's deep colour).
  String svg(Color tint) {
    final hex = (tint.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0');
    return '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 48 48">'
        '${_paths[this]!.replaceAll('TINT', '#$hex')}</svg>';
  }

  /// The bespoke glyph for a stock icon used across the app, if one exists.
  static ZyndioGlyph? forIcon(IconData icon) => _byIcon[icon];
}

const _w = '#ffffff';

const Map<ZyndioGlyph, String> _paths = {
  // A report sheet with a folded corner and a flask in front.
  ZyndioGlyph.labReport: '''
<path d="M16 7h11.5L37 16.5V37a4 4 0 0 1-4 4H16a4 4 0 0 1-4-4V11a4 4 0 0 1 4-4z" fill="$_w" fill-opacity=".38"/>
<path d="M27.5 7v6.5a3 3 0 0 0 3 3H37z" fill="$_w" fill-opacity=".72"/>
<rect x="19.5" y="18" width="10" height="3.2" rx="1.6" fill="$_w"/>
<path d="M21.6 21v4.4l-5.5 9.1A3 3 0 0 0 18.7 39h11.6a3 3 0 0 0 2.6-4.5l-5.5-9.1V21z" fill="$_w"/>
<path d="M18.1 33.3c2.1-1.1 4.2-1.1 6.4 0s4.3 1.1 6.4 0l1 1.6a1.9 1.9 0 0 1-1.6 2.9H18.7a1.9 1.9 0 0 1-1.6-2.9z" fill="TINT" fill-opacity=".38"/>
<circle cx="23.2" cy="30.2" r="1.3" fill="TINT" fill-opacity=".5"/>
<circle cx="26.3" cy="27.8" r=".9" fill="TINT" fill-opacity=".45"/>''',

  // One sample tube: bright cap, graduations, liquid.
  ZyndioGlyph.testTube: '''
<path d="M18.5 12.5h11v21.5a5.5 5.5 0 0 1-11 0z" fill="$_w"/>
<rect x="16.5" y="7.5" width="15" height="5.5" rx="2.75" fill="$_w" fill-opacity=".62"/>
<path d="M18.5 25.6c1.8-1 3.7-1 5.5 0s3.7 1 5.5 0V34a5.5 5.5 0 0 1-11 0z" fill="TINT" fill-opacity=".4"/>
<path d="M23 17h3.5M23 21h2" stroke="TINT" stroke-opacity=".45" stroke-width="1.7" stroke-linecap="round"/>
<circle cx="22.4" cy="31.2" r="1.2" fill="$_w" fill-opacity=".85"/>
<circle cx="25.6" cy="34.4" r=".8" fill="$_w" fill-opacity=".85"/>''',

  // Body composition scan: figure in a viewfinder with a scan beam.
  ZyndioGlyph.scan: '''
<path d="M9 16v-3.5A3.5 3.5 0 0 1 12.5 9H16M32 9h3.5A3.5 3.5 0 0 1 39 12.5V16M39 32v3.5a3.5 3.5 0 0 1-3.5 3.5H32M16 39h-3.5A3.5 3.5 0 0 1 9 35.5V32" fill="none" stroke="$_w" stroke-opacity=".8" stroke-width="2.8" stroke-linecap="round"/>
<circle cx="24" cy="14.6" r="3.6" fill="$_w" fill-opacity=".6"/>
<path d="M24 19.8c-4.3 0-6.9 2.2-6.9 5.6v4.8a1.7 1.7 0 0 0 1.7 1.7h1.3l.7 4.4a1.7 1.7 0 0 0 1.7 1.5h3a1.7 1.7 0 0 0 1.7-1.5l.7-4.4h1.3a1.7 1.7 0 0 0 1.7-1.7v-4.8c0-3.4-2.6-5.6-6.9-5.6z" fill="$_w" fill-opacity=".6"/>
<rect x="11" y="22" width="26" height="5" rx="2.5" fill="$_w" fill-opacity=".22"/>
<rect x="11" y="23.4" width="26" height="2.4" rx="1.2" fill="$_w"/>''',

  // Pen injector with a dose window, set on the diagonal.
  ZyndioGlyph.injection: '''
<g transform="rotate(42 24 24)">
<rect x="21" y="5.5" width="6" height="4.2" rx="1.6" fill="$_w" fill-opacity=".7"/>
<rect x="22.6" y="9.2" width="2.8" height="4.4" rx="1" fill="$_w" fill-opacity=".7"/>
<rect x="18" y="13" width="12" height="18.5" rx="3.4" fill="$_w"/>
<rect x="21" y="17" width="6" height="9.5" rx="1.8" fill="TINT" fill-opacity=".32"/>
<rect x="21" y="21.5" width="6" height="5" rx="1.8" fill="TINT" fill-opacity=".55"/>
<path d="M21 31.5h6l-1.1 3h-3.8z" fill="$_w"/>
<rect x="23.3" y="34" width="1.4" height="7.5" rx=".7" fill="$_w"/>
</g>''',

  // A two-tone capsule and a scored tablet.
  ZyndioGlyph.capsule: '''
<g transform="rotate(-42 22 21)">
<path d="M16 21v-8.5a6 6 0 0 1 12 0V21z" fill="$_w"/>
<path d="M16 21h12v8.5a6 6 0 0 1-12 0z" fill="$_w" fill-opacity=".55"/>
<rect x="18.6" y="10" width="2.4" height="8" rx="1.2" fill="TINT" fill-opacity=".2"/>
</g>
<circle cx="34" cy="34.5" r="5.8" fill="$_w"/>
<path d="M30.4 38.1l7.2-7.2" stroke="TINT" stroke-opacity=".38" stroke-width="1.8" stroke-linecap="round"/>''',

  // Movement: a dumbbell on the diagonal.
  ZyndioGlyph.kettlebell: '''
<g transform="rotate(-40 24 24)">
<rect x="14" y="22.3" width="20" height="3.4" rx="1.7" fill="$_w" fill-opacity=".72"/>
<rect x="6.8" y="17.6" width="4.4" height="12.8" rx="2.2" fill="$_w" fill-opacity=".78"/>
<rect x="36.8" y="17.6" width="4.4" height="12.8" rx="2.2" fill="$_w" fill-opacity=".78"/>
<rect x="10.4" y="13.8" width="6" height="20.4" rx="2.8" fill="$_w"/>
<rect x="31.6" y="13.8" width="6" height="20.4" rx="2.8" fill="$_w"/>
<rect x="12.2" y="16.5" width="1.6" height="15" rx=".8" fill="TINT" fill-opacity=".18"/>
<rect x="33.4" y="16.5" width="1.6" height="15" rx=".8" fill="TINT" fill-opacity=".18"/>
</g>''',

  // The plan: clipboard with a ticked first item.
  ZyndioGlyph.clipboard: '''
<rect x="11.5" y="10" width="25" height="31" rx="5" fill="$_w" fill-opacity=".42"/>
<rect x="14.8" y="14" width="18.4" height="23.5" rx="2.8" fill="$_w"/>
<path d="M19 7.8h10a1.6 1.6 0 0 1 1.6 1.6v3.3a2.2 2.2 0 0 1-2.2 2.2h-8.8a2.2 2.2 0 0 1-2.2-2.2V9.4A1.6 1.6 0 0 1 19 7.8z" fill="$_w"/>
<circle cx="24" cy="10.8" r="1.2" fill="TINT" fill-opacity=".45"/>
<path d="M18.2 21.6l1.8 1.8 3.4-3.6" fill="none" stroke="TINT" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"/>
<path d="M25.6 21.8h4.4" stroke="TINT" stroke-opacity=".38" stroke-width="2" stroke-linecap="round"/>
<rect x="18.2" y="26.4" width="4.2" height="4.2" rx="1.3" fill="TINT" fill-opacity=".22"/>
<path d="M25.6 28.5h4.4" stroke="TINT" stroke-opacity=".28" stroke-width="2" stroke-linecap="round"/>
<path d="M18.6 33.4h11.4" stroke="TINT" stroke-opacity=".18" stroke-width="2" stroke-linecap="round"/>''',

  // A goal: summit with a flag.
  ZyndioGlyph.goal: '''
<path d="M21 39l8.6-12.6a1.4 1.4 0 0 1 2.3 0L40.5 39z" fill="$_w" fill-opacity=".45"/>
<path d="M6.5 39l11-16.2a1.6 1.6 0 0 1 2.6 0L31.2 39z" fill="$_w"/>
<path d="M15.1 26.4l3.7-5.3 3.7 5.3-1.9-1.1-1.8 1.3-1.8-1.3z" fill="TINT" fill-opacity=".3"/>
<path d="M18.8 21.6V9.2" stroke="$_w" stroke-width="2" stroke-linecap="round"/>
<path d="M19.8 9h8.4l-2.2 3.1 2.2 3.1h-8.4z" fill="$_w"/>''',

  // Calendar with a marked day.
  ZyndioGlyph.calendar: '''
<rect x="9" y="11" width="30" height="28.5" rx="5.5" fill="$_w"/>
<path d="M14.5 11h19a5.5 5.5 0 0 1 5.5 5.5v3H9v-3a5.5 5.5 0 0 1 5.5-5.5z" fill="TINT" fill-opacity=".22"/>
<rect x="15.4" y="7.5" width="3.4" height="7.4" rx="1.7" fill="$_w"/>
<rect x="29.2" y="7.5" width="3.4" height="7.4" rx="1.7" fill="$_w"/>
<g fill="TINT" fill-opacity=".26">
<rect x="13.5" y="23.5" width="4" height="3.6" rx="1.2"/><rect x="20" y="23.5" width="4" height="3.6" rx="1.2"/><rect x="26.5" y="23.5" width="4" height="3.6" rx="1.2"/>
<rect x="13.5" y="30" width="4" height="3.6" rx="1.2"/><rect x="20" y="30" width="4" height="3.6" rx="1.2"/>
</g>
<circle cx="30.4" cy="31.8" r="3.8" fill="TINT" fill-opacity=".9"/>''',

  // Secure: shield with a check.
  ZyndioGlyph.shield: '''
<path d="M24 6.8l12.8 4.9v10.6c0 8.5-5.4 15.3-12.8 18.7-7.4-3.4-12.8-10.2-12.8-18.7V11.7z" fill="$_w"/>
<path d="M24 6.8v34.2c-7.4-3.4-12.8-10.2-12.8-18.7V11.7z" fill="TINT" fill-opacity=".08"/>
<path d="M18.6 24.2l3.9 3.9 7.2-7.6" fill="none" stroke="TINT" stroke-width="3" stroke-linecap="round" stroke-linejoin="round"/>''',

  // Resources: open book with a ribbon.
  ZyndioGlyph.book: '''
<path d="M24 14.2c3.6-2.7 8-3.7 13-3.1v25.2c-5-.6-9.4.4-13 3.1z" fill="$_w" fill-opacity=".58"/>
<path d="M24 14.2c-3.6-2.7-8-3.7-13-3.1v25.2c5-.6 9.4.4 13 3.1z" fill="$_w"/>
<path d="M15 18.2c2.4-.1 4.6.4 6 1.2M15 23.2c2.4-.1 4.6.4 6 1.2M15 28.2c2.4-.1 4.6.4 6 1.2" fill="none" stroke="TINT" stroke-opacity=".3" stroke-width="1.7" stroke-linecap="round"/>
<path d="M29.4 11.3v9.4l2.3-1.7 2.3 1.7v-9.8z" fill="$_w"/>''',

  // Food log: a bowl of greens.
  ZyndioGlyph.bowl: '''
<path d="M16.4 23.6c-1.2-5.2 1.6-9.4 7-10.6 1 5.2-1.8 9.4-7 10.6z" fill="$_w" fill-opacity=".55"/>
<path d="M25.2 23.6c.4-5.8 4.4-9 10.2-8.8-.6 5.6-4.4 8.8-10.2 8.8z" fill="$_w" fill-opacity=".55"/>
<circle cx="22.4" cy="20.6" r="3.3" fill="$_w" fill-opacity=".85"/>
<path d="M8.5 24.5h31c0 8-6.9 14.5-15.5 14.5S8.5 32.5 8.5 24.5z" fill="$_w"/>
<path d="M13.4 29.2c1.6 3.4 4.7 5.7 8.6 6.4" fill="none" stroke="TINT" stroke-opacity=".26" stroke-width="2.2" stroke-linecap="round"/>''',

  // Insight: a large and a small spark.
  ZyndioGlyph.sparkle: '''
<path d="M21.5 8.5c1.1 6.6 4.5 10 11.1 11.1-6.6 1.1-10 4.5-11.1 11.1-1.1-6.6-4.5-10-11.1-11.1 6.6-1.1 10-4.5 11.1-11.1z" fill="$_w"/>
<path d="M34 26.5c.6 3 1.9 4.3 4.9 4.9-3 .6-4.3 1.9-4.9 4.9-.6-3-1.9-4.3-4.9-4.9 3-.6 4.3-1.9 4.9-4.9z" fill="$_w" fill-opacity=".68"/>
<circle cx="14.5" cy="35" r="2.1" fill="$_w" fill-opacity=".45"/>''',

  // Sleep: crescent and two stars.
  ZyndioGlyph.moon: '''
<path d="M21.23 13.06A12.5 12.5 0 1 0 34.83 27.57A10.5 10.5 0 0 1 21.23 13.06Z" fill="$_w"/>
<path d="M33.5 8.5c.4 2.1 1.3 3 3.4 3.4-2.1.4-3 1.3-3.4 3.4-.4-2.1-1.3-3-3.4-3.4 2.1-.4 3-1.3 3.4-3.4z" fill="$_w" fill-opacity=".7"/>
<circle cx="39" cy="19" r="1.4" fill="$_w" fill-opacity=".5"/>
<path d="M16 29.4a7.5 7.5 0 0 0 5.8 5.6" fill="none" stroke="TINT" stroke-opacity=".2" stroke-width="2" stroke-linecap="round"/>''',

  // Heart with a pulse trace cut through it.
  ZyndioGlyph.heart: '''
<path d="M24 38.6S10.5 30.8 10.5 20.9a7.4 7.4 0 0 1 13.5-4.2 7.4 7.4 0 0 1 13.5 4.2C37.5 30.8 24 38.6 24 38.6z" fill="$_w"/>
<path d="M12.6 25.2h5.6l2.3-4.4 3.8 8.8 2.5-4.4h8.6" fill="none" stroke="TINT" stroke-opacity=".85" stroke-width="2.6" stroke-linecap="round" stroke-linejoin="round"/>''',

  // Steps: a trainer in profile.
  ZyndioGlyph.steps: '''
<path d="M10 31.2c0-3.6 1.1-6.9 3.3-9.3a1.6 1.6 0 0 1 2-.3l3.4 2c1.6.9 3.5.5 4.5-1l1.9-2.9a1.4 1.4 0 0 1 1.9-.4c4.1 2.5 8.6 4.6 12.9 5.8 2.5.7 4.1 2.8 4.1 5.3v.8z" fill="$_w"/>
<rect x="8.5" y="31.6" width="33" height="5.6" rx="2.8" fill="$_w" fill-opacity=".62"/>
<path d="M21.6 25.8l2.6 1.5M24.6 23.6l2.6 1.5M27.8 21.6l2.4 1.4" stroke="TINT" stroke-opacity=".4" stroke-width="1.8" stroke-linecap="round"/>
<path d="M11.6 28.6h7" stroke="TINT" stroke-opacity=".2" stroke-width="1.8" stroke-linecap="round"/>''',

  // Vitals: a pulse trace over a soft disc.
  ZyndioGlyph.activity: '''
<circle cx="24" cy="24" r="15" fill="$_w" fill-opacity=".3"/>
<path d="M8.5 25h7l3.2-7.4 5 13.4 3.6-8.4 2.6 2.4h9.6" fill="none" stroke="$_w" stroke-width="3.2" stroke-linecap="round" stroke-linejoin="round"/>''',

  // Glucose: a drop with a highlight.
  ZyndioGlyph.droplet: '''
<path d="M24 7.5c5.6 7.1 11.2 12.8 11.2 19.5a11.2 11.2 0 0 1-22.4 0C12.8 20.3 18.4 14.6 24 7.5z" fill="$_w"/>
<path d="M18.4 27.6a5.8 5.8 0 0 0 4.2 5.6" fill="none" stroke="TINT" stroke-opacity=".32" stroke-width="2.3" stroke-linecap="round"/>''',

  // Inflammation: a flame with an inner core.
  ZyndioGlyph.flame: '''
<path d="M24 8c1.6 5.6 9.2 9.5 9.2 18.8a9.2 9.2 0 0 1-18.4 0c0-4.8 2.3-7.5 4.5-9.8.3 3.1 1.6 4.7 3.5 5.5C22 17.7 22.3 12.4 24 8z" fill="$_w"/>
<path d="M24 28.4c2.3 2.1 4.1 3.8 4.1 6.6a4.1 4.1 0 0 1-8.2 0c0-2.6 1.8-4.4 4.1-6.6z" fill="TINT" fill-opacity=".34"/>''',

  // Molecule: NAD+, hormones, chemistry.
  ZyndioGlyph.molecule: '''
<path d="M15 31.5L24 17l10.2 13.6M24 17l12-4" fill="none" stroke="$_w" stroke-opacity=".55" stroke-width="3" stroke-linecap="round"/>
<circle cx="24" cy="16.5" r="5.4" fill="$_w"/>
<circle cx="14.2" cy="32.2" r="4.6" fill="$_w"/>
<circle cx="34.6" cy="31.2" r="4.6" fill="$_w"/>
<circle cx="36.6" cy="12.6" r="2.7" fill="$_w" fill-opacity=".7"/>
<circle cx="24" cy="16.5" r="1.8" fill="TINT" fill-opacity=".28"/>''',

  // Vitamin D: the sun.
  ZyndioGlyph.sun: '''
<g stroke="$_w" stroke-opacity=".62" stroke-width="3" stroke-linecap="round">
<path d="M24 8.5v3.6M24 35.9v3.6M8.5 24h3.6M35.9 24h3.6M13 13l2.6 2.6M32.4 32.4L35 35M13 35l2.6-2.6M32.4 15.6L35 13"/>
</g>
<circle cx="24" cy="24" r="7.6" fill="$_w"/>
<path d="M19.8 22.6a4.6 4.6 0 0 1 3-3.2" fill="none" stroke="TINT" stroke-opacity=".25" stroke-width="1.9" stroke-linecap="round"/>''',

  // Care team: a message bubble.
  ZyndioGlyph.chat: '''
<path d="M13 10h22a5 5 0 0 1 5 5v13a5 5 0 0 1-5 5H22.5l-6.8 5.6a1 1 0 0 1-1.7-.8V33h-1a5 5 0 0 1-5-5V15a5 5 0 0 1 5-5z" fill="$_w"/>
<g fill="TINT" fill-opacity=".5"><circle cx="17.6" cy="21.5" r="2"/><circle cx="24" cy="21.5" r="2"/><circle cx="30.4" cy="21.5" r="2"/></g>''',
};

/// Stock icons already used in tiles across the app → bespoke glyphs, so
/// every [ZyndioIconTile] upgrades without touching each screen.
final Map<IconData, ZyndioGlyph> _byIcon = {
  LucideIcons.fileText: ZyndioGlyph.labReport,
  LucideIcons.flaskConical: ZyndioGlyph.labReport,
  LucideIcons.testTube: ZyndioGlyph.testTube,
  LucideIcons.testTubes: ZyndioGlyph.testTube,
  LucideIcons.scanLine: ZyndioGlyph.scan,
  LucideIcons.syringe: ZyndioGlyph.injection,
  LucideIcons.pill: ZyndioGlyph.capsule,
  LucideIcons.dumbbell: ZyndioGlyph.kettlebell,
  LucideIcons.clipboardList: ZyndioGlyph.clipboard,
  LucideIcons.target: ZyndioGlyph.goal,
  LucideIcons.calendarDays: ZyndioGlyph.calendar,
  LucideIcons.calendar: ZyndioGlyph.calendar,
  LucideIcons.shieldCheck: ZyndioGlyph.shield,
  LucideIcons.bookOpen: ZyndioGlyph.book,
  LucideIcons.utensils: ZyndioGlyph.bowl,
  LucideIcons.brain: ZyndioGlyph.sparkle,
  LucideIcons.sparkles: ZyndioGlyph.sparkle,
  LucideIcons.moon: ZyndioGlyph.moon,
  LucideIcons.heart: ZyndioGlyph.heart,
  LucideIcons.heartPulse: ZyndioGlyph.heart,
  LucideIcons.footprints: ZyndioGlyph.steps,
  LucideIcons.activity: ZyndioGlyph.activity,
  LucideIcons.droplet: ZyndioGlyph.droplet,
  LucideIcons.flame: ZyndioGlyph.flame,
  LucideIcons.atom: ZyndioGlyph.molecule,
  LucideIcons.sun: ZyndioGlyph.sun,
  LucideIcons.messageCircle: ZyndioGlyph.chat,
  LucideIcons.messageSquare: ZyndioGlyph.chat,
};
