import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../config/theme.dart';
import '../../../models/food_analysis.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Utilities
// ─────────────────────────────────────────────────────────────────────────────

Color getScoreColor(int score) {
  if (score >= 80) return BrandColors.emerald500;
  if (score >= 50) return BrandColors.amber500;
  return BrandColors.red500;
}

Color _impactColor(String impact) {
  switch (impact.toLowerCase()) {
    case 'positive': return BrandColors.emerald500;
    case 'negative': return BrandColors.red500;
    default: return BrandColors.amber500;
  }
}

IconData _impactIcon(String impact) {
  switch (impact.toLowerCase()) {
    case 'positive': return LucideIcons.trendingUp;
    case 'negative': return LucideIcons.trendingDown;
    default: return LucideIcons.minus;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Section Title
// ─────────────────────────────────────────────────────────────────────────────

class LensSectionTitle extends StatelessWidget {
  final String title;
  final IconData? icon;
  const LensSectionTitle({super.key, required this.title, this.icon});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Row(
        children: [
          if (icon != null) ...[
            Icon(icon, color: Colors.white38, size: 14),
            const SizedBox(width: 8),
          ],
          Text(
            title,
            style: const TextStyle(
              color: Colors.white54,
              fontSize: 11,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Score Ring (animated)
// ─────────────────────────────────────────────────────────────────────────────

class LensScoreRing extends StatefulWidget {
  final int score;
  final Color? textColor;
  const LensScoreRing({super.key, required this.score, this.textColor});

  @override
  State<LensScoreRing> createState() => _LensScoreRingState();
}

class _LensScoreRingState extends State<LensScoreRing> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _ringAnimation;
  late Animation<int> _scoreAnimation;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1500));
    
    _ringAnimation = Tween<double>(begin: 0.0, end: widget.score / 100.0).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic),
    );

    _scoreAnimation = IntTween(begin: 0, end: widget.score).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic),
    );

    _ctrl.forward();
  }

  @override
  void didUpdateWidget(LensScoreRing oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.score != widget.score) {
      // Re-animate to the new refined score
      _ringAnimation = Tween<double>(begin: _ringAnimation.value, end: widget.score / 100.0).animate(
        CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic),
      );
      _scoreAnimation = IntTween(begin: _scoreAnimation.value, end: widget.score).animate(
        CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic),
      );
      _ctrl.reset();
      _ctrl.forward();
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scoreColor = getScoreColor(widget.score);
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (ctx, _) => Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: 130,
            height: 130,
            child: CustomPaint(
              painter: _GlowRingPainter(
                value: _ringAnimation.value,
                color: scoreColor,
              ),
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                "${_scoreAnimation.value}",
                style: TextStyle(
                  fontSize: 42,
                  fontWeight: FontWeight.bold,
                  color: widget.textColor ?? scoreColor,
                ),
              ),
              Text(
                "/ 100",
                style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 12),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _GlowRingPainter extends CustomPainter {
  final double value;
  final Color color;
  _GlowRingPainter({required this.value, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 8;
    const strokeWidth = 10.0;

    // Background ring
    final bgPaint = Paint()
      ..color = Colors.white.withOpacity(0.08)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(center, radius, bgPaint);

    // Glow layer
    final glowPaint = Paint()
      ..color = color.withOpacity(0.25)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth + 8
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      2 * math.pi * value,
      false,
      glowPaint,
    );

    // Main arc
    final arcPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      2 * math.pi * value,
      false,
      arcPaint,
    );
  }

  @override
  bool shouldRepaint(_GlowRingPainter old) => old.value != value;
}

// ─────────────────────────────────────────────────────────────────────────────
// Macro Bar
// ─────────────────────────────────────────────────────────────────────────────

class LensMacroBar extends StatefulWidget {
  final String label;
  final int amount;
  final Color color;
  final Color? textColor;

  const LensMacroBar({
    super.key,
    required this.label,
    required this.amount,
    required this.color,
    this.textColor,
  });

  @override
  State<LensMacroBar> createState() => _LensMacroBarState();
}

