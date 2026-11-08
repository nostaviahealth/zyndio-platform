// APP-05: the result screen after a lab report is submitted. A held report
// shows the hold message and none of its values; a read report lists its
// results with "Needs review" where the server flagged one. Fictional data.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zyndio_patient/data/lab_submission.dart';
import 'package:zyndio_patient/screens/health_data/lab_report_submitted_screen.dart';

Future<void> _pump(WidgetTester t, LabSubmission s) => t.pumpWidget(
      ProviderScope(child: MaterialApp(home: LabReportSubmittedScreen(submission: s))),
    );

void main() {
  const marker = {'name': 'hsCRP', 'value': '1.7', 'unit': 'mg/L', 'range': '<3', 'status': 'Needs review', 'needs_review': true};

  testWidgets('read report: results listed, flagged value marked Needs review', (t) async {
    await _pump(t, LabSubmission.fromAnalyzeResponse('r1', 200, {
      'status': 'analyzed',
      'extraction_status': 'needs_review',
      'identity_hold': false,
      'needs_review': 1,
      'markers': [
        {'name': 'HbA1c', 'value': '5.5', 'unit': '%', 'range': '<5.7', 'status': 'Normal', 'needs_review': false},
        marker,
      ],
    }));
    expect(find.text('Results added'), findsOneWidget);
    expect(find.text('HbA1c'), findsOneWidget);
    expect(find.text('5.5 %'), findsOneWidget);
    expect(find.text('1.7 mg/L'), findsOneWidget);
    expect(find.text('Needs review'), findsOneWidget);
  });

  testWidgets('identity hold: the patient is told; no values shown even if sent', (t) async {
    await _pump(t, LabSubmission.fromAnalyzeResponse('r1', 200, {
      'status': 'analyzed',
      'identity_hold': true,
      'markers': [marker],
      'message': 'raw server text',
    }));
    expect(find.text('Report on hold'), findsOneWidget);
    expect(find.textContaining("doesn't match your account"), findsOneWidget);
    expect(find.text('hsCRP'), findsNothing);
    expect(find.text('raw server text'), findsNothing);
  });

  testWidgets('extractor off (501): saved, results come after review', (t) async {
    await _pump(t, LabSubmission.fromAnalyzeResponse('r1', 501, {'error': 'analysis_unavailable'}));
    expect(find.text('Report saved'), findsOneWidget);
    expect(find.textContaining('after they review it'), findsOneWidget);
  });

  test('outcome mapping', () {
    LabSubmissionOutcome o(int s, [Object? b]) => LabSubmission.fromAnalyzeResponse('r', s, b).outcome;
    expect(o(200, {'status': 'analyzed', 'extraction_status': 'extracted', 'needs_review': 0}), LabSubmissionOutcome.analyzed);
    expect(o(200, {'status': 'analyzed', 'extraction_status': 'needs_review', 'needs_review': 0}), LabSubmissionOutcome.needsReview);
    expect(o(200, {'status': 'analyzed', 'identity_hold': true}), LabSubmissionOutcome.identityHold);
    expect(o(200, 'not json'), LabSubmissionOutcome.analysisFailed);
    expect(o(409), LabSubmissionOutcome.duplicate);
    expect(o(429), LabSubmissionOutcome.rateLimited);
    expect(o(501), LabSubmissionOutcome.awaitingReview);
    expect(o(404), LabSubmissionOutcome.analysisFailed);
    expect(LabSubmission.fromAnalyzeResponse('r', 409, null).saved, isFalse);
  });
}
