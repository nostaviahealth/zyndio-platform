import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../config/theme.dart';

/// DEXA body composition snapshot for a single scan (baseline or follow-up).
@immutable
class DexaBodyCompositionSnapshot {
  const DexaBodyCompositionSnapshot({
    required this.scanDate,
    required this.deviceVendor,
    required this.deviceModel,
    required this.softwareVersion,
    required this.totalWeightLb,
    required this.fatMassLb,
    required this.leanMassLb,
    required this.visceralFatLbs,
  });

  final String scanDate;
  final String deviceVendor;
  final String deviceModel;
  final String softwareVersion;
  final double totalWeightLb;
  final double fatMassLb;
  final double leanMassLb;
  final double visceralFatLbs;

  String get scannerSummary => '$deviceVendor $deviceModel ($softwareVersion)';

  bool hasMethodChangeFrom(DexaBodyCompositionSnapshot other) {
    return deviceVendor.trim().toLowerCase() !=
            other.deviceVendor.trim().toLowerCase() ||
        deviceModel.trim().toLowerCase() !=
            other.deviceModel.trim().toLowerCase() ||
        softwareVersion.trim().toLowerCase() !=
            other.softwareVersion.trim().toLowerCase();
  }
}

/// 90 / 180 / 365-day next scan & lab milestone reminder model (APP-14).
@immutable
class MilestoneReminderInfo {
  const MilestoneReminderInfo({
    required this.milestoneDays,
    required this.dueDateLabel,
    required this.daysRemaining,
    this.requiresDexaScan = true,
    this.requiresFastingLabs = true,
  }) : assert(
          milestoneDays == 90 || milestoneDays == 180 || milestoneDays == 365,
          'Milestone reminder must be for Day 90, Day 180, or Day 365',
        );

  final int milestoneDays;
  final String dueDateLabel;
  final int daysRemaining;
  final bool requiresDexaScan;
  final bool requiresFastingLabs;

  String get title => 'Day $milestoneDays Milestone Reminder';

  String get requirementsSummary {
    if (requiresDexaScan && requiresFastingLabs) {
      return 'DEXA body composition scan + fasting metabolic lab panel';
    }
    if (requiresDexaScan) return 'DEXA body composition scan';
    if (requiresFastingLabs) return 'Fasting metabolic lab panel';
    return 'Milestone check-in';
  }
}

/// APP-13 & APP-14: Displays baseline vs. follow-up DEXA body composition
/// (Total Weight, Fat Mass, Lean Mass, Visceral Fat) with automatic
/// method-change `insufficient_data` notice when scanner vendor/model/software
/// changed, plus the 90/180/365-day next scan/lab milestone reminder.
class BodyCompositionMilestoneCard extends StatelessWidget {
  const BodyCompositionMilestoneCard({
    super.key,
    required this.baselineScan,
    this.followupScan,
    this.elapsedTreatmentDays,
    this.leanMassFlag = 'none',
    this.nextMilestoneReminder,
    this.onScheduleMilestoneTap,
  });

  final DexaBodyCompositionSnapshot baselineScan;
  final DexaBodyCompositionSnapshot? followupScan;
  final int? elapsedTreatmentDays;
  final String leanMassFlag;
  final MilestoneReminderInfo? nextMilestoneReminder;
  final VoidCallback? onScheduleMilestoneTap;

  static double _round1(double value) {
    return (value * 10).roundToDouble() / 10;
  }

  static double _pctChange(double baseline, double followup) {
    if (baseline == 0) return 0;
    return _round1(((followup - baseline) / baseline) * 100);
  }

  static String _fmtNum(double v) {
    final r = _round1(v);
    if (r == r.roundToDouble()) {
      return r.toInt().toString();
    }
    return r.toStringAsFixed(1);
  }

  static String _fmtSigned(double v, String unit) {
    final r = _round1(v);
    final sign = r > 0 ? '+' : '';
    final unitPart = unit.isEmpty ? '' : (unit == '%' ? '%' : ' $unit');
    return '$sign${_fmtNum(r)}$unitPart';
  }

