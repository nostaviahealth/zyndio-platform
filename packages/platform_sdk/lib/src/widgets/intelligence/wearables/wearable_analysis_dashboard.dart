import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../config/theme.dart';
import '../../../models/wearable_snapshot.dart';
import '../../../services/wearable_intelligence_service.dart';

class BrandWearablesDashboard extends StatelessWidget {
  final WearableSnapshot snapshot;
  final VoidCallback? onBack;
  final VoidCallback? onDeepDive;

  const BrandWearablesDashboard({
    super.key,
    required this.snapshot,
    this.onBack,
    this.onDeepDive,
  });

  @override
  Widget build(BuildContext context) {
    // Calculate Cardio Adaptability
    final cardioScore = WearableIntelligenceService.calculateCardiovascularAdaptability(
      hrv: snapshot.hrv ?? 50.0,
      rhr: (snapshot.rhr ?? 65).toDouble(),
      vo2Max: snapshot.vo2Max ?? 40.0,
    );

    return Container(
      color: const Color(0xFF0A0A0A), // Premium dark theme for wearables
      child: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHeroScore(cardioScore),
                    const SizedBox(height: 24),
                    _buildAiNarrative(cardioScore),
                    const SizedBox(height: 32),
                    const Text(
                      'Performance Metrics',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        _buildMetricCard(
                          title: 'Recovery',
                          value: '\${snapshot.recoveryScore}',
                          unit: '%',
                          icon: LucideIcons.batteryCharging,
                          color: const Color(0xFF10B981),
                        ),
                        const SizedBox(width: 12),
                        _buildMetricCard(
                          title: 'Strain',
                          value: '\${snapshot.strainScore}',
                          unit: '%',
                          icon: LucideIcons.activity,
                          color: const Color(0xFFF97316),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        _buildMetricCard(
                          title: 'Sleep',
                          value: '\${snapshot.sleepScore}',
                          unit: ' / 100',
                          icon: LucideIcons.moon,
                          color: const Color(0xFF6366F1),
                        ),
                        const SizedBox(width: 12),
                        _buildMetricCard(
                          title: 'Stress',
                          value: '\${snapshot.stressScore}',
                          unit: ' / 100',
                          icon: LucideIcons.zap,
                          color: const Color(0xFFEF4444),
                        ),
                      ],
                    ),
                    const SizedBox(height: 32),
                    const Text(
                      'Key Signals',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildSignalList(),
                    const SizedBox(height: 40),
                    Center(
                      child: Text(
                        'Powered by Zyndio Wearable Intelligence',
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.white.withOpacity(0.4),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          if (onBack != null)
            GestureDetector(
              onTap: onBack,
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(LucideIcons.arrowLeft, color: Colors.white, size: 22),
              ),
            )
          else
            const SizedBox(width: 42),

          const Column(
            children: [
              Text(
                'Cardiovascular & Performance',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.3,
                ),
              ),
              Text(
                'Today',
                style: TextStyle(
                  color: Colors.white54,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          
          if (onDeepDive != null)
            GestureDetector(
              onTap: onDeepDive,
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF4F46E5).withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(LucideIcons.sparkles, color: Color(0xFF818CF8), size: 20),
              ),
            )
          else
            const SizedBox(width: 42),
        ],
      ),
    );
  }

  Widget _buildHeroScore(int cardioScore) {
    String statusText;
    Color statusColor;

    if (cardioScore >= 80) {
      statusText = 'Optimal';
      statusColor = const Color(0xFF10B981);
    } else if (cardioScore >= 60) {
      statusText = 'Good';
      statusColor = const Color(0xFF3B82F6);
    } else if (cardioScore >= 40) {
      statusText = 'Average';
      statusColor = const Color(0xFFF59E0B);
    } else {
      statusText = 'Below Target';
      statusColor = const Color(0xFFEF4444);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Adaptability Index',
          style: TextStyle(fontSize: 14, color: Colors.white70, fontWeight: FontWeight.w600),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  '\$cardioScore',
                  style: const TextStyle(fontSize: 56, fontWeight: FontWeight.w800, color: Colors.white, height: 1.0),
                ),
                Text(
                  ' / 100',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: Colors.white.withOpacity(0.4)),
                ),
              ],
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.15),
                borderRadius: BorderRadius.circular(100),
                border: Border.all(color: statusColor.withOpacity(0.3)),
              ),
              child: Text(
                statusText,
                style: TextStyle(color: statusColor, fontSize: 13, fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildAiNarrative(int cardioScore) {
    final narrative = WearableIntelligenceService.getDailyInsight(snapshot.energyScore, snapshot.stressScore);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(LucideIcons.bot, color: Color(0xFF818CF8), size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              narrative,
              style: const TextStyle(fontSize: 14, color: Colors.white70, height: 1.5),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricCard({
    required String title,
    required String value,
    required String unit,
    required IconData icon,
    required Color color,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF111111),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withOpacity(0.05)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 16, color: color),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white70),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  value,
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
                ),
                Text(
                  unit,
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Colors.white.withOpacity(0.5)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSignalList() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF111111),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Column(
        children: [
          _buildSignalRow('Heart Rate Variability', '\${snapshot.hrv?.round() ?? '--'}', 'ms'),
          _buildDivider(),
          _buildSignalRow('Resting Heart Rate', '\${snapshot.rhr ?? '--'}', 'bpm'),
          _buildDivider(),
          _buildSignalRow('VO2 Max', '\${snapshot.vo2Max?.toStringAsFixed(1) ?? '--'}', 'mL/kg/min'),
          _buildDivider(),
          _buildSignalRow('Sleep Duration', '\${snapshot.sleepHours.toStringAsFixed(1)}', 'hrs'),
          _buildDivider(),
          _buildSignalRow('Steps', '\${snapshot.steps}', 'steps'),
        ],
      ),
    );
  }

  Widget _buildSignalRow(String label, String value, String unit) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 14, color: Colors.white70),
          ),
          Row(
            children: [
              Text(
                value,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
              ),
              const SizedBox(width: 4),
              Text(
                unit,
                style: const TextStyle(fontSize: 12, color: Colors.white54),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDivider() {
    return Container(
      height: 1,
      color: Colors.white.withOpacity(0.05),
    );
  }
}
