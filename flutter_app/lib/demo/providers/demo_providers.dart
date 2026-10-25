import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/demo_backend.dart';
import '../logic/clock.dart';

final demoClockProvider = Provider<Clock>((ref) => const SystemClock());

final demoBackendProvider = Provider<DemoBackend>((ref) {
  return DemoBackend(clock: ref.watch(demoClockProvider));
});
