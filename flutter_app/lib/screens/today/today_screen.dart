import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../config/theme.dart';
import '../../providers/intelligence_provider.dart';
import '../../providers/patient_provider.dart';
import '../../providers/wearable_sync_provider.dart';
import '../../providers/feature_flags_provider.dart';
import '../../providers/longevity_provider.dart';
import 'dart:math' as math;
import '../../widgets/programme_journey_card.dart';
import '../../widgets/tc025/tc025_widgets.dart';

// ── Pure helpers (unit-tested) ──────────────────────────────────────────────

/// Greeting by device-time hour + first name (specs §3.1).
String todayGreeting(int hour, String? firstName) {
  final part = hour < 12
      ? 'Good morning'
      : hour < 18
          ? 'Good afternoon'
          : 'Good evening';
  final name = (firstName == null || firstName.trim().isEmpty)
      ? ''
      : ', ${firstName.trim()}';
  return '$part$name';
}

/// First name from a full name, or null.
String? firstNameOf(String? name) {
  final t = (name ?? '').trim();
  if (t.isEmpty) return null;
  return t.split(RegExp(r'\s+')).first;
}

/// Neutral delta text (Rev 2): "Stable" only when the two values are equal at
/// the displayed precision; otherwise an arrow + signed magnitude. Direction is
/// never coloured — the caller always uses delta.neutral.
({String text, bool stable}) zyndioDelta(num current, num previous,
    {int decimals = 0, String unit = ''}) {
  final c = current.toStringAsFixed(decimals);
  final p = previous.toStringAsFixed(decimals);
  if (c == p) return (text: 'Stable', stable: true);
  final diff = current - previous;
  final arrow = diff > 0 ? '↑' : '↓';
  final mag = diff.abs().toStringAsFixed(decimals);
  return (text: '$arrow $mag$unit', stable: false);
}

/// Which render the Today screen shows, from the wearable sync state.
enum TodayState { loading, error, noWearable, offline, data }

TodayState classifyToday(AsyncValue<WearableSyncState> sync) {
  return sync.when(
    loading: () => TodayState.loading,
    error: (_, __) => TodayState.error,
    data: (s) {
      final notLinked = s.error == 'Not linked';
      if (notLinked || s.snapshot == null) return TodayState.noWearable;
      if (s.error != null)
        return TodayState.offline; // refresh failed, cached shown
      return TodayState.data;
    },
  );
}

/// Connected-source display name (names only connected sources, specs §3.1).
String connectedSourceName() =>
    Platform.isIOS ? 'Apple Health' : 'Health Connect';

// ── Screen ──────────────────────────────────────────────────────────────────

class TodayScreen extends ConsumerWidget {
  const TodayScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(patientProfileProvider).value;
    final greeting =
        todayGreeting(DateTime.now().hour, firstNameOf(profile?.name));
    final sync = ref.watch(wearableSyncProvider);
    final state = classifyToday(sync);
    final flags = ref.watch(featureFlagsProvider);
    final longevity = ref.watch(longevityScoreProvider);

    // Z2 Longevity ring: NEVER rendered in PR A. It would require BOTH
    // featureFlagsProvider.longevity_score_enabled (default off) AND a backend
    // longevity_score value; neither exists today, so the ring widget is simply
    // never built and the slot height is 0 (the tiles sit at the top).

