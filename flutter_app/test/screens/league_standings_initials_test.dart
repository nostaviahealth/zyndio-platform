// TC-030 item 9 (Clara PR #29 r2, L-b and L-c): other patients' leaderboard
// rows have no photo (the RPC nulls their avatar_url), so each one must render
// its initials, and an emoji first letter must render as one whole grapheme,
// never a lone UTF-16 surrogate (U+FFFD).
//
// Clara PR #29 r3 / Henry's ruling: initials and names come from LETTERS only
// (an emoji is a separator), so a defensive emoji in a row's name now gives
// "Q" / "CL" initials and "QUINN" / "CASEY L." text (it was "Q\u{1F984}" /
// "\u{1F984}L" / "QUINN \u{1F984}." at 3fc5f75).
//
// Fail-first: blanking the initials in _buildAvatarPlaceholder fails the
// initials group; taking `name[0]` instead of `characters.first` renders
// "Q\uFFFD"-style text and fails the emoji group.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zyndio_patient/config/theme.dart';
import 'package:zyndio_patient/providers/gamification_provider.dart';
import 'package:zyndio_patient/screens/settings/leagues_screen.dart';

Future<void> _pump(WidgetTester tester, List<Map<String, dynamic>> rows) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [leagueStandingsProvider.overrideWith((ref) async => rows)],
      child: MaterialApp(
        theme: BrandTheme.lightTheme,
        home: const Scaffold(body: SingleChildScrollView(child: LeagueStandings())),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

/// Text inside a CircleAvatar (the initials placeholder), in widget order.
List<String> _avatarTexts(WidgetTester tester) => tester
    .widgetList<Text>(find.descendant(of: find.byType(CircleAvatar), matching: find.byType(Text)))
    .map((t) => t.data ?? '')
    .toList();

void main() {
  // Fictional names. Five rows: three podium places plus two list rows, so
  // both avatar placements are covered. Row 0 is the caller.
  final rows = <Map<String, dynamic>>[
    {'name': 'Jordan R.', 'avatar_url': null, 'league_xp': 500, 'is_me': true},
    {'name': 'Avery K.', 'avatar_url': null, 'league_xp': 450, 'is_me': false},
    {'name': 'Quinn \u{1F984}.', 'avatar_url': null, 'league_xp': 400, 'is_me': false},
    {'name': 'Blake M.', 'avatar_url': null, 'league_xp': 350, 'is_me': false},
    {'name': '\u{1F984}Casey L.', 'avatar_url': null, 'league_xp': 300, 'is_me': false},
  ];

  testWidgets('other patients\' rows render their initials, not a blank or an icon', (tester) async {
    await _pump(tester, rows);
    final texts = _avatarTexts(tester);
    expect(texts, contains('AK'));
    expect(texts, contains('BM'));
    expect(texts.where((t) => t.trim().isEmpty), isEmpty);
    // No generic person icon stands in for another patient's initials.
    expect(find.descendant(of: find.byType(CircleAvatar), matching: find.byIcon(Icons.person)), findsNothing);
  });

  testWidgets('an emoji in a name is never an initial, and nothing renders U+FFFD', (tester) async {
    await _pump(tester, rows);
    final texts = _avatarTexts(tester);
    expect(texts, contains('Q'));
    expect(texts, contains('CL'));
    expect(texts.where((t) => t.contains('\u{1F984}')), isEmpty);
    // No rendered Text anywhere on the board carries a replacement char or a
    // lone surrogate.
    for (final t in tester.widgetList<Text>(find.byType(Text))) {
      final s = t.data ?? '';
      expect(s, isNot(contains('\uFFFD')));
      expect(String.fromCharCodes(s.runes), s, reason: 'lone surrogate in "$s"');
    }
    expect(find.text('QUINN'), findsWidgets);
    expect(find.text('CASEY L.'), findsWidgets);
  });
}
