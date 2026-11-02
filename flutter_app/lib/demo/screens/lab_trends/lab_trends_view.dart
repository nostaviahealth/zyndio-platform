import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../config/theme.dart';
import '../../data/fixtures.dart';
import '../../widgets/demo_tab_bar.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/fictional_data_tag.dart';
import '../../widgets/history_row.dart';
import '../../widgets/message_care_team_button.dart';
import '../../widgets/metric_header.dart';
import '../../widgets/range_caveat_card.dart';
import '../../widgets/segmented_control.dart';
import '../../widgets/skeleton.dart';
import '../../widgets/trend_chart.dart';
import '../../widgets/zyndio_banner.dart';
import 'lab_trends_state.dart';

const _rangeSegments = ['3M', '6M', '1Y', 'All'];
const _rangeLegendLabel = 'Default range below 5.7%';

/// Pure view for screens 05/06 (Lab trends). Renders from [state] only — no
/// fetching, no backend calls. The screenshot harness builds it directly
/// from a fixture state; the interactive demo wires it to
/// [LabTrendsController].
class LabTrendsView extends StatelessWidget {
  const LabTrendsView({
    super.key,
    required this.state,
    this.onBack,
    this.onMessageCareTeam,
    this.onTryAgain,
    this.onAddReport,
  });

