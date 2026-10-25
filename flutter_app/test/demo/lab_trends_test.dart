import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zyndio_patient/config/theme.dart';
import 'package:zyndio_patient/demo/data/fixtures.dart';
import 'package:zyndio_patient/demo/screens/lab_trends/lab_trends_state.dart';
import 'package:zyndio_patient/demo/screens/lab_trends/lab_trends_view.dart';

Widget _wrap(Widget child, {Brightness brightness = Brightness.light}) {
  return MaterialApp(
    theme: brightness == Brightness.light ? BrandTheme.lightTheme : BrandTheme.darkTheme,
    home: child,
  );
}

const _diagnosisDosingWords = [
  'diagnos',
  'dose',
  'dosing',
  'treat',
  'prescri',
  'normal for you',
  'good result',
  'bad result',
];

void main() {
  group('LabTrendsView', () {
    testWidgets(
      'T-BIO-01 default: latest 5.5, "−0.7 points since baseline", caveat card and history always shown',
      (tester) async {
        await tester.pumpWidget(_wrap(LabTrendsView(state: LabTrendsState.defaultState())));

        expect(find.text('HbA1c'), findsOneWidget);
        // 5.5 appears in the hero value, the chart's y-axis label and the
        // latest history row — all three are expected, not a duplication bug.
        expect(find.text('5.5'), findsWidgets);
        expect(find.text('Within default range'), findsOneWidget);
        expect(find.text('Oct 14, 2026 · −0.7 points since baseline (Apr 2)'), findsOneWidget);
        expect(
          find.text(
            'These are general default ranges. Your Zyndio care team will confirm the ranges used for your care.',
          ),
          findsOneWidget,
        );
        expect(find.text('Default range below 5.7%'), findsOneWidget);
        for (final point in hba1cTrend) {
          expect(find.text(point.percent.toString()), findsWidgets);
        }
      },
    );

    testWidgets('loading: shows skeletons and the segmented control, not the real values', (tester) async {
      await tester.pumpWidget(_wrap(LabTrendsView(state: LabTrendsState.loading())));

      expect(find.text('HbA1c'), findsOneWidget);
      expect(find.text('5.5'), findsNothing);
      expect(find.text('6M'), findsOneWidget);
      expect(find.text('Within default range'), findsNothing);
    });

    testWidgets('T-BIO-02 single: shows Baseline badge, "your first result" and an empty chart card', (tester) async {
      await tester.pumpWidget(_wrap(LabTrendsView(state: LabTrendsState.single())));

      expect(find.text('6.2'), findsOneWidget);
      expect(find.text('Baseline'), findsOneWidget);
      expect(find.text('Apr 2, 2026 · your first result'), findsOneWidget);
      expect(find.text('Add another report to see a trend'), findsOneWidget);
      expect(
        find.text('Your care team usually orders follow-up labs. When the next result arrives, it will show here.'),
        findsOneWidget,
      );
      expect(find.widgetWithText(FilledButton, 'Add a lab report'), findsOneWidget);
      // No trend for a single point: no segmented control, no chart, no history.
      expect(find.text('6M'), findsNothing);
    });

    testWidgets('error: shows cached data with the last-updated date and Try again, no caveat/history', (tester) async {
      await tester.pumpWidget(_wrap(LabTrendsView(state: LabTrendsState.error())));

      expect(
        find.text("Couldn't refresh. Showing results saved on this phone, last updated Oct 14, 2026."),
        findsOneWidget,
      );
      expect(find.text('5.5'), findsWidgets);
      expect(find.widgetWithText(OutlinedButton, 'Try again'), findsOneWidget);
      expect(
        find.text(
          'These are general default ranges. Your Zyndio care team will confirm the ranges used for your care.',
        ),
        findsNothing,
      );
    });

    testWidgets('T-BIO-02 above: uses warn (not critical) badge/banner and never recolours the line', (tester) async {
      await tester.pumpWidget(_wrap(LabTrendsView(state: LabTrendsState.above())));

      expect(find.text('Above default range'), findsOneWidget);
      expect(
        find.text(
          'This result is above the default range. Your care team will see it too. If you have questions, message them.',
        ),
        findsOneWidget,
      );
      expect(find.widgetWithText(FilledButton, 'Message care team'), findsOneWidget);

      final context = tester.element(find.byType(LabTrendsView));
      final colors = Theme.of(context).extension<ZyndioColors>()!;
      final badge = tester.widget<Container>(
        find.ancestor(of: find.text('Above default range'), matching: find.byType(Container)).first,
      );
      final decoration = badge.decoration! as BoxDecoration;
      expect(decoration.color, isNot(colors.statusCriticalSubtle));
      expect(decoration.color, colors.statusWarningSubtle);
    });

    testWidgets('no diagnosis/dosing or good/bad wording in any state', (tester) async {
      final states = [
        LabTrendsState.loading(),
        LabTrendsState.defaultState(),
        LabTrendsState.single(),
        LabTrendsState.error(),
        LabTrendsState.above(),
      ];
      for (final state in states) {
        await tester.pumpWidget(_wrap(LabTrendsView(state: state)));
        for (final word in _diagnosisDosingWords) {
          expect(
            find.textContaining(RegExp(word, caseSensitive: false)),
            findsNothing,
            reason: '"$word" must never appear on the lab trends screen.',
          );
        }
      }
    });

    testWidgets('every state builds in dark mode too', (tester) async {
      final states = [
        LabTrendsState.loading(),
        LabTrendsState.defaultState(),
        LabTrendsState.single(),
        LabTrendsState.error(),
        LabTrendsState.above(),
      ];
      for (final state in states) {
        await tester.pumpWidget(_wrap(LabTrendsView(state: state), brightness: Brightness.dark));
        expect(find.byType(LabTrendsView), findsOneWidget);
      }
    });
  });
}
