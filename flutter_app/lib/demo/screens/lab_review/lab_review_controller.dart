import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'lab_review_state.dart';

/// Drives [LabReviewState] for the interactive demo build. The fixture
/// "Metabolic panel" report always matches the signed-in patient's identity
/// and always saves successfully — `mismatch`/`error`/`empty` are
/// screenshot-only fixtures (see [labReviewStateForQueryState]), same as the
/// other demo screens' non-happy-path states.
class LabReviewController extends Notifier<LabReviewState> {
  @override
  LabReviewState build() => LabReviewState.defaultState();

  /// Edits are applied in place and survive any later save error — the view
  /// never resets a value it has already shown to the patient.
  void editValue(int index, String newValue) {
    final values = [...state.values];
    values[index] = values[index].copyWith(value: newValue);
    state = state.copyWith(values: values);
  }

  void save() {
    state = state.copyWith(banner: LabReviewBannerKind.saved);
  }
}

final labReviewControllerProvider = NotifierProvider<LabReviewController, LabReviewState>(
  LabReviewController.new,
);
