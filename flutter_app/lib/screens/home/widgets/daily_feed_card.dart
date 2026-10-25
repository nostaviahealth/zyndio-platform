import '../../../config/theme.dart';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../providers/daily_feed_provider.dart';
import '../../../utils/share_canvas_util.dart';

/// Premium daily health snapshot card for the Timeline feed.
/// Two visual states: Standard (white) and Zenith (dark obsidian + glow).
/// Card surfaces a "Hero Metric" — the most impressive, sharable stat.
class DailyFeedCard extends StatefulWidget {
  final DaySnapshot snapshot;

  const DailyFeedCard({super.key, required this.snapshot});

  @override
  State<DailyFeedCard> createState() => _DailyFeedCardState();
}

class _DailyFeedCardState extends State<DailyFeedCard> with SingleTickerProviderStateMixin {
  bool _isSharing = false;
  final GlobalKey _cardKey = GlobalKey();

  late AnimationController _auraController;

  @override
  void initState() {
    super.initState();
    _auraController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _auraController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final score = widget.snapshot.dayScore;
    final scoreColor = _scoreColor(score);
    final isZenith = widget.snapshot.isZenith;
    final highlight = widget.snapshot.highlightMetric;
    final percentile = widget.snapshot.percentileText;

    // ── Guard: treat card as empty if no meaningful biometric data was recorded ──
    final bool hasMetrics = widget.snapshot.steps > 0 ||
        widget.snapshot.sleepHours > 0 ||
        widget.snapshot.activeEnergy > 0 ||
        (widget.snapshot.hrv != null && widget.snapshot.hrv! > 0);

    // Whether there are primary ring metrics (steps/sleep/energy) to show
    final bool hasPrimaryMetrics = widget.snapshot.steps > 0 ||
        widget.snapshot.sleepHours > 0 ||
        widget.snapshot.activeEnergy > 0;

    return RepaintBoundary(
      key: _cardKey,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        constraints: const BoxConstraints(minHeight: 480),
      decoration: isZenith
          ? _zenithDecoration(widget.snapshot.longevityTier, scoreColor)
          : _standardDecoration(scoreColor),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        clipBehavior: Clip.antiAlias,
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(
            sigmaX: context.nc.isDark ? 20 : 0,
            sigmaY: context.nc.isDark ? 20 : 0,
          ),
          child: Stack(
            children: [
            if (isZenith)
              Positioned.fill(
                child: _buildZenithWatermark(widget.snapshot.longevityTier),
              ),
            if (isZenith && hasMetrics)
              Positioned.fill(
                child: AnimatedBuilder(
                  animation: _auraController,
                  builder: (context, child) {
                    return CustomPaint(
                      painter: _HealthAuraPainter(
                        aura: widget.snapshot.healthAura,
                        pulse: _auraController.value,
                        isZenith: true,
                      ),
                    );
                  },
                ),
              ),
            if (!hasMetrics)
              _buildEmptyState(isZenith)
            else
              SingleChildScrollView(
                physics: const ClampingScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildHeader(score, scoreColor, percentile, isZenith),
                    if (highlight != null)
                      _buildHeroMetric(highlight, isZenith),
                    _buildAISummary(isZenith),
                    const SizedBox(height: 12),
                    if (hasPrimaryMetrics) ...[
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Divider(
                          color: isZenith ? Colors.white.withOpacity(0.08) : context.nc.cardBorder,
                          height: 1,
                          thickness: 1,
                        ),
                      ),
                      _buildMetricRings(isZenith),
                    ],
                    if (_hasVitals) ...[
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Divider(
                          color: isZenith ? Colors.white.withOpacity(0.08) : context.nc.cardBorder,
                          height: 1,
                          thickness: 1,
                        ),
                      ),
                      _buildVitalsStrip(isZenith),
                    ],
                    _buildRecoveryBar(scoreColor, isZenith),
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        Visibility(
                          visible: !_isSharing,
                          maintainSize: true,
                          maintainState: true,
                          maintainAnimation: true,
                          child: _buildShareButton(isZenith),
                        ),
                        if (_isSharing)
                          _buildBrandFooter(isZenith),
                      ],
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
          ],
        ),
      ),
    ),
    ),
    );
  }

  bool get _hasVitals =>
      widget.snapshot.hrv != null ||
      widget.snapshot.restingHeartRate != null ||
      widget.snapshot.bloodOxygen != null ||
      widget.snapshot.exerciseMinutes > 0;

  // ── Decorations ──

  BoxDecoration _standardDecoration(Color scoreColor) {
    return BoxDecoration(
      color: context.nc.cardSurface,
      borderRadius: BorderRadius.circular(28),
      border: Border.all(
        color: widget.snapshot.isToday
            ? scoreColor.withOpacity(0.15)
            : context.nc.cardBorder,
      ),
      boxShadow: [
        BoxShadow(
          color: context.nc.shadowColor,
          blurRadius: 24,
          offset: const Offset(0, 4),
        ),
      ],
    );
  }

  BoxDecoration _zenithDecoration(LongevityTier tier, Color scoreColor) {
    List<Color> gradientColors;
    
    switch (tier) {
      case LongevityTier.ethereal: // 95+ (Ethereal White/Gold mesh look)
        gradientColors = [
          const Color(0xFF0F172A),
          const Color(0xFF1E293B),
          const Color(0xFF2A2A1A), // Golden dark hint
          const Color(0xFF0F172A),
        ];
        break;
      case LongevityTier.titanium: // 90-94 (Silver/Blue)
        gradientColors = [
          const Color(0xFF0F172A),
          const Color(0xFF1E293B),
          const Color(0xFF192A40), // Steel blue hint
          const Color(0xFF0F172A),
        ];
        break;
      case LongevityTier.elite: // 85-89 (Jade/Green)
        gradientColors = [
          const Color(0xFF0F172A),
          const Color(0xFF1E293B),
          const Color(0xFF122C25), // Emerald hint
          const Color(0xFF0F172A),
        ];
        break;
      default:
        gradientColors = [
          const Color(0xFF0F172A),
          const Color(0xFF1E293B),
          const Color(0xFF0F172A),
        ];
    }

    return BoxDecoration(
      borderRadius: BorderRadius.circular(28),
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        stops: const [0.0, 0.5, 1.0],
        colors: gradientColors,
      ),
      border: Border.all(
        color: tier == LongevityTier.ethereal 
            ? const Color(0xFFFBBF24).withOpacity(0.4) // Intense gold border
            : scoreColor.withOpacity(0.3),
        width: tier == LongevityTier.ethereal ? 2.0 : 1.5,
      ),
      boxShadow: [
        BoxShadow(
          color: scoreColor.withOpacity(tier == LongevityTier.ethereal ? 0.25 : 0.15),
          blurRadius: 40,
          offset: const Offset(0, 8),
        ),
      ],
    );
  }

  Widget _buildZenithWatermark(LongevityTier tier) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: Stack(
        children: [
          // Simulated Luxury Mesh Effect
          Positioned(
            top: -40,
            right: -20,
            child: Container(
              width: 150,
              height: 150,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    Colors.white.withOpacity(0.05),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 50,
            left: -30,
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    _tierGlowColor(tier).withOpacity(0.08),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          // Zyndio Certified Seal
          Positioned(
            bottom: 20,
            right: 20,
            child: Opacity(
              opacity: 0.05,
              child: Transform.rotate(
                angle: -0.2,
                child: Text(
                  'ZYNDIO \nCERTIFIED',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 4.0,
                    color: Colors.white,
                    height: 1.1,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _tierGlowColor(LongevityTier tier) {
    switch (tier) {
      case LongevityTier.ethereal: return const Color(0xFFFBBF24);
      case LongevityTier.titanium: return const Color(0xFF38BDF8);
      case LongevityTier.elite: return const Color(0xFF34D399);
      default: return Colors.white;
    }
  }

  Widget _buildHeader(int score, Color scoreColor, String? percentile, bool isZenith) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Date Chip
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
            decoration: BoxDecoration(
              color: isZenith
                  ? Colors.white.withOpacity(0.1)
                  : (widget.snapshot.isToday
                      ? context.nc.primary
                      : context.nc.inputFill),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              widget.snapshot.dayLabel,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: isZenith
                    ? Colors.white
                    : (widget.snapshot.isToday
                        ? context.nc.textOnDark
                        : context.nc.textSecondary),
                letterSpacing: -0.2,
              ),
            ),
          ),

          // Spacing to push percentile/score to the right
          const Spacer(),

          // Percentile Pill
          if (percentile != null) ...[
            Flexible(
              child: _PercentilePill(text: percentile, isZenith: isZenith),
            ),
            const SizedBox(width: 12),
          ],

          // Day Score Ring (Aligned)
          if (score > 0)
            _DayScoreRing(score: score, color: scoreColor, isZenith: isZenith),
        ],
      ),
    );
  }

  Widget _buildHeroMetric(HighlightMetric highlight, bool isZenith) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isZenith
                  ? Colors.white.withOpacity(0.08)
                  : context.nc.cardBorder,
            ),
            child: Icon(
              highlight.icon,
              size: 22,
              color: const Color(0xFF10B981),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  highlight.label.toUpperCase(),
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: isZenith
                        ? Colors.white.withOpacity(0.45)
                        : context.nc.textTertiary,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    _ShimmerText(
                      text: highlight.value,
                      isZenith: isZenith,
                    ),
                    if (highlight.subtitle != null) ...[
                      const SizedBox(width: 10),
                      Flexible(
                        child: Text(
                          highlight.subtitle!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: isZenith
                                ? Colors.white.withOpacity(0.35)
                                : context.nc.textTertiary,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          if (widget.snapshot.isPersonalBest)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFF59E0B), Color(0xFFF97316)],
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.emoji_events_rounded, size: 11, color: Colors.white),
                  SizedBox(width: 3),
                  Text(
                    'PB',
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      letterSpacing: 0.8,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildAISummary(bool isZenith) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      child: Text(
        widget.snapshot.summary,
        style: TextStyle(
          fontSize: 14,
          fontWeight: isZenith ? FontWeight.w500 : FontWeight.w500,
          color: isZenith
              ? Colors.white.withOpacity(0.9)
              : context.nc.textPrimary,
          height: 1.5,
          letterSpacing: -0.1,
        ),
        maxLines: 4,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  Widget _buildMetricRings(bool isZenith) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Row(
        children: [
          if (widget.snapshot.steps > 0)
            Expanded(
              child: _BentoMetricCell(
                label: 'Steps',
                value: '${(widget.snapshot.steps / 1000).toStringAsFixed(1)}k',
                progress: widget.snapshot.stepsProgress,
                color: const Color(0xFF3B82F6),
                icon: Icons.directions_walk_rounded,
                isZenith: isZenith,
              ),
            ),
          if (widget.snapshot.steps > 0) const SizedBox(width: 12),
          if (widget.snapshot.sleepHours > 0)
            Expanded(
              child: _BentoMetricCell(
                label: 'Sleep',
                value: '${widget.snapshot.sleepHours.toStringAsFixed(1)}h',
                progress: widget.snapshot.sleepProgress,
                color: const Color(0xFF8B5CF6),
                icon: Icons.bedtime_rounded,
                badge: widget.snapshot.sleepGrade != '--' ? widget.snapshot.sleepGrade : null,
                isZenith: isZenith,
              ),
            ),
          if (widget.snapshot.sleepHours > 0) const SizedBox(width: 12),
          if (widget.snapshot.activeEnergy > 0)
            Expanded(
              child: _BentoMetricCell(
                label: 'Energy',
                value: '${widget.snapshot.activeEnergy.round().toString()}',
                unit: 'kcal',
                progress: widget.snapshot.energyProgress,
                isZenith: isZenith,
                icon: Icons.local_fire_department_rounded,
                color: const Color(0xFFF59E0B),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildVitalsStrip(bool isZenith) {
    final chips = <Widget>[];

    if (widget.snapshot.restingHeartRate != null && widget.snapshot.restingHeartRate! > 0) {
      chips.add(_VitalChip(
        icon: Icons.favorite_rounded,
        label: 'RHR',
        value: '${widget.snapshot.restingHeartRate} bpm',
        color: _rhrColor(widget.snapshot.restingHeartRate!),
        isZenith: isZenith,
      ));
    }

    if (widget.snapshot.hrv != null && widget.snapshot.hrv! > 0) {
      chips.add(_VitalChip(
        icon: Icons.monitor_heart_rounded,
        label: 'HRV',
        value: '${widget.snapshot.hrv!.toStringAsFixed(0)} ms',
        color: _hrvColor(widget.snapshot.hrv!),
        isZenith: isZenith,
      ));
    }

    if (widget.snapshot.bloodOxygen != null && widget.snapshot.bloodOxygen! > 0) {
      chips.add(_VitalChip(
        icon: Icons.water_drop_rounded,
        label: 'SpO₂',
        value: '${widget.snapshot.bloodOxygen}%',
        color: _spo2Color(widget.snapshot.bloodOxygen!),
        isZenith: isZenith,
      ));
    }

    if (widget.snapshot.exerciseMinutes > 0) {
      chips.add(_VitalChip(
        icon: Icons.fitness_center_rounded,
        label: 'Exercise',
        value: '${widget.snapshot.exerciseMinutes} min',
        color: const Color(0xFF06B6D4),
        isZenith: isZenith,
      ));
    }

    if (widget.snapshot.distanceKm >= 0.5) {
      chips.add(_VitalChip(
        icon: Icons.route_rounded,
        label: 'Distance',
        value: '${widget.snapshot.distanceKm.toStringAsFixed(1)} km',
        color: const Color(0xFF10B981),
        isZenith: isZenith,
      ));
    }

    if (chips.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: chips,
      ),
    );
  }

  Widget _buildRecoveryBar(Color scoreColor, bool isZenith) {
    final status = widget.snapshot.recoveryStatus;
    if (status == 'Unknown') return const SizedBox.shrink();

    final ratio = widget.snapshot.recoveryRatio;
    final recoveryColor = _recoveryColor(status);

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: recoveryColor.withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  status == 'Optimal'
                      ? Icons.shield_rounded
                      : status == 'Adequate'
                          ? Icons.shield_outlined
                          : Icons.warning_amber_rounded,
                  size: 10,
                  color: recoveryColor,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'RECOVERY: $status'.toUpperCase(),
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w900,
                  color: recoveryColor,
                  letterSpacing: 0.5,
                ),
              ),
              const Spacer(),
              Text(
                widget.snapshot.activityLevel != 'None'
                    ? '${widget.snapshot.activityLevel} Activity'.toUpperCase()
                    : '',
                style: TextStyle(
                  fontSize: 8,
                  fontWeight: FontWeight.w700,
                  color: isZenith
                      ? Colors.white.withOpacity(0.25)
                      : context.nc.textTertiary,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: SizedBox(
              height: 10,
              child: Stack(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: isZenith
                          ? Colors.white.withOpacity(0.04)
                          : context.nc.cardBorder,
                    ),
                  ),
                  FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: ratio.clamp(0.05, 1.0),
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            recoveryColor.withOpacity(0.4),
                            recoveryColor.withOpacity(0.8),
                            recoveryColor,
                          ],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: recoveryColor.withOpacity(0.3),
                            blurRadius: 10,
                            offset: const Offset(2, 0),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBrandFooter(bool isZenith) {
    return Container(
      width: double.infinity,
      height: 48, // Matches share button absolute height
      alignment: Alignment.center,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Image.asset(
            'assets/icons/app_icon.png',
            width: 32,
            height: 32,
          ),
          const SizedBox(width: 12),
          Text(
            'ZYNDIO',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: isZenith ? Colors.white : context.nc.textPrimary,
              letterSpacing: 2.0,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildShareButton(bool isZenith) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque, // Ensure tap works even on whitespace
        onTap: _isSharing
            ? null
            : () async {
                HapticFeedback.mediumImpact();
                setState(() => _isSharing = true);
                
                try {
                  // Allow _isSharing flag to re-render UI, flipping button to Zyndio Footer
                  await Future.delayed(const Duration(milliseconds: 100));
                  
                  await ShareCanvasUtil.captureWithKeyAndShare(
                    context: context,
                    key: _cardKey,
                    label: widget.snapshot.dayLabel,
                  );
                } finally {
                  if (mounted) {
                    setState(() => _isSharing = false);
                  }
                }
              },
        child: Container(
          width: double.infinity,
          height: 48, // Fixed height for reliable hit target
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isZenith
                ? Colors.white.withOpacity(0.06)
                : context.nc.inputFill,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isZenith
                  ? Colors.white.withOpacity(0.08)
                  : context.nc.divider,
            ),
          ),
          child: _isSharing
              ? SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      isZenith ? Colors.white : context.nc.textTertiary,
                    ),
                  ),
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.ios_share_rounded,
                      size: 16,
                      color: isZenith
                          ? Colors.white.withOpacity(0.6)
                          : context.nc.textTertiary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Share Story',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: isZenith
                            ? Colors.white.withOpacity(0.7)
                            : context.nc.textSecondary,
                        letterSpacing: -0.2,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  /// Compact, premium empty state shown when the device has no health data
  /// for that day. Avoids the stretched blank card bug.
  Widget _buildEmptyState(bool isZenith) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Date chip header (matches _buildHeader style)
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                decoration: BoxDecoration(
                  color: isZenith
                      ? Colors.white.withOpacity(0.1)
                      : (widget.snapshot.isToday
                          ? context.nc.primary
                          : context.nc.inputFill),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  widget.snapshot.dayLabel,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: isZenith
                        ? Colors.white
                        : (widget.snapshot.isToday
                            ? context.nc.textOnDark
                            : context.nc.textSecondary),
                  ),
                ),
              ),
              const Spacer(),
              Icon(
                Icons.sync_problem_rounded,
                size: 16,
                color: isZenith ? Colors.white.withOpacity(0.3) : context.nc.textTertiary,
              ),
            ],
          ),
          
          const SizedBox(height: 64),
          
          Center(
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isZenith ? Colors.white.withOpacity(0.05) : context.nc.inputFill,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.sensors_off_rounded,
                    size: 32,
                    color: isZenith ? Colors.white.withOpacity(0.2) : context.nc.textTertiary,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'No Health Data Yet',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: isZenith ? Colors.white : context.nc.textPrimary,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Your biometric summary for this day is missing or incomplete.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    color: isZenith ? Colors.white.withOpacity(0.4) : context.nc.textTertiary,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () {}, // Trigger sync
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isZenith ? Colors.white.withOpacity(0.1) : context.nc.cardBorder,
                    foregroundColor: isZenith ? Colors.white : context.nc.textSecondary,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.refresh_rounded, size: 16),
                      SizedBox(width: 8),
                      Text('Sync Wearable', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 48),
        ],
      ),
    );
  }

  Color _scoreColor(int score) {
    if (score >= 75) return const Color(0xFF10B981);
    if (score >= 50) return const Color(0xFFF59E0B);
    if (score >= 25) return const Color(0xFFF97316);
    return const Color(0xFFEF4444);
  }

  Color _rhrColor(int rhr) {
    if (rhr <= 60) return const Color(0xFF10B981);
    if (rhr <= 75) return const Color(0xFFF59E0B);
    return const Color(0xFFEF4444);
  }

  Color _hrvColor(double hrv) {
    if (hrv >= 50) return const Color(0xFF10B981);
    if (hrv >= 30) return const Color(0xFFF59E0B);
    return const Color(0xFFEF4444);
  }

  Color _spo2Color(int spo2) {
    if (spo2 >= 96) return const Color(0xFF10B981);
    if (spo2 >= 92) return const Color(0xFFF59E0B);
    return const Color(0xFFEF4444);
  }

  Color _recoveryColor(String status) {
    switch (status) {
      case 'Optimal':
        return const Color(0xFF10B981);
      case 'Adequate':
        return const Color(0xFFF59E0B);
      case 'Strained':
        return const Color(0xFFEF4444);
      default:
        return const Color(0xFF94A3B8);
    }
  }

  String _formatNumber(int n) {
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}k';
    return n.toString();
  }
}

