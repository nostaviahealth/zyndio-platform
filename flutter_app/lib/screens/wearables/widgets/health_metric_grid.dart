import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../../config/theme.dart';
// Import existing card
import '../../health_data/widgets/health_dashboard.dart';

class HealthMetricGrid extends StatelessWidget {
  final int heartRate;
  final double sleepHours;
  final int? bloodOxygen;
  
  const HealthMetricGrid({
    super.key,
    required this.heartRate,
    required this.sleepHours,
    this.bloodOxygen,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: HealthMetricCard(
                title: 'Heart Rate',
                value: heartRate > 0 ? '$heartRate' : '--',
                unit: 'bpm',
                icon: LucideIcons.heart,
                color: BrandColors.red500,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: HealthMetricCard(
                title: 'Sleep',
                value: sleepHours.toString(),
                unit: 'hrs',
                icon: LucideIcons.moon,
                color: BrandColors.indigo500,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        // Blood Oxygen or other metric 
        // For now, let's use a full width card for something else or just another row
        // Let's add Blood Oxygen if we have it, or maybe "Resting HR"
         Row(
          children: [
            Expanded(
              child: HealthMetricCard(
                title: 'Blood Oxygen',
                value: bloodOxygen != null ? '$bloodOxygen' : '--',
                unit: '%',
                icon: LucideIcons.droplet,
                color: BrandColors.emerald500,
              ),
            ),
            const SizedBox(width: 16),
             Expanded(
              child: HealthMetricCard(
                title: 'Resting HR',
                value: heartRate > 0 ? '${heartRate - 5}' : '--', // Mock inference
                unit: 'bpm',
                icon: LucideIcons.activity,
                color: BrandColors.orange500,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
