import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zyndio_patient/config/theme.dart';
import 'package:zyndio_patient/demo/data/fixtures.dart';
import 'package:zyndio_patient/demo/screens/lab_review/lab_review_state.dart';
import 'package:zyndio_patient/demo/screens/lab_review/lab_review_view.dart';

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
];

void main() {
  group('LabReviewView', () {
    testWidgets('default: shows identity match, 6 values, and hsCRP flagged Needs review', (tester) async {
      await tester.pumpWidget(_wrap(LabReviewView(state: LabReviewState.defaultState())));

      expect(find.text('Name and date of birth match your account'), findsOneWidget);
      expect(find.text('Metabolic panel'), findsOneWidget);
      for (final value in labReviewValues) {
        expect(find.text(value.name), findsOneWidget);
      }
      expect(find.text('Needs review'), findsOneWidget);
      expect(find.text('Hard to read on page 2'), findsOneWidget);
      expect(find.text('Your care team sees the original report next to every value.'), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'Save results'), findsOneWidget);
      expect(find.widgetWithText(OutlinedButton, 'Something looks wrong'), findsOneWidget);
    });

    testWidgets('T-LAB loading: makes no time promise and shows skeleton values, not the real ones', (tester) async {
      await tester.pumpWidget(_wrap(LabReviewView(state: LabReviewState.loading())));

      expect(
        find.text("Reading your report. You can leave this screen. We'll let you know when your values are ready."),
        findsOneWidget,
      );
      for (final word in ['minute', 'hour', 'second', 'shortly', 'soon']) {
        expect(
          find.textContaining(RegExp(word, caseSensitive: false)),
          findsNothing,
          reason: 'Loading copy must make no time promise ($word found).',
        );
      }
      expect(find.text('HbA1c'), findsNothing);
      expect(find.text('Save results'), findsNothing);
    });

    testWidgets('T-LAB-02 mismatch: hides every value and shows the hold banner + both actions', (tester) async {
      await tester.pumpWidget(_wrap(LabReviewView(state: LabReviewState.mismatch())));

      expect(
        find.text(
          "The name or date of birth on this report doesn't match your account. "
          "We've put it on hold, and your care team can see the hold.",
        ),
        findsOneWidget,
      );
      expect(
        find.text('Is this your report? Names sometimes differ, for example a maiden name or a nickname.'),
        findsOneWidget,
      );
      expect(find.widgetWithText(FilledButton, 'Yes, this is my report'), findsOneWidget);
      expect(find.widgetWithText(OutlinedButton, 'No, remove this report'), findsOneWidget);
      for (final value in labReviewValues) {
        expect(find.text(value.name), findsNothing);
      }
      expect(find.text('Name and date of birth match your account'), findsNothing);
    });

    testWidgets('empty: shows the no-values card with both recovery actions', (tester) async {
      await tester.pumpWidget(_wrap(LabReviewView(state: LabReviewState.empty())));

      expect(find.text("We couldn't find lab values"), findsOneWidget);
      expect(
        find.text(
          'The report is saved and your care team can still read it. '
          'You can also try a clearer photo or the PDF from your lab.',
        ),
        findsOneWidget,
      );
      expect(find.widgetWithText(FilledButton, 'Try another photo or PDF'), findsOneWidget);
      expect(find.widgetWithText(OutlinedButton, 'Keep report as is'), findsOneWidget);
    });

    testWidgets('error: keeps edits made before the failed save', (tester) async {
      final editedValues = [
        for (final v in labReviewValues)
          v.name == 'HbA1c' ? v.copyWith(value: '5.6') : v,
      ];
      await tester.pumpWidget(_wrap(LabReviewView(state: LabReviewState.error(values: editedValues))));

      expect(
        find.text("Couldn't save. Check your connection and try again. Your edits are kept."),
        findsOneWidget,
      );
      expect(find.text('5.6'), findsOneWidget);
      expect(find.text('5.5'), findsNothing);
      expect(find.text('Name and date of birth match your account'), findsNothing);
      expect(find.widgetWithText(FilledButton, 'Save results'), findsOneWidget);
    });

    testWidgets('saved: shows the saved banner with a single Done button', (tester) async {
      await tester.pumpWidget(_wrap(LabReviewView(state: LabReviewState.saved())));

      expect(find.text('Results saved. Your care team can see them now.'), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'Done'), findsOneWidget);
      expect(find.text('Save results'), findsNothing);
      expect(find.text('Something looks wrong'), findsNothing);
    });

    testWidgets('no diagnosis/dosing wording in any state', (tester) async {
      final states = [
        LabReviewState.loading(),
        LabReviewState.defaultState(),
        LabReviewState.mismatch(),
        LabReviewState.empty(),
        LabReviewState.error(),
        LabReviewState.saved(),
      ];
      for (final state in states) {
        await tester.pumpWidget(_wrap(LabReviewView(state: state)));
        for (final word in _diagnosisDosingWords) {
          expect(
            find.textContaining(RegExp(word, caseSensitive: false)),
            findsNothing,
            reason: '"$word" must never appear on the lab review screen.',
          );
        }
      }
    });

    testWidgets('every state builds in dark mode too', (tester) async {
      final states = [
        LabReviewState.loading(),
        LabReviewState.defaultState(),
        LabReviewState.mismatch(),
        LabReviewState.empty(),
        LabReviewState.error(),
        LabReviewState.saved(),
      ];
      for (final state in states) {
        await tester.pumpWidget(_wrap(LabReviewView(state: state), brightness: Brightness.dark));
        expect(find.byType(LabReviewView), findsOneWidget);
      }
    });
  });
}