class _PercentilePill extends StatelessWidget {
  final String text;
  final bool isZenith;

  const _PercentilePill({required this.text, required this.isZenith});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        gradient: isZenith
            ? const LinearGradient(
                colors: [Color(0xFFF59E0B), Color(0xFFF97316)],
              )
            : null,
        color: isZenith ? null : const Color(0xFFFFF7ED),
        borderRadius: BorderRadius.circular(10),
        border: isZenith
            ? null
            : Border.all(color: const Color(0xFFF59E0B).withOpacity(0.2)),
      ),
      child: Text(
        text.toUpperCase(),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w700,
          color: isZenith ? Colors.white.withOpacity(0.9) : const Color(0xFFD97706),
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}

class _ShimmerText extends StatefulWidget {
  final String text;
  final bool isZenith;

  const _ShimmerText({required this.text, required this.isZenith});

  @override
  State<_ShimmerText> createState() => _ShimmerTextState();
}

class _ShimmerTextState extends State<_ShimmerText>
    with SingleTickerProviderStateMixin {
  late AnimationController _shimmerController;

  @override
  void initState() {
    super.initState();
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2500),
    );
    if (widget.isZenith) {
      _shimmerController.repeat();
    }
  }

  @override
  void didUpdateWidget(_ShimmerText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isZenith && !_shimmerController.isAnimating) {
      _shimmerController.repeat();
    } else if (!widget.isZenith && _shimmerController.isAnimating) {
      _shimmerController.stop();
    }
  }

  @override
  void dispose() {
    _shimmerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isZenith) {
      return Text(
        widget.text,
        style: TextStyle(
          fontSize: 32,
          fontWeight: FontWeight.w900,
          color: context.nc.textPrimary,
          letterSpacing: -1.2,
          height: 1.1,
        ),
      );
    }

    return AnimatedBuilder(
      animation: _shimmerController,
      builder: (context, child) {
        return ShaderMask(
          shaderCallback: (bounds) {
            return LinearGradient(
              begin: Alignment(-1.0 + 2.0 * _shimmerController.value, 0),
              end: Alignment(1.0 + 2.0 * _shimmerController.value, 0),
              colors: const [
                Colors.white,
                Color(0xFFF59E0B),
                Colors.white,
              ],
              stops: const [0.0, 0.5, 1.0],
            ).createShader(bounds);
          },
          child: Text(
            widget.text,
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w900,
              color: Colors.white,
              letterSpacing: -1.2,
              height: 1.1,
            ),
          ),
        );
      },
    );
  }
}