class _LensMacroBarState extends State<LensMacroBar> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));
    _animation = Tween<double>(
      begin: 0,
      end: (widget.amount / 100).clamp(0.0, 1.0),
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));
    Future.delayed(const Duration(milliseconds: 200), () {
      if (mounted) _ctrl.forward();
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final textColor = widget.textColor ?? Colors.white;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(widget.label, style: TextStyle(color: textColor.withOpacity(0.8), fontSize: 13)),
              Text("${widget.amount}g", style: TextStyle(color: textColor, fontSize: 13, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 6),
          AnimatedBuilder(
            animation: _animation,
            builder: (_, __) => ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: _animation.value,
                backgroundColor: Colors.white.withOpacity(0.08),
                color: widget.color,
                minHeight: 6,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Bio Impact Card
// ─────────────────────────────────────────────────────────────────────────────

class LensBioImpactCard extends StatelessWidget {
  final BioImpactItem item;
  const LensBioImpactCard({super.key, required this.item});

  @override
  Widget build(BuildContext context) {
    final color = _impactColor(item.impact);
    final icon = _impactIcon(item.impact);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 2), // Align icon with first line of text
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 14),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (item.category.isNotEmpty) ...[
                  Text(
                    item.category.toUpperCase(),
                    style: TextStyle(
                      color: color,
                      fontSize: 9,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.0,
                    ),
                  ),
                  const SizedBox(height: 4),
                ],
                Text(
                  item.title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  item.description,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.55),
                    fontSize: 12,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Toxin Item
// ─────────────────────────────────────────────────────────────────────────────

class LensToxinItem extends StatelessWidget {
  final Toxin toxin;
  const LensToxinItem({super.key, required this.toxin});

  Color _severityColor(String severity) {
    switch (severity.toLowerCase()) {
      case 'high': return BrandColors.red500;
      case 'medium': return BrandColors.orange500;
      default: return BrandColors.amber500;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _severityColor(toxin.severity);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.07),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              toxin.severity.toUpperCase(),
              style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 0.5),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(toxin.name, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 2),
                Text(toxin.details, style: TextStyle(color: Colors.white.withOpacity(0.55), fontSize: 11, height: 1.4)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Metabolic Card
// ─────────────────────────────────────────────────────────────────────────────

class LensMetabolicCard extends StatelessWidget {
  final String label;
  final String value;
  final Color? textColor;

  const LensMetabolicCard({
    super.key, 
    required this.label, 
    required this.value,
    this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveColor = textColor ?? Colors.white;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: effectiveColor.withOpacity(0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: effectiveColor.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label, 
            style: TextStyle(
              color: effectiveColor.withOpacity(0.45), 
              fontSize: 11,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value, 
            style: TextStyle(
              color: effectiveColor, 
              fontSize: 15, 
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ── V2 NEW WIDGETS ──────────────────────────────────────────────────────────
// ─────────────────────────────────────────────────────────────────────────────

/// UPF Processing Level Widget
class LensUPFCard extends StatelessWidget {
  final UPFAnalysis upf;
  const LensUPFCard({super.key, required this.upf});

  Color _levelColor() {
    switch (upf.score) {
      case <= 2: return BrandColors.emerald500;
      case <= 5: return BrandColors.amber500;
      default: return BrandColors.red500;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (upf.level == 'Unknown') return const SizedBox.shrink();
    final color = _levelColor();
    final barValue = (upf.score / 10.0).clamp(0.0, 1.0);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(LucideIcons.testTube2, color: color, size: 14),
                  const SizedBox(width: 8),
                  Text("Processing Level", style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 13)),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  upf.level,
                  style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: barValue,
              backgroundColor: Colors.white.withOpacity(0.08),
              valueColor: AlwaysStoppedAnimation<Color>(color),
              minHeight: 6,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            upf.verdict,
            style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 12, height: 1.4),
          ),
          if (upf.additives.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: upf.additives.map((additive) => Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: BrandColors.red500.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: BrandColors.red500.withOpacity(0.2)),
                ),
                child: Text(
                  additive,
                  style: const TextStyle(color: BrandColors.red500, fontSize: 10, fontWeight: FontWeight.w500),
                ),
              )).toList(),
            ),
          ],
        ],
      ),
    );
  }
}

/// Circadian Clock Match Widget
class LensCircadianCard extends StatelessWidget {
  final CircadianMatch circadian;
  const LensCircadianCard({super.key, required this.circadian});

  Color _matchColor() {
    switch (circadian.match.toLowerCase()) {
      case 'excellent': return BrandColors.emerald500;
      case 'good': return const Color(0xFF22D3EE);
      case 'fair': return BrandColors.amber500;
      default: return BrandColors.red500;
    }
  }

  IconData _timeIcon() {
    switch (circadian.mealTime.toLowerCase()) {
      case 'morning': return LucideIcons.sunrise;
      case 'afternoon': return LucideIcons.sun;
      case 'evening': return LucideIcons.sunset;
      default: return LucideIcons.moon;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (circadian.match == 'Unknown') return const SizedBox.shrink();
    final color = _matchColor();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF1E1B4B).withOpacity(0.6),
            color.withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(_timeIcon(), color: color, size: 16),
              const SizedBox(width: 8),
              Text(
                "${circadian.mealTime} • Circadian Match",
                style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 13),
              ),
              const Spacer(),
              Text(
                "${circadian.matchScore}%",
                style: TextStyle(color: color, fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: circadian.matchScore / 100,
              backgroundColor: Colors.white.withOpacity(0.08),
              valueColor: AlwaysStoppedAnimation<Color>(color),
              minHeight: 5,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            circadian.reason,
            style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 12, height: 1.4),
          ),
          if (circadian.recommendation.isNotEmpty) ...[
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(LucideIcons.lightbulb, color: BrandColors.amber500, size: 13),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    circadian.recommendation,
                    style: TextStyle(color: BrandColors.amber500.withOpacity(0.9), fontSize: 11, height: 1.4),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// Bio-Hack "Optimization Tip" Card
class LensBioHackCard extends StatelessWidget {
  final BioHack bioHack;
  const LensBioHackCard({super.key, required this.bioHack});

  @override
  Widget build(BuildContext context) {
    if (bioHack.tip.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF059669).withOpacity(0.12),
            const Color(0xFF065F46).withOpacity(0.08),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: BrandColors.emerald500.withOpacity(0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: BrandColors.emerald500.withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(LucideIcons.zap, color: BrandColors.emerald500, size: 14),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  "BIO-HACK THIS MEAL",
                  style: TextStyle(
                    color: BrandColors.emerald500,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
              if (bioHack.potencyPercent > 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: BrandColors.emerald500.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    "+${bioHack.potencyPercent}%",
                    style: const TextStyle(
                      color: BrandColors.emerald500,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            bioHack.tip,
            style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600, height: 1.4),
          ),
          const SizedBox(height: 8),
          Text(
            bioHack.mechanism,
            style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 12, height: 1.4),
          ),
          if (bioHack.timing.isNotEmpty) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Icon(LucideIcons.clock, color: Colors.white.withOpacity(0.4), size: 12),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    bioHack.timing,
                    style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 11, fontStyle: FontStyle.italic),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// Hormonal Impact — Big Three Radar
class LensHormonalCard extends StatelessWidget {
  final HormonalImpact hormonal;
  const LensHormonalCard({super.key, required this.hormonal});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _HormoneRow(hormone: hormonal.insulin, icon: LucideIcons.activity),
        const SizedBox(height: 10),
        _HormoneRow(hormone: hormonal.leptin, icon: LucideIcons.shield),
        const SizedBox(height: 10),
        _HormoneRow(hormone: hormonal.ghrelin, icon: LucideIcons.flame),
      ],
    );
  }
}

class _HormoneRow extends StatelessWidget {
  final HormoneReading hormone;
  final IconData icon;
  const _HormoneRow({required this.hormone, required this.icon});

  @override
  Widget build(BuildContext context) {
    final color = _impactColor(hormone.impact);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 14),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      hormone.name,
                      style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        hormone.response,
                        style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                if (hormone.detail.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    hormone.detail,
                    style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 11, height: 1.4),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Bioavailability Card
class LensBioavailabilityCard extends StatelessWidget {
  final Bioavailability bioavailability;
  const LensBioavailabilityCard({super.key, required this.bioavailability});

  @override
  Widget build(BuildContext context) {
    if (bioavailability.absorptionScore == 0 && bioavailability.tips.isEmpty) return const SizedBox.shrink();

    final score = bioavailability.absorptionScore;
    final color = getScoreColor(score);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Absorption score bar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.04),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withOpacity(0.08)),
          ),
          child: Row(
            children: [
              Icon(LucideIcons.microscope, color: color, size: 16),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          "Nutrient Absorption",
                          style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 12),
                        ),
                        Text(
                          "$score%",
                          style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: score / 100,
                        backgroundColor: Colors.white.withOpacity(0.08),
                        valueColor: AlwaysStoppedAnimation<Color>(color),
                        minHeight: 5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        if (bioavailability.tips.isNotEmpty) ...[
          const SizedBox(height: 8),
          ...bioavailability.tips.map((tip) => _BioavailabilityTipRow(tip: tip)),
        ],
      ],
    );
  }
}

class _BioavailabilityTipRow extends StatelessWidget {
  final BioavailabilityTip tip;
  const _BioavailabilityTipRow({required this.tip});

  @override
  Widget build(BuildContext context) {
    final color = tip.impact == 'positive' ? BrandColors.emerald500 : BrandColors.red500;
    final icon = tip.impact == 'positive' ? LucideIcons.plus : LucideIcons.minus;

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 1),
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(color: color.withOpacity(0.15), shape: BoxShape.circle),
            child: Icon(icon, color: color, size: 10),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        tip.title,
                        style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.07),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        tip.type,
                        style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 9),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  tip.description,
                  style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 11, height: 1.4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Longevity Impact Card
