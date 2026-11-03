import 'dart:async';
import 'dart:ui' show SemanticsAction, Tristate;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:zyndio_patient/config/biomarker_segments.dart';
import 'package:zyndio_patient/config/theme.dart';
import 'package:zyndio_patient/models/lab_report.dart';
import 'package:zyndio_patient/providers/lab_reports_provider.dart';
import 'package:zyndio_patient/screens/biomarkers/biomarkers_screen.dart';
import 'package:zyndio_patient/screens/health_data/health_data_screen.dart';

LabMarker _m(String name, String value,
        {String unit = '', double? low, double? high, String status = 'In-range'}) =>
    LabMarker(
      name: name,
      value: value,
      range: '',
      status: status,
      unit: unit,
      minRange: low,
      maxRange: high,
    );

/// Two reports so the NAD+ hero has a 26 → 41 trend. Fictional only.
List<LabReport> _reports() => [
      LabReport(
        id: 'r2',
        date: '2026-06-01',
        title: 'Longevity panel',
        summary: '',
        markers: [
          _m('Intracellular NAD+', '41', unit: 'µM'),
          _m('HbA1c', '5.2', unit: '%', low: 4.0, high: 5.6),
          _m('Glucose', '92', unit: 'mg/dL', low: 65, high: 99),
          _m('LDL Cholesterol', '140', unit: 'mg/dL', low: 0, high: 129, status: 'High'),
          _m('Testosterone', '600', unit: 'ng/dL', low: 300, high: 1000),
          _m('Ferritin', '120', unit: 'ng/mL'), // unmapped → no segment
        ],
      ),
      LabReport(
        id: 'r1',
        date: '2026-01-01',
        title: 'Baseline panel',
        summary: '',
        markers: [_m('Intracellular NAD+', '26', unit: 'µM')],
      ),
    ];

GoRouter _router(Widget home) => GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(path: '/', builder: (c, s) => Scaffold(body: home)),
        GoRoute(
            path: '/health_data/upload',
            name: 'upload_report',
            builder: (c, s) => const Scaffold(body: Text('UPLOAD SCREEN'))),
        GoRoute(
            path: '/settings',
            name: 'settings',
            builder: (c, s) => const Scaffold(body: Text('SETTINGS'))),
      ],
    );

enum _Mode { data, error, loading }

Future<void> _pump(
  WidgetTester tester, {
  List<LabReport> reports = const [],
  _Mode mode = _Mode.data,
  Brightness b = Brightness.light,
  bool settle = true,
}) async {
  final override = switch (mode) {
    _Mode.data => labReportsProvider.overrideWith((ref) async => reports),
    _Mode.error => labReportsProvider.overrideWith((ref) async {
          throw StateError('boom');
        }),
    _Mode.loading =>
      labReportsProvider.overrideWith((ref) => Completer<List<LabReport>>().future),
  };
  tester.view.physicalSize = const Size(1200, 3600);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [override],
      child: MaterialApp.router(
        theme: b == Brightness.light ? BrandTheme.lightTheme : BrandTheme.darkTheme,
        routerConfig: _router(const BiomarkersScreen()),
      ),
    ),
  );
  if (settle) await tester.pumpAndSettle();
}