class _DayScoreRing extends StatelessWidget {
  final int score;
  final Color color;
  final bool isZenith;

  const _DayScoreRing({required this.score, required this.color, this.isZenith = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isZenith ? Colors.white.withOpacity(0.06) : context.nc.cardSurface,
      ),
      child: CustomPaint(
        painter: _ScoreRingPainter(
          progress: score / 100.0,
          color: color,
          isZenith: isZenith,
        ),
        child: Center(
          child: Text(
            '$score',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: color,
              letterSpacing: -0.5,
            ),
          ),
        ),
      ),
    );
  }
}

class _ScoreRingPainter extends CustomPainter {
  final double progress;
  final Color color;
  final bool isZenith;

  _ScoreRingPainter({required this.progress, required this.color, this.isZenith = false});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - 8) / 2;
    const strokeWidth = 4.0;
    const startAngle = -math.pi / 2;
    final sweepAngle = 2 * math.pi * progress.clamp(0.0, 1.0);

    final rect = Rect.fromCircle(center: center, radius: radius);

    canvas.drawArc(
      rect,
      0,
      2 * math.pi,
      false,
      Paint()
        ..color = isZenith ? color.withOpacity(0.15) : color.withOpacity(0.1)
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round,
    );

    if (progress > 0) {
      canvas.drawArc(
        rect,
        startAngle,
        sweepAngle,
        false,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeWidth
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  @override
  bool shouldRepaint(_ScoreRingPainter old) =>
      old.progress != progress || old.color != color || old.isZenith != isZenith;
}

class _BentoMetricCell extends StatelessWidget {
  final String label;
  final String value;
  final String? unit;
  final double progress;
  final Color color;
  final IconData icon;
  final String? badge;
  final bool isZenith;

  const _BentoMetricCell({
    required this.label,
    required this.value,
    this.unit,
    required this.progress,
    required this.color,
    required this.icon,
    this.badge,
    this.isZenith = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isZenith ? Colors.white.withOpacity(0.06) : context.nc.inputFill,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isZenith ? Colors.white.withOpacity(0.12) : context.nc.cardBorder,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(icon, size: 14, color: color.withOpacity(0.8)),
              if (badge != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    badge!,
                    style: TextStyle(fontSize: 8, fontWeight: FontWeight.w900, color: color),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                value,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: isZenith ? Colors.white : context.nc.textPrimary,
                  letterSpacing: -0.5,
                ),
              ),
              if (unit != null) ...[
                const SizedBox(width: 3),
                Text(
                  unit!,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: isZenith ? Colors.white.withOpacity(0.4) : context.nc.textTertiary,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 4),
          Text(
            label.toUpperCase(),
            style: TextStyle(
              fontSize: 8,
              fontWeight: FontWeight.w800,
              color: isZenith ? Colors.white.withOpacity(0.3) : context.nc.textTertiary,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 7),
          // Bento progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: SizedBox(
              height: 3,
              child: Stack(
                children: [
                  Container(
                    color: isZenith
                        ? Colors.white.withOpacity(0.08)
                        : color.withOpacity(0.1),
                  ),
                  FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: progress.clamp(0.0, 1.0),
                    child: Container(
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricRingCell extends StatelessWidget {
  final String label;
  final String value;
  final double progress;
  final Color color;
  final IconData icon;
  final String? badge;
  final bool isZenith;

  final String? subtitle;

  const _MetricRingCell({
    required this.label,
    required this.value,
    required this.progress,
    required this.color,
    required this.icon,
    this.badge,
    this.isZenith = false,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 72,
          height: 72,
          child: Stack(
            alignment: Alignment.center,
            children: [
              CustomPaint(
                size: const Size(72, 72),
                painter: _LiquidGlassRingPainter(
                  progress: progress,
                  color: color,
                  isZenith: isZenith,
                ),
              ),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(icon, size: 18, color: color.withOpacity(isZenith ? 0.9 : 0.7)),
                    const SizedBox(height: 2),
                    Text(
                      value,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: isZenith ? Colors.white : color,
                        letterSpacing: -0.3,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Text(
          label.toUpperCase(),
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.w700,
            color: isZenith ? Colors.white.withOpacity(0.4) : context.nc.textTertiary,
            letterSpacing: 1.0,
          ),
        ),
        if (subtitle != null || badge != null) ...[
          const SizedBox(height: 4),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (subtitle != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: isZenith 
                        ? const Color(0xFFFBBF24).withOpacity(0.1) 
                        : const Color(0xFFFFF7ED),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: (isZenith ? const Color(0xFFFBBF24) : const Color(0xFFFDBA74)).withOpacity(0.15),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.auto_awesome, 
                        size: 7, 
                        color: isZenith ? const Color(0xFFFBBF24) : const Color(0xFFD97706)
                      ),
                      const SizedBox(width: 3),
                      Text(
                        subtitle!.toUpperCase(),
                        style: TextStyle(
                          fontSize: 7.5,
                          fontWeight: FontWeight.w900,
                          color: isZenith ? const Color(0xFFFBBF24) : const Color(0xFFD97706),
                          letterSpacing: 0.3,
                        ),
                      ),
                    ],
                  ),
                ),
              if (subtitle != null && badge != null) const SizedBox(width: 4),
              if (badge != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: color.withOpacity(isZenith ? 0.15 : 0.08),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    badge!,
                    style: TextStyle(
                      fontSize: 8,
                      fontWeight: FontWeight.w900,
                      color: color,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ],
    );
  }
}

class _LiquidGlassRingPainter extends CustomPainter {
  final double progress;
  final Color color;
  final bool isZenith;

  _LiquidGlassRingPainter({required this.progress, required this.color, this.isZenith = false});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - 10) / 2;
    const strokeWidth = 5.0;
    const startAngle = -math.pi / 2;
    final sweepAngle = 2 * math.pi * progress.clamp(0.0, 1.0);

    final rect = Rect.fromCircle(center: center, radius: radius);

    canvas.drawArc(
      rect,
      0,
      2 * math.pi,
      false,
      Paint()
        ..color = isZenith ? color.withOpacity(0.12) : color.withOpacity(0.08)
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round,
    );

    if (progress > 0) {
      canvas.drawArc(
        rect,
        startAngle,
        sweepAngle,
        false,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeWidth
          ..strokeCap = StrokeCap.round,
      );
    }
  }

  @override
  bool shouldRepaint(_LiquidGlassRingPainter old) =>
      old.progress != progress || old.color != color || old.isZenith != isZenith;
}

class _VitalChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final bool isZenith;

  const _VitalChip({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    this.isZenith = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: isZenith
            ? color.withOpacity(0.1)
            : color.withOpacity(0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isZenith
              ? color.withOpacity(0.2)
              : color.withOpacity(0.1),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 5),
          Text(
            '$label ',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w500,
              color: color.withOpacity(0.7),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: color,
              letterSpacing: -0.3,
            ),
          ),
        ],
      ),
    );
  }
}

/// Dynamic Health Aura Painter (Idea 8)
/// Creates a fluid, pulsating glow based on biometrics
class _HealthAuraPainter extends CustomPainter {
  final HealthAura aura;
  final double pulse;
  final bool isZenith;

  _HealthAuraPainter({
    required this.aura,
    required this.pulse,
    required this.isZenith,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Idea 8 Polish: Center-Right focal point for a more balanced "Mist" effect
    final center = Offset(size.width * 0.6, size.height * 0.5);
    final paint = Paint()..maskFilter = const MaskFilter.blur(BlurStyle.normal, 80);

    // Dynamic scale based on pulse animation
    final scale = 0.8 + (pulse * 0.25);
    final opacity = isZenith ? 0.15 : 0.08;

    for (int i = 0; i < aura.colors.length; i++) {
      final color = aura.colors[i];
      // Layers have different radii for a "volumetric" feel
      final radius = (size.width * 0.45) * (1.2 - (i * 0.3)) * scale;
      
      paint.color = color.withOpacity(opacity / (i + 1));
      
      // Shift center slightly for each layer using the pulse to create a "fluid" drift
      final offsetCenter = Offset(
        center.dx + math.sin(pulse * math.pi * 2 + (i * 1.5)) * 25,
        center.dy + math.cos(pulse * math.pi * 2 + (i * 1.5)) * 25,
      );

      canvas.drawCircle(offsetCenter, radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _HealthAuraPainter oldDelegate) => true;
}
