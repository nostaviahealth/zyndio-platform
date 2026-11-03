// TC-030 item 9: the leaderboard name formatter must be robust, and must read
// the same as the server's patient_leaderboard_top10().
//
// PR #29 r5 - Henry's REJECT rule (Clara r4 H1 + M1), the same rule as the
// server (migration 20261103123000_tc030_leaderboard_name_nfkc):
//   a. NFKC first; b. NULL or any '@' -> 'Anonymous'; c. any
//   Default_Ignorable_Code_Point -> 'Anonymous'; d. any digit -> 'Anonymous';
//   e. only letters, marks, ASCII space, ASCII '-', ' and ’ allowed, anything
//   else -> 'Anonymous' ((c) and (e) on the raw value AND its NFKC form);
//   f. an apostrophe only between two letters/marks; g. spaces and hyphens
//   split; h. "First L." / one piece alone, 18-code-point cap.
//
// The probe table below is generated from the same list as supabase/tests/741
// (work/.claude-runs/tc030h3r5/gen.py) and pins the SAME expectation for every
// round 1-5 shape: Clara's r3 + r4 probe lists, every case of the bbf14a0 table
// and unit tests, every name bbf14a0's 741 pinned, and the r5 additions.
import 'package:flutter_test/flutter_test.dart';
import 'package:zyndio_patient/services/gamification_service.dart';

