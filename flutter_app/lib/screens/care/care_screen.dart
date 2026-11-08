import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../widgets/tc025/tc025_widgets.dart';
import '../health_data/my_lab_records_screen.dart';
import '../../providers/feature_flags_provider.dart';

/// Care tab — interim for PR A. Tab label "Care", page title "My Care".
///
/// The profile card, care-team card, Resources and the Secure Clinical Portal
/// row need new tables / providers and land in PR B. For PR A we show only Z11
/// rows to destinations that already exist today (Lab Results, Appointments).
class CareScreen extends ConsumerWidget {
  const CareScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appointmentsEnabled =
        ref.watch(featureFlagsProvider).appointmentsEnabled;
    return ZyndioTabScaffold(
      title: 'My Care',
      subtitle: 'Your clinical team, results and resources.',
      children: [
        ZyndioListRow(
          icon: LucideIcons.flaskConical,
          title: 'Lab Results',
          subtitle: 'Your biomarker reports and uploads.',
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const MyLabRecordsScreen()),
          ),
        ),
        // Appointments is mock data until it ships (feature flag).
        if (appointmentsEnabled) ...[
          const SizedBox(height: 12),
          ZyndioListRow(
            icon: LucideIcons.calendarHeart,
            title: 'Appointments',
            subtitle: 'Book or review visits with your care team.',
            onTap: () => context.pushNamed('appointments'),
          ),
        ],
      ],
    );
  }
}
