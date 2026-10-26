import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../../config/theme.dart';
import 'highlight_card.dart';
import 'recovery_radar_chart.dart';
import 'circadian_wave_chart.dart';
import 'sleep_consistency_chart.dart';
import 'heart_rate_zones_chart.dart';
import 'health_correlations_chart.dart';

class HealthInsightsCarousel extends StatefulWidget {
  final int steps;
  final double sleepHours;
  final double hrv;
  final int rhr;
  final List<Map<String, dynamic>> weeklySleep;
  final List<Map<String, dynamic>> hrHistory;
  final List<Map<String, dynamic>> weeklySteps;

  const HealthInsightsCarousel({
    super.key,
    required this.steps,
    required this.sleepHours,
    required this.hrv,
    required this.rhr,
    required this.weeklySleep,
    required this.hrHistory,
    required this.weeklySteps,
  });

  @override
  State<HealthInsightsCarousel> createState() => _HealthInsightsCarouselState();
}

class _HealthInsightsCarouselState extends State<HealthInsightsCarousel> {
  final PageController _controller = PageController(viewportFraction: 0.9);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 400, // Sufficient height for charts + text
      child: PageView(
        controller: _controller,
        padEnds: false,
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: HighlightCard(
              title: "Recovery",
              icon: LucideIcons.activity,
              color: BrandColors.indigo500,
              insight: "Your recovery is balanced. Aim for 30 more mins of sleep tonight to optimize.",
              child: RecoveryRadarChart(
                steps: widget.steps,
                sleepHours: widget.sleepHours,
                hrv: widget.hrv,
                rhr: widget.rhr,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: HighlightCard(
              title: "Energy Rhythm",
              icon: LucideIcons.sun,
              color: BrandColors.orange500,
              insight: "Peak energy predicted at 10:00 AM. Schedule deep work around this time.",
              child: const CircadianWaveChart(wakeTime: TimeOfDay(hour: 7, minute: 0)),
            ),
          ),
          if (widget.weeklySleep.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: HighlightCard(
                title: "Sleep Trends",
                icon: LucideIcons.moon,
                color: BrandColors.indigo500,
                insight: "You slept an average of ${widget.sleepHours} hours over the last 7 days.",
                child: SleepConsistencyChart(weeklySleep: widget.weeklySleep),
              ),
            ),
          if (widget.hrHistory.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: HighlightCard(
                title: "Heart Zones",
                icon: LucideIcons.heart,
                color: BrandColors.red500,
                insight: "Most of your training this week was in the Fat Burn zone.",
                child: HeartRateZonesChart(hrHistory: widget.hrHistory),
              ),
            ),
          if (widget.weeklySteps.isNotEmpty && widget.weeklySleep.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: HighlightCard(
                title: "Correlations",
                icon: LucideIcons.link,
                color: BrandColors.emerald500,
                insight: "Days with higher activity (>8k steps) show 15% better sleep quality.",
                child: HealthCorrelationsChart(weeklySteps: widget.weeklySteps, weeklySleep: widget.weeklySleep),
              ),
            ),
        ],
      ),
    );
  }
}