class LensLongevityCard extends StatelessWidget {
  final LongevityImpact longevity;
  const LensLongevityCard({super.key, required this.longevity});

  Color _effectColor(String effect) {
    final e = effect.toLowerCase();
    if (e.contains('activating') || e.contains('anti') || e.contains('inhibiting')) return BrandColors.emerald500;
    if (e.contains('suppressing') || e.contains('pro')) return BrandColors.red500;
    return Colors.white38;
  }

  @override
  Widget build(BuildContext context) {
    if (longevity.longevityScore == 0) return const SizedBox.shrink();

    final credit = longevity.longevityCredit;
    final creditColor = credit >= 0 ? BrandColors.emerald500 : BrandColors.red500;
    final creditPrefix = credit >= 0 ? "+" : "";

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF4F46E5).withOpacity(0.12),
            const Color(0xFF7C3AED).withOpacity(0.06),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF6366F1).withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: const Color(0xFF6366F1).withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(LucideIcons.dna, color: Color(0xFF818CF8), size: 14),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  "Longevity Score",
                  style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 13),
                ),
              ),
              Text(
                "$creditPrefix$credit pts",
                style: TextStyle(
                  color: creditColor,
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Score bar
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: longevity.longevityScore / 100,
              backgroundColor: Colors.white.withOpacity(0.08),
              color: const Color(0xFF6366F1),
              minHeight: 5,
            ),
          ),
          const SizedBox(height: 12),

          // Three pathway chips
          Row(
            children: [
              _PathwayChip(label: "Sirtuin", value: longevity.sirtuinEffect, color: _effectColor(longevity.sirtuinEffect)),
              const SizedBox(width: 6),
              _PathwayChip(label: "mTOR", value: longevity.mTorEffect, color: _effectColor(longevity.mTorEffect)),
              const SizedBox(width: 6),
              _PathwayChip(label: "Inflam.", value: longevity.inflammationEffect.split('-').first, color: _effectColor(longevity.inflammationEffect)),
            ],
          ),
          const SizedBox(height: 12),

          // Summary
          Text(
            longevity.longevitySummary,
            style: TextStyle(color: Colors.white.withOpacity(0.65), fontSize: 12, height: 1.5),
          ),
        ],
      ),
    );
  }
}