void main() {
  String fmt(String? raw) => GamificationService.formatLeaderboardName(raw);
  String ini(String? raw) => GamificationService.leaderboardInitials(raw);

  group('formatLeaderboardName (reject rule)', () {
    test('a plain two-word name becomes "First L."; trims; one word alone', () {
      expect(fmt('Jordan Rivera'), 'Jordan R.');
      expect(fmt('  Jordan Rivera  '), 'Jordan R.');
      expect(fmt('jordan   rivera'), 'Jordan R.');
      expect(fmt('Riley'), 'Riley');
      expect(fmt('blake'), 'Blake');
    });

    test('(a) NFKC first: fullwidth letters and ligatures normalise; e + U+0301 composes', () {
      expect(fmt('\uFF31\uFF55\uFF49\uFF4E\uFF4E Testcase'), 'Quinn T.');
      expect(fmt('\uFB01ona Testcase'), 'Fiona T.');
      expect(fmt('e\u0301mile Testcase'), '\u00C9mile T.');
    });

    test('(b) null or any @ (also fullwidth/small @ after NFKC) is exactly "Anonymous"', () {
      expect(fmt(null), 'Anonymous');
      expect(fmt('jordan.rivera@example.com'), 'Anonymous');
      expect(fmt('@testcase'), 'Anonymous');
      expect(fmt('Quinn\uFF20'), 'Anonymous');
      expect(fmt('qtestcase\uFE6Bexample'), 'Anonymous');
    });

    test('(c) any Default_Ignorable_Code_Point gives "Anonymous" (every range)', () {
      // Start, middle and end of each of the 17 Unicode 17.0.0 ranges.
      const ranges = <(int, int)>[
        (0x00AD, 0x00AD),
        (0x034F, 0x034F),
        (0x061C, 0x061C),
        (0x115F, 0x1160),
        (0x17B4, 0x17B5),
        (0x180B, 0x180F),
        (0x200B, 0x200F),
        (0x202A, 0x202E),
        (0x2060, 0x206F),
        (0x3164, 0x3164),
        (0xFE00, 0xFE0F),
        (0xFEFF, 0xFEFF),
        (0xFFA0, 0xFFA0),
        (0xFFF0, 0xFFF8),
        (0x1BCA0, 0x1BCA3),
        (0x1D173, 0x1D17A),
        (0xE0000, 0xE0FFF),
      ];
      for (final (lo, hi) in ranges) {
        for (final cp in {lo, (lo + hi) ~/ 2, hi}) {
          final raw = 'Quinn${String.fromCharCode(cp)}Testcase';
          expect(fmt(raw), 'Anonymous', reason: 'U+${cp.toRadixString(16).toUpperCase()}');
          expect(ini(raw), '?', reason: 'U+${cp.toRadixString(16).toUpperCase()}');
        }
      }
      expect(fmt('\u3164'), 'Anonymous');
      expect(fmt('Quinn Testcase\u3164'), 'Anonymous');
    });

    test('(d) any digit gives "Anonymous"', () {
      expect(fmt('Quinn2 Testcase'), 'Anonymous');
      expect(fmt('Quinn \u0663'), 'Anonymous');
      expect(fmt('Quinn \u2167'), 'Anonymous');
    });

    test('(e) symbols, punctuation, emoji, NBSP and other whitespace give "Anonymous"', () {
      for (final raw in [
        'Rivera, Jordan', 'jordan.rivera', 'morgan_lee', 'Quinn+Testcase',
        'Jordan R.', 'Quinn \u{1F984}Testcase', 'Jordan\u00A0Rivera',
        'Jordan\t\n  Rivera', 'Quinn\u3000Testcase', 'Quinn \u24D0', 'Quinn\u2122',
        'Quinn\u00B2',
      ]) {
        expect(fmt(raw), 'Anonymous', reason: raw);
        expect(ini(raw), '?', reason: raw);
      }
    });

    test('(f) apostrophes only between letters/marks', () {
      expect(fmt("Quinn O'Brien"), 'Quinn O.');
      expect(fmt('Quinn O\u2019Brien'), 'Quinn O.');
      expect(fmt("Quinn'Testcase"), "Quinn'Testcase");
      for (final raw in ["'Quinn Testcase", "Quinn Testcase'", "Quinn O''Brien", "Quinn 'Testcase"]) {
        expect(fmt(raw), 'Anonymous', reason: raw);
      }
    });

    test('(g) spaces and hyphens split; runs collapse; empty pieces drop', () {
      expect(fmt('Quinn-Testcase'), 'Quinn T.');
      expect(fmt("Mary-Jane O'Neil"), 'Mary O.');
      expect(fmt('  Quinn  --  Testcase  '), 'Quinn T.');
      expect(fmt('-Quinn'), 'Quinn');
      expect(fmt('-'), 'Anonymous');
      expect(fmt('   '), 'Anonymous');
      expect(fmt('Riley Clinic-B'), 'Riley B.');
    });

    test('(h) capped at 18 code points, never splitting an astral letter', () {
      final out = fmt('Maximiliana Wolfeschlegelstein');
      expect(out, 'Maximiliana W.');
      final long = fmt('Quinnabellarosalinde Testcase');
      expect(long.runes.length, GamificationService.leaderboardNameMaxLength);
      expect(String.fromCharCodes(long.runes), long);
      expect(fmt('Quinn \u{1D400}bc'), 'Quinn A.');
    });

    test('a custom fallback is honoured', () {
      expect(GamificationService.formatLeaderboardName(null, fallback: 'Unknown'), 'Unknown');
    });
  });

  group('leaderboardInitials', () {
    test('first + last initial; one piece -> one initial; rejected -> "?"', () {
      expect(ini('Jordan Rivera'), 'JR');
      expect(ini('Riley Smith Jones'), 'RJ');
      expect(ini('Riley'), 'R');
      expect(ini('blake'), 'B');
      expect(ini(null), '?');
      expect(ini('jordan.rivera@example.com'), '?');
      expect(ini('\u{1F984}'), '?');
    });
  });

  group('server-name display helpers (the app re-formats the RPC output)', () {
    test('"First L." from the server is shown unchanged, with its initials', () {
      expect(GamificationService.leaderboardDisplayName('Jordan R.'), 'Jordan R.');
      expect(GamificationService.leaderboardDisplayInitials('Jordan R.'), 'JR');
      expect(GamificationService.leaderboardDisplayName('Riley'), 'Riley');
      expect(GamificationService.leaderboardDisplayName('Quinn O.'), 'Quinn O.');
      expect(GamificationService.leaderboardDisplayName('\u00C9mile T.'), '\u00C9mile T.');
    });

    test('Anonymous, null and anything the rule rejects are anonymous rows', () {
      expect(GamificationService.isLeaderboardAnonymous('Anonymous'), isTrue);
      expect(GamificationService.isLeaderboardAnonymous(null), isTrue);
      expect(GamificationService.isLeaderboardAnonymous('quinn@example.test'), isTrue);
      expect(GamificationService.isLeaderboardAnonymous('Jordan R.'), isFalse);
      expect(GamificationService.leaderboardDisplayName('Quinn 2.'), 'Anonymous');
      expect(GamificationService.leaderboardDisplayName('Quinn..'), 'Anonymous');
    });
  });

  group('PR #29 r1-r5 probe table (same expectations as supabase/tests/741)', () {
    // (label, raw name, formatLeaderboardName, leaderboardInitials)
    const cases = <(String, String?, String, String)>[
    ('comma', 'Testcase, Quinn', 'Anonymous', '?'),
    ('comma-nospace', 'Testcase,Quinn', 'Anonymous', '?'),
    ('email', 'quinn.testcase@example.test', 'Anonymous', '?'),
    ('email-underscore', 'quinn_testcase@example.test', 'Anonymous', '?'),
    ('email-plain', 'qtestcase@example.test', 'Anonymous', '?'),
    ('nbsp', 'Quinn\u00A0Testcase', 'Anonymous', '?'),
    ('tab-newline', 'Quinn\u0009\u000ATestcase', 'Anonymous', '?'),
    ('single', 'Quinn', 'Quinn', 'Q'),
    ('three-words', 'Quinn Avery Testcase', 'Quinn T.', 'QT'),
    ('emoji', 'Quinn \u{1F984}Testcase', 'Anonymous', '?'),
    ('emoji-first', '\u{1F984} Testcase', 'Anonymous', '?'),
    ('unicode', 'Zo\u00EB \u00C5ngstr\u00F6m', 'Zo\u00EB \u00C5.', 'Z\u00C5'),
    ('zwsp', 'Quinn\u200BTestcase', 'Anonymous', '?'),
    ('emspace', 'Quinn\u2003Testcase', 'Anonymous', '?'),
    ('ideographic', 'Quinn\u3000Testcase', 'Anonymous', '?'),
    ('empty', '', 'Anonymous', '?'),
    ('whitespace', '   ', 'Anonymous', '?'),
    ('nbsp-only', '\u00A0\u00A0', 'Anonymous', '?'),
    ('dot-local', 'Quinn.Testcase', 'Anonymous', '?'),
    ('at-first', '@testcase', 'Anonymous', '?'),
    ('long', 'Quinnabellarosalind Testcase', 'Quinnabellarosalin', 'QT'),
    ('null', null, 'Anonymous', '?'),
    ('email-hyphen', 'quinn-testcase@example.test', 'Anonymous', '?'),
    ('email-upper', 'QUINN.TESTCASE@EXAMPLE.TEST', 'Anonymous', '?'),
    ('email-plus', 'quinn+testcase@example.test', 'Anonymous', '?'),
    ('email-plus-dot', 'quinn.t+clinic@example.test', 'Anonymous', '?'),
    ('multi-at', 'quinn.testcase@foo@example.test', 'Anonymous', '?'),
    ('multi-at2', 'quinn@testcase@example.test', 'Anonymous', '?'),
    ('lead-trail-sep', '_quinn.testcase_', 'Anonymous', '?'),
    ('lead-dot-surname', '.testcase', 'Anonymous', '?'),
    ('trail-dot', 'testcase.', 'Anonymous', '?'),
    ('dot-only-surname-email', '.testcase@example.test', 'Anonymous', '?'),
    ('zwnj', 'Quinn\u200CTestcase', 'Anonymous', '?'),
    ('zwj', 'Quinn\u200DTestcase', 'Anonymous', '?'),
    ('wj', 'Quinn\u2060Testcase', 'Anonymous', '?'),
    ('bom', 'Quinn\uFEFFTestcase', 'Anonymous', '?'),
    ('soft-hyphen', 'Quinn\u00ADTestcase', 'Anonymous', '?'),
    ('lrm', 'Quinn\u200ETestcase', 'Anonymous', '?'),
    ('rlm', 'Quinn\u200FTestcase', 'Anonymous', '?'),
    ('mongolian-vs', 'Quinn\u180ETestcase', 'Anonymous', '?'),
    ('invisible-times', 'Quinn\u2062Testcase', 'Anonymous', '?'),
    ('rlo-joined', 'Quinn\u202ETestcase', 'Anonymous', '?'),
    ('rlo-word', 'Quinn \u202ETestcase', 'Anonymous', '?'),
    ('combining', 'Que\u0301nn Te\u0301stcase', 'Qu\u00E9nn T.', 'QT'),
    ('combining-lead', 'Quinn \u0301Testcase', 'Quinn T.', 'QT'),
    ('very-long', 'QQQQQQQQQQQQQQQQQQQQQQQQQQQQQQQQQQQQQQQQ TTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTT', 'QQQQQQQQQQQQQQQQQQ', 'QT'),
    ('very-long-joined', 'Quinnabellarosalindevangeline.Testcasesmithington', 'Anonymous', '?'),
    ('digits', 'Quinn2 Testcase99', 'Anonymous', '?'),
    ('digits-only', '12345', 'Anonymous', '?'),
    ('honorific', 'Dr. Quinn Testcase', 'Anonymous', '?'),
    ('hyphen-surname', 'Quinn Testcase-Smith', 'Quinn S.', 'QS'),
    ('hyphen-comma', 'Testcase-Smith, Quinn', 'Anonymous', '?'),
    ('handle-email', 'qtestcase@example.test', 'Anonymous', '?'),
    ('camel-email', 'QuinnTestcase@example.test', 'Anonymous', '?'),
    ('plain-handle', 'qtestcase', 'Qtestcase', 'Q'),
    ('emoji-joined', 'Quinn\u{1F984}Testcase', 'Anonymous', '?'),
    ('thin-space', 'Quinn\u2009Testcase', 'Anonymous', '?'),
    ('line-sep', 'Quinn\u2028Testcase', 'Anonymous', '?'),
    ('comma-email', 'Testcase, Quinn@example.test', 'Anonymous', '?'),
    ('plus2', 'quinn+testcase@example.test', 'Anonymous', '?'),
    ('handle-at', 'qtestcase@', 'Anonymous', '?'),
    ('at-handle', '@testcase', 'Anonymous', '?'),
    ('a@b', 'a@b', 'Anonymous', '?'),
    ('fullwidth-at', 'qtestcase\uFF20example.test', 'Anonymous', '?'),
    ('fullwidth-at-dot', 'quinn.testcase\uFF20example.test', 'Anonymous', '?'),
    ('small-at', 'qtestcase\uFE6Bexample.test', 'Anonymous', '?'),
    ('small-at-dot', 'quinn.testcase\uFE6Bexample.test', 'Anonymous', '?'),
    ('at-lookalike-2148', 'qtestcase\u24D0example.test', 'Anonymous', '?'),
    ('email-no-at-spaced', 'qtestcase at example dot test', 'Qtestcase T.', 'QT'),
    ('homoglyph-cyrillic', 'Quinn \u0422estcase', 'Quinn \u0422.', 'Q\u0422'),
    ('homoglyph-latin-cyr-mix', 'Qu\u0456nn T\u0435stcase', 'Qu\u0456nn T.', 'QT'),
    ('hebrew', '\u05D9\u05E2\u05DC \u05DB\u05D4\u05DF', '\u05D9\u05E2\u05DC \u05DB.', '\u05D9\u05DB'),
    ('arabic', '\u0644\u064E\u064A\u0652\u0644\u064E\u0649 \u062D\u064E\u0633\u064E\u0646', '\u0644\u064E\u064A\u0652\u0644\u064E\u0649 \u062D\u064E.', '\u0644\u064E\u062D\u064E'),
    ('devanagari', '\u0905\u0928\u093F\u0924\u093E \u0936\u0930\u094D\u092E\u093E', '\u0905\u0928\u093F\u0924\u093E \u0936.', '\u0905\u0936'),
    ('cjk', '\u738B \u5C0F\u660E', '\u738B \u5C0F.', '\u738B\u5C0F'),
    ('cjk-joined', '\u738B\u5C0F\u660E', '\u738B\u5C0F\u660E', '\u738B'),
    ('thai', '\u0E2A\u0E21\u0E0A\u0E32\u0E22 \u0E43\u0E08\u0E14\u0E35', '\u0E2A\u0E21\u0E0A\u0E32\u0E22 \u0E43.', '\u0E2A\u0E43'),
    ('all-digits', '2024 1999', 'Anonymous', '?'),
    ('apostrophe-only', '\'\'', 'Anonymous', '?'),
    ('rsquo-only', '\u2019\u2019', 'Anonymous', '?'),
    ('obrien', 'Quinn O\'Brien', 'Quinn O.', 'QO'),
    ('obrien-only', 'O\'Brien', 'O\'Brien', 'O'),
    ('apostrophe-joined', 'Quinn\'Testcase', 'Quinn\'Testcase', 'Q'),
    ('digit-joined', 'Quinn1Testcase', 'Anonymous', '?'),
    ('long80', 'Quinnabellarosalindevangelinemarigold Testcasesmithingtonworthshire-Jones', 'Quinnabellarosalin', 'QJ'),
    ('null2', null, 'Anonymous', '?'),
    ('comma-only', ',', 'Anonymous', '?'),
    ('multi-comma', 'Testcase, Quinn, Jr', 'Anonymous', '?'),
    ('hangul-filler-3164', 'Quinn\u3164Testcase', 'Anonymous', '?'),
    ('hangul-jungseong-1160', 'Quinn\u1160Testcase', 'Anonymous', '?'),
    ('hangul-choseong-115F', 'Quinn\u115FTestcase', 'Anonymous', '?'),
    ('halfwidth-hangul-FFA0', 'Quinn\uFFA0Testcase', 'Anonymous', '?'),
    ('cgj-034F', 'Quinn\u034FTestcase', 'Anonymous', '?'),
    ('vs16-FE0F', 'Quinn\uFE0FTestcase', 'Anonymous', '?'),
    ('vs-supp-E0100', 'Quinn\u{E0100}Testcase', 'Anonymous', '?'),
    ('mongolian-fvs-180B', 'Quinn\u180BTestcase', 'Anonymous', '?'),
    ('khmer-17B4', 'Quinn\u17B4Testcase', 'Anonymous', '?'),
    ('combining-joiner-0301', 'Quinn\u0301Testcase', 'Quin\u0144Testcase', 'Q'),
    ('tag-chars-E0041', 'Quinn\u{E0041}Testcase', 'Anonymous', '?'),
    ('braille-blank-2800', 'Quinn\u2800Testcase', 'Anonymous', '?'),
    ('emoji-zwj-seq', 'Quinn \u{1F468}\u200D\u{1F469} Testcase', 'Anonymous', '?'),
    ('mark-lead-piece', '\u0301Quinn \u0301Testcase', 'Quinn T.', 'QT'),
    ('rlo-lead', '\u202EQuinn Testcase', 'Anonymous', '?'),
    ('digit-lead-piece', '9Quinn 7Testcase', 'Anonymous', '?'),
    ('fullwidth-letters', '\uFF31\uFF55\uFF49\uFF4E\uFF4E \uFF34\uFF45\uFF53\uFF54', 'Quinn T.', 'QT'),
    ('apostrophe-surname', 'Se\u00E1n O\'Brien', 'Se\u00E1n O.', 'SO'),
    ('apostrophe-lead', 'd\'Arcy Testcase', 'D\'Arcy T.', 'DT'),
    ('curly-apostrophe-lead', 'Quinn \u2019Testcase', 'Anonymous', '?'),
    ('devanagari-conjunct', '\u092A\u094D\u0930\u093F\u092F\u093E \u0936\u0930\u094D\u092E\u093E', '\u092A\u094D\u0930\u093F\u092F\u093E \u0936.', '\u092A\u094D\u0936'),
    ('decomposed-first', 'e\u0301mile Testcase', '\u00C9mile T.', '\u00C9T'),
    ('arabic-digit-token', 'Quinn \u0661\u0662', 'Anonymous', '?'),
    ('digit-led-surname', 'Quinn 2Testcase', 'Anonymous', '?'),
    ('mark-only-token', 'Quinn \u0301\u0301', 'Quinn', 'Q'),
    ('rlo-only', '\u202E\u202E', 'Anonymous', '?'),
    ('lowercase-two', 'quinn testcase', 'Quinn T.', 'QT'),
    ('handle-no-dot', 'qtestcase@', 'Anonymous', '?'),
    ('at-only', '@', 'Anonymous', '?'),
    ('plus-joined', 'Quinn+Testcase', 'Anonymous', '?'),
    ('astral-letter-initial', 'Quinn \u{1D400}bc', 'Quinn A.', 'QA'),
    ('r5-hyphen-joined', 'Quinn-Testcase', 'Quinn T.', 'QT'),
    ('r5-hyphen-double-barrel', 'Mary-Jane O\'Neil', 'Mary O.', 'MO'),
    ('r5-runs-of-separators', '  Quinn  --  Testcase  ', 'Quinn T.', 'QT'),
    ('r5-leading-hyphen', '-Quinn', 'Quinn', 'Q'),
    ('r5-hyphen-only', '-', 'Anonymous', '?'),
    ('r5-trailing-hyphen-piece', 'Quinn -', 'Quinn', 'Q'),
    ('r5-rsquo-inside', 'Quinn O\u2019Brien', 'Quinn O.', 'QO'),
    ('r5-apostrophe-leading', '\'Quinn Testcase', 'Anonymous', '?'),
    ('r5-apostrophe-trailing', 'Quinn Testcase\'', 'Anonymous', '?'),
    ('r5-apostrophe-doubled', 'Quinn O\'\'Brien', 'Anonymous', '?'),
    ('r5-apostrophe-after-space', 'Quinn \'Testcase', 'Anonymous', '?'),
    ('r5-apostrophe-after-mark', 'Que\u0301\'nn Testcase', 'Qu\u00E9\'nn T.', 'QT'),
    ('r5-di-17B5', 'Quinn\u17B5Testcase', 'Anonymous', '?'),
    ('r5-di-180F', 'Quinn\u180FTestcase', 'Anonymous', '?'),
    ('r5-di-FE00', 'Quinn\uFE00Testcase', 'Anonymous', '?'),
    ('r5-di-E01EF', 'Quinn\u{E01EF}Testcase', 'Anonymous', '?'),
    ('r5-di-061C-alm', 'Quinn\u061CTestcase', 'Anonymous', '?'),
    ('r5-di-2064', 'Quinn\u2064Testcase', 'Anonymous', '?'),
    ('r5-di-206F', 'Quinn\u206FTestcase', 'Anonymous', '?'),
    ('r5-di-1BCA0', 'Quinn\u{1BCA0}Testcase', 'Anonymous', '?'),
    ('r5-di-1D173', 'Quinn\u{1D173}Testcase', 'Anonymous', '?'),
    ('r5-di-FFF0-unassigned', 'Quinn\uFFF0Testcase', 'Anonymous', '?'),
    ('r5-di-E0001-tag', 'Quinn\u{E0001}Testcase', 'Anonymous', '?'),
    ('r5-di-3164-trailing', 'Quinn Testcase\u3164', 'Anonymous', '?'),
    ('r5-di-3164-only', '\u3164', 'Anonymous', '?'),
    ('r5-di-vs16-after-word', 'Quinn\uFE0F Testcase', 'Anonymous', '?'),
    ('r5-nfkc-fullwidth-at-only', 'Quinn\uFF20', 'Anonymous', '?'),
    ('r5-nfkc-ligature-fi', '\uFB01ona Testcase', 'Fiona T.', 'FT'),
    ('r5-nfkc-composes-e-acute', 'e\u0301mile Testcase', '\u00C9mile T.', '\u00C9T'),
    ('r5-circled-a-word', 'Quinn \u24D0', 'Anonymous', '?'),
    ('r5-superscript-two', 'Quinn\u00B2', 'Anonymous', '?'),
    ('r5-roman-numeral', 'Quinn \u2167', 'Anonymous', '?'),
    ('r5-trademark', 'Quinn\u2122', 'Anonymous', '?'),
    ('r5-dot-trailing', 'Quinn.', 'Anonymous', '?'),
    ('r5-already-formatted', 'Jordan R.', 'Anonymous', '?'),
    ('r5-fullwidth-space', 'Quinn\u3000Testcase\u3000Jr', 'Anonymous', '?'),
    ('r5-hangul-name', '\uAE40 \uBBFC\uC900', '\uAE40 \uBBFC.', '\uAE40\uBBFC'),
    ('r1-unit-02', 'Jordan Rivera', 'Jordan R.', 'JR'),
    ('r1-unit-03', '  Jordan Rivera  ', 'Jordan R.', 'JR'),
    ('r1-unit-04', 'Jordan\u00A0Rivera', 'Anonymous', '?'),
    ('r1-unit-05', 'Jordan\u0009\u000A \u00A0Rivera', 'Anonymous', '?'),
    ('r1-unit-06', 'Rivera, Jordan', 'Anonymous', '?'),
    ('r1-unit-07', 'Riley', 'Riley', 'R'),
    ('r1-unit-08', 'jordan.rivera@example.com', 'Anonymous', '?'),
    ('r1-unit-09', 'jordan.rivera', 'Anonymous', '?'),
    ('r1-unit-10', 'morgan_lee', 'Anonymous', '?'),
    ('r1-unit-16', '\u200B\u200B', 'Anonymous', '?'),
    ('r1-unit-22', 'Quinn \u{1F984}.', 'Anonymous', '?'),
    ('r1-unit-24', '\u{1F984}Quinn Testcase', 'Anonymous', '?'),
    ('r1-unit-25', 'Quinnabellarosali\u{1F984}\u{1F984} Testcase', 'Anonymous', '?'),
    ('r1-unit-26', 'Maximiliana Wolfeschlegelstein', 'Maximiliana W.', 'MW'),
    ('r1-unit-28', 'Riley\u0009Smith\u000AJones', 'Anonymous', '?'),
    ('r1-unit-30', '\u{1F984}', 'Anonymous', '?'),
    ('r1-unit-31', 'blake', 'Blake', 'B'),
    ('r2-underscore-joined', 'Quinn_Testcase', 'Anonymous', '?'),
    ('r2-lowercase-single', 'quinn', 'Quinn', 'Q'),
    ];
    final forbidden = RegExp('[@\uFFFD]');
    final startsWithMark = RegExp(r'^\p{M}', unicode: true);
    // Default_Ignorable_Code_Point (Unicode 17.0.0), as in the migration.
    bool hasDefaultIgnorable(String s) => s.runes.any((cp) =>
        cp == 0xAD || cp == 0x34F || cp == 0x61C || (cp >= 0x115F && cp <= 0x1160) ||
        (cp >= 0x17B4 && cp <= 0x17B5) || (cp >= 0x180B && cp <= 0x180F) ||
        (cp >= 0x200B && cp <= 0x200F) || (cp >= 0x202A && cp <= 0x202E) ||
        (cp >= 0x2060 && cp <= 0x206F) || cp == 0x3164 || (cp >= 0xFE00 && cp <= 0xFE0F) ||
        cp == 0xFEFF || cp == 0xFFA0 || (cp >= 0xFFF0 && cp <= 0xFFF8) ||
        (cp >= 0x1BCA0 && cp <= 0x1BCA3) || (cp >= 0x1D173 && cp <= 0x1D17A) ||
        (cp >= 0xE0000 && cp <= 0xE0FFF));
    test('the table has every shape once', () {
      expect(cases.map((c) => c.$1).toSet().length, cases.length);
      expect(cases.length, 175);
    });
    for (final (label, raw, name, initials) in cases) {
      test('[$label]', () {
        final out = GamificationService.formatLeaderboardName(raw);
        expect(out, name);
        expect(GamificationService.leaderboardInitials(raw), initials);
        expect(forbidden.hasMatch(out), isFalse, reason: 'no @ or U+FFFD');
        expect(hasDefaultIgnorable(out), isFalse, reason: 'no default-ignorable code point');
        expect(startsWithMark.hasMatch(initials), isFalse, reason: 'no bare mark initial');
        // The app re-formats the server's already-formatted value: stable.
        expect(GamificationService.leaderboardDisplayName(out), out);
        // Initials the app derives from the server's value: the same, except a
        // name cut at the 18-code-point cap may have lost its last initial.
        final shown = GamificationService.leaderboardDisplayInitials(out);
        if (out.runes.length < GamificationService.leaderboardNameMaxLength) {
          expect(shown, initials);
        } else {
          expect(initials.startsWith(shown) && shown.isNotEmpty, isTrue, reason: shown);
        }
        if (raw != null && raw.contains('@')) {
          expect(out, 'Anonymous');
          expect(initials, '?');
        }
      });
    }
  });

  group('standingFromRow', () {
    test('drops avatar_url for other patients, keeps it for the own row', () {
      // Henry (TC-030 item 9): no photos of other patients on the leaderboard.
      final other = GamificationService.standingFromRow(
        {'name': 'Avery K.', 'avatar_url': 'data:image/png;base64,AAA', 'league_xp': 500, 'is_me': false},
      );
      final me = GamificationService.standingFromRow(
        {'name': 'Jordan R.', 'avatar_url': 'data:image/png;base64,BBB', 'league_xp': 400, 'is_me': true},
      );

      expect(other['avatar_url'], isNull);
      expect(me['avatar_url'], 'data:image/png;base64,BBB');
    });
  });
}
