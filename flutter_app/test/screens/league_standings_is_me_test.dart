// TC-026 (Henry follow-up, 2 Nov): the leaderboard no longer carries any
// user/patient id. LeagueStandings highlights the caller's own row from the
// server-set `is_me` flag only - exactly one row, on the podium or in the list.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zyndio_patient/config/theme.dart';
import 'package:zyndio_patient/providers/gamification_provider.dart';
import 'package:zyndio_patient/screens/settings/leagues_screen.dart';

List<Map<String, dynamic>> _rows({required int meIndex}) {
  const names = ['Avery K.', 'Blake M.', 'Casey L.', 'Jordan R.', 'Riley'];
  return [
    for (var i = 0; i < names.length; i++)
      {'name': names[i], 'avatar_url': null, 'league_xp': 500 - i * 50, 'is_me': i == meIndex},
  ];
}

Future<BuildContext> _pump(WidgetTester tester, List<Map<String, dynamic>> rows) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [leagueStandingsProvider.overrideWith((ref) async => rows)],
      child: MaterialApp(
        theme: BrandTheme.darkTheme,
        home: const Scaffold(body: SingleChildScrollView(child: LeagueStandings())),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return tester.element(find.byType(LeagueStandings));
}

Color? _nameColor(WidgetTester tester, String name) =>
    tester.widget<Text>(find.text(name.toUpperCase())).style?.color;

void main() {
  testWidgets('list row: only the is_me row (#4) is highlighted', (tester) async {
    final rows = _rows(meIndex: 3);
    final context = await _pump(tester, rows);
    final nc = context.nc;

    expect(_nameColor(tester, 'Jordan R.'), nc.textPrimary);
    expect(_nameColor(tester, 'Riley'), nc.textSecondary);
    for (final other in ['Avery K.', 'Blake M.', 'Casey L.']) {
      expect(_nameColor(tester, other), nc.textSecondary, reason: other);
    }

    // The list row's highlight container is tinted only for is_me.
    BoxDecoration rowDecoration(String name) => tester
        .widget<Container>(find.ancestor(of: find.text(name.toUpperCase()), matching: find.byType(Container)).first)
        .decoration as BoxDecoration;
    expect(rowDecoration('Jordan R.').color, isNot(Colors.transparent));
    expect(rowDecoration('Riley').color, Colors.transparent);
  });

  testWidgets('podium: only the is_me row (#1) is highlighted', (tester) async {
    final context = await _pump(tester, _rows(meIndex: 0));
    final nc = context.nc;

    expect(_nameColor(tester, 'Avery K.'), nc.textPrimary);
    for (final other in ['Blake M.', 'Casey L.', 'Jordan R.', 'Riley']) {
      expect(_nameColor(tester, other), nc.textSecondary, reason: other);
    }
  });

  testWidgets('no row is highlighted when no row has is_me (e.g. ids only)', (tester) async {
    // Rows without is_me - even carrying a user_id - must never be treated as
    // the caller's own row (the old id comparison would match null == null).
    final rows = [
      for (final r in _rows(meIndex: -1)) {...r..remove('is_me'), 'user_id': null},
    ];
    final context = await _pump(tester, rows);
    final nc = context.nc;
    for (final name in ['Avery K.', 'Blake M.', 'Casey L.', 'Jordan R.', 'Riley']) {
      expect(_nameColor(tester, name), nc.textSecondary, reason: name);
    }
  });
}