class _PathwayChip extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _PathwayChip({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withOpacity(0.25)),
        ),
        child: Column(
          children: [
            Text(label, style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 9)),
            const SizedBox(height: 2),
            Text(
              value,
              style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

/// Predictive Metabolic Curve Animation
class LensMetabolicCurveWidget extends StatefulWidget {
  final String energyCurve;
  const LensMetabolicCurveWidget({super.key, required this.energyCurve});

  @override
  State<LensMetabolicCurveWidget> createState() => _LensMetabolicCurveWidgetState();
}

class _LensMetabolicCurveWidgetState extends State<LensMetabolicCurveWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1800));
    _animation = CurvedAnimation(parent: _ctrl, curve: Curves.easeInOutCubic);
    Future.delayed(const Duration(milliseconds: 400), () {
      if (mounted) _ctrl.forward();
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  List<Offset> _getPoints(double progress, Size size) {
    final curveType = widget.energyCurve.toLowerCase();
    final List<Offset> points = [];
    final steps = 60;

    for (int i = 0; i <= steps; i++) {
      final t = i / steps;
      if (t > progress) break;
      final x = t * size.width;
      double y;

      if (curveType.contains('spike')) {
        // Sharp rise then crash
        if (t < 0.3) {
          y = 1 - (t / 0.3); // rise
        } else if (t < 0.5) {
          y = (t - 0.3) / 0.2; // crash to 0
        } else {
          y = 0.1 + (t - 0.5) * 0.3; // slow recovery
        }
      } else if (curveType.contains('sustained')) {
        // Smooth, steady bell
        y = 1 - math.pow(2 * t - 1, 2).toDouble();
      } else {
        // Crash curve — initial dip
        y = math.pow(math.sin(t * math.pi * 0.8), 0.7).toDouble();
      }

      // Invert y since Flutter canvas y is inverted
      points.add(Offset(x, size.height * (1 - (y * 0.72 + 0.08))));
    }

    return points;
  }

  @override
  Widget build(BuildContext context) {
    final curveType = widget.energyCurve.toLowerCase();
    Color lineColor;
    String label;

    if (curveType.contains('spike')) {
      lineColor = BrandColors.red500;
      label = "Glucose Spike";
    } else if (curveType.contains('sustained')) {
      lineColor = BrandColors.emerald500;
      label = "Sustained Energy";
    } else {
      lineColor = BrandColors.amber500;
      label = "Energy Crash";
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              "6-Hour Energy Simulation",
              style: TextStyle(color: Colors.white.withOpacity(0.55), fontSize: 11),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: lineColor.withOpacity(0.12),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(label, style: TextStyle(color: lineColor, fontSize: 10, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
        const SizedBox(height: 10),
        AnimatedBuilder(
          animation: _animation,
          builder: (_, __) => SizedBox(
            height: 80,
            width: double.infinity,
            child: CustomPaint(
              painter: _MetabolicCurvePainter(
                progress: _animation.value,
                energyCurveType: widget.energyCurve,
                lineColor: lineColor,
                getPointsFn: _getPoints,
              ),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text("Now", style: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 9)),
            Text("3h", style: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 9)),
            Text("+6h", style: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 9)),
          ],
        ),
      ],
    );
  }
}

