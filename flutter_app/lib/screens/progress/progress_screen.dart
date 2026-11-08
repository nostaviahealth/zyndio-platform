import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../data/body_composition.dart';
import '../../providers/body_composition_provider.dart';
import '../../widgets/tc025/tc025_widgets.dart';
import '../../providers/feature_flags_provider.dart';

/// Progress tab. Shows stored body-composition scans when the patient can
/// read them. Does not compute a clinical score or a milestone recommendation.
class ProgressScreen extends ConsumerWidget {
  const ProgressScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scans = ref.watch(bodyCompositionScansProvider);
    final appointmentsEnabled =
        ref.watch(featureFlagsProvider).appointmentsEnabled;
    return ZyndioTabScaffold(
      title: 'Body Composition',
      subtitle: 'DEXASCAN · Measurable results. Real progress.',
      onRefresh: () => ref.refresh(bodyCompositionScansProvider.future),
      children: scans.when(
        loading: () => const [
          ZyndioStateCard(
            icon: LucideIcons.activity,
            title: 'Loading body composition',
            body: 'Checking for scans your care team has released.',
          ),
        ],
        error: (_, __) => [
          ZyndioStateCard(
            icon: LucideIcons.triangleAlert,
            title: "We couldn't load body composition",
            body: 'Check your connection and try again.',
            actionLabel: 'Try again',
            onAction: () => ref.invalidate(bodyCompositionScansProvider),
          ),
        ],
        data: (rows) => rows.isEmpty
            ? [
                ZyndioStateCard(
                  icon: LucideIcons.activity,
                  title: 'No DEXASCAN results yet',
                  body:
                      'Your body composition will appear here after a scan has been bound to your record.',
                  // Booking is mock data until Appointments ships (feature flag).
                  actionLabel:
                      appointmentsEnabled ? 'Book my baseline scan' : null,
                  onAction: appointmentsEnabled
                      ? () => context.pushNamed('appointments')
                      : null,
                ),
              ]
            : [for (final scan in rows) _ScanCard(scan: scan)],
      ),
    );
  }
}

class _ScanCard extends StatelessWidget {
  const _ScanCard({required this.scan});

  final StoredBodyScan scan;

  @override
  Widget build(BuildContext context) {
    final device = scan.deviceLine;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: ZyndioStateCard(
        icon: LucideIcons.activity,
        title: scan.scanDate.isEmpty ? 'Scan on file' : scan.scanDate,
        body: [
          if (device.isNotEmpty) device,
          if (scan.measures.isEmpty)
            'No measures were stored with this scan.'
          else
            scan.measures.map((m) => '${m.name}: ${m.value}').join('\n'),
        ].join('\n'),
      ),
    );
  }
}
