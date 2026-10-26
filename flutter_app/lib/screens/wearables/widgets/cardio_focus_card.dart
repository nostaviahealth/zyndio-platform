import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'dashboard_card_style.dart';
import '../../../config/theme.dart';

/// Cardio Focus card (small card showing aerobic focus).
/// Matches reference: "Cardio Focus" → "Low Aerobic" with percentage + bar.
class CardioFocusCard extends StatelessWidget {
  final String focusType; // "Low Aerobic", "High Aerobic", "Anaerobic"
  final int percent; // 0-100
  final int minutes; // Raw exercise minutes
  final VoidCallback? onTap;

  const CardioFocusCard({
    super.key,
    this.focusType = 'Low Aerobic',
    this.percent = 0,
    this.minutes = 0,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bool hasData = percent > 0;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: DashboardCardStyle.decorationOf(context),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(LucideIcons.heartPulse, size: 14, color: context.nc.textSecondary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Cardio Focus',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: context.nc.textSecondary,
                    ),
                  ),
                ),
                Icon(LucideIcons.chevronRight, size: 14, color: const Color(0xFFCBD5E1)),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              focusType != 'No data' ? focusType : 'No data',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: focusType != 'No data' ? context.nc.textPrimary : context.nc.textTertiary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              hasData ? '$minutes min' : '-- min',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: hasData ? const Color(0xFF06B6D4) : const Color(0xFFCBD5E1),
              ),
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: percent / 100.0,
                backgroundColor: context.nc.textTertiary.withOpacity(0.1),
                valueColor: AlwaysStoppedAnimation<Color>(
                  hasData ? const Color(0xFF06B6D4) : context.nc.textTertiary.withOpacity(0.2),
                ),
                minHeight: 6,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// HRR (Heart Rate Recovery) card — small paired card with Cardio Focus.
class HrrCard extends StatelessWidget {
  final String value; // e.g. "No data" or "32 bpm"
  final String range; // e.g. "Normal" or "No range"
  final VoidCallback? onTap;

  const HrrCard({
    super.key,
    this.value = 'No data',
    this.range = 'No range',
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bool hasData = value != 'No data';

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: DashboardCardStyle.decorationOf(context),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(LucideIcons.heart, size: 14, color: context.nc.textSecondary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'HRR',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: context.nc.textSecondary,
                    ),
                  ),
                ),
                Icon(LucideIcons.chevronRight, size: 14, color: const Color(0xFFCBD5E1)),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              value,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: hasData ? context.nc.textPrimary : context.nc.textTertiary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              range,
              style: TextStyle(
                fontSize: 13,
                color: context.nc.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            // Slider-like indicator
            Stack(
              children: [
                Container(
                  height: 6,
                  decoration: BoxDecoration(
                    color: context.nc.textTertiary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                if (hasData)
                  Positioned(
                    right: 0,
                    child: Container(
                      width: 14,
                      height: 6,
                      decoration: BoxDecoration(
                        color: const Color(0xFF94A3B8),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
