import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zyndio_patient/config/theme.dart';
import 'package:zyndio_patient/widgets/body_composition_milestone_card.dart';

void main() {
  const baselineHologic = DexaBodyCompositionSnapshot(
    scanDate: '2026-05-01',
    deviceVendor: 'Hologic',
    deviceModel: 'Horizon A',
    softwareVersion: 'APEX 5.6.1',
    totalWeightLb: 228,
    fatMassLb: 82,
    leanMassLb: 137,
    visceralFatLbs: 3.4,
  );

  const followupHologic = DexaBodyCompositionSnapshot(
    scanDate: '2026-10-28',
    deviceVendor: 'Hologic',
    deviceModel: 'Horizon A',
    softwareVersion: 'APEX 5.6.1',
    totalWeightLb: 194,
    fatMassLb: 55,
    leanMassLb: 133,
    visceralFatLbs: 2.1,
  );

  const followupGeLunar = DexaBodyCompositionSnapshot(
    scanDate: '2026-10-28',
    deviceVendor: 'GE Healthcare',
    deviceModel: 'Lunar iDXA',
    softwareVersion: 'enCORE 18',
    totalWeightLb: 194,
    fatMassLb: 55,
    leanMassLb: 133,
    visceralFatLbs: 2.1,
  );

  Widget wrap(Widget child) {
    return MaterialApp(
      theme: BrandTheme.lightTheme,
      home: Scaffold(
        body: SingleChildScrollView(child: child),
      ),
    );
  }

  group('APP-13 & APP-14 BodyCompositionMilestoneCard', () {
    testWidgets(
      'APP-13: displays baseline vs. follow-up DEXA Golden Fixture values when scanner is unchanged',
      (tester) async {
        await tester.pumpWidget(
          wrap(
            const BodyCompositionMilestoneCard(
              baselineScan: baselineHologic,
              followupScan: followupHologic,
              elapsedTreatmentDays: 180,
              leanMassFlag: 'watch',
            ),
          ),
        );

        expect(find.text('DEXA Body Composition'), findsOneWidget);
        expect(find.text('Day 180'), findsOneWidget);

        // Total Weight: 228 lb -> 194 lb (-34 lb, -14.9%)
        expect(find.text('228 lb -> 194 lb'), findsOneWidget);
        expect(find.textContaining('-34 lb (-14.9%)'), findsOneWidget);

        // Fat Mass: 82 lb -> 55 lb (-27 lb, -32.9%)
        expect(find.text('82 lb -> 55 lb'), findsOneWidget);
        expect(find.textContaining('-27 lb (-32.9%)'), findsOneWidget);

        // Lean Mass: 137 lb -> 133 lb (-4 lb, -2.9%) + Lean mass: watch badge
        expect(find.text('137 lb -> 133 lb'), findsOneWidget);
        expect(find.textContaining('-4 lb (-2.9%)'), findsOneWidget);
        expect(find.text('Lean mass: watch'), findsOneWidget);

        // Visceral Fat: 3.4 lbs -> 2.1 lbs
        expect(find.text('3.4 lbs -> 2.1 lbs'), findsOneWidget);

        // No method-change warning when scanner vendor/model/software match
        expect(
          find.textContaining('method_changed_dexa_scanner'),
          findsNothing,
        );
      },
    );

    testWidgets(
      'APP-13: shows insufficient_data notice when DEXA scanner vendor/model/software changes between scans',
      (tester) async {
        await tester.pumpWidget(
          wrap(
            const BodyCompositionMilestoneCard(
              baselineScan: baselineHologic,
              followupScan: followupGeLunar,
              elapsedTreatmentDays: 180,
            ),
          ),
        );

        expect(
          find.textContaining('Insufficient data (method_changed_dexa_scanner)'),
          findsOneWidget,
        );
        expect(
          find.text('insufficient_data (scanner changed)'),
          findsNWidgets(3), // Fat Mass, Lean Mass, Visceral Fat
        );
      },
    );

    testWidgets(
      'APP-14: displays 90/180/365-day next scan and lab milestone reminder and invokes schedule callback',
      (tester) async {
        var scheduleTapped = false;

        await tester.pumpWidget(
          wrap(
            BodyCompositionMilestoneCard(
              baselineScan: baselineHologic,
              followupScan: followupHologic,
              elapsedTreatmentDays: 90,
              nextMilestoneReminder: const MilestoneReminderInfo(
                milestoneDays: 180,
                dueDateLabel: 'Oct 28, 2026',
                daysRemaining: 14,
              ),
              onScheduleMilestoneTap: () {
                scheduleTapped = true;
              },
            ),
          ),
        );

        expect(find.text('Day 180 Milestone Reminder'), findsOneWidget);
        expect(find.text('Due in 14 days (Oct 28, 2026)'), findsOneWidget);
        expect(
          find.textContaining(
            'DEXA body composition scan + fasting metabolic lab panel',
          ),
          findsOneWidget,
        );

        await tester.tap(find.text('Schedule Day 180 Scan & Labs'));
        await tester.pump();
        expect(scheduleTapped, isTrue);
      },
    );
  });
}
