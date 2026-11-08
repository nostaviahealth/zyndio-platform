import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../config/theme.dart';
import '../data/programme_journey.dart';
import '../providers/feature_flags_provider.dart';
import '../providers/programme_journey_provider.dart';
import 'tc025/tc025_widgets.dart';

String _date(DateTime d) => DateFormat('d MMM y').format(d);

/// "in 12 days", "tomorrow", "today", "3 days ago".
String relativeDays(int days) {
  if (days == 0) return 'today';
  if (days == 1) return 'tomorrow';
  if (days == -1) return 'yesterday';
  if (days > 1) return 'in $days days';
  return '${-days} days ago';
}

/// One line on where the next milestone stands, e.g.
/// "Due 5 Jan 2027 · in 57 days" or "Booking window open until 4 Feb 2027".
String milestoneDueLine(ProgrammeJourney j, ProgrammeMilestone m) {
  final days = j.daysUntil(m);
  if (m.status == MilestoneStatus.dueNow && days < 0) {
    final closes =
        m.target.add(const Duration(days: kMilestoneWindowDays));
    return 'Booking window open until ${_date(closes)}';
  }
  return 'Due ${_date(m.target)} · ${relativeDays(days)}';
}

/// Today's programme card: a "Getting started" checklist until the baseline
/// scan arrives, then the Day 90 / 180 / 365 track with the next milestone
/// and, when it is close, a prompt to book the scan and labs (APP-14).
///
/// Renders nothing while its sources load or if any failed.
class ProgrammeJourneyCard extends ConsumerWidget {
  const ProgrammeJourneyCard({super.key, this.trailingGap = 20});

  /// Space below the card when it renders (none when it doesn't).
  final double trailingGap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final journey = ref.watch(programmeJourneyProvider);
    if (journey == null) return const SizedBox.shrink();
    final canBook = ref.watch(featureFlagsProvider).appointmentsEnabled;
    return Padding(
      padding: EdgeInsets.only(bottom: trailingGap),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const ZyndioSectionLabel('Your programme'),
          journey.hasBaseline
              ? _MilestoneCard(journey: journey, canBook: canBook)
              : _SetupCard(journey: journey, canBook: canBook),
        ],
      ),
    );
  }
}

// ── Before the baseline scan: setup checklist ───────────────────────────────

class _SetupCard extends StatelessWidget {
  const _SetupCard({required this.journey, required this.canBook});
  final ProgrammeJourney journey;
  final bool canBook;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).extension<ZyndioColors>()!;
    final next = journey.nextSetupStep;
    final total = journey.setup.length;
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
      decoration: zyndioCard(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            container: true,
            header: true,
            child: Text(
              'Getting started',
              style: _titleStyle(c),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${journey.setupDone} of $total steps done',
            style: _captionStyle(c),
          ),
          const SizedBox(height: 14),
          _ProgressBar(fraction: journey.setupDone / total),
          const SizedBox(height: 8),
          for (final item in journey.setup)
            _SetupRow(
              item: item,
              isNext: identical(item, next),
              action: identical(item, next) ? _actionFor(context, item) : null,
            ),
        ],
      ),
    );
  }

  ({String label, VoidCallback onTap})? _actionFor(
      BuildContext context, ProgrammeSetupItem item) {
    switch (item.step) {
      case ProgrammeSetupStep.baselineLabs:
        return (
          label: 'Upload labs',
          onTap: () => context.pushNamed('upload_report'),
        );
      case ProgrammeSetupStep.baselineScan:
        // Booking is mock data until Appointments ships (feature flag).
        return canBook
            ? (
                label: 'Book scan',
                onTap: () => context.pushNamed('appointments'),
              )
            : null;
      case ProgrammeSetupStep.carePlan:
        return null;
    }
  }
}

