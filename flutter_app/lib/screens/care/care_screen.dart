import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../config/theme.dart';
import '../../providers/feature_flags_provider.dart';
import '../../providers/patient_provider.dart';
import '../../widgets/tc025/tc025_widgets.dart';
import '../health_data/my_lab_records_screen.dart';

/// Care tab (client mockup "My Care"): the patient's profile card, then
/// image-led rows to their results, scans, medications, visits and resources.
/// Every row goes somewhere that exists; Appointments is behind its flag
/// (mock data) and Resources is marked "Coming soon" until content exists.
class CareScreen extends ConsumerWidget {
  const CareScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appointmentsEnabled = ref.watch(featureFlagsProvider).appointmentsEnabled;
    return ZyndioTabScaffold(
      title: 'My Care',
      subtitle: 'Your clinical team, results and resources.',
      children: [
        const _ProfileCard(),
        const SizedBox(height: 12),
        ZyndioListRow(
          icon: LucideIcons.flaskConical,
          tint: ZyndioTint.violet,
          title: 'Lab Results',
          subtitle: 'DEXASCAN, NAD+ and quarterly lab results.',
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const MyLabRecordsScreen()),
          ),
        ),
        const SizedBox(height: 12),
        ZyndioListRow(
          icon: LucideIcons.scanLine,
          tint: ZyndioTint.teal,
          title: 'DEXASCAN Reports',
          subtitle: 'View scans and body composition trends.',
          onTap: () => context.go('/progress'),
        ),
        const SizedBox(height: 12),
        ZyndioListRow(
          icon: LucideIcons.pill,
          tint: ZyndioTint.rose,
          title: 'Medications & Protocols',
          subtitle: 'Therapies, supplements and your plan.',
          onTap: () => context.go('/my-plan'),
        ),
        if (appointmentsEnabled) ...[
          const SizedBox(height: 12),
          ZyndioListRow(
            icon: LucideIcons.calendarDays,
            tint: ZyndioTint.blue,
            title: 'Appointments',
            subtitle: 'Schedule and manage your visits.',
            onTap: () => context.pushNamed('appointments'),
          ),
        ],
        const SizedBox(height: 12),
        ZyndioListRow(
          icon: LucideIcons.bookOpen,
          tint: ZyndioTint.amber,
          title: 'Resources',
          subtitle: 'Guides and educational content.',
          trailingBadge: 'Coming soon',
          onTap: () => ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Resources are coming soon.')),
          ),
        ),
      ],
    );
  }
}

class _ProfileCard extends ConsumerWidget {
  const _ProfileCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = Theme.of(context).extension<ZyndioColors>()!;
    final p = ref.watch(patientProfileProvider).value;
    final name = (p?.name ?? '').trim();
    final initials = zyndioInitials(name);
    final details = [
      if (p?.age != null) 'Age ${p!.age}',
      if (p?.createdAt != null) 'Member since ${DateFormat('MMM yyyy').format(p!.createdAt!)}',
    ];
    return Semantics(
      button: true,
      label: ['Profile', if (name.isNotEmpty) name, ...details].join(', '),
      onTap: () => context.pushNamed('settings'),
      child: ExcludeSemantics(
        child: GestureDetector(
          onTap: () => context.pushNamed('settings'),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: c.bgSurface,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: c.borderSubtle),
            ),
            child: Row(
              children: [
                Container(
                  width: 68,
                  height: 68,
                  padding: const EdgeInsets.all(3),
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: ZyndioGradients.brand,
                  ),
                  child: Container(
                    alignment: Alignment.center,
                    decoration: BoxDecoration(shape: BoxShape.circle, color: c.bgSurface),
                    child: initials.isEmpty
                        ? Icon(LucideIcons.user, size: 28, color: c.textPrimary)
                        : Text(
                            initials,
                            style: TextStyle(
                              fontFamily: ZyndioType.family,
                              fontSize: 22,
                              fontWeight: FontWeight.w700,
                              color: c.textPrimary,
                            ),
                          ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name.isEmpty ? 'Your profile' : name,
                        style: TextStyle(
                          fontFamily: ZyndioType.family,
                          fontSize: 19,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.3,
                          color: c.textPrimary,
                        ),
                      ),
                      for (final d in details) ...[
                        const SizedBox(height: 3),
                        Text(d,
                            style: TextStyle(
                                fontFamily: ZyndioType.family,
                                fontSize: 14,
                                color: c.textSecondary)),
                      ],
                    ],
                  ),
                ),
                Icon(LucideIcons.chevronRight, size: 20, color: c.textTertiary),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
