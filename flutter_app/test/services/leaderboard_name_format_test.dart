// TC-030 item 9 (Clara PR #25 r2): the leaderboard name formatter must be
// robust. The RPC already returns "First L.", but the UI formats defensively
// so an odd value (NBSP/tab/newline whitespace, "Last, First", a one-word or
// email-like name, an over-long name) can't break the "First L." shape or the
// row layout. These cases fail on the old code, which did only `.toUpperCase()`.
//
// Clara PR #29 r3 / Henry's ruling: a name is never built from an email or a
// handle (any '@' -> 'Anonymous' / '?'), and tokens split on anything that is
// not a letter, mark, number or apostrophe, each starting at its first letter -
// the same rule as the server (migration 20261103110000). The probe table at
// the bottom is the same table supabase/tests/741 pins against the RPC.
import 'package:flutter_test/flutter_test.dart';
import 'package:zyndio_patient/services/gamification_service.dart';

void main() {
  String fmt(String? raw) => GamificationService.formatLeaderboardName(raw);

  group('formatLeaderboardName', () {
    test('already-formatted "First L." is left as-is (idempotent)', () {
      expect(fmt('Jordan R.'), 'Jordan R.');
    });

    test('a plain two-word name becomes "First L."', () {
      expect(fmt('Jordan Rivera'), 'Jordan R.');
    });

    test('trims surrounding whitespace', () {
      expect(fmt('  Jordan Rivera  '), 'Jordan R.');
    });

    test('splits on a non-breaking space (NBSP) between first and last', () {
      //   (NBSP): a plain `.split(" ")` never handles this, so the initial
      // would be wrong or the whole string renders as one unsplit word.
      expect(fmt('Jordan Rivera'), 'Jordan R.');
    });

    test('collapses runs of mixed whitespace (tab, newline, NBSP, spaces)', () {
      expect(fmt('Jordan\t\n  Rivera'), 'Jordan R.');
    });

    test('handles the "Last, First" comma form', () {
      expect(fmt('Rivera, Jordan'), 'Jordan R.');
    });

    test('a one-word name is used as-is (no empty initial)', () {
      expect(fmt('Riley'), 'Riley');
    });

    test('an email-like name is never used: exactly "Anonymous" (Henry, PR #29 r3)', () {
      // TC-030 item 9: a name is never built from an email or handle - not even
      // an initial - so nothing of the local part or domain can surface.
      expect(fmt('jordan.rivera@example.com'), 'Anonymous');
      expect(fmt('jordan.rivera@example.com'), isNot(contains('@')));
      expect(fmt('jordan.rivera@example.com'), isNot(contains('rivera')));
      expect(fmt('jordan.rivera@example.com'), isNot(contains('example')));
    });

    test('a bare "first.last" token (server-stripped email) also becomes "First L."', () {
      // The RPC drops the domain but can still hand back "jordan.rivera"; the
      // client must not render that verbatim either.
      expect(fmt('jordan.rivera'), 'Jordan R.');
      expect(fmt('morgan_lee'), 'Morgan L.');
    });

    test('zero-width-joined names split like whitespace (Clara PR #29 r2 H3)', () {
      expect(fmt('Quinn\u200BTestcase'), 'Quinn T.');
      expect(fmt('Quinn\u200CTestcase'), 'Quinn T.');
      expect(fmt('Quinn\u200DTestcase'), 'Quinn T.');
      expect(fmt('Quinn\u2060Testcase'), 'Quinn T.');
      expect(fmt('Quinn\uFEFFTestcase'), 'Quinn T.');
      expect(fmt('\u200B\u200B'), 'Anonymous');
    });

    test('dot/underscore/hyphen-joined names -> "Quinn T."; emails -> "Anonymous"', () {
      expect(fmt('Quinn.Testcase'), 'Quinn T.');
      expect(fmt('quinn.testcase@example.test'), 'Anonymous');
      expect(fmt('quinn_testcase@example.test'), 'Anonymous');
      expect(fmt('quinn-testcase@example.test'), 'Anonymous');
    });

    test('a value with no local part ("@handle") falls back, never shows the handle', () {
      expect(fmt('@testcase'), 'Anonymous');
      expect(fmt('@testcase'), isNot(contains('testcase')));
    });

    test('an emoji is a separator, never an initial, and never split (no U+FFFD)', () {
      // PR #29 r3: initials come from the first LETTER, so the server now
      // returns "Quinn T." for "Quinn \u{1F984}Testcase" (was "Quinn \u{1F984}.").
      expect(fmt('Quinn \u{1F984}.'), 'Quinn');
      expect(fmt('Quinn \u{1F984}Testcase'), 'Quinn T.');
      expect(fmt('\u{1F984}Quinn Testcase'), 'Quinn T.');
      for (final out in [fmt('Quinn \u{1F984}Testcase'), fmt('\u{1F984}Quinn Testcase')]) {
        expect(out, isNot(contains('\uFFFD')));
        // Every UTF-16 unit is paired: re-encoding round-trips unchanged.
        expect(String.fromCharCodes(out.runes), out);
      }
    });

    test('the length cap never splits an emoji', () {
      final out = fmt('Quinnabellarosali\u{1F984}\u{1F984} Testcase');
      expect(out, isNot(contains('\uFFFD')));
      expect(String.fromCharCodes(out.runes), out);
    });

    test('caps the rendered length', () {
      final out = fmt('Maximiliana Wolfeschlegelstein');
      expect(out.length, lessThanOrEqualTo(GamificationService.leaderboardNameMaxLength));
    });

    test('null or blank falls back', () {
      expect(fmt(null), 'Anonymous');
      expect(fmt('   '), 'Anonymous');
      expect(GamificationService.formatLeaderboardName(null, fallback: 'Unknown'), 'Unknown');
    });
  });

  group('leaderboardInitials', () {
    // TC-030 item 9 (Ava): non-caller rows show initials, not a generic icon.
    String ini(String? raw) => GamificationService.leaderboardInitials(raw);

    test('two-word name -> first + last initial', () {
      expect(ini('Jordan Rivera'), 'JR');
      expect(ini('Jordan R.'), 'JR');
    });

    test('"Last, First" -> first + last initial', () {
      expect(ini('Rivera, Jordan'), 'JR');
    });

    test('an email-like name gives no initials at all (Henry, PR #29 r3)', () {
      expect(ini('jordan.rivera@example.com'), '?');
      expect(ini('jordan.rivera'), 'JR');
    });

    test('mixed whitespace (NBSP/tab/newline) still splits', () {
      expect(ini('Jordan Rivera'), 'JR');
      expect(ini('Riley\tSmith\nJones'), 'RJ');
    });

    test('initials come from letters only - an emoji is never an initial (no U+FFFD)', () {
      expect(ini('Quinn \u{1F984}.'), 'Q');
      expect(ini('\u{1F984} Testcase'), 'T');
      expect(ini('\u{1F984}'), '?');
      expect(ini('Quinn \u{1F984}.'), isNot(contains('\uFFFD')));
    });

    test('zero-width-joined and dot-joined names -> two initials', () {
      expect(ini('Quinn\u200BTestcase'), 'QT');
      expect(ini('Quinn.Testcase'), 'QT');
    });

    test('"@handle" falls back', () {
      expect(ini('@testcase'), '?');
    });

    test('one-word name -> single initial', () {
      expect(ini('Riley'), 'R');
      expect(ini('blake'), 'B');
    });

    test('null or blank falls back', () {
      expect(ini(null), '?');
      expect(ini('   '), '?');
    });
  });

  group('Clara PR #29 r3 probe table (same expectations as supabase/tests/741)', () {
    // (label, raw name, formatLeaderboardName, leaderboardInitials)
    const cases = <(String, String?, String, String)>[
    ('comma', 'Testcase, Quinn', 'Quinn T.', 'QT'),
    ('comma-nospace', 'Testcase,Quinn', 'Quinn T.', 'QT'),
    ('email', 'quinn.testcase@example.test', 'Anonymous', '?'),
    ('email-underscore', 'quinn_testcase@example.test', 'Anonymous', '?'),
    ('email-plain', 'qtestcase@example.test', 'Anonymous', '?'),
    ('nbsp', 'Quinn\u00A0Testcase', 'Quinn T.', 'QT'),
    ('tab-newline', 'Quinn\u0009\u000ATestcase', 'Quinn T.', 'QT'),
    ('single', 'Quinn', 'Quinn', 'Q'),
    ('three-words', 'Quinn Avery Testcase', 'Quinn T.', 'QT'),
    ('emoji', 'Quinn \u{1F984}Testcase', 'Quinn T.', 'QT'),
    ('emoji-first', '\u{1F984} Testcase', 'Testcase', 'T'),
    ('unicode', 'Zo\u00EB \u00C5ngstr\u00F6m', 'Zo\u00EB \u00C5.', 'Z\u00C5'),
    ('zwsp', 'Quinn\u200BTestcase', 'Quinn T.', 'QT'),
    ('emspace', 'Quinn\u2003Testcase', 'Quinn T.', 'QT'),
    ('ideographic', 'Quinn\u3000Testcase', 'Quinn T.', 'QT'),
    ('empty', '', 'Anonymous', '?'),
    ('whitespace', '   ', 'Anonymous', '?'),
    ('nbsp-only', '\u00A0\u00A0', 'Anonymous', '?'),
    ('dot-local', 'Quinn.Testcase', 'Quinn T.', 'QT'),
    ('at-first', '@testcase', 'Anonymous', '?'),
    ('long', 'Quinnabellarosalind Testcase', 'Quinnabellarosalin', 'QT'),
    ('null', null, 'Anonymous', '?'),
    ('email-hyphen', 'quinn-testcase@example.test', 'Anonymous', '?'),
    ('email-upper', 'QUINN.TESTCASE@EXAMPLE.TEST', 'Anonymous', '?'),
    ('email-plus', 'quinn+testcase@example.test', 'Anonymous', '?'),
    ('email-plus-dot', 'quinn.t+clinic@example.test', 'Anonymous', '?'),
    ('multi-at', 'quinn.testcase@foo@example.test', 'Anonymous', '?'),
    ('multi-at2', 'quinn@testcase@example.test', 'Anonymous', '?'),
    ('lead-trail-sep', '_quinn.testcase_', 'Quinn T.', 'QT'),
    ('lead-dot-surname', '.testcase', 'Testcase', 'T'),
    ('trail-dot', 'testcase.', 'Testcase', 'T'),
    ('dot-only-surname-email', '.testcase@example.test', 'Anonymous', '?'),
    ('zwnj', 'Quinn\u200CTestcase', 'Quinn T.', 'QT'),
    ('zwj', 'Quinn\u200DTestcase', 'Quinn T.', 'QT'),
    ('wj', 'Quinn\u2060Testcase', 'Quinn T.', 'QT'),
    ('bom', 'Quinn\uFEFFTestcase', 'Quinn T.', 'QT'),
    ('soft-hyphen', 'Quinn\u00ADTestcase', 'Quinn T.', 'QT'),
    ('lrm', 'Quinn\u200ETestcase', 'Quinn T.', 'QT'),
    ('rlm', 'Quinn\u200FTestcase', 'Quinn T.', 'QT'),
    ('mongolian-vs', 'Quinn\u180ETestcase', 'Quinn T.', 'QT'),
    ('invisible-times', 'Quinn\u2062Testcase', 'Quinn T.', 'QT'),
    ('rlo-joined', 'Quinn\u202ETestcase', 'Quinn T.', 'QT'),
    ('rlo-word', 'Quinn \u202ETestcase', 'Quinn T.', 'QT'),
    ('combining', 'Que\u0301nn Te\u0301stcase', 'Que\u0301nn T.', 'QT'),
    ('combining-lead', 'Quinn \u0301Testcase', 'Quinn T.', 'QT'),
    ('very-long', 'QQQQQQQQQQQQQQQQQQQQQQQQQQQQQQQQQQQQQQQQ TTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTTT', 'QQQQQQQQQQQQQQQQQQ', 'QT'),
    ('very-long-joined', 'Quinnabellarosalindevangeline.Testcasesmithington', 'Quinnabellarosalin', 'QT'),
    ('digits', 'Quinn2 Testcase99', 'Quinn2 T.', 'QT'),
    ('digits-only', '12345', 'Anonymous', '?'),
    ('honorific', 'Dr. Quinn Testcase', 'Dr T.', 'DT'),
    ('hyphen-surname', 'Quinn Testcase-Smith', 'Quinn S.', 'QS'),
    ('hyphen-comma', 'Testcase-Smith, Quinn', 'Quinn S.', 'QS'),
    ('handle-email', 'qtestcase@example.test', 'Anonymous', '?'),
    ('camel-email', 'QuinnTestcase@example.test', 'Anonymous', '?'),
    ('plain-handle', 'qtestcase', 'Qtestcase', 'Q'),
    ('emoji-joined', 'Quinn\u{1F984}Testcase', 'Quinn T.', 'QT'),
    ('thin-space', 'Quinn\u2009Testcase', 'Quinn T.', 'QT'),
    ('line-sep', 'Quinn\u2028Testcase', 'Quinn T.', 'QT'),
    ('comma-email', 'Testcase, Quinn@example.test', 'Anonymous', '?'),
    ('apostrophe-surname', 'Se\u00E1n O\'Brien', 'Se\u00E1n O.', 'SO'),
    ('apostrophe-lead', 'd\'Arcy Testcase', 'D\'Arcy T.', 'DT'),
    ('curly-apostrophe-lead', 'Quinn \u2019Testcase', 'Quinn T.', 'QT'),
    ('devanagari-conjunct', '\u092A\u094D\u0930\u093F\u092F\u093E \u0936\u0930\u094D\u092E\u093E', '\u092A\u094D\u0930\u093F\u092F\u093E \u0936.', '\u092A\u094D\u0936'),
    ('decomposed-first', 'e\u0301mile Testcase', 'E\u0301mile T.', 'E\u0301T'),
    ('arabic-digit-token', 'Quinn \u0661\u0662', 'Quinn', 'Q'),
    ('digit-led-surname', 'Quinn 2Testcase', 'Quinn T.', 'QT'),
    ('mark-only-token', 'Quinn \u0301\u0301', 'Quinn', 'Q'),
    ('rlo-only', '\u202E\u202E', 'Anonymous', '?'),
    ('lowercase-two', 'quinn testcase', 'Quinn T.', 'QT'),
    ('comma-only', ',', 'Anonymous', '?'),
    ('handle-no-dot', 'qtestcase@', 'Anonymous', '?'),
    ('at-only', '@', 'Anonymous', '?'),
    ('plus-joined', 'Quinn+Testcase', 'Quinn T.', 'QT'),
    ('astral-letter-initial', 'Quinn \u{1D400}bc', 'Quinn \u{1D400}.', 'Q\u{1D400}'),
    ];
    final forbidden = RegExp('[@\uFFFD\u00AD\u200E\u200F\u180E\u2062\u202A-\u202E\u200B-\u200D\u2060\uFEFF\u2066-\u2069]');
    final startsWithMark = RegExp(r'^\p{M}', unicode: true);
    for (final (label, raw, name, initials) in cases) {
      test('[$label]', () {
        final out = GamificationService.formatLeaderboardName(raw);
        expect(out, name);
        expect(GamificationService.leaderboardInitials(raw), initials);
        expect(forbidden.hasMatch(out), isFalse, reason: 'no @, U+FFFD or format char');
        expect(startsWithMark.hasMatch(initials), isFalse, reason: 'no bare mark initial');
        // The app re-formats the server's already-formatted value: stable.
        expect(GamificationService.formatLeaderboardName(out), out);
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
