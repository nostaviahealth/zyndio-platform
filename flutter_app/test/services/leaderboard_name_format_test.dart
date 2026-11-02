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

    test('an email-like name uses the local part, domain stripped', () {
      expect(fmt('jordan.rivera@example.com'), startsWith('jordan.rivera'));
      expect(fmt('jordan.rivera@example.com'), isNot(contains('@')));
      expect(fmt('jordan.rivera@example.com'), isNot(contains('example')));
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
