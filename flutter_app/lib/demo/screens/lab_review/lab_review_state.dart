import 'package:flutter/foundation.dart';

import '../../data/fixtures.dart';

enum LabReviewBannerKind { none, error, saved }

const _docTitle = 'Metabolic panel';
const _docSubtitle = 'Fictional Reference Lab · 2 pages';
const _docCollected = 'Collected Oct 14, 2026';

/// Maps the screenshot harness's `?state=` query param to a fixture
/// [LabReviewState]. Unknown/missing values fall back to `default`.
LabReviewState labReviewStateForQueryState(String? queryState) => switch (queryState) {
      'loading' => LabReviewState.loading(),
      'mismatch' => LabReviewState.mismatch(),
      'empty' => LabReviewState.empty(),
      'error' => LabReviewState.error(),
      'saved' => LabReviewState.saved(),
      _ => LabReviewState.defaultState(),
    };

/// Immutable view-state for [LabReviewView]. Each factory matches one of the
/// 6 screenshot states (loading, default, mismatch, empty, error, saved).
@immutable
class LabReviewState {
  const LabReviewState({
    this.isLoading = false,
    this.isMismatch = false,
    this.isEmpty = false,
    this.banner = LabReviewBannerKind.none,
    this.values = const [],
    this.docTitle = _docTitle,
    this.docSubtitle = _docSubtitle,
    this.docCollected = _docCollected,
  });

  // Loading never promises a time: the info banner only says the screen can
  // be left and values will be ready later (T-LAB-02 adjacent, screens.md §04).
  factory LabReviewState.loading() => const LabReviewState(isLoading: true);

  factory LabReviewState.defaultState() => const LabReviewState(values: labReviewValues);

  // T-LAB-02: name/DOB mismatch hides every value and puts the report on
  // hold instead of extracting anything.
  factory LabReviewState.mismatch() => const LabReviewState(isMismatch: true);

  factory LabReviewState.empty() => const LabReviewState(isEmpty: true);

  factory LabReviewState.error({List<LabReviewValue>? values}) => LabReviewState(
        banner: LabReviewBannerKind.error,
        values: values ?? labReviewValues,
      );

  factory LabReviewState.saved() => const LabReviewState(
        banner: LabReviewBannerKind.saved,
        values: labReviewValues,
      );

  final bool isLoading;
  final bool isMismatch;
  final bool isEmpty;
  final LabReviewBannerKind banner;
  final List<LabReviewValue> values;
  final String docTitle;
  final String docSubtitle;
  final String docCollected;

  LabReviewState copyWith({
    bool? isLoading,
    bool? isMismatch,
    bool? isEmpty,
    LabReviewBannerKind? banner,
    List<LabReviewValue>? values,
  }) {
    return LabReviewState(
      isLoading: isLoading ?? this.isLoading,
      isMismatch: isMismatch ?? this.isMismatch,
      isEmpty: isEmpty ?? this.isEmpty,
      banner: banner ?? this.banner,
      values: values ?? this.values,
      docTitle: docTitle,
      docSubtitle: docSubtitle,
      docCollected: docCollected,
    );
  }
}
