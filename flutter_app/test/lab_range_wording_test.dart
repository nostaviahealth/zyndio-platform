import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zyndio_patient/config/biomarker_segments.dart';
import 'package:zyndio_patient/config/lab_range_wording.dart';
import 'package:zyndio_patient/config/theme.dart';

void main() {
  group('APP-06 bounded, non-diagnostic lab range wording', () {
    test('pinned patient-facing strings use care-team bounded wording', () {
      expect(
        kOutsideClinicRange,
        "Outside your clinic's range: discuss with your care team",
      );
      expect(kOutsideClinicRangeShort, 'Outside range');
      expect(kWithinClinicRange, "Within your clinic's range");
      expect(kNoRangeProvided, 'No lab range provided');
      expect(
        kDefaultRangesCaveat,
        'These are general default ranges, not yet confirmed by your clinic. '
        'Your care team will confirm the ranges used for your care.',
      );
    });

    test('never contains diagnostic or patient-grading phrases', () {
      final allStrings = [
        kOutsideClinicRange,
        kOutsideClinicRangeShort,
        kWithinClinicRange,
        kNoRangeProvided,
        kDefaultRangesCaveat,
        biomarkerRangeCaption(value: 140, low: 0, high: 129),
        biomarkerRangeCaption(value: 50, low: 65, high: 99),
        biomarkerRangeCaption(value: 85, low: 65, high: 99),
        biomarkerRangeCaption(value: 41, low: null, high: null),
      ].join(' ').toLowerCase();

      const forbiddenPhrases = [
        'you have',
        'prediabetes',
        'diabetes',
        'hypothyroid',
        'hyperthyroid',
        'needs focus',
        'optimal profile',
        'above lab range',
        'below lab range',
        'abnormal',
        'diagnosed',
      ];

      for (final forbidden in forbiddenPhrases) {
        expect(
          allStrings.contains(forbidden),
          isFalse,
          reason: 'Patient-facing lab copy must not contain "$forbidden"',
        );
      }
    });

    testWidgets(
      'DefaultRangesCaveat renders when clinicLabRangesApprovedProvider is false',
      (tester) async {
        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              theme: BrandTheme.lightTheme,
              home: const Scaffold(
                body: DefaultRangesCaveat(),
              ),
            ),
          ),
        );

        expect(find.byKey(const Key('default-ranges-caveat')), findsOneWidget);
        expect(find.text(kDefaultRangesCaveat), findsOneWidget);
      },
    );

    testWidgets(
      'DefaultRangesCaveat hides once clinicLabRangesApprovedProvider is true',
      (tester) async {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              clinicLabRangesApprovedProvider.overrideWithValue(true),
            ],
            child: MaterialApp(
              theme: BrandTheme.lightTheme,
              home: const Scaffold(
                body: DefaultRangesCaveat(),
              ),
            ),
          ),
        );

        expect(find.byKey(const Key('default-ranges-caveat')), findsNothing);
        expect(find.text(kDefaultRangesCaveat), findsNothing);
      },
    );
  });
}
