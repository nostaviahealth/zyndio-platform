// TC-030 item 0a (Ava, PR #29 review): the own-row cues must clear contrast and
// must not be double-read.
//   - Own list-row border is the solid design token #2563EB (WCAG 1.4.1 >=3:1)
//     in both light and dark.
//   - The "You" pill text clears AA (>=4.5:1) on its tint: #1D4ED8 light,
//     #93C5FD dark.
//   - Each row exposes exactly ONE semantics label (rank, name, you, XP); the
//     per-child name node is excluded so a screen reader reads the row once.
//
// Fail-first: the reviewed head drew the border with context.nc.primary @70%
// (2.46:1 light), coloured the pill with context.nc.primary (2.71:1 light) and
// wrapped the row in Semantics WITHOUT excludeSemantics (name read twice), so
// each assertion below goes red on it.
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

Future<void> _pump(WidgetTester tester, List<Map<String, dynamic>> rows, ThemeData theme) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [leagueStandingsProvider.overrideWith((ref) async => rows)],
      child: MaterialApp(
        theme: theme,
        home: const Scaffold(body: SingleChildScrollView(child: LeagueStandings())),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Border _ownRowBorder(WidgetTester tester, String name) {
  final container = tester.widget<Container>(
    find.ancestor(of: find.text(name.toUpperCase()), matching: find.byType(Container)).first,
  );
  return (container.decoration as BoxDecoration).border as Border;
}

void main() {
  group('own-row list border is the solid #2563EB token', () {
    testWidgets('light', (tester) async {
      await _pump(tester, _rows(meIndex: 3), BrandTheme.lightTheme);
      expect(_ownRowBorder(tester, 'Jordan R.').top.color, const Color(0xFF2563EB));
    });

    testWidgets('dark', (tester) async {
      await _pump(tester, _rows(meIndex: 3), BrandTheme.darkTheme);
      expect(_ownRowBorder(tester, 'Jordan R.').top.color, const Color(0xFF2563EB));
    });
  });

  group('"You" pill text clears AA on its tint', () {
    testWidgets('light -> #1D4ED8', (tester) async {
      await _pump(tester, _rows(meIndex: 3), BrandTheme.lightTheme);
      expect(tester.widget<Text>(find.text('You')).style?.color, const Color(0xFF1D4ED8));
    });

    testWidgets('dark -> #93C5FD', (tester) async {
      await _pump(tester, _rows(meIndex: 3), BrandTheme.darkTheme);
      expect(tester.widget<Text>(find.text('You')).style?.color, const Color(0xFF93C5FD));
    });
  });

  group('each row is read exactly once (no duplicated name/rank)', () {
    testWidgets('own list row exposes a single combined label', (tester) async {
      final handle = tester.ensureSemantics();
      await _pump(tester, _rows(meIndex: 3), BrandTheme.darkTheme);

      // The combined label carries rank, name, the "you" cue and XP, once.
      expect(find.bySemanticsLabel('#4, Jordan R., you, 350 XP'), findsOneWidget);
      // ...and the name is NOT also announced by a separate child Text node.
      expect(find.bySemanticsLabel(RegExp('Jordan R', caseSensitive: false)), findsOneWidget);
      handle.dispose();
    });

    testWidgets('own podium row exposes a single combined label', (tester) async {
      final handle = tester.ensureSemantics();
      await _pump(tester, _rows(meIndex: 0), BrandTheme.darkTheme);

      expect(find.bySemanticsLabel('#1, Avery K., you, 500 XP'), findsOneWidget);
      expect(find.bySemanticsLabel(RegExp('Avery K', caseSensitive: false)), findsOneWidget);
      handle.dispose();
    });

    testWidgets('a non-caller row has no "you" and is read once', (tester) async {
      final handle = tester.ensureSemantics();
      await _pump(tester, _rows(meIndex: 3), BrandTheme.darkTheme);

      // Riley (index 4) is not the caller: label has rank + name + XP, no "you".
      expect(find.bySemanticsLabel('#5, Riley, 300 XP'), findsOneWidget);
      expect(find.bySemanticsLabel(RegExp('Riley', caseSensitive: false)), findsOneWidget);
      handle.dispose();
    });
  });
}
