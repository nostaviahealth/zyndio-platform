import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../config/theme.dart';
import '../../../data/health_repository.dart';

// Provider for health metrics
final healthMetricsProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final repo = HealthRepository();
  // Check permissions first to avoid errors if not connected
  if (await repo.hasPermissions()) {
    final now = DateTime.now();
    final midnight = DateTime(now.year, now.month, now.day);
    return repo.getDailyMetrics(startTime: midnight, endTime: now);
  }
  return {};
});

class HealthDataDashboard extends ConsumerWidget {
  const HealthDataDashboard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final metricsAsync = ref.watch(healthMetricsProvider);

    return metricsAsync.when(
      data: (metrics) {
        if (metrics.isEmpty) {
          // If no data or not connected, show a small promo or nothing
          // For now, let's show a "Connect" prompt if strictly empty
          return const SizedBox.shrink(); 
        }

        final steps = metrics['steps'] as int? ?? 0;
        final heartRate = metrics['heartRate'] as int? ?? 0;
        final sleepHours = metrics['sleepHours'] as double? ?? 0.0;

        return Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: HealthMetricCard(
                    title: 'Steps',
                    value: steps.toString(), // TODO: Format with commas
                    unit: 'steps',
                    icon: LucideIcons.footprints,
                    color: BrandColors.orange500,
                  ),
                ),
                const SizedBox(width: 16), // Increased spacing
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
            const SizedBox(height: 16), // Increased spacing
            HealthMetricCard(
              title: 'Heart Rate',
              value: heartRate > 0 ? '$heartRate' : '--',
              unit: 'bpm',
              icon: LucideIcons.heart,
              color: BrandColors.red500,
              isFullWidth: true,
            ),
             const SizedBox(height: 24),
          ],
        );
      },
      loading: () => const SizedBox(height: 100, child: Center(child: Text('Loading Bio-Metrics...', style: TextStyle(color: BrandColors.slate400, fontSize: 13)))),
      error: (e, s) => const SizedBox.shrink(), // Hide on error
    );
  }
}

class HealthMetricCard extends StatelessWidget {
  final String title;
  final String value;
  final String unit;
  final IconData icon;
  final Color color;
  final bool isFullWidth;

  const HealthMetricCard({
    super.key,
    required this.title,
    required this.value,
    required this.unit,
    required this.icon,
    required this.color,
    this.isFullWidth = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20), // Increased padding
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 24,
            offset: const Offset(0, 4),
          ),
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 40,
            offset: const Offset(0, 12),
          ),
        ],
        border: Border.all(color: const Color(0xFFF1F5F9)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(10), // Larger icon container
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 20, color: color), // Larger icon
              ),
              if (isFullWidth)
                 Container(
                   padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                   decoration: BoxDecoration(
                     color: BrandColors.slate100,
                     borderRadius: BorderRadius.circular(12),
                   ),
                   child: const Text(
                     "Today",
                     style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: BrandColors.slate500),
                   ),
                 )
            ],
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: BrandColors.slate500,
              letterSpacing: 0.2, // Added letter spacing
            ),
          ),
          const SizedBox(height: 4), // Reduced spacing
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                value,
                style: const TextStyle(
                  fontSize: 28, // Larger value
                  fontWeight: FontWeight.w800, // Bolder
                  color: BrandColors.dark,
                  letterSpacing: -1.0, // Tighter tracking
                  height: 1.0,
                ),
              ),
              const SizedBox(width: 4),
              Padding(
                padding: const EdgeInsets.only(bottom: 2), // Visual alignment
                child: Text(
                  unit,
                  style: const TextStyle(
                    fontSize: 13, // Smaller unit
                    color: BrandColors.slate400,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
