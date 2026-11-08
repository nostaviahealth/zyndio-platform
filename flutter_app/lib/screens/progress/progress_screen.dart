import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../data/body_composition.dart';
import '../../data/dexa_measures.dart';
import '../../config/theme.dart';
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
    final c = Theme.of(context).extension<ZyndioColors>()!;
    final device = scan.deviceLine;
    final groups = groupDexaMeasures(scan.measures);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: c.bgSurface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: c.borderSubtle),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(LucideIcons.activity, size: 20, color: c.brandPrimary),
                const SizedBox(width: 8),
                Expanded(
                  child: Semantics(
                    header: true,
                    child: Text(
                      scan.scanDate.isEmpty ? 'DEXA scan' : 'DEXA scan · ${scan.scanDate}',
                      style: TextStyle(
                        fontFamily: ZyndioType.family,
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: c.textPrimary,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            if (device.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(device, style: TextStyle(fontSize: 13, color: c.textTertiary)),
            ],
            if (groups.isEmpty) ...[
              const SizedBox(height: 12),
              Text('No measures were stored with this scan.',
                  style: TextStyle(fontSize: 15, color: c.textSecondary)),
            ],
            for (final g in groups) ...[
              const SizedBox(height: 16),
              Semantics(
                header: true,
                child: Text(
                  g.section.title.toUpperCase(),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                    color: c.textSecondary,
                  ),
                ),
              ),
              const SizedBox(height: 6),
              for (final r in g.rows)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 5),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(r.label,
                            style: TextStyle(fontSize: 15, color: c.textSecondary)),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        r.value,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: c.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
            const SizedBox(height: 12),
            Text(
              'Values are as reported by the scan provider. Review them with your care team.',
              style: TextStyle(fontSize: 12, color: c.textTertiary),
            ),
          ],
        ),
      ),
    );
  }
}
