import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';


import '../../config/theme.dart';
import '../../data/health_repository.dart';
import '../../models/lab_report.dart';
import '../../data/protocol_repository.dart';
import '../../providers/auth_provider.dart';
import '../../providers/intelligence_provider.dart';
import '../../providers/lab_reports_provider.dart';
import '../../providers/patient_provider.dart';
import '../../providers/protocol_provider.dart';
import '../../providers/rhythm_provider.dart';
import '../../models/daily_rhythm.dart';
import '../../widgets/ai_card.dart';
import '../wearables/widgets/dashboard_card_style.dart';
import '../wearables/widgets/health_monitor_card.dart';
import '../../widgets/intelligence_glow_wrapper.dart';

/// Unified Dashboard — the app's home screen.
/// Aggregates key data from Wearables, Labs, Protocol, and Intelligence.
class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  final HealthRepository _healthRepo = HealthRepository();
  bool _isLoadingVitals = true;

  // Wearable vitals (subset)
  int? _restingHeartRate;
  double? _hrv;
  double _sleepHours = 0;
  int? _bloodOxygen;

  @override
  void initState() {
    super.initState();
    _fetchVitals();
  }

  Future<void> _fetchVitals() async {
    try {
      await _healthRepo.configure();
      final linked = await _healthRepo.isLinked();
      if (!linked) {
        if (mounted) setState(() => _isLoadingVitals = false);
        return;
      }

      final now = DateTime.now();
      final start = DateTime(now.year, now.month, now.day);
      final end = DateTime(now.year, now.month, now.day, 23, 59, 59);

      final results = await Future.wait([
        _healthRepo.getDailyMetrics(startTime: start, endTime: end),
      ]);

      final metrics = results[0];

      if (mounted) {
        setState(() {
          _restingHeartRate = metrics['restingHeartRate'] as int?;
          _hrv = metrics['hrv'] as double?;
          _sleepHours = (metrics['sleepHours'] as num?)?.toDouble() ?? 0;
          _bloodOxygen = metrics['bloodOxygen'] as int?;
          _isLoadingVitals = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingVitals = false);
    }
  }

  // ═══════════════════════════════════════════════
  // HELPERS
  // ═══════════════════════════════════════════════

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  String _formatSleep(double hours) {
    final h = hours.floor();
    final m = ((hours - h) * 60).round();
    if (h == 0 && m == 0) return '--';
    return m > 0 ? '${h}h ${m}m' : '${h}h';
  }

  Widget _sectionHeader(String title, String subtitle, {VoidCallback? onSeeAll}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: context.nc.textPrimary,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 13,
                    color: context.nc.textTertiary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          if (onSeeAll != null)
            GestureDetector(
              onTap: onSeeAll,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: context.nc.inputFill,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'See all',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: context.nc.textTertiary,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════
  // BUILD
  // ═══════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(patientProfileProvider);
    final profile = profileAsync.value;
    final user = ref.watch(currentUserProvider);

    final String name = (profile?.name != null && profile!.name!.isNotEmpty)
        ? profile.name!.split(' ').first
        : (user?.userMetadata?['name'] as String?)?.split(' ').first ?? 'User';

    final intelligenceAsync = ref.watch(intelligenceDataProvider);
    final intelligence = intelligenceAsync.value;
    final insights = ref.watch(aiInsightsProvider);
    final labsAsync = ref.watch(labReportsProvider);
    final protocolState = ref.watch(protocolProvider);
    final rhythmState = ref.watch(dailyRhythmProvider);
    final DailyRhythm? rhythm = rhythmState.rhythm.value;

    final int? chronAge = profile?.age;
    int? bioAge = intelligence?.biologicalAge;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: context.nc.isDark ? Colors.transparent : context.nc.scaffoldBg,
        body: SafeArea(
          bottom: false,
          child: RefreshIndicator(
            onRefresh: _fetchVitals,
            color: BrandColors.emerald500,
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                // ══════════════════════════════════════════
                // 1. HEADER
                // ══════════════════════════════════════════
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${_greeting()}, $name',
                                style: TextStyle(
                                  fontSize: 28,
                                  fontWeight: FontWeight.w900,
                                  color: context.nc.textPrimary,
                                  letterSpacing: -0.5,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _todayDateString(),
                                style: TextStyle(
                                  fontSize: 14,
                                  color: context.nc.textTertiary,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                        GestureDetector(
                          onTap: () => context.pushNamed('notifications'),
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: context.nc.cardSurface,
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.06),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Icon(LucideIcons.bell, size: 20, color: context.nc.textPrimary),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Content
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
                      const SizedBox(height: 24),

                      // ══════════════════════════════════════════
                      // 2. BIO AGE HERO CARD
                      // ══════════════════════════════════════════
                      _BioAgeHeroCard(
                        chronAge: chronAge,
                        bioAge: bioAge,
                        overallScore: intelligence?.overallScore,
                        onTap: () => context.go('/intelligence'),
                      ),
                      const SizedBox(height: 24),

                      // ══════════════════════════════════════════
                      // 3. AI INSIGHTS (reuse AICard)
                      // ══════════════════════════════════════════
                      _sectionHeader('AI Insights', 'Personalized recommendations'),
                      AICard(insights: insights),
                      const SizedBox(height: 24),

                      // ══════════════════════════════════════════
                      // 4. TODAY'S VITALS (2×2 grid)
                      // ══════════════════════════════════════════
                      _sectionHeader(
                        'Today\'s Vitals',
                        'Key metrics from your wearable',
                        onSeeAll: () => context.go('/wearables'),
                      ),
                      _isLoadingVitals
                          ? _buildVitalsLoading()
                          : _buildVitalsGrid(),
                      const SizedBox(height: 24),

                      // ══════════════════════════════════════════
                      // 5. INTELLIGENCE SNAPSHOT
                      // ══════════════════════════════════════════
                      _sectionHeader(
                        'Health Score',
                        'Intelligence analysis overview',
                        onSeeAll: () => context.go('/intelligence'),
                      ),
                      _IntelligenceSnapshotCard(
                        overallScore: intelligence?.overallScore,
                        domains: intelligence?.healthDomains ?? [],
                        onTap: () => context.go('/intelligence'),
                      ),
                      const SizedBox(height: 24),

                      // ══════════════════════════════════════════
                      // 6. LAB SUMMARY
                      // ══════════════════════════════════════════
                      _sectionHeader(
                        'Lab Results',
                        'Biomarker status overview',
                        onSeeAll: () => context.go('/health_data'),
                      ),
                      labsAsync.when(
                        data: (reports) => _LabSummaryCard(
                          reports: reports,
                          onTap: () => context.go('/health_data'),
                        ),
                        loading: () => _buildCardShimmer(height: 140),
                        error: (_, __) => _buildEmptyCard('Lab data unavailable', LucideIcons.testTube),
                      ),
                      const SizedBox(height: 24),

                      // ══════════════════════════════════════════
                      // 7. PROTOCOL PROGRESS
                      // ══════════════════════════════════════════
                      _sectionHeader(
                        'Protocol',
                        protocolState.selectedProtocol?.title ?? 'Your health plan',
                        onSeeAll: () => context.go('/protocol'),
                      ),
                      _ProtocolProgressCard(
                        protocol: protocolState.selectedProtocol,
                        rhythm: rhythm,
                        onTap: () => context.go('/protocol'),
                      ),
                      const SizedBox(height: 24),

                      // ══════════════════════════════════════════
                      // 8. ASK INTELLIGENCE CTA
                      // ══════════════════════════════════════════
                      _AskIntelligenceCTA(
                        onTap: () => context.pushNamed('chat'),
                      ),

                      const SizedBox(height: 120), // Bottom padding for navbar
                    ]),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _todayDateString() {
    final now = DateTime.now();
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
                    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    const days = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    return '${days[now.weekday - 1]}, ${months[now.month - 1]} ${now.day}';
  }

  Widget _buildVitalsGrid() {
    return GridView.count(
      padding: EdgeInsets.zero,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 1.35,
      children: [
        HealthMonitorCard(
          icon: LucideIcons.heart,
          label: 'RHR',
          valueStr: _restingHeartRate != null ? '$_restingHeartRate' : '--',
          unit: 'bpm',
          numericValue: _restingHeartRate?.toDouble(),
          minBound: 40,
          maxBound: 100,
          normalMin: 50,
          normalMax: 70,
          higherColor: const Color(0xFFF97316),
          lowerColor: const Color(0xFF10B981), // Better to be low RHR
          onTap: () => context.go('/wearables'),
        ),
        HealthMonitorCard(
          icon: LucideIcons.activity,
          label: 'HRV',
          valueStr: _hrv != null ? _hrv!.round().toString() : '--',
          unit: 'ms',
          numericValue: _hrv,
          minBound: 10,
          maxBound: 120,
          normalMin: 30,
          normalMax: 80,
          higherColor: const Color(0xFF3B82F6), // Blue is good for high HRV
          lowerColor: const Color(0xFFF97316),  // Orange/warning for low HRV
          onTap: () => context.go('/wearables'),
        ),
        HealthMonitorCard(
          icon: LucideIcons.moon,
          label: 'Sleep',
          valueStr: _sleepHours > 0 ? _formatSleep(_sleepHours) : '--',
          unit: '',
          numericValue: _sleepHours > 0 ? _sleepHours : null,
          minBound: 0,
          maxBound: 12,
          normalMin: 7,
          normalMax: 9,
          higherColor: const Color(0xFF3B82F6), // Extra sleep is fine
          lowerColor: const Color(0xFFF97316),  // Not enough sleep
          onTap: () => context.go('/wearables'),
        ),
        HealthMonitorCard(
          icon: LucideIcons.droplets,
          label: 'SpO2',
          valueStr: _bloodOxygen != null ? '$_bloodOxygen' : '--',
          unit: '%',
          numericValue: _bloodOxygen?.toDouble(),
          minBound: 85,
          maxBound: 100,
          normalMin: 95,
          normalMax: 100,
          higherColor: const Color(0xFF10B981), // 100% is fine
          lowerColor: const Color(0xFFEF4444),  // Low SpO2 is bad
          onTap: () => context.go('/wearables'),
        ),
      ],
    );
  }

  Widget _buildVitalsLoading() {
    return GridView.count(
      padding: EdgeInsets.zero,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 1.35,
      children: List.generate(4, (_) => _buildCardShimmer()),
    );
  }

  Widget _buildCardShimmer({double height = 100}) {
    return Container(
      height: height,
      decoration: DashboardCardStyle.decorationOf(context),
      child: const Center(
        child: SizedBox(
          width: 24, height: 24,
          child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFCBD5E1)),
        ),
      ),
    );
  }

  Widget _buildEmptyCard(String message, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: DashboardCardStyle.decorationOf(context),
      child: Row(
        children: [
          Icon(icon, size: 24, color: const Color(0xFFCBD5E1)),
          const SizedBox(width: 16),
          Text(
            message,
            style: const TextStyle(
              fontSize: 15,
              color: Color(0xFF94A3B8),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// 2. BIO AGE HERO CARD
// ═══════════════════════════════════════════════════════════════════

class _BioAgeHeroCard extends StatelessWidget {
  final int? chronAge;
  final int? bioAge;
  final int? overallScore;
  final VoidCallback onTap;

  const _BioAgeHeroCard({
    required this.chronAge,
    required this.bioAge,
    required this.overallScore,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bool hasData = bioAge != null && chronAge != null;
    final bool isYounger = hasData && bioAge! < chronAge!;
    final Color accentColor = isYounger ? const Color(0xFF10B981) : const Color(0xFFF97316);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
          ),
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF0F172A).withOpacity(0.3),
              blurRadius: 30,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: hasData
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Top row
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: accentColor.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              isYounger ? LucideIcons.trendingDown : LucideIcons.trendingUp,
                              size: 14,
                              color: accentColor,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${isYounger ? '' : '+'}${bioAge! - chronAge!} years',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: accentColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Spacer(),
                      const Icon(LucideIcons.arrowRight, size: 18, color: Color(0xFF64748B)),
                    ],
                  ),
                  const SizedBox(height: 20),
                  // Bio Age display
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      // Bio Age (large)
                      Flexible(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Biological Age',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: Color(0xFF94A3B8),
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '$bioAge',
                              style: const TextStyle(
                                fontSize: 48,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                                height: 1.0,
                                letterSpacing: -2,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      // Chron Age (smaller)
                      Flexible(
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Calendar Age',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: Color(0xFF64748B),
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '$chronAge',
                                style: const TextStyle(
                                  fontSize: 28,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF94A3B8),
                                  letterSpacing: -1,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const Spacer(),
                      // Score circle
                      if (overallScore != null)
                        SizedBox(
                          width: 56,
                          height: 56,
                          child: CustomPaint(
                            painter: _ScoreRingPainter(
                              progress: overallScore! / 100.0,
                              color: accentColor,
                            ),
                            child: Center(
                              child: Text(
                                '$overallScore',
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              )
            : // Empty state
              Column(
                children: [
                  const Icon(LucideIcons.dna, size: 40, color: Color(0xFF475569)),
                  const SizedBox(height: 12),
                  Text(
                    'Upload lab reports to unlock\nyour Biological Age',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Colors.white.withOpacity(0.7),
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 16),
                  GestureDetector(
                    onTap: () => context.go('/health_data'),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF3B82F6),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Text(
                        'Upload Labs',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// SCORE RING PAINTER
// ═══════════════════════════════════════════════════════════════════

class _ScoreRingPainter extends CustomPainter {
  final double progress;
  final Color color;

  _ScoreRingPainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 3;

    // Background track
    final bgPaint = Paint()
      ..color = const Color(0xFF334155)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(center, radius, bgPaint);

    // Progress arc
    final fgPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      2 * math.pi * progress,
      false,
      fgPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _ScoreRingPainter old) =>
      old.progress != progress || old.color != color;
}

// ═══════════════════════════════════════════════════════════════════
// 5. INTELLIGENCE SNAPSHOT CARD
// ═══════════════════════════════════════════════════════════════════

class _IntelligenceSnapshotCard extends StatelessWidget {
  final int? overallScore;
  final List domains;
  final VoidCallback onTap;

  const _IntelligenceSnapshotCard({
    required this.overallScore,
    required this.domains,
    required this.onTap,
  });

  Color _scoreColor(int score) {
    if (score >= 80) return const Color(0xFF10B981);
    if (score >= 60) return const Color(0xFF3B82F6);
    if (score >= 40) return const Color(0xFFFBBF24);
    return const Color(0xFFF97316);
  }

  @override
  Widget build(BuildContext context) {
    if (overallScore == null) {
      return GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: DashboardCardStyle.decorationOf(context),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(LucideIcons.brain, size: 24, color: Color(0xFF94A3B8)),
              ),
              const SizedBox(width: 16),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Health Score',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Upload labs to generate your score',
                      style: TextStyle(
                        fontSize: 13,
                        color: Color(0xFF94A3B8),
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(LucideIcons.arrowRight, size: 18, color: Color(0xFFCBD5E1)),
            ],
          ),
        ),
      );
    }

    final topDomains = domains.take(4).toList();
    final color = _scoreColor(overallScore!);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: DashboardCardStyle.decorationOf(context),
        child: Column(
          children: [
            // Score row
            Row(
              children: [
                // Score ring
                SizedBox(
                  width: 64,
                  height: 64,
                  child: CustomPaint(
                    painter: _ScoreRingPainter(
                      progress: overallScore! / 100.0,
                      color: color,
                    ),
                    child: Center(
                      child: Text(
                        '$overallScore',
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Overall Health Score',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        overallScore! >= 80
                            ? 'Excellent'
                            : overallScore! >= 60
                                ? 'Good'
                                : overallScore! >= 40
                                    ? 'Fair'
                                    : 'Needs attention',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: color,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(LucideIcons.arrowRight, size: 18, color: Color(0xFFCBD5E1)),
              ],
            ),
            if (topDomains.isNotEmpty) ...[
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Divider(height: 1, color: Color(0xFFF1F5F9)),
              ),
              // Domain bars
              ...topDomains.map((d) {
                final score = d.score as int;
                final dColor = _scoreColor(score);
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 90,
                        child: Text(
                          d.name,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF64748B),
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: score / 100.0,
                            minHeight: 6,
                            backgroundColor: const Color(0xFFF1F5F9),
                            valueColor: AlwaysStoppedAnimation(dColor),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      SizedBox(
                        width: 28,
                        child: Text(
                          '$score',
                          textAlign: TextAlign.right,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: dColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ],
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// 6. LAB SUMMARY CARD
// ═══════════════════════════════════════════════════════════════════

class _LabSummaryCard extends StatelessWidget {
  final List<LabReport> reports;
  final VoidCallback onTap;

  const _LabSummaryCard({required this.reports, required this.onTap});

  @override
  Widget build(BuildContext context) {
    // Aggregate markers
    final allMarkers = reports.expand((r) => r.markers).toList();
    final int total = allMarkers.length;
    final int optimal = allMarkers.where((m) => m.isOptimal).length;
    final int inRange = allMarkers.where((m) => m.isInRange).length;
    final int outlier = allMarkers.where((m) => m.isOutlier).length;

    if (total == 0) {
      return GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: DashboardCardStyle.decorationOf(context),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(LucideIcons.testTube, size: 24, color: Color(0xFF94A3B8)),
              ),
              const SizedBox(width: 16),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'No Lab Reports',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Upload your reports to see biomarker insights',
                      style: TextStyle(
                        fontSize: 13,
                        color: Color(0xFF94A3B8),
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(LucideIcons.arrowRight, size: 18, color: Color(0xFFCBD5E1)),
            ],
          ),
        ),
      );
    }

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: DashboardCardStyle.decorationOf(context),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Icon(LucideIcons.testTube, size: 18, color: Color(0xFF3B82F6)),
                const SizedBox(width: 8),
                Text(
                  '$total Biomarkers Analyzed',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const Spacer(),
                const Icon(LucideIcons.arrowRight, size: 18, color: Color(0xFFCBD5E1)),
              ],
            ),
            const SizedBox(height: 16),
            // Progress bar
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: SizedBox(
                height: 10,
                child: Row(
                  children: [
                    if (optimal > 0)
                      Expanded(
                        flex: optimal,
                        child: Container(color: const Color(0xFF10B981)),
                      ),
                    if (inRange > 0)
                      Expanded(
                        flex: inRange,
                        child: Container(color: const Color(0xFF3B82F6)),
                      ),
                    if (outlier > 0)
                      Expanded(
                        flex: outlier,
                        child: Container(color: const Color(0xFFF97316)),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            // Legend
            Row(
              children: [
                _LegendDot(color: const Color(0xFF10B981), label: 'Optimal', count: optimal),
                const SizedBox(width: 16),
                _LegendDot(color: const Color(0xFF3B82F6), label: 'In Range', count: inRange),
                const SizedBox(width: 16),
                _LegendDot(color: const Color(0xFFF97316), label: 'Outlier', count: outlier),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;
  final int count;

  const _LegendDot({required this.color, required this.label, required this.count});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(
          '$label ($count)',
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: Color(0xFF64748B),
          ),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// 7. PROTOCOL PROGRESS CARD
// ═══════════════════════════════════════════════════════════════════

class _ProtocolProgressCard extends StatelessWidget {
  final ProtocolData? protocol;
  final DailyRhythm? rhythm;
  final VoidCallback onTap;

  const _ProtocolProgressCard({
    required this.protocol,
    required this.rhythm,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    if (protocol == null) {
      return GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: DashboardCardStyle.decorationOf(context),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(LucideIcons.clipboardList, size: 24, color: Color(0xFF94A3B8)),
              ),
              const SizedBox(width: 16),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'No Active Protocol',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Choose a health plan to get started',
                      style: TextStyle(
                        fontSize: 13,
                        color: Color(0xFF94A3B8),
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(LucideIcons.arrowRight, size: 18, color: Color(0xFFCBD5E1)),
            ],
          ),
        ),
      );
    }

    // Calculate adherence
    int totalTasks = 0;
    int completedTasks = 0;

    if (rhythm != null) {
      for (final task in rhythm!.tasks) {
        totalTasks++;
        if (task.isCompleted) completedTasks++;
      }
    }

    final double adherence = totalTasks > 0 ? completedTasks / totalTasks : 0.0;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: DashboardCardStyle.decorationOf(context),
        child: Row(
          children: [
            // Adherence ring
            SizedBox(
              width: 64,
              height: 64,
              child: CustomPaint(
                painter: _ScoreRingPainter(
                  progress: adherence,
                  color: const Color(0xFF10B981),
                ),
                child: Center(
                  child: Text(
                    '${(adherence * 100).round()}%',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    protocol?.title ?? 'Protocol',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF0F172A),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$completedTasks of $totalTasks tasks completed today',
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF94A3B8),
                    ),
                  ),
                ],
              ),
            ),
            const Icon(LucideIcons.arrowRight, size: 18, color: Color(0xFFCBD5E1)),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// 8. ASK INTELLIGENCE CTA
// ═══════════════════════════════════════════════════════════════════

class _AskIntelligenceCTA extends StatelessWidget {
  final VoidCallback onTap;

  const _AskIntelligenceCTA({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return IntelligenceGlowWrapper(
      borderRadius: 28,
      blurSigma: 12,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [Color(0xFF3B82F6), Color(0xFF8B5CF6)],
            ),
            borderRadius: BorderRadius.circular(28),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(LucideIcons.brain, size: 22, color: Colors.white),
              ),
              const SizedBox(width: 16),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Ask Intelligence',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Get AI-powered health guidance',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFFE0E7FF),
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(LucideIcons.arrowRight, size: 20, color: Colors.white),
            ],
          ),
        ),
      ),
    );
  }
}
