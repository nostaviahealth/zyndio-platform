import 'dart:io';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'dashboard_card_style.dart';
import '../../../../config/theme.dart';
import '../../../services/vo2_max_service.dart';

/// VO2 Max (Cardio Fitness) card styled like the Stress & Energy card.
/// Shows 3 stat columns: Current VO2 Max, Fitness Level, Percentile.
class Vo2MaxCard extends StatelessWidget {
  final double? vo2Max; // ml/kg/min
  final int? age;
  final bool? isMale;
  final DateTime? lastUpdated;

  const Vo2MaxCard({
    super.key,
    this.vo2Max,
    this.age,
    this.isMale,
    this.lastUpdated,
  });

  @override
  Widget build(BuildContext context) {
    final bool hasData = vo2Max != null && vo2Max! > 0;
    final String timeStr = lastUpdated != null
        ? '${lastUpdated!.hour > 12 ? lastUpdated!.hour - 12 : (lastUpdated!.hour == 0 ? 12 : lastUpdated!.hour)}:${lastUpdated!.minute.toString().padLeft(2, '0')} ${lastUpdated!.hour >= 12 ? 'PM' : 'AM'}'
        : '--:--';

    final fitness = hasData
        ? Vo2MaxService.classifyFitness(vo2Max!, age: age, isMale: isMale)
        : (level: '--', percentile: 0.0, color: const Color(0xFF9CA3AF));

    final levelColor = fitness.color;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: DashboardCardStyle.decorationOf(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: hasData ? levelColor : const Color(0xFFCBD5E1),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Cardio Fitness',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: context.nc.textPrimary,
                      letterSpacing: -0.3,
                    ),
                  ),
                ],
              ),
              Icon(LucideIcons.arrowRight, size: 20, color: context.nc.textTertiary),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            hasData ? 'Last updated at $timeStr' : (Platform.isIOS ? 'Waiting for Apple Watch data' : 'Waiting for wearable data'),
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: context.nc.textSecondary,
            ),
          ),
          const SizedBox(height: 20),

          // 3 stat columns
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _StatColumn(
                value: hasData ? vo2Max!.toStringAsFixed(1) : '--',
                label: 'VO₂ Max',
                unit: 'ml/kg/min',
                color: const Color(0xFF10B981),
              ),
              Container(width: 1, height: 44, color: context.nc.divider.withOpacity(0.1)),
              _StatColumn(
                value: hasData ? fitness.level : '--',
                label: 'Level',
                unit: '',
                color: levelColor,
              ),
              Container(width: 1, height: 44, color: context.nc.divider.withOpacity(0.1)),
              _StatColumn(
                value: hasData ? 'Top ${(100 - fitness.percentile).round()}%' : '--',
                label: 'Percentile',
                unit: '',
                color: const Color(0xFF3B82F6),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatColumn extends StatelessWidget {
  final String value;
  final String label;
  final String unit;
  final Color color;

  const _StatColumn({
    required this.value,
    required this.label,
    required this.color,
    this.unit = '',
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            value,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: value.length > 5 ? 16 : 22,
              fontWeight: FontWeight.w800,
              color: color,
              letterSpacing: -0.5,
            ),
          ),
          if (unit.isNotEmpty) ...[
            const SizedBox(height: 1),
            Text(
              unit,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w500,
                color: context.nc.textSecondary,
              ),
            ),
          ],
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: context.nc.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