class _MetabolicCurvePainter extends CustomPainter {
  final double progress;
  final String energyCurveType;
  final Color lineColor;
  final List<Offset> Function(double progress, Size size) getPointsFn;

  _MetabolicCurvePainter({
    required this.progress,
    required this.energyCurveType,
    required this.lineColor,
    required this.getPointsFn,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0) return;
    final points = getPointsFn(progress, size);
    if (points.length < 2) return;

    // Glow line
    final glowPaint = Paint()
      ..color = lineColor.withOpacity(0.2)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);

    // Main line
    final linePaint = Paint()
      ..color = lineColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    // Fill gradient
    final fillPath = Path()..moveTo(points.first.dx, size.height);
    for (final p in points) {
      fillPath.lineTo(p.dx, p.dy);
    }
    fillPath.lineTo(points.last.dx, size.height);
    fillPath.close();

    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [lineColor.withOpacity(0.2), lineColor.withOpacity(0.0)],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    canvas.drawPath(fillPath, fillPaint);

    final curvePath = Path()..moveTo(points.first.dx, points.first.dy);
    for (int i = 1; i < points.length; i++) {
      final prev = points[i - 1];
      final curr = points[i];
      final midX = (prev.dx + curr.dx) / 2;
      curvePath.cubicTo(midX, prev.dy, midX, curr.dy, curr.dx, curr.dy);
    }

    canvas.drawPath(curvePath, glowPaint);
    canvas.drawPath(curvePath, linePaint);

    // Dot at current position
    final last = points.last;
    final dotPaint = Paint()..color = lineColor;
    final dotGlowPaint = Paint()
      ..color = lineColor.withOpacity(0.3)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
    canvas.drawCircle(last, 6, dotGlowPaint);
    canvas.drawCircle(last, 4, dotPaint);
  }

  @override
  bool shouldRepaint(_MetabolicCurvePainter old) => old.progress != progress;
}

/// Wearable Bio-Data Integration Banner
class LensBioDataBanner extends StatelessWidget {
  final int recoveryScore;
  final int stressScore;
  final double sleepHours;
  final double? hrv;
  const LensBioDataBanner({
    super.key,
    required this.recoveryScore,
    required this.stressScore,
    required this.sleepHours,
    this.hrv,
  });

