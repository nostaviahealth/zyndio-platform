import 'package:flutter/foundation.dart';

import '../../widgets/badge.dart';

enum UploadRowIcon { reading, onHold, saved, uploading, queued, failed }

@immutable
class UploadRowState {
  const UploadRowState({
    required this.title,
    required this.subline,
    required this.icon,
    this.badgeLabel,
    this.badgeVariant,
    this.progress,
    this.showRetry = false,
  });

  final String title;
  final String subline;
  final UploadRowIcon icon;
  final String? badgeLabel;
  final BadgeVariant? badgeVariant;

  /// Fraction complete (0.0-1.0), shown only for [UploadRowIcon.uploading].
  final double? progress;
  final bool showRetry;
}

enum LabUploadBannerKind { none, duplicate, offline, error }

const _readingRow = UploadRowState(
  title: 'Report from Oct 14, 2026',
  subline: "Reading values. We'll let you know when they're ready.",
  icon: UploadRowIcon.reading,
);

const _onHoldRow = UploadRowState(
  title: 'Report from Sep 2, 2026',
  subline: "Name doesn't match your account",
  icon: UploadRowIcon.onHold,
  badgeLabel: 'On hold',
  badgeVariant: BadgeVariant.warn,
);

const _savedRow = UploadRowState(
  title: 'Report from Aug 6, 2026',
  subline: '14 values saved',
  icon: UploadRowIcon.saved,
  badgeLabel: 'Saved',
  badgeVariant: BadgeVariant.ok,
);

const _uploadingRow = UploadRowState(
  title: 'New report',
  subline: 'Uploading page 2 of 3',
  icon: UploadRowIcon.uploading,
  progress: 0.6,
);

const _queuedRow = UploadRowState(
  title: 'New report',
  subline: 'Waiting for connection',
  icon: UploadRowIcon.queued,
  badgeLabel: 'Queued',
  badgeVariant: BadgeVariant.warn,
);

const _failedRow = UploadRowState(
  title: 'New report',
  subline: 'Upload failed',
  icon: UploadRowIcon.failed,
  showRetry: true,
);

/// Maps the screenshot harness's `?state=` query param to a fixture
/// [LabUploadState]. Unknown/missing values fall back to `default`.
LabUploadState labUploadStateForQueryState(String? queryState) => switch (queryState) {
      'empty' => LabUploadState.empty(),
      'uploading' => LabUploadState.uploading(),
      'duplicate' => LabUploadState.duplicate(),
      'offline' => LabUploadState.offline(),
      'error' => LabUploadState.error(),
      _ => LabUploadState.defaultState(),
    };

/// Immutable view-state for [LabUploadView]. Each factory matches one of the
/// 6 screenshot states (empty, default, uploading, duplicate, offline, error).
@immutable
class LabUploadState {
  const LabUploadState({
    this.isEmpty = false,
    this.rows = const [],
    this.banner = LabUploadBannerKind.none,
    this.duplicateDateLabel,
  });

  factory LabUploadState.defaultState() =>
      const LabUploadState(rows: [_readingRow, _onHoldRow, _savedRow]);

  factory LabUploadState.empty() => const LabUploadState(isEmpty: true);

  factory LabUploadState.uploading() => const LabUploadState(rows: [_uploadingRow, _savedRow]);

  // Matched by file, never blocks: the duplicate banner offers "Upload
  // anyway"/"Cancel" alongside the row history, it never replaces it.
  factory LabUploadState.duplicate() => const LabUploadState(
        banner: LabUploadBannerKind.duplicate,
        duplicateDateLabel: 'Aug 6, 2026',
        rows: [_savedRow],
      );

  factory LabUploadState.offline() => const LabUploadState(
        banner: LabUploadBannerKind.offline,
        rows: [_queuedRow, _savedRow],
      );

  factory LabUploadState.error() => const LabUploadState(
        banner: LabUploadBannerKind.error,
        rows: [_failedRow, _savedRow],
      );

  final bool isEmpty;
  final List<UploadRowState> rows;
  final LabUploadBannerKind banner;
  final String? duplicateDateLabel;

  LabUploadState copyWith({
    bool? isEmpty,
    List<UploadRowState>? rows,
    LabUploadBannerKind? banner,
    String? duplicateDateLabel,
  }) {
    return LabUploadState(
      isEmpty: isEmpty ?? this.isEmpty,
      rows: rows ?? this.rows,
      banner: banner ?? this.banner,
      duplicateDateLabel: duplicateDateLabel ?? this.duplicateDateLabel,
    );
  }
}