void main() {
  group('Biomarkers pure helpers', () {
    test('parseMarkerValue handles free-form values', () {
      expect(parseMarkerValue('7.3'), 7.3);
      expect(parseMarkerValue('<5'), 5);
      expect(parseMarkerValue('1,234'), 1234);
      expect(parseMarkerValue('n/a'), isNull);
      expect(parseMarkerValue(null), isNull);
    });

    test('caption mapping covers every Q11 case', () {
      // within
      expect(biomarkerRangeCaption(value: 90, low: 65, high: 99), 'Within lab range');
      // above / below
      expect(biomarkerRangeCaption(value: 140, low: 0, high: 129), 'Above lab range');
      expect(biomarkerRangeCaption(value: 50, low: 65, high: 99), 'Below lab range');
      // needed bound missing but flagged → outside
      expect(biomarkerRangeCaption(value: null, low: null, high: null, status: 'outlier'),
          'Outside lab range');
      // status-only high/low when no numeric comparison
      expect(biomarkerRangeCaption(value: null, low: null, high: null, status: 'high'),
          'Above lab range');
      expect(biomarkerRangeCaption(value: null, low: null, high: null, status: 'low'),
          'Below lab range');
      // no range at all
      expect(biomarkerRangeCaption(value: 41, low: null, high: null), 'No lab range provided');
    });

    test('segment map: lead-first, unmapped excluded', () {
      expect(segmentForMarker('Intracellular NAD+'), BiomarkerSegment.nad);
      expect(segmentForMarker('HbA1c'), BiomarkerSegment.metabolic);
      expect(segmentForMarker('Testosterone'), BiomarkerSegment.hormones);
      expect(segmentForMarker('hs-CRP'), BiomarkerSegment.inflammation);
      expect(segmentForMarker('Ferritin'), isNull);
      expect(isSegmentLead('Intracellular NAD+', BiomarkerSegment.nad), isTrue);
      expect(isSegmentLead('HbA1c', BiomarkerSegment.metabolic), isTrue);
      expect(isSegmentLead('Glucose', BiomarkerSegment.metabolic), isFalse);
    });

    test('segmentView puts the lead marker first and gathers its trend', () {
      final newest = sortReportsNewestFirst(_reports());
      final nad = segmentView(newest, BiomarkerSegment.nad);
      expect(nad.hero!.name, 'Intracellular NAD+');
      expect(nad.leadTrend.length, 2); // 26 then 41, oldest → newest
      expect(nad.leadTrend.first.marker.value, '26');
      expect(nad.leadTrend.last.marker.value, '41');

      final metabolic = segmentView(newest, BiomarkerSegment.metabolic);
      expect(metabolic.hero!.name, 'HbA1c'); // lead first even though not first in report
      // Ferritin (unmapped) is in no segment.
      for (final seg in BiomarkerSegment.values) {
        expect(segmentView(newest, seg).markers.any((m) => m.name == 'Ferritin'), isFalse);
      }
    });

    test('trendDeltaText: null for single point, neutral text for a trend', () {
      final newest = sortReportsNewestFirst(_reports());
      expect(trendDeltaText(segmentView(newest, BiomarkerSegment.nad).leadTrend),
          contains('26 → 41'));
      expect(trendDeltaText(segmentView(newest, BiomarkerSegment.metabolic).leadTrend), isNull);
    });

    // ── C1 pure helpers ─────────────────────────────────────────────────────
    test('baselineCaptionText: first reading for a trend, null for single', () {
      final newest = sortReportsNewestFirst(_reports());
      expect(baselineCaptionText(segmentView(newest, BiomarkerSegment.nad).leadTrend),
          'Baseline: 26 µM · 2026-01-01');
      // Single point → no baseline caption.
      expect(baselineCaptionText(segmentView(newest, BiomarkerSegment.metabolic).leadTrend),
          isNull);
    });

    test('firstResultCaptionText: single point only', () {
      final newest = sortReportsNewestFirst(_reports());
      expect(firstResultCaptionText(segmentView(newest, BiomarkerSegment.metabolic).leadTrend),
          'First result · 2026-06-01. Your trend appears after your next test.');
      // ≥2 points → no first-result caption.
      expect(firstResultCaptionText(segmentView(newest, BiomarkerSegment.nad).leadTrend), isNull);
    });

    test('hasLabBand: true only when both bounds exist', () {
      expect(hasLabBand(_m('HbA1c', '5.2', low: 4.0, high: 5.6)), isTrue);
      expect(hasLabBand(_m('Intracellular NAD+', '41')), isFalse); // no bounds
      expect(hasLabBand(_m('LDL', '140', high: 129)), isFalse); // one bound only
      expect(hasLabBand(_m('X', '1', low: 1)), isFalse); // one bound only
    });

    test('markerInfoCopy: data-only, non-clinical lines', () {
      final c = markerInfoCopy(_m('Intracellular NAD+', '41', unit: 'µM'), '2026-06-01');
      expect(c.title, 'About Intracellular NAD+');
      expect(c.latestLine, 'Latest: 41 µM on 2026-06-01');
      expect(c.rangeLine, 'No lab range provided');
      expect(c.sourceLine, 'Lab reference ranges come from the laboratory that ran your test.');
      expect(c.careLine, 'Questions about your results go to your care team.');
      // With a range:
      final c2 = markerInfoCopy(_m('HbA1c', '5.2', unit: '%', low: 4.0, high: 5.6), '2026-06-01');
      expect(c2.rangeLine, 'Lab range 4–5.6 %');
    });
  });

  group('Biomarkers C1 hero', () {
    testWidgets('trend chart renders with ≥2 readings', (tester) async {
      await _pump(tester, reports: _reports());
      expect(find.byKey(const Key('biomarker-trend-chart')), findsOneWidget);
    });

    testWidgets('baseline caption shows the first reading', (tester) async {
      await _pump(tester, reports: _reports());
      expect(find.text('Baseline: 26 µM · 2026-01-01'), findsOneWidget);
    });

    testWidgets('single result: first-result caption, one chart, no delta',
        (tester) async {
      final single = [
        LabReport(
          id: 'r1',
          date: '2026-01-01',
          title: 'Baseline',
          summary: '',
          markers: [_m('Intracellular NAD+', '26', unit: 'µM')],
        ),
      ];
      await _pump(tester, reports: single);
      expect(
          find.text(
              'First result · 2026-01-01. Your trend appears after your next test.'),
          findsOneWidget);
      expect(find.byKey(const Key('biomarker-trend-chart')), findsOneWidget);
      expect(find.textContaining('→'), findsNothing);
    });

    testWidgets('(i) info button is ≥44×44 and opens/closes the explainer sheet',
        (tester) async {
      final handle = tester.ensureSemantics();
      await _pump(tester, reports: _reports());
      // A11y button exists with the data-only label.
      expect(find.bySemanticsLabel('About Intracellular NAD+'), findsOneWidget);
      final size = tester.getSize(find.byKey(const Key('marker-info-button')));
      expect(size.width, greaterThanOrEqualTo(44));
      expect(size.height, greaterThanOrEqualTo(44));

      await tester.tap(find.byKey(const Key('marker-info-button')));
      await tester.pumpAndSettle();
      // Non-clinical, data-only copy.
      expect(find.text('Latest: 41 µM on 2026-06-01'), findsOneWidget);
      // "No lab range provided" appears twice: the hero caption and the sheet.
      expect(find.text('No lab range provided'), findsNWidgets(2));
      expect(
          find.text('Lab reference ranges come from the laboratory that ran your test.'),
          findsOneWidget);
      expect(find.text('Questions about your results go to your care team.'),
          findsOneWidget);

      await tester.tap(find.bySemanticsLabel('Close'));
      await tester.pumpAndSettle();
      expect(find.text('Questions about your results go to your care team.'),
          findsNothing);
      handle.dispose();
    });

    // M1 (Ava, PR #30 review): the (i) node must be its own 44×44 node, not a
    // node covering the whole hero card, and the readout is read first.
    testWidgets('M1: (i) semantics node is 44×44 and follows the readout',
        (tester) async {
      final handle = tester.ensureSemantics();
      await _pump(tester, reports: _reports());
      final info =
          find.semantics.byLabel('About Intracellular NAD+').evaluate().single;
      final r = info.rect;
      expect(r.width, closeTo(44, 0.5), reason: 'width ${r.width}');
      expect(r.height, closeTo(44, 0.5), reason: 'height ${r.height}');
      // The readout is a sibling, not a child of the (i) node.
      var childCount = 0;
      info.visitChildren((_) {
        childCount++;
        return true;
      });
      expect(childCount, 0);
      final order = tester.semantics
          .simulatedAccessibilityTraversal()
          .map((n) => n.label)
          .toList();
      final readoutAt = order.indexWhere((l) => l.startsWith('Intracellular NAD+, 41'));
      final infoAt = order.indexOf('About Intracellular NAD+');
      expect(readoutAt, isNonNegative);
      expect(infoAt, greaterThan(readoutAt));
      handle.dispose();
    });

    testWidgets('chart has one text alternative listing every point', (tester) async {
      final handle = tester.ensureSemantics();
      await _pump(tester, reports: _reports());
      expect(
        find.bySemanticsLabel(RegExp(r'26 µM on 2026-01-01.*41 µM on 2026-06-01')),
        findsOneWidget,
      );
      handle.dispose();
    });

    testWidgets('chart renders in dark mode', (tester) async {
      await _pump(tester, b: Brightness.dark, reports: _reports());
      expect(find.byKey(const Key('biomarker-trend-chart')), findsOneWidget);
    });
  });

  group('Biomarkers screen', () {
    testWidgets('default: segments + NAD+ hero with trend + full-report CTA',
        (tester) async {
      await _pump(tester, reports: _reports());
      expect(find.text('Biomarkers'), findsOneWidget);
      expect(find.text('NAD+'), findsOneWidget);
      expect(find.text('Metabolic'), findsOneWidget);
      expect(find.text('Intracellular NAD+'), findsOneWidget); // hero
      expect(find.textContaining('26 → 41'), findsOneWidget); // neutral trend delta
      expect(find.text('View Full Biomarker Report'), findsOneWidget);
      // No composite score / FICTIONAL badge.
      expect(find.textContaining('Score'), findsNothing);
      expect(find.textContaining('FICTIONAL'), findsNothing);
    });

    testWidgets('switch to Metabolic shows HbA1c hero + marker tiles + captions',
        (tester) async {
      await _pump(tester, reports: _reports());
      await tester.tap(find.text('Metabolic'));
      await tester.pumpAndSettle();
      expect(find.text('HbA1c'), findsOneWidget);
      expect(find.text('Glucose'), findsOneWidget);
      expect(find.text('LDL Cholesterol'), findsOneWidget);
      expect(find.text('Above lab range'), findsOneWidget); // LDL 140 > 129
      expect(find.text('Within lab range'), findsWidgets);
    });

    // H1 (Ava, PR #30 review): screen-reader activation == finger tap.
    testWidgets('H1: semantics tap on each segment pill selects that segment',
        (tester) async {
      final handle = tester.ensureSemantics();
      await _pump(tester, reports: _reports());
      const heroFor = {
        'Metabolic': 'HbA1c',
        'Hormones': 'Testosterone',
        'Inflammation': 'Upload a lab report', // empty segment
        'NAD+': 'Intracellular NAD+',
      };
      for (final e in heroFor.entries) {
        final node = find.semantics.byLabel(e.key).evaluate().single;
        expect(node.getSemanticsData().hasAction(SemanticsAction.tap), isTrue,
            reason: '${e.key} exposes SemanticsAction.tap');
        tester.semantics.tap(find.semantics.byLabel(e.key));
        await tester.pumpAndSettle();
        expect(
            find.semantics
                .byLabel(e.key)
                .evaluate()
                .single
                .getSemanticsData()
                .flagsCollection
                .isSelected,
            Tristate.isTrue,
            reason: '${e.key} selected');
        expect(find.text(e.value), findsWidgets, reason: '${e.key} content');
      }
      handle.dispose();
    });

    testWidgets('H1: semantics tap on View Full Biomarker Report opens the report',
        (tester) async {
      final handle = tester.ensureSemantics();
      await _pump(tester, reports: _reports());
      final node =
          find.semantics.byLabel('View Full Biomarker Report').evaluate().single;
      expect(node.getSemanticsData().hasAction(SemanticsAction.tap), isTrue);
      tester.semantics.tap(find.semantics.byLabel('View Full Biomarker Report'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byType(HealthDataScreen), findsOneWidget);
      handle.dispose();
    });

    testWidgets('empty segment shows copy + Upload CTA', (tester) async {
      await _pump(tester, reports: _reports());
      await tester.tap(find.text('Inflammation'));
      await tester.pumpAndSettle();
      expect(find.text('No results in this group yet'), findsOneWidget);
      expect(find.text('Upload a lab report'), findsOneWidget);
    });

    testWidgets('empty: no results card → upload', (tester) async {
      await _pump(tester, reports: const []);
      expect(find.text('No lab results yet'), findsOneWidget);
      await tester.tap(find.text('Upload a lab report'));
      await tester.pumpAndSettle();
      expect(find.text('UPLOAD SCREEN'), findsOneWidget);
    });

    testWidgets('single result: hero with no trend delta', (tester) async {
      final single = [
        LabReport(
          id: 'r1',
          date: '2026-01-01',
          title: 'Baseline',
          summary: '',
          markers: [_m('Intracellular NAD+', '26', unit: 'µM')],
        ),
      ];
      await _pump(tester, reports: single);
      expect(find.text('Intracellular NAD+'), findsOneWidget);
      expect(find.textContaining('→'), findsNothing); // no delta for a single point
    });

    testWidgets('error: card + Try again', (tester) async {
      await _pump(tester, mode: _Mode.error);
      expect(find.text("We couldn't load your results"), findsOneWidget);
      expect(find.text('Try again'), findsOneWidget);
    });

    testWidgets('loading: skeleton with one Loading semantics', (tester) async {
      final handle = tester.ensureSemantics();
      await _pump(tester, mode: _Mode.loading, settle: false);
      await tester.pump();
      expect(find.bySemanticsLabel('Loading'), findsOneWidget);
      handle.dispose();
    });

    testWidgets('renders in dark mode', (tester) async {
      await _pump(tester, b: Brightness.dark, reports: _reports());
      expect(find.text('Intracellular NAD+'), findsOneWidget);
    });
  });
}
