import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/zyndio_repository.dart';
import '../../providers/demo_providers.dart';
import 'lab_trends_state.dart';

/// Drives [LabTrendsState] for the interactive demo build, reading the
/// signed-in patient's own trend through [ZyndioRepository] — never a
/// different patient's data (same isolation guarantee the repository tests
/// cover for `hba1cTrendFor`). Starts in [LabTrendsState.loading] and loads
/// once [refresh] is called (after this provider finishes building —
/// Riverpod disallows reading/writing [currentSessionProvider] from inside
/// this provider's own `build`), same as the other screens resolve their
/// session lazily from an action method, not from `build`.
class LabTrendsController extends Notifier<LabTrendsState> {
  @override
  LabTrendsState build() => LabTrendsState.loading();

  ZyndioRepository get _repo => ref.read(zyndioRepositoryProvider);
  RepoSession get _session => requireDemoSession(ref);

  void refresh() {
    final points = _repo.hba1cTrendFor(_session);
    if (points.isEmpty) {
      state = LabTrendsState.loading();
    } else if (points.length == 1) {
      state = LabTrendsState.single(points: points);
    } else {
      state = LabTrendsState.defaultState(points: points);
    }
  }
}

final labTrendsControllerProvider = NotifierProvider<LabTrendsController, LabTrendsState>(
  LabTrendsController.new,
);
