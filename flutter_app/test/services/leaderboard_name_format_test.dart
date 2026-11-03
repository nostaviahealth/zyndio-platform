// TC-030 item 9 (Clara PR #25 r2): the leaderboard name formatter must be
// robust. The RPC already returns "First L.", but the UI formats defensively
// so an odd value (NBSP/tab/newline whitespace, "Last, First", a one-word or
// email-like name, an over-long name) can't break the "First L." shape or the
// row layout. These cases fail on the old code, which did only `.toUpperCase()`.
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

    test('an email-like name renders "First L.", never the local part or surname', () {
      // TC-030 item 9 (Ava): "jordan.rivera@x.org" must not surface the full
      // local part ("JORDAN.RIVERA") or the surname - only "Jordan R.".
      expect(fmt('jordan.rivera@example.com'), 'Jordan R.');
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

    test('dot/underscore/hyphen-joined names and email local parts -> "Quinn T."', () {
      expect(fmt('Quinn.Testcase'), 'Quinn T.');
      expect(fmt('quinn.testcase@example.test'), 'Quinn T.');
      expect(fmt('quinn_testcase@example.test'), 'Quinn T.');
      expect(fmt('quinn-testcase@example.test'), 'Quinn T.');
    });

    test('a value with no local part ("@handle") falls back, never shows the handle', () {
      expect(fmt('@testcase'), 'Anonymous');
      expect(fmt('@testcase'), isNot(contains('testcase')));
    });

    test('an emoji first letter is never split into a lone surrogate (no U+FFFD)', () {
      // The server returns "Quinn \u{1F984}." for "Quinn \u{1F984}Testcase".
      expect(fmt('Quinn \u{1F984}.'), 'Quinn \u{1F984}.');
      expect(fmt('Quinn \u{1F984}Testcase'), 'Quinn \u{1F984}.');
      expect(fmt('\u{1F984}Quinn Testcase'), '\u{1F984}Quinn T.');
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

    test('an email-like name uses the name, never the domain', () {
      expect(ini('jordan.rivera@example.com'), 'JR');
      expect(ini('jordan.rivera'), 'JR');
    });

    test('mixed whitespace (NBSP/tab/newline) still splits', () {
      expect(ini('Jordan Rivera'), 'JR');
      expect(ini('Riley\tSmith\nJones'), 'RJ');
    });

    test('emoji first letters stay whole graphemes (no U+FFFD)', () {
      expect(ini('Quinn \u{1F984}.'), 'Q\u{1F984}');
      expect(ini('\u{1F984} Testcase'), '\u{1F984}T');
      expect(ini('\u{1F984}'), '\u{1F984}');
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
