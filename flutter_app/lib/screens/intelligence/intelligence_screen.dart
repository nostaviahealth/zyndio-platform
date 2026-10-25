import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:fl_chart/fl_chart.dart';
import 'dart:math' as math;
import '../../models/intelligence_data.dart';
import '../../config/theme.dart';
import '../../widgets/ai_card.dart';
import '../../widgets/health_disclaimer_banner.dart';
import '../../providers/intelligence_provider.dart';
import '../../providers/theme_provider.dart';
import '../wearables/widgets/dashboard_card_style.dart';
import '../../providers/proactive_insight_provider.dart';
import '../../widgets/ask_intelligence_button.dart';
import 'widgets/metabolic_sparkline.dart';
import 'widgets/intelligence_feed.dart';
import 'widgets/activity_meter_card.dart';
import '../../services/feature_gate_service.dart';

/// Intelligence screen matching React Intelligence.tsx
class IntelligenceScreen extends ConsumerWidget {
  const IntelligenceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final insights = ref.watch(aiInsightsProvider);
    final isImmersive = ref.watch(themeProvider);
    final intelligenceAsync = ref.watch(intelligenceDataProvider);
    final proactiveInsight = ref.watch(proactiveInsightProvider);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: context.nc.isDark ? Brightness.light : Brightness.dark,
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarIconBrightness: context.nc.isDark ? Brightness.light : Brightness.dark,
        systemNavigationBarContrastEnforced: false,
      ),
      child: Scaffold(
        backgroundColor: context.nc.isDark ? Colors.black : context.nc.scaffoldBg,
        body: Stack(
          children: [
            // ── Background Ambient Glows (High Intelligence Aesthetic) ──
            if (context.nc.isDark) ...[
              // Top Right Glow (Indigo)
              Positioned(
                top: -100,
                right: -100,
                child: Container(
                  width: 500,
                  height: 500,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        const Color(0xFF4F46E5).withValues(alpha: 0.15),
                        const Color(0xFF4F46E5).withValues(alpha: 0),
                      ],
                    ),
                  ),
                ),
              ),
              // Bottom Left Glow (Amber)
              Positioned(
                bottom: -150,
                left: -100,
                child: Container(
                  width: 600,
                  height: 600,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        const Color(0xFFF59E0B).withValues(alpha: 0.08),
                        const Color(0xFFF59E0B).withValues(alpha: 0),
                      ],
                    ),
                  ),
                ),
              ),
            ],

            SafeArea(
              bottom: false,
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 100), // Added bottom padding for fab
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Page Header ──
                    Text(
                      'Intelligence',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                        color: context.nc.textPrimary,
                        letterSpacing: -0.8,
                        height: 1.1,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'AI-powered health insights and analysis',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: context.nc.textSecondary,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Proactive Insight Banner (shows when anomaly detected)
                    if (proactiveInsight != null)
                      _ProactiveInsightBanner(insight: proactiveInsight),

                    // Zyndio AI Card
                    AICard(
                      insights: insights.isEmpty 
                          ? [
                              'How was my sleep quality last night?',
                              'What do my latest biomarkers mean?',
                              'Suggest a meal plan for better energy.',
                              'How can I lower my biological age?',
                              'Explain my daily recovery score.',
                            ] 
                          : insights,
                    ),
                    const SizedBox(height: 24),

                    // Activity Meter Card
                    ActivityMeterCard(key: const ValueKey('activity_meter')),
                    const SizedBox(height: 24),

                    // Metabolic Sparkline (Glucose/Energy prediction)
                    PlusLockedOverlay(
                      title: 'Glucose Stability',
                      subtitle: 'Unlock metabolic predictions and glucose stability analysis.',
                      child: MetabolicSparkline(isImmersive: isImmersive),
                    ),
                    const SizedBox(height: 24),

                    // Overall Score Card
                    if (intelligenceAsync.maybeWhen(data: (d) => (d?.biomarkersScore ?? d?.overallScore) != null, orElse: () => false)) ...[
                      _OverallScoreCard(
                        isImmersive: isImmersive,
                        intelligenceAsync: intelligenceAsync,
                      ),
                      const SizedBox(height: 24),
                    ],

                    // Intelligence Feed (Daily Briefing)
                    Text(
                      'Daily Briefing',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: context.nc.textPrimary,
                        letterSpacing: -0.4,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Actionable insights based on your recent data',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: context.nc.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 16),
                    IntelligenceFeed(isImmersive: isImmersive),
                    const SizedBox(height: 24),

                    // Health Domains (Data Strips) — Also part of System Balance gating
                    if (intelligenceAsync.value?.healthDomains.isNotEmpty ?? false) ...[
                      PlusLockedOverlay(
                        title: 'Health Domains',
                        subtitle: 'Detailed breakdown of your physiological systems.',
                        child: _HealthDomainsSummaryCard(
                          isImmersive: isImmersive,
                          intelligenceAsync: intelligenceAsync,
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],

                    // Disease Risk Analysis
                    if (intelligenceAsync.value?.diseaseRisks.isNotEmpty ?? false) ...[
                      PlusLockedOverlay(
                        title: 'Disease Risk',
                        subtitle: 'Advanced predictive modeling for long-term health risks.',
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Disease Risk Analysis',
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w800,
                                    color: context.nc.textPrimary,
                                    letterSpacing: -0.4,
                                  ),
                                ),
                                GestureDetector(
                                  onTap: () => context.push('/intelligence/disease-risk'),
                                  child: Row(
                                    children: [
                                      Text(
                                        'View All',
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: context.nc.textSecondary,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      Icon(LucideIcons.chevronRight, size: 16, color: context.nc.textTertiary),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            
                            intelligenceAsync.when(
                              data: (data) {
                                if (data == null || data.diseaseRisks.isEmpty) {
                                  return const SizedBox.shrink();
                                }
                                return Column(
                                  children: data.diseaseRisks.map((risk) => _DiseaseRiskCard(
                                    condition: risk.condition,
                                    probability: risk.probability,
                                    level: risk.level,
                                    drivers: risk.drivers,
                                    isImmersive: isImmersive,
                                  )).toList(),
                                );
                              },
                              loading: () => const Center(child: CircularProgressIndicator()),
                              error: (err, stack) => Text('Error loading risks: $err', style: TextStyle(color: context.nc.textSecondary)),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],

                    const SizedBox(height: 40),
                    const HealthDisclaimerBanner(
                      message: DisclaimerMessages.generalHealth,
                    ),
                    const SizedBox(height: 16),
                    Center(
                      child: GestureDetector(
                        onTap: () => context.push('/settings/privacy'),
                        child: Text(
                          'Powered by Zyndio Intelligence\nHealth data is securely processed by Azure OpenAI & Google Gemini.\nLearn how we protect your data.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 11,
                            color: context.nc.textTertiary,
                            height: 1.5,
                            decoration: TextDecoration.underline,
                            decorationColor: const Color(0xFF94A3B8).withOpacity(0.3),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 120),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OverallScoreCard extends StatelessWidget {
  final bool isImmersive;
  final AsyncValue<IntelligenceData?> intelligenceAsync;

  const _OverallScoreCard({
    required this.isImmersive,
    required this.intelligenceAsync,
  });

  @override
  Widget build(BuildContext context) {
    
    return intelligenceAsync.when(
      data: (data) {
        final int? score = data?.biomarkersScore ?? data?.overallScore;
        
        if (score == null) {
          return const SizedBox.shrink();
        }

        return _buildCard(context, score);
      },
      loading: () => _buildCard(context, null, isLoading: true),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  Widget _buildCard(BuildContext context, int? score, {bool isLoading = false}) {
    // Premium Design Tokens - Emerald/Teal
    const Color primaryGreen = Color(0xFF10B981); 
    
    // Determine status and color based on score
    String status = 'Needs Data';
    Color statusColor = BrandColors.slate400;
    String message = 'Upload lab reports to get your health score.';
    
    if (score != null) {
      if (score >= 80) {
        status = 'Optimized';
        statusColor = primaryGreen;
        message = 'Your health metrics are currently optimized.';
      } else if (score >= 60) {
        status = 'Good';
        statusColor = const Color(0xFF10B981); // Green
        message = 'Your health metrics are in a good range.';
      } else if (score >= 40) {
        status = 'Fair';
        statusColor = const Color(0xFFF59E0B); // Amber
        message = 'Some health metrics require attention.';
      } else {
        status = 'Action Needed';
        statusColor = const Color(0xFFEF4444); // Red
        message = 'Critical health metrics need immediate attention.';
      }
    }

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: context.nc.cardSurface,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          // Layer 1: Soft Ambient Glow
          BoxShadow(
            color: (score != null ? statusColor : Colors.black).withOpacity(0.06),
            blurRadius: 24,
            offset: const Offset(0, 4),
          ),
          // Layer 2: Deeper Defined Shadow
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 40,
            offset: const Offset(0, 12),
          ),
        ],
        border: Border.all(color: context.nc.cardBorder),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Bar
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: (score != null ? statusColor : BrandColors.slate400).withOpacity(0.08),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(LucideIcons.activity, size: 14, color: (score != null ? statusColor : BrandColors.slate400)),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'OVERALL HEALTH',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: context.nc.textSecondary,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            
            const SizedBox(height: 16),
            
            // Score Row
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                isLoading 
                ? const SizedBox(
                    height: 60, 
                    width: 60, 
                    child: CircularProgressIndicator(strokeWidth: 2, color: BrandColors.slate300)
                  )
                : ShaderMask(
                  shaderCallback: (bounds) => LinearGradient(
                    colors: score != null 
                        ? [context.nc.textPrimary, context.nc.textSecondary]
                        : [context.nc.divider, context.nc.textTertiary], // Grey for no data
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ).createShader(bounds),
                  child: Text(
                    score != null ? '$score' : '--',
                    style: TextStyle(
                      fontSize: 64, // Reduced to be more balanced
                      fontWeight: FontWeight.w900,
                      color: context.nc.cardSurface,
                      height: 0.9,
                      letterSpacing: -3.0,
                    ),
                  ),
                ),
                if (score != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8, left: 6),
                    child: Text(
                      '/100',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: context.nc.textTertiary,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ),
                const Spacer(),
                // Status Pill
                if (score != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [statusColor, statusColor.withOpacity(0.8)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(100),
                    ),
                    child: Text(
                      status,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: context.nc.cardSurface,
                      ),
                    ),
                  ),
              ],
            ),
            
            const SizedBox(height: 12),
            
            Text(
              message,
              style: TextStyle(
                fontSize: 13,
                color: context.nc.textSecondary,
                fontWeight: FontWeight.w500,
                height: 1.2,
              ),
            ),

            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: AskIntelligenceButton(
                onTap: () {
                  context.pushNamed('chat', queryParameters: {
                    'initialMessage': 'Explain my overall health score of $score and how to improve it based on my data.'
                  });
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}


class _HealthDomainsSummaryCard extends StatelessWidget {
  final bool isImmersive;
  final AsyncValue<IntelligenceData?> intelligenceAsync;

  const _HealthDomainsSummaryCard({
    required this.isImmersive,
    required this.intelligenceAsync,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Health Domains',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: context.nc.textPrimary,
                letterSpacing: -0.4,
              ),
            ),
            GestureDetector(
              onTap: () => context.pushNamed('health_domains'),
              child: Row(
                children: [
                  Text(
                    'View All',
                    style: TextStyle(
                      fontSize: 14,
                      color: context.nc.textSecondary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(LucideIcons.chevronRight, size: 16, color: context.nc.textTertiary),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        
        intelligenceAsync.when(
          data: (data) {
            if (data == null || data.healthDomains.isEmpty) {
               return const SizedBox.shrink();
            }
            
            return Column(
              children: data.healthDomains.map((d) {
                return _DataStripRow(domain: d, isImmersive: isImmersive);
              }).toList(),
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, stack) => Text('Error loading data', style: TextStyle(color: context.nc.textSecondary)),
        ),
      ],
    );
  }


}

class _DataStripRow extends StatelessWidget {
  final HealthDomain domain;
  final bool isImmersive;

  const _DataStripRow({required this.domain, required this.isImmersive});

  String _getEffectiveGrade(int score, String? backendGrade) {
    if (backendGrade != null && backendGrade.isNotEmpty && backendGrade != '-') return backendGrade;
    if (score >= 90) return 'A';
    if (score >= 80) return 'B';
    if (score >= 70) return 'C';
    if (score >= 60) return 'D';
    return 'F';
  }

  Color _getColor(String grade) {
    if (grade.startsWith('A')) return BrandColors.emerald500;
    if (grade.startsWith('B')) return BrandColors.blue500;
    if (grade.startsWith('C')) return BrandColors.amber500;
    if (grade.startsWith('D')) return BrandColors.orange500;
    return BrandColors.red500;
  }

  @override
  Widget build(BuildContext context) {
    final grade = _getEffectiveGrade(domain.score, domain.grade);
    final color = _getColor(grade);
    
    final content = Row(
      children: [
        // Icon Box
        Container(
           padding: const EdgeInsets.all(8),
           margin: const EdgeInsets.only(right: 12),
           decoration: BoxDecoration(
             color: color.withOpacity(isImmersive ? 0.3 : 0.1),
             borderRadius: BorderRadius.circular(10),
           ),
           child: Icon(
             _getIcon(domain.name),
             size: 18,
             color: color,
           ),
        ),

        // Name & Score
        SizedBox(
          width: 90, 
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                domain.name, 
                style: TextStyle(
                  fontWeight: FontWeight.bold, 
                  fontSize: 13,
                  color: context.nc.textPrimary,
                ),
              ),
              Text(
                'Score: ${domain.score}', 
                style: TextStyle(
                  fontSize: 11,
                  color: BrandColors.slate400,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        
        // Sparkline
        Expanded(
          child: SizedBox(
            height: 30,
            child: LineChart(
              LineChartData(
                gridData: const FlGridData(show: false),
                titlesData: const FlTitlesData(show: false),
                borderData: FlBorderData(show: false),
                minX: 0, maxX: 9,
                minY: 0, maxY: 10,
                lineBarsData: [
                  LineChartBarData(
                    spots: _generateSparkData(domain.score),
                    isCurved: true,
                    gradient: LinearGradient(
                      colors: [color.withOpacity(0.5), color],
                    ),
                    barWidth: 3,
                    isStrokeCapRound: true,
                    dotData: const FlDotData(show: false),
                    belowBarData: BarAreaData(
                      show: true, 
                      gradient: LinearGradient(
                        colors: [
                          color.withOpacity(0.15),
                          color.withOpacity(0.0),
                        ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      )
                    ),
                  )
                ],
              )
            ),
          ),
        ),
        const SizedBox(width: 16),
        
        // Grade (Big)
        Container(
          width: 40,
          alignment: Alignment.centerRight,
          child: Text(
             grade, 
             textAlign: TextAlign.right,
             style: TextStyle(
               fontWeight: FontWeight.w800, 
               fontSize: 22, 
               color: color,
               height: 1,
             ),
           ),
        ),
      ],
    );

    return GestureDetector(
      onTap: () {
        context.pushNamed('chat', queryParameters: {
          'initialMessage': 'Explain my ${domain.name} score of ${domain.score} (${_getEffectiveGrade(domain.score, domain.grade)}) and what factors are driving it.'
        });
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        decoration: DashboardCardStyle.decorationOf(context),
        child: content,
      ),
    );
  }

  IconData _getIcon(String name) {
    final n = name.toLowerCase();
    if (n.contains('heart') || n.contains('cardio')) return LucideIcons.heart;
    if (n.contains('metabolic')) return LucideIcons.flame;
    if (n.contains('immune')) return LucideIcons.zap;
    if (n.contains('hormonal')) return LucideIcons.activity;
    if (n.contains('longevity')) return LucideIcons.hourglass; 
    return LucideIcons.activity;
  }

  List<FlSpot> _generateSparkData(int score) {
    final rng = math.Random(score);
    return List.generate(10, (i) {
      double val = (score / 10) + rng.nextInt(3) - 1.5;
      if (val < 0) val = 0;
      if (val > 10) val = 10;
      return FlSpot(i.toDouble(), val);
    });
  }
}

class _DiseaseRiskCard extends ConsumerWidget {
  final String condition;
  final int probability;
  final String level;
  final List<String> drivers;
  final bool isImmersive;

  const _DiseaseRiskCard({
    required this.condition,
    required this.probability,
    required this.level,
    required this.drivers,
    required this.isImmersive,
  });

  Color get _levelColor {
    switch (level.toLowerCase()) {
      case 'low':
        return BrandColors.emerald500;
      case 'moderate':
        return BrandColors.orange500;
      case 'high':
        return BrandColors.red500;
      default:
        return BrandColors.slate500;
    }
  }

  /// Generates wearable-based modifiers for this disease condition
  List<Map<String, dynamic>> _getWearableModifiers(WearableSnapshot? w) {
    if (w == null) return [];
    final mods = <Map<String, dynamic>>[];
    final lc = condition.toLowerCase();

    if (lc.contains('cardio') || lc.contains('heart') || lc.contains('hypertension')) {
      // Cardiovascular / Hypertension
      if (w.rhr != null && w.rhr! < 65) {
        mods.add({'label': 'Low RHR ↓ Risk', 'positive': true});
      } else if (w.rhr != null && w.rhr! > 80) {
        mods.add({'label': 'High RHR ↑ Risk', 'positive': false});
      }
      if (w.hrv != null && w.hrvBaseline != null && w.hrv! > w.hrvBaseline! * 1.1) {
        mods.add({'label': 'Strong HRV ↓ Risk', 'positive': true});
      }
      if (w.stressScore >= 50) {
        mods.add({'label': 'Elevated Stress ↑ Risk', 'positive': false});
      }
    }

    if (lc.contains('diabet') || lc.contains('metabol')) {
      // Diabetes / Metabolic
      if (w.strainScore >= 40) {
        mods.add({'label': 'Active Exercise ↓ Risk', 'positive': true});
      } else if (w.steps < 3000 && w.exerciseMinutes < 10) {
        mods.add({'label': 'Sedentary ↑ Risk', 'positive': false});
      }
      if (w.sleepHours >= 7) {
        mods.add({'label': 'Good Sleep ↓ Risk', 'positive': true});
      }
    }

    if (lc.contains('hypertension') || lc.contains('blood pressure')) {
      if (w.sleepHours >= 7 && w.sleepEfficiency >= 0.8) {
        mods.add({'label': 'Restorative Sleep ↓ Risk', 'positive': true});
      }
    }

    // General modifiers for any condition
    if (w.recoveryScore >= 80 && mods.length < 2) {
      mods.add({'label': 'High Recovery ↓ Risk', 'positive': true});
    }

    return mods;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final wearable = ref.watch(wearableStateProvider).value;
    final wearableMods = _getWearableModifiers(wearable);

    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                condition,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: context.nc.textPrimary,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: _levelColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '$probability% - $level',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: _levelColor,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            // Lab-based drivers
            ...drivers.map((driver) {
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: context.nc.divider,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  driver,
                  style: const TextStyle(fontSize: 11, color: BrandColors.slate600),
                ),
              );
            }),
            // Wearable modifiers
            ...wearableMods.map((mod) {
              final bool positive = mod['positive'] as bool;
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: positive
                      ? const Color(0xFFD1FAE5) // Emerald-100
                      : const Color(0xFFFEE2E2), // Red-100
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: positive
                        ? const Color(0xFF6EE7B7) // Emerald-300
                        : const Color(0xFFFCA5A5), // Red-300
                    width: 0.5,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      LucideIcons.watch,
                      size: 10,
                      color: positive ? BrandColors.emerald600 : BrandColors.red500,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      mod['label'] as String,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: positive ? BrandColors.emerald600 : BrandColors.red500,
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ],
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GestureDetector(
        onTap: () {
          context.pushNamed('chat', queryParameters: {
            'initialMessage': 'Explain my risk of $condition ($level) and how to mitigate it based on my data.'
          });
        },
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: DashboardCardStyle.decorationOf(context),
          child: content,
        ),
      ),
    );
  }
}

/// Banner showing a proactive health insight with an actionable CTA
class _ProactiveInsightBanner extends ConsumerWidget {
  final ProactiveInsight insight;

  const _ProactiveInsightBanner({required this.insight});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF3C7), // Amber 50
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFDE68A)), // Amber 200
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(LucideIcons.alertCircle, color: Color(0xFFD97706), size: 20),
              const SizedBox(width: 8),
              Text(
                insight.title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFFB45309), // Amber 700
                  letterSpacing: -0.2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            insight.body,
            style: const TextStyle(
              fontSize: 14,
              color: Color(0xFFB45309),
              height: 1.4,
            ),
          ),
          if (insight.suggestedQuestion != null) ...[
            const SizedBox(height: 12),
            GestureDetector(
              onTap: () {
                HapticFeedback.lightImpact();
                context.pushNamed('chat', queryParameters: {'initialMessage': insight.suggestedQuestion});
              },
              child: Row(
                children: [
                  const Text(
                    'Get advice',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFFD97706),
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(LucideIcons.arrowRight, size: 16, color: Color(0xFFD97706)),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