  @override
  Widget build(BuildContext context) {
    final bool hasRealData = recoveryScore > 0 || stressScore > 0 || sleepHours > 0;
    if (!hasRealData) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF0EA5E9).withOpacity(0.12),
            const Color(0xFF6366F1).withOpacity(0.06),
          ],
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF0EA5E9).withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(LucideIcons.watch, color: Color(0xFF38BDF8), size: 13),
              const SizedBox(width: 7),
              Text(
                "PERSONALIZED FOR YOU TODAY",
                style: TextStyle(
                  color: const Color(0xFF38BDF8).withOpacity(0.9),
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.8,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              if (recoveryScore > 0)
                _BioChip(label: "Recovery", value: "$recoveryScore%", color: _recoveryColor(recoveryScore)),
              if (stressScore > 0) ...[
                const SizedBox(width: 8),
                _BioChip(label: "Stress", value: "$stressScore/100", color: _stressColor(stressScore)),
              ],
              if (sleepHours > 0) ...[
                const SizedBox(width: 8),
                _BioChip(label: "Sleep", value: "${sleepHours.toStringAsFixed(1)}h", color: const Color(0xFF818CF8)),
              ],
              if (hrv != null) ...[
                const SizedBox(width: 8),
                _BioChip(label: "HRV", value: "${hrv!.round()}", color: BrandColors.emerald500),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Color _recoveryColor(int score) {
    if (score >= 70) return BrandColors.emerald500;
    if (score >= 40) return BrandColors.amber500;
    return BrandColors.red500;
  }

  Color _stressColor(int score) {
    if (score >= 60) return BrandColors.red500;
    if (score >= 35) return BrandColors.amber500;
    return BrandColors.emerald500;
  }
}

class _BioChip extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _BioChip({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Column(
        children: [
          Text(value, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold)),
          Text(label, style: TextStyle(color: color.withOpacity(0.6), fontSize: 9)),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Digital Twin — Holographic Medical UI (Siri-Fusion)
// ─────────────────────────────────────────────────────────────────────────────

class LensDigitalTwin extends StatefulWidget {
  final List<BioImpactItem> impacts;
  const LensDigitalTwin({super.key, required this.impacts});

  @override
  State<LensDigitalTwin> createState() => _LensDigitalTwinState();
}

class _LensDigitalTwinState extends State<LensDigitalTwin> with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    BioImpactItem? find(String pattern) {
      for (final i in widget.impacts) {
        if (i.category.toLowerCase().contains(pattern) || i.title.toLowerCase().contains(pattern)) {
          return i;
        }
      }
      return null;
    }

    final brain = find('mental') ?? find('focus');
    final gut = find('gut') ?? find('microbiome');
    final metabolic = find('hormonal') ?? find('insulin');

    // Build nodes list for the row layout
    final nodes = <_NodeData>[];
    if (brain != null) nodes.add(_NodeData('Neural', brain.impact, LucideIcons.brain, const Color(0xFFA855F7)));
    if (metabolic != null) nodes.add(_NodeData('Metabolic', metabolic.impact, LucideIcons.heartPulse, const Color(0xFFF59E0B)));
    if (gut != null) nodes.add(_NodeData('Gut', gut.impact, LucideIcons.leaf, const Color(0xFF22D3EE)));

    if (nodes.isEmpty) return const SizedBox.shrink();

    return AnimatedBuilder(
      animation: _pulseAnim,
      builder: (context, child) {
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
          decoration: BoxDecoration(
            color: const Color(0xFF0A0A0F),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white.withOpacity(0.06)),
          ),
          child: Stack(
            children: [
              // ── Aurora Blobs (Siri-style) ─────────────────────────────
              Positioned(
                top: -20, right: -10,
                child: Container(
                  width: 100, height: 100,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(colors: [
                      const Color(0xFFF59E0B).withOpacity(0.08 * _pulseAnim.value),
                      Colors.transparent,
                    ]),
                  ),
                ),
              ),
              Positioned(
                bottom: -15, left: -10,
                child: Container(
                  width: 90, height: 90,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(colors: [
                      const Color(0xFFA855F7).withOpacity(0.07 * _pulseAnim.value),
                      Colors.transparent,
                    ]),
                  ),
                ),
              ),
              Positioned(
                top: 20, left: 30,
                child: Container(
                  width: 70, height: 70,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(colors: [
                      const Color(0xFF22D3EE).withOpacity(0.06 * _pulseAnim.value),
                      Colors.transparent,
                    ]),
                  ),
                ),
              ),

              // ── Main Content ─────────────────────────────────────────
              Column(
                children: [
                  Text(
                    "SYSTEMIC BIO-RESPONSE",
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.25),
                      fontSize: 10,
                      letterSpacing: 2.0,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 20),

                  // ── Node Row ──────────────────────────────────────────
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: nodes.map((n) => _HoloNode(
                      label: n.label,
                      impact: n.impact,
                      icon: n.icon,
                      baseColor: n.baseColor,
                      pulseValue: _pulseAnim.value,
                    )).toList(),
                  ),

                  const SizedBox(height: 16),

                  // ── Scan Line ─────────────────────────────────────────
                  Container(
                    height: 1,
                    margin: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.transparent,
                          const Color(0xFF22D3EE).withOpacity(0.15 * _pulseAnim.value),
                          const Color(0xFFA855F7).withOpacity(0.12 * _pulseAnim.value),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    "Predictive signal transduction analysis",
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.18),
                      fontSize: 9,
                      fontStyle: FontStyle.italic,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _NodeData {
  final String label;
  final String impact;
  final IconData icon;
  final Color baseColor;
  _NodeData(this.label, this.impact, this.icon, this.baseColor);
}

class _HoloNode extends StatelessWidget {
  final String label;
  final String impact;
  final IconData icon;
  final Color baseColor;
  final double pulseValue;

  const _HoloNode({
    required this.label,
    required this.impact,
    required this.icon,
    required this.baseColor,
    required this.pulseValue,
  });

  @override
  Widget build(BuildContext context) {
    final impactColor = _impactColor(impact);
    // Mix: base glow color with the impact status color
    final glowColor = Color.lerp(baseColor, impactColor, 0.5)!;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Outer glow ring
        Container(
          width: 56, height: 56,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: glowColor.withOpacity(0.2 + 0.15 * pulseValue), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: glowColor.withOpacity(0.12 * pulseValue),
                blurRadius: 16,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Center(
            // Inner icon circle
            child: Container(
              width: 38, height: 38,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: glowColor.withOpacity(0.1),
                border: Border.all(color: glowColor.withOpacity(0.15), width: 1),
              ),
              child: Icon(icon, color: glowColor.withOpacity(0.7 + 0.3 * pulseValue), size: 18),
            ),
          ),
        ),
        const SizedBox(height: 8),
        // Glassmorphic label
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.04),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: Colors.white.withOpacity(0.06)),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: glowColor.withOpacity(0.8),
              fontSize: 9,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
            ),
          ),
        ),
        const SizedBox(height: 4),
        // Impact status dot
        Container(
          width: 6, height: 6,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: impactColor,
            boxShadow: [
              BoxShadow(color: impactColor.withOpacity(0.4), blurRadius: 4),
            ],
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Intelligence Insight Card
// ─────────────────────────────────────────────────────────────────────────────

class LensIntelligenceInsight extends StatefulWidget {
  final String insight;
  const LensIntelligenceInsight({super.key, required this.insight});

  @override
  State<LensIntelligenceInsight> createState() => _LensIntelligenceInsightState();
}

class _LensIntelligenceInsightState extends State<LensIntelligenceInsight> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    if (widget.insight.isEmpty) return const SizedBox.shrink();

    return GestureDetector(
      onTap: () => setState(() => _isExpanded = !_isExpanded),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF0A0A0F),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
          boxShadow: [
            BoxShadow(
              color: BrandColors.emerald500.withValues(alpha: 0.03),
              blurRadius: 20,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "INTELLIGENCE INSIGHT",
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.3),
                    fontSize: 9,
                    letterSpacing: 2.0,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Icon(
                  _isExpanded ? LucideIcons.chevronUp : LucideIcons.chevronDown,
                  color: Colors.white.withValues(alpha: 0.2),
                  size: 14,
                ),
              ],
            ),
            const SizedBox(height: 12),
            AnimatedSize(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
              child: Text(
                widget.insight,
                maxLines: _isExpanded ? null : 2,
                overflow: _isExpanded ? TextOverflow.visible : TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  height: 1.5,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
