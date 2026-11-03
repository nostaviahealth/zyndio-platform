// TC-030 item 11 (Ava): leaderboard contrast/robustness. The own-row XP uses a
// success green that meets AA on both surfaces (#047857 light / #34D399 dark);
// the empty and error states use readable sentence-case copy in the theme's
// secondary token instead of the old all-caps/invisible text.
//
// Fail-first: the pre-item-11 screen had no "No standings yet" empty copy, no
// friendly error line, and coloured own-row XP with an invisible Colors.white38
// rather than the AA success green - so every assertion below goes red on it.
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

Future<void> _pump(
  WidgetTester tester,
  Future<List<Map<String, dynamic>>> Function(Ref ref) build, {
  ThemeData? theme,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [leagueStandingsProvider.overrideWith(build)],
      child: MaterialApp(
        theme: theme ?? BrandTheme.darkTheme,
        home: const Scaffold(body: SingleChildScrollView(child: LeagueStandings())),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('empty standings show readable "No standings yet" copy', (tester) async {
    await _pump(tester, (ref) async => <Map<String, dynamic>>[]);
    expect(find.text('No standings yet'), findsOneWidget);
  });

  testWidgets('a load error shows friendly copy, not the raw exception', (tester) async {
    await _pump(tester, (ref) async => throw Exception('boom'));
    expect(find.textContaining("Standings couldn't load"), findsOneWidget);
    expect(find.textContaining('boom'), findsNothing);
  });

  testWidgets('own-row XP uses the AA success green (dark: #34D399)', (tester) async {
    await _pump(tester, (ref) async => _rows(meIndex: 3), theme: BrandTheme.darkTheme);
    final xp = tester.widget<Text>(find.text('350 XP')); // Jordan R. (is_me) at index 3
    expect(xp.style?.color, const Color(0xFF34D399));
  });

  testWidgets('own-row XP uses the AA success green (light: #047857)', (tester) async {
    await _pump(tester, (ref) async => _rows(meIndex: 3), theme: BrandTheme.lightTheme);
    final xp = tester.widget<Text>(find.text('350 XP'));
    expect(xp.style?.color, const Color(0xFF047857));
  });
}
