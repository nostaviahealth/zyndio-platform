import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../config/theme.dart';
import '../../data/protocol_repository.dart';
import '../../providers/feature_flags_provider.dart';
import '../../providers/my_plan_provider.dart';
import '../../providers/protocol_provider.dart';
import '../../widgets/tc025/tc025_widgets.dart';
import '../protocol/protocol_screen.dart';

/// My Plan tab (client mockup): Therapies / Supplements / Testing / Goals.
///
/// Therapies come from `patient_treatments` (no dose by design); the plan,
/// supplements and goals from the care-team plan; upcoming tests from
/// [upcomingTestsProvider] (no source yet, so real builds say so). Tapping the
/// plan opens the full plan view.
class MyPlanScreen extends ConsumerStatefulWidget {
  const MyPlanScreen({super.key});

  @override
  ConsumerState<MyPlanScreen> createState() => _MyPlanScreenState();
}

class _MyPlanScreenState extends ConsumerState<MyPlanScreen> {
  static const _segments = ['Therapies', 'Supplements', 'Testing', 'Goals'];
  int _segment = 0;

  @override
  Widget build(BuildContext context) {
    final plan = ref.watch(protocolProvider).selectedProtocol;
    final therapies = ref.watch(patientTherapiesProvider);
    final tests = ref.watch(upcomingTestsProvider);
    final canSchedule = ref.watch(featureFlagsProvider).appointmentsEnabled;

    final body = switch (_segment) {
      0 => _therapies(context, therapies, plan, tests, canSchedule),
      1 => _supplements(plan),
      2 => _testing(tests, canSchedule),
      _ => _goals(plan),
    };

    return ZyndioTabScaffold(
      title: 'My Plan',
      subtitle: 'Physician-led therapies and nutrition.',
      onRefresh: () async {
        ref.invalidate(patientTherapiesProvider);
        await ref.read(protocolProvider.notifier).fetchLibrary();
      },
      children: [
        ZyndioSegmentedTabs(
          labels: _segments,
          selected: _segment,
          onSelected: (i) => setState(() => _segment = i),
        ),
        const SizedBox(height: 16),
        ...body,
      ],
    );
  }

