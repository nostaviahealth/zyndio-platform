// TC-030 item 0a (Ava, PR #25 review): the leaderboard must mark the caller's
// own row with a non-colour cue - a visible "You" pill and a screen-reader
// "(you)" suffix - on both the podium and the list, so the own-row cue does not
// rely on colour alone (WCAG 1.4.1).
//
// Fail-first: the pre-item-0a screen highlighted the own row by colour only, with
// no "You" pill and no "(you)" Semantics label, so every assertion below goes red
// on the old code.
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

Future<void> _pump(WidgetTester tester, List<Map<String, dynamic>> rows) async {
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
}

void main() {
  testWidgets('list row: own row shows a "You" pill and a (you) screen-reader label', (tester) async {
    final handle = tester.ensureSemantics();
    await _pump(tester, _rows(meIndex: 3)); // Jordan R. is me, in the list

    // Exactly one visible "You" pill, on the own row only.
    expect(find.text('You'), findsOneWidget);
    // Screen reader announces the own row with a (you) suffix.
    expect(find.bySemanticsLabel(RegExp(r'\(you\)')), findsOneWidget);
    handle.dispose();
  });

  testWidgets('podium: own podium row shows a "You" pill and a (you) screen-reader label', (tester) async {
    final handle = tester.ensureSemantics();
    await _pump(tester, _rows(meIndex: 0)); // Avery K. is me, on the podium

    expect(find.text('You'), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp(r'\(you\)')), findsOneWidget);
    handle.dispose();
  });

  testWidgets('no "You" cue when no row is the caller', (tester) async {
    final handle = tester.ensureSemantics();
    await _pump(tester, _rows(meIndex: -1)); // nobody is me

    expect(find.text('You'), findsNothing);
    expect(find.bySemanticsLabel(RegExp(r'\(you\)')), findsNothing);
    handle.dispose();
  });
}