  final LabTrendsState state;
  final VoidCallback? onBack;
  final VoidCallback? onMessageCareTeam;
  final VoidCallback? onTryAgain;
  final VoidCallback? onAddReport;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<ZyndioColors>()!;
    // The demo entrypoint (main_demo.dart) sets no SystemUiOverlayStyle, so the
    // transparent Android status bar falls back to OS-default icon brightness —
    // dark-on-dark (invisible) in dark mode. Pin it to the canvas it sits over,
    // the same way the production screens do, so the HbA1c detail's bar stays
    // legible as content scrolls beneath it. SafeArea below still keeps that
    // content out from under the bar. (TC-030 item 5, Ava.)
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final overlayStyle = SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
      statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
    );
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: overlayStyle,
      child: Scaffold(
        backgroundColor: colors.bgCanvas,
        body: SafeArea(
          bottom: false,
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(
                    ZyndioSpace.s16,
                    ZyndioSpace.s16,
                    ZyndioSpace.s16,
                    ZyndioSpace.s24,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          TextButton.icon(
                            onPressed: () => onBack?.call(),
                            icon: const Icon(Icons.chevron_left),
                            label: const Text('Labs'),
                          ),
                          const FictionalDataTag(),
                        ],
                      ),
                      Text(
                        state.title,
                        style: ZyndioType.title1.copyWith(
                          color: colors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: ZyndioSpace.s4 + 4),
                      Text(
                        state.subtitle,
                        style: ZyndioType.subhead.copyWith(
                          color: colors.textSecondary,
                        ),
                      ),
                      ..._body(context),
                    ],
                  ),
                ),
              ),
              const DemoTabBar(selected: DemoTab.labs),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _body(BuildContext context) {
    if (state.isLoading) return _loadingBody(context);
    if (state.isSingle) return _singleBody(context);
    return _trendBody(context);
  }

  List<Widget> _loadingBody(BuildContext context) {
    return [
      const SizedBox(height: ZyndioSpace.s16),
      Semantics(
        label: 'Loading',
        child: const Skeleton(width: 120, height: 48),
      ),
      const SizedBox(height: ZyndioSpace.s8),
      const Skeleton(width: 220, height: 14),
      const SizedBox(height: ZyndioSpace.s16),
      SegmentedControl(segments: _rangeSegments, selectedIndex: 1),
      const SizedBox(height: ZyndioSpace.s12),
      const Skeleton(height: ZyndioSize.chartHeight),
    ];
  }

  List<Widget> _singleBody(BuildContext context) {
    return [
      const SizedBox(height: ZyndioSpace.s16),
      MetricHeader(
        value: state.latest.percent.toString(),
        unit: '%',
        badgeLabel: state.badgeLabel,
        badgeVariant: state.badgeVariant,
        meta: state.metaLine,
      ),
      const SizedBox(height: ZyndioSpace.s16),
      const EmptyState(
        icon: Icons.science_outlined,
        title: 'Add another report to see a trend',
        message: 'Your care team usually orders follow-up labs. When the next result arrives, it will show here.',
      ),
      const SizedBox(height: ZyndioSpace.s16),
      FilledButton(
        onPressed: () => onAddReport?.call(),
        child: const Text('Add a lab report'),
      ),
    ];
  }

  List<Widget> _trendBody(BuildContext context) {
    final colors = Theme.of(context).extension<ZyndioColors>()!;
    return [
      if (state.isCachedError) ...[
        const SizedBox(height: ZyndioSpace.s12),
        ZyndioBanner(
          variant: BannerVariant.warning,
          message: state.cachedErrorMessage,
        ),
      ],
      const SizedBox(height: ZyndioSpace.s16),
      MetricHeader(
        value: state.latest.percent.toString(),
        unit: '%',
        badgeLabel: state.badgeLabel,
        badgeVariant: state.badgeVariant,
        meta: state.metaLine,
      ),
      const SizedBox(height: ZyndioSpace.s16),
      SegmentedControl(segments: _rangeSegments, selectedIndex: 1),
      const SizedBox(height: ZyndioSpace.s12),
      TrendChart(points: state.points, rangeCeiling: state.rangeCeiling),
      const SizedBox(height: ZyndioSpace.s8),
      Row(
        children: [
          Container(
            width: 16,
            height: 10,
            decoration: BoxDecoration(
              color: colors.chartRange,
              border: Border.all(color: colors.borderSubtle),
            ),
          ),
          const SizedBox(width: ZyndioSpace.s8),
          Text(
            _rangeLegendLabel,
            style: ZyndioType.caption.copyWith(
              color: colors.textTertiary,
              fontWeight: FontWeight.w400,
            ),
          ),
        ],
      ),
      if (state.isAboveRange) ...[
        const SizedBox(height: ZyndioSpace.s12),
        const ZyndioBanner(
          variant: BannerVariant.warning,
          message: 'This result is above the default range. Your care team will see it too. If you have questions, message them.',
        ),
        const SizedBox(height: ZyndioSpace.s12),
        MessageCareTeamButton(onPressed: () => onMessageCareTeam?.call()),
      ] else if (state.isCachedError) ...[
        const SizedBox(height: ZyndioSpace.s16),
        OutlinedButton(
          onPressed: () => onTryAgain?.call(),
          child: const Text('Try again'),
        ),
      ] else ...[
        const SizedBox(height: ZyndioSpace.s12),
        RangeCaveatCard(onMessageCareTeam: () => onMessageCareTeam?.call()),
        const SizedBox(height: ZyndioSpace.s12),
        _HistoryCard(points: state.points),
      ],
    ];
  }
}

class _HistoryCard extends StatelessWidget {
  const _HistoryCard({required this.points});

  final List<HbA1cPoint> points;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<ZyndioColors>()!;
    final reversed = points.reversed.toList();
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.bgSurface,
        borderRadius: BorderRadius.circular(ZyndioRadius.lg),
        border: Border.all(color: colors.borderSubtle),
      ),
      child: Column(
        children: [
          for (var i = 0; i < reversed.length; i++) ...[
            HistoryRow(
              date: LabTrendsState.formatDate(reversed[i].date),
              value: reversed[i].percent.toString(),
              unit: '%',
            ),
            if (i != reversed.length - 1)
              Divider(
                height: 1,
                color: colors.borderSubtle,
                indent: ZyndioSpace.s16,
                endIndent: ZyndioSpace.s16,
              ),
          ],
        ],
      ),
    );
  }
}
