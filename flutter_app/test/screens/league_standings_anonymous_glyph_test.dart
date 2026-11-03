// TC-030 item 20 (Ava, PR #29 r5): an anonymous leaderboard row shows the Lucide
// `user` glyph (not '?' or 'A') at 20px on the 28px list avatar, on the same
// tint and in the same textSecondary colour as the initials, and is read as
// "#n, Anonymous, N XP". On the caller's OWN anonymous row the "You" pill is the
// row's only visible label and the screen reader reads "#n, You, N XP" - the row
// never reads "Anonymous, you". A named own row keeps "#n, Jordan R., you, N XP".
//
// Fail-first: at bbf14a0 an anonymous row rendered a '?' initials avatar (no
// glyph), and an own anonymous row read "#n, Anonymous, you, N XP" with the
// "ANONYMOUS" text beside the pill, so every assertion below on those goes red.
// Fictional names only.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:zyndio_patient/config/theme.dart';
import 'package:zyndio_patient/providers/gamification_provider.dart';
import 'package:zyndio_patient/screens/settings/leagues_screen.dart';

Future<void> _pump(WidgetTester tester, List<Map<String, dynamic>> rows, {bool dark = false}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [leagueStandingsProvider.overrideWith((ref) async => rows)],
      child: MaterialApp(
        theme: dark ? BrandTheme.darkTheme : BrandTheme.lightTheme,
        home: const Scaffold(body: SingleChildScrollView(child: LeagueStandings())),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

final _glyph = find.byKey(const ValueKey('leaderboard-anonymous-glyph'));

/// CircleAvatar that directly wraps [child].
CircleAvatar _avatarOf(WidgetTester tester, Finder child) =>
    tester.widget<CircleAvatar>(find.ancestor(of: child, matching: find.byType(CircleAvatar)).first);

void main() {
  // Rows 0-2 are the podium, 3+ the list. The server returns 'Anonymous' for a
  // rejected name; null is handled the same way.
  List<Map<String, dynamic>> board({int meIndex = 0, String meName = 'Jordan R.'}) => [
        {'name': 'Avery K.', 'avatar_url': null, 'league_xp': 500, 'is_me': meIndex == 0},
        {'name': 'Blake M.', 'avatar_url': null, 'league_xp': 450, 'is_me': meIndex == 1},
        {'name': 'Casey L.', 'avatar_url': null, 'league_xp': 400, 'is_me': meIndex == 2},
        {'name': meIndex == 3 ? meName : 'Anonymous', 'avatar_url': null, 'league_xp': 350, 'is_me': meIndex == 3},
        {'name': null, 'avatar_url': null, 'league_xp': 300, 'is_me': false},
        {'name': 'Riley', 'avatar_url': null, 'league_xp': 250, 'is_me': false},
      ];

  for (final dark in [false, true]) {
    final mode = dark ? 'dark' : 'light';

    testWidgets('[$mode] anonymous rows show the Lucide user glyph, 20px, same tint and colour as initials',
        (tester) async {
      await _pump(tester, board(meIndex: 0), dark: dark);

      // Two anonymous list rows ('Anonymous' and null) -> two glyphs.
      expect(_glyph, findsNWidgets(2));
      for (final icon in tester.widgetList<Icon>(_glyph)) {
        expect(icon.icon, LucideIcons.user);
        expect(icon.size, 20, reason: '20px at the 28px (radius 14) list avatar');
      }
      // Same tint and colour as a named row's initials avatar (Riley -> "R").
      final initials = find.descendant(of: find.byType(CircleAvatar), matching: find.text('R'));
      expect(initials, findsOneWidget);
      final initialsText = tester.widget<Text>(initials);
      final glyphIcon = tester.widget<Icon>(_glyph.first);
      expect(glyphIcon.color, initialsText.style!.color);
      expect(_avatarOf(tester, _glyph.first).backgroundColor, _avatarOf(tester, initials).backgroundColor);
      expect(_avatarOf(tester, _glyph.first).radius, 14);

      // No '?' or 'A' placeholder initials anywhere.
      final avatarTexts = tester
          .widgetList<Text>(find.descendant(of: find.byType(CircleAvatar), matching: find.byType(Text)))
          .map((t) => t.data)
          .toList();
      expect(avatarTexts, isNot(contains('?')));
      expect(avatarTexts, isNot(contains('A')));
    });
  }

  testWidgets('another patient\'s anonymous row reads "#n, Anonymous, N XP"', (tester) async {
    final handle = tester.ensureSemantics();
    await _pump(tester, board(meIndex: 0));
    expect(find.bySemanticsLabel('#4, Anonymous, 350 XP'), findsOneWidget);
    expect(find.bySemanticsLabel('#5, Anonymous, 300 XP'), findsOneWidget);
    expect(find.text('ANONYMOUS'), findsNWidgets(2));
    handle.dispose();
  });

  testWidgets('own anonymous list row: the "You" pill is the label - "#n, You, N XP", never "Anonymous, you"',
      (tester) async {
    final handle = tester.ensureSemantics();
    await _pump(tester, board(meIndex: 3, meName: 'Anonymous'));

    expect(find.bySemanticsLabel('#4, You, 350 XP'), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp(r'Anonymous, you', caseSensitive: false)), findsNothing);
    expect(find.text('You'), findsOneWidget);
    // Only the OTHER anonymous row (#5) shows the word; the own row shows the pill alone.
    expect(find.text('ANONYMOUS'), findsOneWidget);
    // The own anonymous row still gets the glyph avatar (no photo).
    expect(_glyph, findsNWidgets(2));
    handle.dispose();
  });

  testWidgets('own anonymous podium row: "#1, You, N XP" and no "ANONYMOUS" text', (tester) async {
    final handle = tester.ensureSemantics();
    final rows = board(meIndex: -1)..[0] = {'name': null, 'avatar_url': null, 'league_xp': 500, 'is_me': true};
    await _pump(tester, rows);

    expect(find.bySemanticsLabel('#1, You, 500 XP'), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp(r'Anonymous, you', caseSensitive: false)), findsNothing);
    expect(find.text('You'), findsOneWidget);
    // Podium glyph is scaled the same way (radius 45 -> 45 * 10 / 7).
    final podiumGlyph = tester.widgetList<Icon>(_glyph).firstWhere((i) => i.size! > 20);
    expect(podiumGlyph.size, closeTo(45 * 10 / 7, 0.001));
    handle.dispose();
  });

  testWidgets('a named own row keeps "#n, Jordan R., you, N XP"', (tester) async {
    final handle = tester.ensureSemantics();
    await _pump(tester, board(meIndex: 3, meName: 'Jordan R.'));
    expect(find.bySemanticsLabel('#4, Jordan R., you, 350 XP'), findsOneWidget);
    expect(find.text('JORDAN R.'), findsOneWidget);
    handle.dispose();
  });

  test('leaderboardRowLabel wording', () {
    expect(leaderboardRowLabel(rank: 4, name: 'Anonymous', xp: 350, isMe: true, youOnly: true), '#4, You, 350 XP');
    expect(leaderboardRowLabel(rank: 5, name: 'Anonymous', xp: 300, isMe: false, youOnly: false),
        '#5, Anonymous, 300 XP');
    expect(leaderboardRowLabel(rank: 2, name: 'Jordan R.', xp: 450, isMe: true, youOnly: false),
        '#2, Jordan R., you, 450 XP');
  });
}
