import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
    return ZyndioTabScaffold(
      title: greeting,
      hero: _TodayHero(
        greeting: greeting,
        date: DateFormat('EEEE, d MMMM').format(DateTime.now()),
        // Z2: ring only with BOTH the flag AND a real score (none in prod yet).
        score: showRing ? longevity : null,
      ),
      onRefresh: () => ref.read(wearableSyncProvider.notifier).sync(),
      children:
          _bodyFor(context, ref, state, sync.value, flags.recoveryScoreEnabled),
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
          decoration: zyndioCard(context, radius: 22),
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

/// Today's signature moment: a full-bleed indigo-to-blue gradient with soft
/// light orbs, the greeting in white, and (only with the flag AND a real
/// score, TC-025 Z2) the Longevity ring glowing inside it.
class _TodayHero extends StatelessWidget {
  const _TodayHero({required this.greeting, required this.date, this.score});

  final String greeting;
  final String date;
  final LongevityScore? score;

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    final s = score;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      // White status-bar icons over the dark hero.
      value: SystemUiOverlayStyle.light,
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(36)),
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFF120D45),
                Color(0xFF2A1C9A),
                Color(0xFF3B47DD),
                Color(0xFF2E6BEA)
              ],
              stops: [0.0, 0.38, 0.72, 1.0],
            ),
          ),
          child: Stack(
            children: [
              // Soft light orbs for depth.
              Positioned(
                top: -60,
                right: -40,
                child: _Orb(
                    size: 220,
                    color: const Color(0xFF8B6BFF).withValues(alpha: 0.45)),
              ),
              Positioned(
                bottom: -80,
                left: -60,
                child: _Orb(
                    size: 240,
                    color: const Color(0xFF22D3EE).withValues(alpha: 0.22)),
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(20, top + 14, 20, 28),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                date.toUpperCase(),
                                style: TextStyle(
                                  fontFamily: ZyndioType.family,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 1.3,
                                  color: Colors.white.withValues(alpha: 0.7),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Semantics(
                                header: true,
                                child: Text(
                                  greeting,
                                  style: const TextStyle(
                                    fontFamily: ZyndioType.family,
                                    fontSize: 30,
                                    height: 36 / 30,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: -0.8,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                "Here's your health overview for today.",
                                style: TextStyle(
                                  fontFamily: ZyndioType.family,
                                  fontSize: 15,
                                  color: Colors.white.withValues(alpha: 0.75),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const ZyndioAvatarButton(onDark: true),
                      ],
                    ),
                    if (s != null) ...[
                      const SizedBox(height: 22),
                      Semantics(
                        container: true,
                        label: [
                          'Longevity score ${s.score} out of 100',
                          if (s.trendPercent != null)
                            'trending ${s.trendPercent! >= 0 ? 'up' : 'down'} ${s.trendPercent!.abs()} percent ${s.trendPeriod}',
                        ].join(', '),
                        child: ExcludeSemantics(
                          child: Row(
                            children: [
                              SizedBox(
                                width: 156,
                                height: 156,
                                child: CustomPaint(
                                  painter: _RingPainter(
                                    fraction: s.score.clamp(0, 100) / 100,
                                    track: Colors.white.withValues(alpha: 0.14),
                                  ),
                                  child: Center(
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          '${s.score}',
                                          style: const TextStyle(
                                            fontFamily: ZyndioType.family,
                                            fontSize: 50,
                                            height: 1.0,
                                            fontWeight: FontWeight.w700,
                                            letterSpacing: -1.5,
                                            fontFeatures: ZyndioType.tabular,
                                            color: Colors.white,
                                          ),
                                        ),
                                        const SizedBox(height: 6),
                                        Text(
                                          'Longevity Score',
                                          style: TextStyle(
                                            fontFamily: ZyndioType.family,
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.white
                                                .withValues(alpha: 0.75),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 18),
                              if (s.trendPercent != null)
                                Expanded(
                                  child: Container(
                                    padding: const EdgeInsets.fromLTRB(
                                        16, 14, 16, 16),
                                    decoration: BoxDecoration(
                                      color:
                                          Colors.white.withValues(alpha: 0.10),
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(
                                          color: Colors.white
                                              .withValues(alpha: 0.16)),
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text('Trending',
                                            style: TextStyle(
                                                fontFamily: ZyndioType.family,
                                                fontSize: 13,
                                                color: Colors.white
                                                    .withValues(alpha: 0.7))),
                                        const SizedBox(height: 2),
                                        Text(
                                          s.trendPercent! >= 0 ? 'Up' : 'Down',
                                          style: const TextStyle(
                                            fontFamily: ZyndioType.family,
                                            fontSize: 24,
                                            fontWeight: FontWeight.w700,
                                            color: Colors.white,
                                          ),
                                        ),
                                        const SizedBox(height: 10),
                                        Text(
                                          '${s.trendPercent! >= 0 ? '↑' : '↓'} ${s.trendPercent! >= 0 ? '+' : ''}${s.trendPercent}%',
                                          style: const TextStyle(
                                            fontFamily: ZyndioType.family,
                                            fontSize: 20,
                                            fontWeight: FontWeight.w700,
                                            fontFeatures: ZyndioType.tabular,
                                            color: Color(0xFF7DF0C8),
                                          ),
                                        ),
                                        Text(s.trendPeriod,
                                            style: TextStyle(
                                                fontFamily: ZyndioType.family,
                                                fontSize: 13,
                                                color: Colors.white
                                                    .withValues(alpha: 0.7))),
                                      ],
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Orb extends StatelessWidget {
  const _Orb({required this.size, required this.color});
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(colors: [color, color.withValues(alpha: 0)]),
        ),
      );
}

class _RingPainter extends CustomPainter {
  _RingPainter({required this.fraction, required this.track});
  final double fraction;
  final Color track;

  static const _start = math.pi * 0.75; // 135°
  static const _sweep = math.pi * 1.5; // 270°

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 14.0;
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
          Color(0xFF7C8CFF),
          Color(0xFF38BDF8),
          Color(0xFF2DD4BF),
          Color(0xFF86EFAC)
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
      decoration: zyndioCard(context).copyWith(
        gradient: Theme.of(context).brightness == Brightness.dark
            ? null
            : const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFFF4F1FF), Color(0xFFEEF4FF)],
              ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const ZyndioIconTile(
                  icon: LucideIcons.brain, tint: ZyndioTint.violet, size: 40),
              const SizedBox(width: 12),
              Text(
                'Zyndio AI Insight',
                style: TextStyle(
                  fontFamily: ZyndioType.family,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.2,
                  color: c.textPrimary,
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