class _SetupRow extends StatelessWidget {
  const _SetupRow({required this.item, required this.isNext, this.action});
  final ProgrammeSetupItem item;
  final bool isNext;
  final ({String label, VoidCallback onTap})? action;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).extension<ZyndioColors>()!;
    final state = item.done ? 'done' : (isNext ? 'next step' : 'to do');
    return Semantics(
      container: true,
      label: '${item.title}, $state. ${item.done ? item.doneDetail : item.detail}',
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ExcludeSemantics(
              child: _StepDot(
                done: item.done,
                active: isNext,
                number: item.step.index + 1,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: ExcludeSemantics(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      style: TextStyle(
                        fontFamily: ZyndioType.family,
                        fontSize: 15,
                        height: 20 / 15,
                        fontWeight: isNext ? FontWeight.w700 : FontWeight.w600,
                        color: item.done ? c.textSecondary : c.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      item.done ? item.doneDetail : item.detail,
                      style: _captionStyle(c),
                    ),
                  ],
                ),
              ),
            ),
            if (action != null) ...[
              const SizedBox(width: 10),
              _PillButton(label: action!.label, onTap: action!.onTap),
            ],
          ],
        ),
      ),
    );
  }
}

// ── After the baseline: milestone track ─────────────────────────────────────

class _MilestoneCard extends StatelessWidget {
  const _MilestoneCard({required this.journey, required this.canBook});
  final ProgrammeJourney journey;
  final bool canBook;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).extension<ZyndioColors>()!;
    final next = journey.nextMilestone;
    final pending = journey.setup.where((s) => !s.done).toList();
    return Semantics(
      container: true,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: zyndioCard(context),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Semantics(
                    container: true,
                    header: true,
                    child: Text(
                      'Day ${journey.programmeDay} of your programme',
                      style: _titleStyle(c),
                    ),
                  ),
                ),
                Semantics(
                  container: true,
                  button: true,
                  label: 'Open body composition',
                  onTap: () => context.go('/progress'),
                  child: ExcludeSemantics(
                    child: InkResponse(
                      onTap: () => context.go('/progress'),
                      radius: 22,
                      child: Padding(
                        padding: const EdgeInsets.all(6),
                        child: Icon(LucideIcons.chevronRight,
                            size: 20, color: c.textTertiary),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              'Baseline scan ${_date(journey.baselineDate!)}',
              style: _captionStyle(c),
            ),
            const SizedBox(height: 18),
            MilestoneTrack(journey: journey),
            const SizedBox(height: 18),
            if (next != null)
              _NextMilestone(journey: journey, milestone: next, canBook: canBook)
            else
              _Callout(
                icon: LucideIcons.award,
                title: 'First programme year complete',
                body:
                    'Your care team will talk you through what comes next.',
              ),
            for (final item in pending) ...[
              const SizedBox(height: 10),
              _Callout(
                icon: item.step == ProgrammeSetupStep.baselineLabs
                    ? LucideIcons.flaskConical
                    : LucideIcons.clipboardList,
                title: item.title,
                body: item.detail,
                action: item.step == ProgrammeSetupStep.baselineLabs
                    ? (
                        label: 'Upload',
                        onTap: () => context.pushNamed('upload_report'),
                      )
                    : null,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _NextMilestone extends StatelessWidget {
  const _NextMilestone({
    required this.journey,
    required this.milestone,
    required this.canBook,
  });
  final ProgrammeJourney journey;
  final ProgrammeMilestone milestone;
  final bool canBook;

  @override
  Widget build(BuildContext context) {
    final booking = journey.bookingOpen;
    return _Callout(
      icon: LucideIcons.calendarClock,
      highlighted: booking,
      title: 'Next: ${milestone.label} scan and labs',
      body: [
        milestoneDueLine(journey, milestone),
        if (booking && !canBook) 'Your clinic will help you book both.',
      ].join('\n'),
      action: booking && canBook
          ? (label: 'Book', onTap: () => context.pushNamed('appointments'))
          : null,
    );
  }
}

/// Baseline · Day 90 · Day 180 · Day 365 as connected dots. Completed
/// milestones are filled, the next one is ringed, a closed window without a
/// scan is a hollow dot (worded neutrally, never as a failure).
class MilestoneTrack extends StatelessWidget {
  const MilestoneTrack({super.key, required this.journey});
  final ProgrammeJourney journey;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).extension<ZyndioColors>()!;
    final next = journey.nextMilestone;
    final nodes = <({String label, bool done, bool active, String a11y})>[
      (
        label: 'Baseline',
        done: true,
        active: false,
        a11y: 'Baseline scan, ${_date(journey.baselineDate!)}',
      ),
      for (final m in journey.milestones)
        (
          label: m.label,
          done: m.status == MilestoneStatus.completed,
          active: identical(m, next),
          a11y: '${m.label}, ${milestoneStatusText(m)}',
        ),
    ];
    return Semantics(
      container: true,
      label: nodes.map((n) => n.a11y).join('. '),
      child: ExcludeSemantics(
        child: LayoutBuilder(builder: (context, box) {
          // Equal columns; the connector runs between dot centres behind them.
          final inset = box.maxWidth / (nodes.length * 2);
          return Stack(
            children: [
              Positioned(
                top: 11.5,
                left: inset,
                right: inset,
                child: Row(
                  children: [
                    for (var i = 1; i < nodes.length; i++)
                      Expanded(
                        child: Container(
                          height: 3,
                          decoration: BoxDecoration(
                            gradient:
                                nodes[i].done ? ZyndioGradients.brand : null,
                            color: nodes[i].done ? null : c.borderSubtle,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final n in nodes)
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _StepDot(done: n.done, active: n.active),
                          const SizedBox(height: 6),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              n.label,
                              maxLines: 1,
                              style: TextStyle(
                                fontFamily: ZyndioType.family,
                                fontSize: 12,
                                fontWeight: n.active
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                                color: n.active || n.done
                                    ? c.textPrimary
                                    : c.textTertiary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ],
          );
        }),
      ),
    );
  }
}

/// Plain-language status of one milestone, for lists and screen readers.
String milestoneStatusText(ProgrammeMilestone m) => switch (m.status) {
      MilestoneStatus.completed => 'scan received ${_date(m.scanDate!)}',
      MilestoneStatus.dueNow => 'due now, around ${_date(m.target)}',
      MilestoneStatus.upcoming => 'due ${_date(m.target)}',
      MilestoneStatus.notRecorded => 'no scan recorded',
    };

/// Body Composition tab: the full scan schedule as a vertical list.
class ProgrammeScheduleCard extends ConsumerWidget {
  const ProgrammeScheduleCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final journey = ref.watch(programmeJourneyProvider);
    if (journey == null || !journey.hasBaseline) {
      return const SizedBox.shrink();
    }
    final c = Theme.of(context).extension<ZyndioColors>()!;
    final next = journey.nextMilestone;
    final rows = <({String title, String detail, bool done, bool active})>[
      (
        title: 'Baseline scan',
        detail: _date(journey.baselineDate!),
        done: true,
        active: false,
      ),
      for (final m in journey.milestones)
        (
          title: '${m.label} scan and labs',
          detail: identical(m, next)
              ? milestoneDueLine(journey, m)
              : _capitalise(milestoneStatusText(m)),
          done: m.status == MilestoneStatus.completed,
          active: identical(m, next),
        ),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const ZyndioSectionLabel('Your scan schedule'),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          decoration: zyndioCard(context),
          child: Column(
            children: [
              for (var i = 0; i < rows.length; i++)
                Semantics(
                  container: true,
                  label: '${rows[i].title}, ${rows[i].detail}',
                  child: ExcludeSemantics(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Row(
                        children: [
                          _StepDot(
                              done: rows[i].done, active: rows[i].active),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  rows[i].title,
                                  style: TextStyle(
                                    fontFamily: ZyndioType.family,
                                    fontSize: 15,
                                    fontWeight: rows[i].active
                                        ? FontWeight.w700
                                        : FontWeight.w600,
                                    color: c.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(rows[i].detail,
                                    style: _captionStyle(c)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Follow-up scans count within $kMilestoneWindowDays days of each date.',
          style: _captionStyle(c),
        ),
      ],
    );
  }

  static String _capitalise(String s) =>
      s.isEmpty ? s : '${s[0].toUpperCase()}${s.substring(1)}';
}

// ── Small parts ─────────────────────────────────────────────────────────────

TextStyle _titleStyle(ZyndioColors c) => TextStyle(
      fontFamily: ZyndioType.family,
      fontSize: 18,
      height: 24 / 18,
      fontWeight: FontWeight.w700,
      letterSpacing: -0.3,
      color: c.textPrimary,
    );

TextStyle _captionStyle(ZyndioColors c) => TextStyle(
      fontFamily: ZyndioType.family,
      fontSize: 13,
      height: 18 / 13,
      color: c.textSecondary,
    );

class _StepDot extends StatelessWidget {
  const _StepDot({required this.done, required this.active, this.number});
  final bool done;
  final bool active;
  final int? number;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).extension<ZyndioColors>()!;
    const size = 26.0;
    if (done) {
      return Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          gradient: ZyndioGradients.brand,
        ),
        child: const Icon(LucideIcons.check, size: 15, color: Colors.white),
      );
    }
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: active ? c.brandSubtle : c.bgSurface,
        border: Border.all(
          color: active ? const Color(0xFF6A4CF5) : c.borderStrong,
          width: active ? 2.5 : 1.5,
        ),
      ),
      child: number == null
          ? null
          : Text(
              '$number',
              style: TextStyle(
                fontFamily: ZyndioType.family,
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: active ? c.brandOnSubtle : c.textTertiary,
              ),
            ),
    );
  }
}

class _ProgressBar extends StatelessWidget {
  const _ProgressBar({required this.fraction});
  final double fraction;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).extension<ZyndioColors>()!;
    return ExcludeSemantics(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: SizedBox(
          height: 6,
          child: Stack(
            children: [
              Positioned.fill(child: ColoredBox(color: c.bgSunken)),
              FractionallySizedBox(
                widthFactor: fraction.clamp(0, 1).toDouble(),
                child: const DecoratedBox(
                  decoration: BoxDecoration(gradient: ZyndioGradients.brand),
                  child: SizedBox.expand(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Callout extends StatelessWidget {
  const _Callout({
    required this.icon,
    required this.title,
    required this.body,
    this.action,
    this.highlighted = false,
  });
  final IconData icon;
  final String title;
  final String body;
  final ({String label, VoidCallback onTap})? action;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).extension<ZyndioColors>()!;
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: highlighted
            ? (dark ? c.brandSubtle.withValues(alpha: 0.18) : c.brandSubtle)
            : context.z25.tileBg,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(icon,
              size: 20,
              color: highlighted && !dark ? c.brandOnSubtle : c.textPrimary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontFamily: ZyndioType.family,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: c.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(body, style: _captionStyle(c)),
              ],
            ),
          ),
          if (action != null) ...[
            const SizedBox(width: 10),
            _PillButton(label: action!.label, onTap: action!.onTap),
          ],
        ],
      ),
    );
  }
}

class _PillButton extends StatelessWidget {
  const _PillButton({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      button: true,
      label: label,
      onTap: onTap,
      child: ExcludeSemantics(
        child: GestureDetector(
          onTap: onTap,
          behavior: HitTestBehavior.opaque,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 44),
            child: Center(
              widthFactor: 1,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  gradient: ZyndioGradients.brand,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  label,
                  style: const TextStyle(
                    fontFamily: ZyndioType.family,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