  @override
  Widget build(BuildContext context) {
    final c =
        Theme.of(context).extension<ZyndioColors>() ?? ZyndioColors.light;
    final followup = followupScan;
    final scannerChanged =
        followup != null && followup.hasMethodChangeFrom(baselineScan);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
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
                    'DEXA Body Composition',
                    style: ZyndioType.headline.copyWith(color: c.textPrimary),
                  ),
                ),
              ),
              if (elapsedTreatmentDays != null)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: c.brandSubtle,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    'Day $elapsedTreatmentDays',
                    style:
                        ZyndioType.caption.copyWith(color: c.brandOnSubtle),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            followup == null
                ? 'Baseline scan (${baselineScan.scanDate}) · ${baselineScan.scannerSummary}'
                : 'Baseline (${baselineScan.scanDate}) vs. Follow-up (${followup.scanDate})',
            style: ZyndioType.footnote.copyWith(color: c.textSecondary),
          ),
          if (scannerChanged) ...[
            const SizedBox(height: 12),
            Semantics(
              liveRegion: true,
              container: true,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: c.statusWarningSubtle,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      LucideIcons.triangleAlert,
                      size: 18,
                      color: c.statusWarning,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Insufficient data (method_changed_dexa_scanner): Baseline (${baselineScan.scannerSummary}) and follow-up (${followup.scannerSummary}) were captured on different DEXA systems. Regional and visceral fat trend comparisons are withheld.',
                        style: ZyndioType.footnote
                            .copyWith(color: c.statusWarning),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 14),
          _buildMeasureRow(
            context: context,
            colors: c,
            label: 'Total Weight',
            unit: 'lb',
            baseline: baselineScan.totalWeightLb,
            followup: followup?.totalWeightLb,
            lowerIsBetter: true,
            methodChanged: false,
          ),
          const Divider(height: 18),
          _buildMeasureRow(
            context: context,
            colors: c,
            label: 'Fat Mass',
            unit: 'lb',
            baseline: baselineScan.fatMassLb,
            followup: followup?.fatMassLb,
            lowerIsBetter: true,
            methodChanged: scannerChanged,
          ),
          const Divider(height: 18),
          _buildMeasureRow(
            context: context,
            colors: c,
            label: 'Lean Mass',
            unit: 'lb',
            baseline: baselineScan.leanMassLb,
            followup: followup?.leanMassLb,
            lowerIsBetter: false,
            methodChanged: scannerChanged,
            badgeLabel: leanMassFlag != 'none'
                ? 'Lean mass: $leanMassFlag'
                : null,
            badgeWarning: leanMassFlag == 'watch' || leanMassFlag == 'flagged',
          ),
          const Divider(height: 18),
          _buildMeasureRow(
            context: context,
            colors: c,
            label: 'Visceral Fat',
            unit: 'lbs',
            baseline: baselineScan.visceralFatLbs,
            followup: followup?.visceralFatLbs,
            lowerIsBetter: true,
            methodChanged: scannerChanged,
          ),
          if (nextMilestoneReminder != null) ...[
            const SizedBox(height: 18),
            _buildMilestoneReminderBanner(context, c, nextMilestoneReminder!),
          ],
        ],
      ),
    );
  }

  Widget _buildMeasureRow({
    required BuildContext context,
    required ZyndioColors colors,
    required String label,
    required String unit,
    required double baseline,
    required double? followup,
    required bool lowerIsBetter,
    required bool methodChanged,
    String? badgeLabel,
    bool badgeWarning = false,
  }) {
    final baseStr = '${_fmtNum(baseline)} $unit';
    if (followup == null) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: ZyndioType.subhead.copyWith(
              color: colors.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
          Text(
            '$baseStr (baseline)',
            style: ZyndioType.numeric(ZyndioType.subhead)
                .copyWith(color: colors.textSecondary),
          ),
        ],
      );
    }

    final followStr = '${_fmtNum(followup)} $unit';
    final deltaAbs = _round1(followup - baseline);
    final deltaPct = _pctChange(baseline, followup);

    String statusText;
    Color statusColor;
    if (methodChanged) {
      statusText = 'insufficient_data (scanner changed)';
      statusColor = colors.statusWarning;
    } else {
      final isFavourable = lowerIsBetter ? deltaPct < -1.0 : deltaPct > 1.0;
      final isStable = deltaPct.abs() <= 1.0;
      final trendWord = isStable
          ? 'stable'
          : isFavourable
              ? 'improving'
              : 'watch';
      statusText =
          '${_fmtSigned(deltaAbs, unit)} (${_fmtSigned(deltaPct, '%')}) · $trendWord';
      statusColor = isFavourable
          ? colors.statusSuccess
          : isStable
              ? colors.textSecondary
              : colors.statusWarning;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: ZyndioType.subhead.copyWith(
                  color: colors.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            if (badgeLabel != null) ...[
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: badgeWarning
                      ? colors.statusWarningSubtle
                      : colors.brandSubtle,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  badgeLabel,
                  style: ZyndioType.caption.copyWith(
                    color: badgeWarning
                        ? colors.statusWarning
                        : colors.brandOnSubtle,
                  ),
                ),
              ),
              const SizedBox(width: 8),
            ],
            Text(
              '$baseStr -> $followStr',
              style: ZyndioType.numeric(ZyndioType.subhead).copyWith(
                color: colors.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Align(
          alignment: Alignment.centerRight,
          child: Text(
            statusText,
            style: ZyndioType.numeric(ZyndioType.footnote).copyWith(
              color: statusColor,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMilestoneReminderBanner(
    BuildContext context,
    ZyndioColors colors,
    MilestoneReminderInfo reminder,
  ) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.bgSunken,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colors.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(LucideIcons.calendarClock,
                  size: 18, color: colors.brandPrimary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  reminder.title,
                  style: ZyndioType.subhead.copyWith(
                    color: colors.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: colors.brandSubtle,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  'Due in ${reminder.daysRemaining} days (${reminder.dueDateLabel})',
                  style: ZyndioType.caption.copyWith(
                    color: colors.brandOnSubtle,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Upcoming milestone requirements: ${reminder.requirementsSummary}.',
            style: ZyndioType.footnote.copyWith(color: colors.textSecondary),
          ),
          if (onScheduleMilestoneTap != null) ...[
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: onScheduleMilestoneTap,
                icon: const Icon(LucideIcons.calendarCheck, size: 16),
                label: Text('Schedule Day ${reminder.milestoneDays} Scan & Labs'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(0, 48),
                  foregroundColor: colors.brandPrimary,
                  side: BorderSide(color: colors.brandPrimary),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