    final showRing = flags.longevityScoreEnabled &&
        longevity != null &&
        state != TodayState.loading;
    final score = showRing ? longevity : null;
    return ZyndioTabScaffold(
      title: greeting,
      subtitle: "Here's your health overview for today.",
      eyebrow: DateFormat('EEEE, d MMMM').format(DateTime.now()),
      onRefresh: () => ref.read(wearableSyncProvider.notifier).sync(),
      children: [
        // Z2: score card only with BOTH the flag AND a real score.
        if (score != null) ...[
          _ScoreCard(score: score),
          const SizedBox(height: 20),
        ],
        // Where the patient is in the programme: setup steps, then the
        // Day 90 / 180 / 365 scan-and-labs milestones (APP-14).
        const ProgrammeJourneyCard(),
        ..._bodyFor(
            context, ref, state, sync.value, flags.recoveryScoreEnabled),
      ],
    );
  }

  List<Widget> _bodyFor(
    BuildContext context,
    WidgetRef ref,
    TodayState state,
    WearableSyncState? syncState,
    bool recoveryEnabled,
  ) {
    switch (state) {
      case TodayState.loading:
        return const [_TodayLoading()];
      case TodayState.error:
        return [
          ZyndioStateCard(
            icon: LucideIcons.triangleAlert,
            title: "We couldn't load today's overview",
            body:
                'Check your connection and try again. Nothing you saved has been lost.',
            actionLabel: 'Try again',
            onAction: () => ref.read(wearableSyncProvider.notifier).sync(),
          ),
          // Insight is lab-based and still shown; food log stays reachable.
          const SizedBox(height: 12),
          _InsightCard(ref: ref),
          // Food log row is NOT shown in the error state (Q5).
        ];
      case TodayState.noWearable:
        return [
          _ConnectCard(),
          const SizedBox(height: 12),
          _InsightCard(ref: ref),
          const SizedBox(height: 14),
          _primaryInsightCta(context),
          const SizedBox(height: 16),
          _foodLogRow(context),
        ];
      case TodayState.offline:
      case TodayState.data:
        final snap = syncState!.snapshot!;
        return [
          if (state == TodayState.offline) ...[
            ZyndioStateBanner(
              message:
                  "You're offline. Showing what was saved at ${_syncedTime(syncState.lastSynced)}. We'll refresh when you're back online.",
            ),
            const SizedBox(height: 12),
          ],
          const ZyndioSectionLabel("Today's vitals"),
          _MetricGrid(snapshot: snap, recoveryEnabled: recoveryEnabled),
          const SizedBox(height: 8),
          _changeCaption(context, syncState.lastSynced),
          const SizedBox(height: 16),
          _InsightCard(ref: ref),
          const SizedBox(height: 14),
          _primaryInsightCta(context),
          const SizedBox(height: 16),
          _foodLogRow(context),
        ];
    }
  }

  Widget _changeCaption(BuildContext context, DateTime? lastSynced) {
    final c = Theme.of(context).extension<ZyndioColors>()!;
    return Text(
      'Change vs. your previous 7 days · ${connectedSourceName()}, synced ${_syncedTime(lastSynced)}',
      style: TextStyle(
        fontFamily: ZyndioType.family,
        fontSize: 13,
        height: 18 / 13,
        color: c.textTertiary,
      ),
    );
  }

  Widget _primaryInsightCta(BuildContext context) {
    return ZyndioGradientButton(
      label: 'View My Insights',
      onTap: () => context.pushNamed('chat'),
    );
  }

  Widget _foodLogRow(BuildContext context) {
    // Q5 (Ava, 3 Nov): one Z11 row below the Insight CTA, outside the metric grid.
    return ZyndioListRow(
      icon: LucideIcons.utensils,
      tint: ZyndioTint.amber,
      title: 'Food log',
      subtitle: 'Log a meal by describing it, scanning it or speaking.',
      onTap: () => context.pushNamed('lens_history'),
    );
  }

  static String _syncedTime(DateTime? t) {
    if (t == null) return 'recently';
    final h = t.hour % 12 == 0 ? 12 : t.hour % 12;
    final m = t.minute.toString().padLeft(2, '0');
    final ap = t.hour < 12 ? 'AM' : 'PM';
    return '$h:$m $ap';
  }
}

class _ConnectCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ZyndioStateCard(
      icon: LucideIcons.activity,
      title: 'Connect your health data',
      body:
          'See sleep, recovery, activity and HRV here. Connect Apple Health or Health Connect.',
      actionLabel: 'Connect',
      onAction: () => context.pushNamed('connect_wearable'),
    );
  }
}

/// 2×2 metric grid (Z1). Tiles appear only for metrics a connected source
/// supplies. **Recovery never appears** — it is never derived (Rev 2). With an
/// odd count the last tile spans both columns.
class _MetricGrid extends StatelessWidget {
  const _MetricGrid({required this.snapshot, this.recoveryEnabled = false});
  final WearableSnapshot snapshot;
  final bool recoveryEnabled;

