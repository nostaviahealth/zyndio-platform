import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../config/theme.dart';
import '../../providers/intelligence_provider.dart';
import '../../providers/patient_provider.dart';
import '../../providers/wearable_sync_provider.dart';
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
      if (s.error != null) return TodayState.offline; // refresh failed, cached shown
      return TodayState.data;
    },
  );
}

/// Connected-source display name (names only connected sources, specs §3.1).
String connectedSourceName() => Platform.isIOS ? 'Apple Health' : 'Health Connect';

// ── Screen ──────────────────────────────────────────────────────────────────

class TodayScreen extends ConsumerWidget {
  const TodayScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(patientProfileProvider).value;
    final greeting = todayGreeting(DateTime.now().hour, firstNameOf(profile?.name));
    final sync = ref.watch(wearableSyncProvider);
    final state = classifyToday(sync);

    // Z2 Longevity ring: NEVER rendered in PR A. It would require BOTH
    // featureFlagsProvider.longevity_score_enabled (default off) AND a backend
    // longevity_score value; neither exists today, so the ring widget is simply
    // never built and the slot height is 0 (the tiles sit at the top).

    return ZyndioTabScaffold(
      title: greeting,
      subtitle: "Here's your health overview for today.",
      onRefresh: () => ref.read(wearableSyncProvider.notifier).sync(),
      children: _bodyFor(context, ref, state, sync.value),
    );
  }

  List<Widget> _bodyFor(
    BuildContext context,
    WidgetRef ref,
    TodayState state,
    WearableSyncState? syncState,
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
          _MetricGrid(snapshot: snap),
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
    return _GradientCta(
      label: 'View My Insights →',
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
  const _MetricGrid({required this.snapshot});
  final WearableSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final tiles = <_MetricTile>[];

    if (snapshot.sleepHours > 0) {
      tiles.add(_MetricTile(
        icon: LucideIcons.moon,
        label: 'Sleep',
        value: _hoursMinutes(snapshot.sleepHours),
      ));
    }
    if (snapshot.steps > 0) {
      tiles.add(_MetricTile(
        icon: LucideIcons.footprints,
        label: 'Activity',
        value: _grouped(snapshot.steps),
        unit: 'steps',
      ));
    }
    if (snapshot.hrv != null) {
      final prev = snapshot.hrvBaseline;
      tiles.add(_MetricTile(
        icon: LucideIcons.activity,
        label: 'HRV',
        value: snapshot.hrv!.round().toString(),
        unit: 'ms',
        // HRV baseline IS the user's 7-day rolling average → an honest delta.
        delta: prev == null
            ? null
            : zyndioDelta(snapshot.hrv!, prev, decimals: 0, unit: 'ms'),
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
    this.unit,
    this.delta,
  });

  final IconData icon;
  final String label;
  final String value;
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
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: z.tileBg,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, size: 24, color: c.textSecondary),
                  const SizedBox(width: 8),
                  Text(
                    label,
                    style: TextStyle(
                      fontFamily: ZyndioType.family,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: c.textPrimary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              RichText(
                text: TextSpan(
                  text: value,
                  style: TextStyle(
                    fontFamily: ZyndioType.family,
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: c.textPrimary,
                  ),
                  children: [
                    if (unit != null)
                      TextSpan(
                        text: ' $unit',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: c.textSecondary,
                        ),
                      ),
                  ],
                ),
              ),
              if (delta != null) ...[
                const SizedBox(height: 4),
                Row(
                  children: [
                    if (delta!.stable)
                      Icon(LucideIcons.equal, size: 15, color: z.deltaNeutral),
                    Text(
                      delta!.text,
                      style: TextStyle(
                        fontFamily: ZyndioType.family,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: z.deltaNeutral, // neutral, never red/green
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
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
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: c.bgSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: c.borderSubtle),
        boxShadow: ZyndioShadow.cardFor(Theme.of(context).brightness),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: ZyndioGradients.brand,
                ),
                child: const Icon(LucideIcons.sparkles, size: 18, color: Colors.white),
              ),
              const SizedBox(width: 8),
              Text(
                'Zyndio AI Insight',
                style: TextStyle(
                  fontFamily: ZyndioType.family,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: c.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            body,
            style: TextStyle(
              fontFamily: ZyndioType.family,
              fontSize: 15,
              height: 22 / 15,
              color: c.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

class _GradientCta extends StatelessWidget {
  const _GradientCta({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: ExcludeSemantics(
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            height: 52,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              gradient: ZyndioGradients.brand,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Text(
              label,
              style: const TextStyle(
                fontFamily: ZyndioType.family,
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ),
        ),
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
