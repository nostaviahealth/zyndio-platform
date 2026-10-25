import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/zyndio_repository.dart';
import '../../providers/demo_providers.dart';
import 'consent_state.dart';

/// Drives [ConsentState] for the interactive demo build and the Step 6
/// end-to-end test: toggling docs/partner sharing, and recording each
/// agreed doc with the repository (version "0.1", clock-timestamped),
/// scoped to the signed-in patient's session.
class ConsentController extends Notifier<ConsentState> {
  @override
  ConsentState build() => ConsentState.unchecked();

  ZyndioRepository get _repo => ref.read(zyndioRepositoryProvider);
  RepoSession get _session => requireDemoSession(ref);

  void toggleDoc(String docId) {
    state = state.copyWith(
      docs: [
        for (final d in state.docs)
          d.doc.id == docId ? d.copyWith(checked: !d.checked, showRequiredError: false) : d,
      ],
    );
  }

  void togglePartnerSharing() {
    state = state.copyWith(partnerSharingOn: !state.partnerSharingOn);
  }

  /// Marks every unchecked required row critical (never disables the
  /// button). When all are checked, records each with the repository and
  /// returns true so the caller can continue.
  bool submit() {
    final hasMissing = state.docs.any((d) => !d.checked);
    if (hasMissing) {
      state = state.copyWith(
        docs: [
          for (final d in state.docs) d.checked ? d : d.copyWith(showRequiredError: true),
        ],
      );
      return false;
    }
    for (final d in state.docs) {
      _repo.agreeToDoc(_session, d.doc.id, version: '0.1');
    }
    return true;
  }
}

final consentControllerProvider = NotifierProvider<ConsentController, ConsentState>(
  ConsentController.new,
);