  @override
  Widget build(BuildContext context) {
    final tiles = <_MetricTile>[];

    if (snapshot.sleepHours > 0) {
      tiles.add(_MetricTile(
        icon: LucideIcons.moon,
        tint: ZyndioTint.indigo,
        label: 'Sleep',
        value: _hoursMinutes(snapshot.sleepHours),
      ));
    }
    // Recovery only behind its flag AND with a source value (TC-025 guardrail).
    if (recoveryEnabled && snapshot.recoveryScore > 0) {
      tiles.add(_MetricTile(
        icon: LucideIcons.heart,
        tint: ZyndioTint.rose,
        label: 'Recovery',
        value: '${snapshot.recoveryScore}',
        unit: '/ 100',
      ));
    }
    if (snapshot.steps > 0) {
      tiles.add(_MetricTile(
        icon: LucideIcons.footprints,
        tint: ZyndioTint.green,
        label: 'Activity',
        value: _grouped(snapshot.steps),
        unit: 'steps',
      ));
    }
    if (snapshot.hrv != null) {
      final prev = snapshot.hrvBaseline;
      tiles.add(_MetricTile(
        icon: LucideIcons.activity,
        tint: ZyndioTint.blue,
        label: 'HRV',
        value: snapshot.hrv!.round().toString(),
        unit: 'ms',
        // HRV baseline IS the user's 7-day rolling average → an honest delta.
        delta: prev == null
            ? null
            : zyndioDelta(snapshot.hrv!, prev, decimals: 0, unit: 'ms'),
      ));
    }
    // Resting HR fills the grid when Recovery isn't shown (keeps it 2x2).
    if (snapshot.rhr != null && tiles.length.isOdd) {
      final prev = snapshot.rhrBaseline;
      tiles.add(_MetricTile(
        icon: LucideIcons.heartPulse,
        tint: ZyndioTint.rose,
        label: 'Resting HR',
        value: snapshot.rhr!.toString(),
        unit: 'bpm',
        // Same 7-day rolling baseline as HRV → an honest, neutral delta.
        delta: prev == null
            ? null
            : zyndioDelta(snapshot.rhr!, prev, decimals: 0, unit: 'bpm'),
      ));
    }
    // Recovery intentionally omitted: never derived, no source supplies it.

    if (tiles.isEmpty) {
      return const SizedBox.shrink();
    }

    // Build rows of two; an odd final tile spans the full width.
    final rows = <Widget>[];
    for (var i = 0; i < tiles.length; i += 2) {
      if (i + 1 < tiles.length) {
        rows.add(IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: tiles[i]),
              const SizedBox(width: 12),
              Expanded(child: tiles[i + 1]),
            ],
          ),
        ));
      } else {
        rows.add(SizedBox(width: double.infinity, child: tiles[i]));
      }
      if (i + 2 < tiles.length) rows.add(const SizedBox(height: 12));
    }
    return Column(children: rows);
  }

  static String _hoursMinutes(double hours) {
    final h = hours.floor();
    final m = ((hours - h) * 60).round();
    return '${h}h ${m}m';
  }

  static String _grouped(int n) {
    final s = n.toString();
    final buf = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
      buf.write(s[i]);
    }
    return buf.toString();
  }
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({
    required this.icon,
    required this.label,
    required this.value,
    this.tint = ZyndioTint.blue,
    this.unit,
    this.delta,
  });

  final IconData icon;
  final String label;
  final String value;
  final ZyndioTint tint;
  final String? unit;
  final ({String text, bool stable})? delta;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).extension<ZyndioColors>()!;
    final z = context.z25;
    final sem = [
      label,
      '$value${unit != null ? ' $unit' : ''}',
      if (delta != null) delta!.text,
    ].join(', ');
    return Semantics(
      label: sem,
      container: true,
      child: ExcludeSemantics(
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
          decoration: Theme.of(context).brightness == Brightness.dark
              ? zyndioCard(context, radius: 22)
              : BoxDecoration(
                  color: tint.pastel,
                  borderRadius: BorderRadius.circular(22),
                ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ZyndioIconTile(icon: icon, tint: tint, size: 36),
              const SizedBox(height: 14),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontFamily: ZyndioType.family,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: c.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  RichText(
                    text: TextSpan(
                      text: value,
                      style: TextStyle(
                        fontFamily: ZyndioType.family,
                        fontSize: 26,
                        height: 1.1,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.6,
                        fontFeatures: ZyndioType.tabular,
                        color: c.textPrimary,
                      ),
                      children: [
                        if (unit != null)
                          TextSpan(
                            text: ' $unit',
                            style: TextStyle(
                              fontSize: 13,
                              letterSpacing: 0,
                              fontWeight: FontWeight.w500,
                              color: c.textSecondary,
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (delta != null) ...[
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        if (delta!.stable)
                          Icon(LucideIcons.equal,
                              size: 14, color: z.deltaNeutral),
                        Text(
                          delta!.text,
                          style: TextStyle(
                            fontFamily: ZyndioType.family,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: z.deltaNeutral, // neutral, never red/green
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Longevity Score card (client mockup): the ring with the score, the
/// quarter's trend beside it, and an explicit "illustrative summary" label
/// (client brief). Built only with the flag AND a real score (TC-025 Z2).
class _ScoreCard extends StatelessWidget {
  const _ScoreCard({required this.score});
  final LongevityScore score;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).extension<ZyndioColors>()!;
    final z = context.z25;
    final s = score;
    final trend = s.trendPercent;
    return Semantics(
      container: true,
      label: [
        'Longevity score ${s.score} out of 100',
        if (trend != null)
          'trending ${trend >= 0 ? 'up' : 'down'} ${trend.abs()} percent ${s.trendPeriod}',
        'Illustrative summary, not a diagnosis',
      ].join(', '),
      child: ExcludeSemantics(
        child: Container(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
          decoration: zyndioCard(context, radius: 26),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  SizedBox(
                    width: 138,
                    height: 138,
                    child: CustomPaint(
                      painter: _RingPainter(
                        fraction: s.score.clamp(0, 100) / 100,
                        track: z.tileBg,
                      ),
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '${s.score}',
                              style: TextStyle(
                                fontFamily: ZyndioType.family,
                                fontSize: 44,
                                height: 1.0,
                                fontWeight: FontWeight.w700,
                                letterSpacing: -1.4,
                                fontFeatures: ZyndioType.tabular,
                                color: c.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'of 100',
                              style: TextStyle(
                                fontFamily: ZyndioType.family,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: c.textTertiary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 18),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Longevity Score',
                          style: TextStyle(
                            fontFamily: ZyndioType.family,
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.2,
                            color: c.textPrimary,
                          ),
                        ),
                        if (trend != null) ...[
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: c.brandSubtle,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  trend >= 0
                                      ? LucideIcons.trendingUp
                                      : LucideIcons.trendingDown,
                                  size: 15,
                                  color: c.brandOnSubtle,
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  '${trend >= 0 ? '+' : ''}$trend%',
                                  style: TextStyle(
                                    fontFamily: ZyndioType.family,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    fontFeatures: ZyndioType.tabular,
                                    color: c.brandOnSubtle,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Trending ${trend >= 0 ? 'up' : 'down'} ${s.trendPeriod}',
                            style: TextStyle(
                              fontFamily: ZyndioType.family,
                              fontSize: 14,
                              height: 20 / 14,
                              color: c.textSecondary,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Icon(LucideIcons.info, size: 14, color: c.textTertiary),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Illustrative summary of your recent data. Not a diagnosis.',
                      style: TextStyle(
                        fontFamily: ZyndioType.family,
                        fontSize: 12.5,
                        height: 18 / 12.5,
                        color: c.textTertiary,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({required this.fraction, required this.track});
  final double fraction;
  final Color track;

  static const _start = math.pi * 0.75; // 135°
  static const _sweep = math.pi * 1.5; // 270°

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 13.0;
    final rect = Rect.fromLTWH(
        stroke / 2, stroke / 2, size.width - stroke, size.height - stroke);
    final base = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..color = track;
    canvas.drawArc(rect, _start, _sweep, false, base);
    final arc = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      // Gradient runs 0.._sweep, rotated to the arc's start so it never wraps.
      ..shader = const SweepGradient(
        // Offset a little before the arc start so the round start cap samples
        // the first colour instead of wrapping to the last.
        startAngle: 0,
        endAngle: _sweep + 0.3,
        colors: [
          Color(0xFF7B5CFA),
          Color(0xFF4F6BF5),
          Color(0xFF2E7BEA),
          Color(0xFF38BDF8)
        ],
        stops: [0.0, 0.35, 0.7, 1.0],
        transform: GradientRotation(_start - 0.3),
      ).createShader(rect);
    canvas.drawArc(rect, _start, _sweep * fraction, false, arc);
  }

  @override
  bool shouldRepaint(covariant _RingPainter old) =>
      old.fraction != fraction || old.track != track;
}

/// Z3 Insight card. Copy from the existing AI insight providers; no "New" badge
/// until there is real unopened-insight data (Q12).
class _InsightCard extends StatelessWidget {
  const _InsightCard({required this.ref});
  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).extension<ZyndioColors>()!;
    final insights = ref.watch(aiInsightsProvider);
    final body = insights.isNotEmpty
        ? insights.first
        : 'Your personalised insights appear here as your data comes in.';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 20),
      decoration: Theme.of(context).brightness == Brightness.dark
          ? zyndioCard(context)
          : BoxDecoration(
              color: ZyndioTint.violet.pastel,
              borderRadius: BorderRadius.circular(24),
            ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const ZyndioIconTile(
                  icon: LucideIcons.brain, tint: ZyndioTint.violet, size: 40),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Zyndio AI Insight',
                  style: TextStyle(
                    fontFamily: ZyndioType.family,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.2,
                    color: c.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            body,
            style: TextStyle(
              fontFamily: ZyndioType.family,
              fontSize: 16,
              height: 24 / 16,
              color: c.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

/// Loading skeleton that matches the populated layout (one Loading semantics).
class _TodayLoading extends StatelessWidget {
  const _TodayLoading();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Loading',
      container: true,
      child: Column(
        children: [
          Row(
            children: [
              Expanded(child: _skel(84)),
              const SizedBox(width: 12),
              Expanded(child: _skel(84)),
            ],
          ),
          const SizedBox(height: 12),
          _skel(84),
          const SizedBox(height: 16),
          _skel(120), // insight
          const SizedBox(height: 14),
          _skel(52), // CTA
          const SizedBox(height: 16),
          _skel(76), // food log row
        ],
      ),
    );
  }

  Widget _skel(double h) => Builder(builder: (context) {
        return Container(
          height: h,
          decoration: BoxDecoration(
            color: context.nc.shimmerBase,
            borderRadius: BorderRadius.circular(16),
          ),
        );
      });
}
