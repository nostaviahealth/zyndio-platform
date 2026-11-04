/// APP-05: what happened to a lab report the patient submitted.
///
/// The report is always filed first (private file + lab_reports row with its
/// SHA-256); the server then reads it (analyze-lab-report). Every outcome
/// other than [LabSubmissionOutcome.duplicate] means the report is saved.
/// Patient-facing text is fixed here - never a backend message.
enum LabSubmissionOutcome {
  /// Results extracted and filed; none need review.
  analyzed,

  /// Results filed; some values will be checked by the care team.
  needsReview,

  /// The name or date of birth on the report doesn't match the account.
  identityHold,

  /// Saved; automatic reading is switched off, the care team will add results.
  awaitingReview,

  /// This exact file was already uploaded (same SHA-256). Nothing new saved.
  duplicate,

  /// Saved; the reading budget is used up for now.
  rateLimited,

  /// Saved, but reading it failed.
  analysisFailed,
}

/// One result as the server filed it (lab_reports.data.markers shape).
class LabSubmissionMarker {
  const LabSubmissionMarker({
    required this.name,
    required this.value,
    required this.unit,
    required this.range,
    required this.status,
    required this.needsReview,
  });

  final String name;
  final String value;
  final String unit;
  final String range;
  final String status;
  final bool needsReview;

  static LabSubmissionMarker? fromJson(Object? json) {
    if (json is! Map) return null;
    final name = json['name'];
    if (name is! String || name.isEmpty) return null;
    String s(Object? v) => v == null ? '' : v.toString();
    return LabSubmissionMarker(
      name: name,
      value: s(json['value']),
      unit: s(json['unit']),
      range: s(json['range']),
      status: s(json['status']),
      needsReview: json['needs_review'] == true,
    );
  }
}

class LabSubmission {
  const LabSubmission({
    required this.outcome,
    this.reportId,
    this.markers = const [],
    this.needsReviewCount = 0,
  });

  final LabSubmissionOutcome outcome;
  final String? reportId;
  final List<LabSubmissionMarker> markers;
  final int needsReviewCount;

  bool get saved => outcome != LabSubmissionOutcome.duplicate;

  /// Maps analyze-lab-report's answer. [status] is the HTTP status, [body]
  /// the decoded JSON (or null). Only fixed fields are read; any message the
  /// server sends is ignored in favour of [message].
  factory LabSubmission.fromAnalyzeResponse(
      String reportId, int status, Object? body) {
    final map = body is Map ? body : const {};
    if (status == 200 && map['status'] == 'analyzed') {
      if (map['identity_hold'] == true) {
        return LabSubmission(
            outcome: LabSubmissionOutcome.identityHold, reportId: reportId);
      }
      final markers = (map['markers'] is List ? map['markers'] as List : const [])
          .map(LabSubmissionMarker.fromJson)
          .whereType<LabSubmissionMarker>()
          .toList();
      final needsReview = map['needs_review'] is int ? map['needs_review'] as int : 0;
      final reportNeedsReview = map['extraction_status'] == 'needs_review';
      return LabSubmission(
        outcome: needsReview > 0 || reportNeedsReview
            ? LabSubmissionOutcome.needsReview
            : LabSubmissionOutcome.analyzed,
        reportId: reportId,
        markers: markers,
        needsReviewCount: needsReview,
      );
    }
    final outcome = switch (status) {
      501 => LabSubmissionOutcome.awaitingReview,
      409 => LabSubmissionOutcome.duplicate,
      429 => LabSubmissionOutcome.rateLimited,
      _ => LabSubmissionOutcome.analysisFailed,
    };
    return LabSubmission(outcome: outcome, reportId: reportId);
  }

  String get title => switch (outcome) {
        LabSubmissionOutcome.analyzed => 'Results added',
        LabSubmissionOutcome.needsReview => 'Results added',
        LabSubmissionOutcome.identityHold => 'Report on hold',
        LabSubmissionOutcome.awaitingReview => 'Report saved',
        LabSubmissionOutcome.duplicate => 'Already uploaded',
        LabSubmissionOutcome.rateLimited => 'Report saved',
        LabSubmissionOutcome.analysisFailed => 'Report saved',
      };

  String get message => switch (outcome) {
        LabSubmissionOutcome.analyzed =>
          'We read your report and added the results to your record.',
        LabSubmissionOutcome.needsReview =>
          'We read your report. Values marked "Needs review" will be checked by your care team.',
        LabSubmissionOutcome.identityHold =>
          "The name or date of birth on this report doesn't match your account, so it's on hold. "
              'Your care team will check it before any results are added to your record.',
        LabSubmissionOutcome.awaitingReview =>
          'Your report is saved. Your care team will add the results after they review it.',
        LabSubmissionOutcome.duplicate =>
          "You've already uploaded this report, so it wasn't added again.",
        LabSubmissionOutcome.rateLimited =>
          "Your report is saved. We couldn't read it right now; your care team will add the results.",
        LabSubmissionOutcome.analysisFailed =>
          "Your report is saved. We couldn't read it automatically; your care team will add the results.",
      };
}