  void _openPlan(BuildContext context) => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const ProtocolScreen()),
      );

  List<Widget> _spaced(List<Widget> items) => [
        for (var i = 0; i < items.length; i++) ...[
          if (i > 0) const SizedBox(height: 12),
          items[i],
        ],
      ];

  List<Widget> _therapies(
    BuildContext context,
    AsyncValue<List<PatientTherapy>> therapies,
    ProtocolData? plan,
    List<UpcomingTest> tests,
    bool canSchedule,
  ) {
    if (therapies.isLoading && !therapies.hasValue) {
      return const [
        ZyndioStateCard(
          icon: LucideIcons.syringe,
          title: 'Loading your therapies',
          body: 'Checking what your care team has prescribed.',
        ),
      ];
    }
    if (therapies.hasError && !therapies.hasValue) {
      return [
        ZyndioStateCard(
          icon: LucideIcons.triangleAlert,
          title: "We couldn't load your therapies",
          body: 'Check your connection and try again.',
          actionLabel: 'Try again',
          onAction: () => ref.invalidate(patientTherapiesProvider),
        ),
      ];
    }
    const tints = [ZyndioTint.violet, ZyndioTint.blue, ZyndioTint.teal];
    final list = therapies.value ?? const [];
    final cards = <Widget>[
      for (var i = 0; i < list.length; i++)
        _PlanCard(
          icon: LucideIcons.syringe,
          tint: tints[i % tints.length],
          title: list[i].name,
          lines: [
            if (list[i].startedOn != null)
              'Started ${DateFormat('MMM d, yyyy').format(list[i].startedOn!)}',
          ],
          badge: list[i].status == null
              ? null
              : (list[i].isActive ? 'Active' : _title(list[i].status!)),
          badgeActive: list[i].isActive,
        ),
      if (plan != null)
        _PlanCard(
          icon: LucideIcons.dumbbell,
          tint: ZyndioTint.green,
          title: plan.title,
          lines: [
            for (final t in [...plan.lifestyle, ...plan.fitness].take(3)) t.title,
          ],
          badge: 'Active',
          badgeActive: true,
          onTap: () => _openPlan(context),
        ),
    ];
    if (cards.isEmpty) {
      cards.add(const ZyndioStateCard(
        icon: LucideIcons.clipboardList,
        title: 'No therapies yet',
        body: 'Therapies and your plan appear here once your physician prescribes them.',
      ));
    }
    if (tests.isNotEmpty) cards.add(_UpcomingTestCard(test: tests.first, canSchedule: canSchedule));
    return _spaced(cards);
  }

  List<Widget> _supplements(ProtocolData? plan) {
    final items = plan?.supplements ?? const [];
    if (items.isEmpty) {
      return const [
        ZyndioStateCard(
          icon: LucideIcons.pill,
          title: 'No supplements in your plan',
          body: 'Supplements your care team recommends will appear here.',
        ),
      ];
    }
    return _spaced([
      for (final s in items)
        _PlanCard(
          icon: LucideIcons.pill,
          tint: ZyndioTint.amber,
          title: s.title,
          lines: [if (s.detail.isNotEmpty) s.detail, if (s.time.isNotEmpty) s.time],
        ),
    ]);
  }

  List<Widget> _testing(List<UpcomingTest> tests, bool canSchedule) {
    if (tests.isEmpty) {
      return const [
        ZyndioStateCard(
          icon: LucideIcons.testTube,
          title: 'No tests scheduled',
          body: 'Your next lab panel or scan will appear here once your care team schedules it.',
        ),
      ];
    }
    return _spaced([for (final t in tests) _UpcomingTestCard(test: t, canSchedule: canSchedule)]);
  }

  List<Widget> _goals(ProtocolData? plan) {
    if (plan == null) {
      return const [
        ZyndioStateCard(
          icon: LucideIcons.target,
          title: 'No goals yet',
          body: 'Your care team will publish your plan and goals after your first consultation.',
        ),
      ];
    }
    return _spaced([
      if (plan.targetMetrics.isNotEmpty) _TargetsCard(metrics: plan.targetMetrics),
      for (final t in [...plan.lifestyle, ...plan.fitness])
        _PlanCard(
          icon: t.icon ?? LucideIcons.target,
          tint: ZyndioTint.green,
          title: t.title,
          lines: [if (t.detail.isNotEmpty) t.detail, if (t.frequency != null) t.frequency!],
        ),
    ]);
  }

  static String _title(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({
    required this.icon,
    required this.tint,
    required this.title,
    this.lines = const [],
    this.badge,
    this.badgeActive = false,
    this.onTap,
  });

  final IconData icon;
  final ZyndioTint tint;
  final String title;
  final List<String> lines;
  final String? badge;
  final bool badgeActive;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).extension<ZyndioColors>()!;
    final z = context.z25;
    final card = Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 14, 16),
      decoration: BoxDecoration(
        color: c.bgSurface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: c.borderSubtle),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ZyndioIconTile(icon: icon, tint: tint, size: 52),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: TextStyle(
                          fontFamily: ZyndioType.family,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: c.textPrimary,
                        ),
                      ),
                    ),
                    if (badge != null)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                        decoration: BoxDecoration(
                          color: badgeActive ? z.badgeActiveBg : z.badgeNeutralBg,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          badge!,
                          style: TextStyle(
                            fontFamily: ZyndioType.family,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: badgeActive ? z.badgeActiveText : z.badgeNeutralText,
                          ),
                        ),
                      ),
                  ],
                ),
                for (final l in lines) ...[
                  const SizedBox(height: 3),
                  Text(l,
                      style: TextStyle(
                          fontFamily: ZyndioType.family,
                          fontSize: 14,
                          height: 20 / 14,
                          color: c.textSecondary)),
                ],
              ],
            ),
          ),
          if (onTap != null) ...[
            const SizedBox(width: 6),
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Icon(LucideIcons.chevronRight, size: 20, color: c.textTertiary),
            ),
          ],
        ],
      ),
    );
    if (onTap == null) {
      return Semantics(container: true, label: [title, ...lines, if (badge != null) badge!].join(', '), child: ExcludeSemantics(child: card));
    }
    return Semantics(
      button: true,
      label: [title, ...lines, if (badge != null) badge!].join(', '),
      onTap: onTap,
      child: ExcludeSemantics(child: GestureDetector(onTap: onTap, child: card)),
    );
  }
}

class _UpcomingTestCard extends StatelessWidget {
  const _UpcomingTestCard({required this.test, required this.canSchedule});
  final UpcomingTest test;
  final bool canSchedule;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).extension<ZyndioColors>()!;
    final due = test.due == null ? null : 'Due ${DateFormat('MMM d, yyyy').format(test.due!)}';
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      decoration: BoxDecoration(
        color: context.z25.tileBg,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Row(
        children: [
          const ZyndioIconTile(icon: LucideIcons.testTube, tint: ZyndioTint.violet, size: 52),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Upcoming Testing',
                    style: TextStyle(
                        fontFamily: ZyndioType.family,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: c.textPrimary)),
                const SizedBox(height: 3),
                Text(test.title, style: TextStyle(fontFamily: ZyndioType.family, fontSize: 14, color: c.textSecondary)),
                if (due != null)
                  Text(due, style: TextStyle(fontFamily: ZyndioType.family, fontSize: 14, color: c.textSecondary)),
              ],
            ),
          ),
          if (canSchedule)
            GestureDetector(
              onTap: () => context.pushNamed('appointments'),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  gradient: ZyndioGradients.brand,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: const Text('Schedule',
                    style: TextStyle(
                        fontFamily: ZyndioType.family,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.white)),
              ),
            ),
        ],
      ),
    );
  }
}

class _TargetsCard extends StatelessWidget {
  const _TargetsCard({required this.metrics});
  final List<String> metrics;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).extension<ZyndioColors>()!;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: c.bgSurface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: c.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Target markers',
              style: TextStyle(
                  fontFamily: ZyndioType.family,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: c.textPrimary)),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final m in metrics)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: context.z25.tileBg,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(m,
                      style: TextStyle(
                          fontFamily: ZyndioType.family,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: c.textPrimary)),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
