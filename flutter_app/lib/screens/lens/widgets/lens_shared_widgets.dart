import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../config/theme.dart';
import '../../../models/food_analysis.dart';
import '../../../widgets/tc025/tc025_widgets.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Utilities
// ─────────────────────────────────────────────────────────────────────────────

/// Score colour without a [BuildContext] (kept for API compatibility). Uses
/// the shared tint families, which read on both light and dark surfaces.
/// Widgets with a context use [_scoreColor] (semantic status tokens) instead.
Color getScoreColor(int score) {
  if (score >= 80) return ZyndioTint.green.colors.last;
  if (score >= 50) return ZyndioTint.amber.colors.last;
  return ZyndioTint.rose.colors.last;
}

Color _scoreColor(ZyndioColors c, int score) {
  if (score >= 80) return c.statusSuccess;
  if (score >= 50) return c.statusWarning;
  return c.statusCritical;
}

Color _impactColor(ZyndioColors c, String impact) {
  switch (impact.toLowerCase()) {
    case 'positive':
      return c.statusSuccess;
    case 'negative':
      return c.statusCritical;
    default:
      return c.statusWarning;
  }
}

ZyndioPillTone _impactTone(String impact) {
  switch (impact.toLowerCase()) {
    case 'positive':
      return ZyndioPillTone.success;
    case 'negative':
      return ZyndioPillTone.critical;
    default:
      return ZyndioPillTone.warning;
  }
}

IconData _impactIcon(String impact) {
  switch (impact.toLowerCase()) {
    case 'positive':
      return LucideIcons.trendingUp;
    case 'negative':
      return LucideIcons.trendingDown;
    default:
      return LucideIcons.minus;
  }
}

TextStyle _style(
  double size,
  Color color, {
  FontWeight weight = FontWeight.w400,
  double? height,
  double? letterSpacing,
  FontStyle? fontStyle,
}) =>
    TextStyle(
      fontFamily: ZyndioType.family,
      fontSize: size,
      fontWeight: weight,
      height: height,
      letterSpacing: letterSpacing,
      fontStyle: fontStyle,
      color: color,
    );

/// Thin rounded progress track used by every Lens meter.
class _Meter extends StatelessWidget {
  const _Meter({required this.value, required this.color, this.height = 6});
  final double value;
  final Color color;
  final double height;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: LinearProgressIndicator(
        value: value.clamp(0.0, 1.0),
        backgroundColor: context.zc.bgSunken,
        valueColor: AlwaysStoppedAnimation<Color>(color),
        minHeight: height,
      ),
    );
  }
}

/// Small round icon badge on a soft tint of [color].
class _IconBadge extends StatelessWidget {
  const _IconBadge({required this.icon, required this.color, this.size = 30});
  final IconData icon;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        shape: BoxShape.circle,
      ),
      child: Icon(icon, color: color, size: size * 0.5),
    );
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
    final c = context.zc;
    return Align(
      alignment: Alignment.centerLeft,
      child: Row(
        children: [
          if (icon != null) ...[
            Icon(icon, color: c.textTertiary, size: 14),
            const SizedBox(width: 8),
          ],
          Expanded(
            child: Semantics(
              header: true,
              child: Text(
                title,
                style: _style(12, c.textTertiary,
                    weight: FontWeight.w700, letterSpacing: 1.3),
              ),
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
    final c = context.zc;
    final scoreColor = _scoreColor(c, widget.score);
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (ctx, _) => SizedBox(
        width: 130,
        height: 130,
        child: Stack(
          fit: StackFit.expand,
          children: [
            CustomPaint(
              painter: _GlowRingPainter(
                value: _ringAnimation.value,
                color: scoreColor,
                track: c.bgSunken,
              ),
            ),
            // FittedBox keeps the number inside the ring at any text size.
            Padding(
              padding: const EdgeInsets.all(26),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      "${_scoreAnimation.value}",
                      style: _style(42, widget.textColor ?? scoreColor,
                              weight: FontWeight.w700, height: 1.1)
                          .copyWith(fontFeatures: ZyndioType.tabular),
                    ),
                    Text(
                      "/ 100",
                      style: _style(12, c.textTertiary),
                    ),
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

class _GlowRingPainter extends CustomPainter {
  final double value;
  final Color color;
  final Color track;
  _GlowRingPainter({required this.value, required this.color, required this.track});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 8;
    const strokeWidth = 10.0;

    // Background ring
    final bgPaint = Paint()
      ..color = track
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(center, radius, bgPaint);

    // Glow layer
    final glowPaint = Paint()
      ..color = color.withValues(alpha: 0.22)
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
  bool shouldRepaint(_GlowRingPainter old) =>
      old.value != value || old.color != color || old.track != track;
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
    final c = context.zc;
    final labelColor = widget.textColor?.withValues(alpha: 0.8) ?? c.textSecondary;
    final valueColor = widget.textColor ?? c.textPrimary;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(color: widget.color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(widget.label, style: _style(14, labelColor)),
              ),
              const SizedBox(width: 8),
              Text(
                "${widget.amount}g",
                style: _style(14, valueColor, weight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 6),
          AnimatedBuilder(
            animation: _animation,
            builder: (_, __) => _Meter(value: _animation.value, color: widget.color),
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
    final c = context.zc;
    final color = _impactColor(c, item.impact);
    final icon = _impactIcon(item.impact);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: zyndioCard(context, radius: 18),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _IconBadge(icon: icon, color: color),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (item.category.isNotEmpty) ...[
                  Text(
                    item.category.toUpperCase(),
                    style: _style(11, color, weight: FontWeight.w700, letterSpacing: 1.0),
                  ),
                  const SizedBox(height: 4),
                ],
                Text(
                  item.title,
                  style: _style(15, c.textPrimary, weight: FontWeight.w600, height: 20 / 15),
                ),
                const SizedBox(height: 4),
                Text(
                  item.description,
                  style: _style(13, c.textSecondary, height: 1.45),
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

  ZyndioPillTone _severityTone(String severity) {
    switch (severity.toLowerCase()) {
      case 'high':
        return ZyndioPillTone.critical;
      case 'medium':
        return ZyndioPillTone.warning;
      default:
        return ZyndioPillTone.neutral;
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.zc;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: zyndioCard(context, radius: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  toxin.name,
                  style: _style(14, c.textPrimary, weight: FontWeight.w600),
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: ZyndioPill(
                  toxin.severity.toUpperCase(),
                  tone: _severityTone(toxin.severity),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(toxin.details, style: _style(13, c.textSecondary, height: 1.4)),
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
    final c = context.zc;
    final custom = textColor;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: custom?.withValues(alpha: 0.06) ?? c.bgSunken,
        borderRadius: BorderRadius.circular(14),
        border: custom == null ? null : Border.all(color: custom.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: _style(12, custom?.withValues(alpha: 0.55) ?? c.textTertiary),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: _style(15, custom ?? c.textPrimary, weight: FontWeight.w700),
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

  (Color, ZyndioPillTone) _level(ZyndioColors c) {
    switch (upf.score) {
      case <= 2:
        return (c.statusSuccess, ZyndioPillTone.success);
      case <= 5:
        return (c.statusWarning, ZyndioPillTone.warning);
      default:
        return (c.statusCritical, ZyndioPillTone.critical);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (upf.level == 'Unknown') return const SizedBox.shrink();
    final c = context.zc;
    final (color, tone) = _level(c);
    final barValue = (upf.score / 10.0).clamp(0.0, 1.0);

    return ZyndioCard(
      padding: const EdgeInsets.all(16),
      radius: 20,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(LucideIcons.testTube2, color: color, size: 16),
              const SizedBox(width: 8),
              Expanded(
                child: Text("Processing Level", style: _style(14, c.textSecondary)),
              ),
              const SizedBox(width: 8),
              Flexible(child: ZyndioPill(upf.level, tone: tone)),
            ],
          ),
          const SizedBox(height: 12),
          _Meter(value: barValue, color: color),
          const SizedBox(height: 10),
          Text(
            upf.verdict,
            style: _style(13, c.textSecondary, height: 1.4),
          ),
          if (upf.additives.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: upf.additives
                  .map((additive) => ZyndioPill(additive, tone: ZyndioPillTone.critical))
                  .toList(),
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

  Color _matchColor(ZyndioColors c) {
    switch (circadian.match.toLowerCase()) {
      case 'excellent':
        return c.statusSuccess;
      case 'good':
        return c.brandPrimary;
      case 'fair':
        return c.statusWarning;
      default:
        return c.statusCritical;
    }
  }

  IconData _timeIcon() {
    switch (circadian.mealTime.toLowerCase()) {
      case 'morning':
        return LucideIcons.sunrise;
      case 'afternoon':
        return LucideIcons.sun;
      case 'evening':
        return LucideIcons.sunset;
      default:
        return LucideIcons.moon;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (circadian.match == 'Unknown') return const SizedBox.shrink();
    final c = context.zc;
    final color = _matchColor(c);

    return ZyndioCard(
      padding: const EdgeInsets.all(16),
      radius: 20,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _IconBadge(icon: _timeIcon(), color: color),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  "${circadian.mealTime} • Circadian Match",
                  style: _style(14, c.textSecondary),
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  "${circadian.matchScore}%",
                  textAlign: TextAlign.end,
                  style: _style(17, color, weight: FontWeight.w700),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _Meter(value: circadian.matchScore / 100, color: color, height: 5),
          const SizedBox(height: 10),
          Text(
            circadian.reason,
            style: _style(13, c.textSecondary, height: 1.4),
          ),
          if (circadian.recommendation.isNotEmpty) ...[
            const SizedBox(height: 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Icon(LucideIcons.lightbulb, color: c.statusWarning, size: 14),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    circadian.recommendation,
                    style: _style(13, c.textPrimary, height: 1.4),
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
    final c = context.zc;

    return ZyndioCard(
      padding: const EdgeInsets.all(18),
      radius: 20,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const ZyndioIconTile(icon: LucideIcons.zap, tint: ZyndioTint.green, size: 34),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  "BIO-HACK THIS MEAL",
                  style: _style(12, c.statusSuccess,
                      weight: FontWeight.w700, letterSpacing: 1.2),
                ),
              ),
              if (bioHack.potencyPercent > 0) ...[
                const SizedBox(width: 8),
                Flexible(
                  child: ZyndioPill(
                    "+${bioHack.potencyPercent}%",
                    tone: ZyndioPillTone.success,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 12),
          Text(
            bioHack.tip,
            style: _style(16, c.textPrimary, weight: FontWeight.w600, height: 1.4),
          ),
          const SizedBox(height: 8),
          Text(
            bioHack.mechanism,
            style: _style(13, c.textSecondary, height: 1.4),
          ),
          if (bioHack.timing.isNotEmpty) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Icon(LucideIcons.clock, color: c.textTertiary, size: 13),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    bioHack.timing,
                    style: _style(12, c.textTertiary, fontStyle: FontStyle.italic),
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
    final c = context.zc;
    final color = _impactColor(c, hormone.impact);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: zyndioCard(context, radius: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _IconBadge(icon: icon, color: color, size: 32),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        hormone.name,
                        style: _style(14, c.textPrimary, weight: FontWeight.w600),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: ZyndioPill(hormone.response, tone: _impactTone(hormone.impact)),
                    ),
                  ],
                ),
                if (hormone.detail.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    hormone.detail,
                    style: _style(13, c.textSecondary, height: 1.4),
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

    final c = context.zc;
    final score = bioavailability.absorptionScore;
    final color = _scoreColor(c, score);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Absorption score bar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: zyndioCard(context, radius: 16),
          child: Row(
            children: [
              Icon(LucideIcons.microscope, color: color, size: 18),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            "Nutrient Absorption",
                            style: _style(13, c.textSecondary),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          "$score%",
                          style: _style(14, color, weight: FontWeight.w700),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    _Meter(value: score / 100, color: color, height: 5),
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
    final c = context.zc;
    final color = tip.impact == 'positive' ? c.statusSuccess : c.statusCritical;
    final icon = tip.impact == 'positive' ? LucideIcons.plus : LucideIcons.minus;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: zyndioCard(context, radius: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _IconBadge(icon: icon, color: color, size: 24),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        tip.title,
                        style: _style(14, c.textPrimary, weight: FontWeight.w600),
                      ),
                    ),
                    if (tip.type.isNotEmpty) ...[
                      const SizedBox(width: 6),
                      Flexible(child: ZyndioPill(tip.type)),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  tip.description,
                  style: _style(13, c.textSecondary, height: 1.4),
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

  Color _effectColor(ZyndioColors c, String effect) {
    final e = effect.toLowerCase();
    if (e.contains('activating') || e.contains('anti') || e.contains('inhibiting')) return c.statusSuccess;
    if (e.contains('suppressing') || e.contains('pro')) return c.statusCritical;
    return c.textSecondary;
  }

  @override
  Widget build(BuildContext context) {
    if (longevity.longevityScore == 0) return const SizedBox.shrink();

    final c = context.zc;
    final credit = longevity.longevityCredit;
    final creditColor = credit >= 0 ? c.statusSuccess : c.statusCritical;
    final creditPrefix = credit >= 0 ? "+" : "";

    return ZyndioCard(
      padding: const EdgeInsets.all(16),
      radius: 20,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              const ZyndioIconTile(icon: LucideIcons.dna, tint: ZyndioTint.indigo, size: 34),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  "Longevity Score",
                  style: _style(14, c.textSecondary),
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  "$creditPrefix$credit pts",
                  textAlign: TextAlign.end,
                  style: _style(16, creditColor, weight: FontWeight.w700),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Score bar
          _Meter(
            value: longevity.longevityScore / 100,
            color: ZyndioTint.indigo.colors.last,
            height: 5,
          ),
          const SizedBox(height: 12),

          // Three pathway chips
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _PathwayChip(label: "Sirtuin", value: longevity.sirtuinEffect, color: _effectColor(c, longevity.sirtuinEffect)),
              const SizedBox(width: 6),
              _PathwayChip(label: "mTOR", value: longevity.mTorEffect, color: _effectColor(c, longevity.mTorEffect)),
              const SizedBox(width: 6),
              _PathwayChip(label: "Inflam.", value: longevity.inflammationEffect.split('-').first, color: _effectColor(c, longevity.inflammationEffect)),
            ],
          ),
          const SizedBox(height: 12),

          // Summary
          Text(
            longevity.longevitySummary,
            style: _style(13, c.textSecondary, height: 1.5),
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
    final c = context.zc;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
        decoration: BoxDecoration(
          color: c.bgSunken,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: _style(11, c.textTertiary),
            ),
            const SizedBox(height: 2),
            Text(
              value,
              maxLines: 1,
              style: _style(12, color, weight: FontWeight.w700),
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
    final c = context.zc;
    final curveType = widget.energyCurve.toLowerCase();
    Color lineColor;
    ZyndioPillTone tone;
    String label;

    if (curveType.contains('spike')) {
      lineColor = c.statusCritical;
      tone = ZyndioPillTone.critical;
      label = "Glucose Spike";
    } else if (curveType.contains('sustained')) {
      lineColor = c.statusSuccess;
      tone = ZyndioPillTone.success;
      label = "Sustained Energy";
    } else {
      lineColor = c.statusWarning;
      tone = ZyndioPillTone.warning;
      label = "Energy Crash";
    }

    final axis = _style(11, c.textTertiary);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                "6-Hour Energy Simulation",
                style: _style(13, c.textSecondary),
              ),
            ),
            const SizedBox(width: 8),
            Flexible(child: ZyndioPill(label, tone: tone)),
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
            Text("Now", style: axis),
            Text("3h", style: axis),
            Text("+6h", style: axis),
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
      ..color = lineColor.withValues(alpha: 0.2)
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
        colors: [lineColor.withValues(alpha: 0.2), lineColor.withValues(alpha: 0.0)],
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
      ..color = lineColor.withValues(alpha: 0.3)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
    canvas.drawCircle(last, 6, dotGlowPaint);
    canvas.drawCircle(last, 4, dotPaint);
  }

  @override
  bool shouldRepaint(_MetabolicCurvePainter old) =>
      old.progress != progress || old.lineColor != lineColor;
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
    final c = context.zc;

    return ZyndioCard(
      padding: const EdgeInsets.all(16),
      radius: 20,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(LucideIcons.watch, color: c.brandPrimary, size: 14),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  "PERSONALIZED FOR YOU TODAY",
                  style: _style(11, c.brandPrimary,
                      weight: FontWeight.w700, letterSpacing: 0.8),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // Wrap, not Row: four chips never overflow a narrow phone.
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (recoveryScore > 0)
                _BioChip(label: "Recovery", value: "$recoveryScore%", color: _recoveryColor(c, recoveryScore)),
              if (stressScore > 0)
                _BioChip(label: "Stress", value: "$stressScore/100", color: _stressColor(c, stressScore)),
              if (sleepHours > 0)
                _BioChip(label: "Sleep", value: "${sleepHours.toStringAsFixed(1)}h", color: ZyndioTint.indigo.colors.last),
              if (hrv != null)
                _BioChip(label: "HRV", value: "${hrv!.round()}", color: c.statusSuccess),
            ],
          ),
        ],
      ),
    );
  }

  Color _recoveryColor(ZyndioColors c, int score) {
    if (score >= 70) return c.statusSuccess;
    if (score >= 40) return c.statusWarning;
    return c.statusCritical;
  }

  Color _stressColor(ZyndioColors c, int score) {
    if (score >= 60) return c.statusCritical;
    if (score >= 35) return c.statusWarning;
    return c.statusSuccess;
  }
}

class _BioChip extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _BioChip({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    final c = context.zc;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: c.bgSunken,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(value, style: _style(13, color, weight: FontWeight.w700)),
          Text(label, style: _style(11, c.textTertiary)),
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

    final violet = ZyndioTint.violet.colors.last;
    final amber = ZyndioTint.amber.colors.last;
    final teal = ZyndioTint.teal.colors.last;

    // Build nodes list for the row layout
    final nodes = <_NodeData>[];
    if (brain != null) nodes.add(_NodeData('Neural', brain.impact, LucideIcons.brain, violet));
    if (metabolic != null) nodes.add(_NodeData('Metabolic', metabolic.impact, LucideIcons.heartPulse, amber));
    if (gut != null) nodes.add(_NodeData('Gut', gut.impact, LucideIcons.leaf, teal));

    if (nodes.isEmpty) return const SizedBox.shrink();
    final c = context.zc;

    Widget blob(double size, Color color, double alpha) => Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(colors: [
              color.withValues(alpha: alpha * _pulseAnim.value),
              color.withValues(alpha: 0),
            ]),
          ),
        );

    return AnimatedBuilder(
      animation: _pulseAnim,
      builder: (context, child) {
        return Container(
          width: double.infinity,
          clipBehavior: Clip.antiAlias,
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
          decoration: zyndioCard(context, radius: 24),
          child: Stack(
            children: [
              // ── Aurora Blobs (Siri-style) ─────────────────────────────
              Positioned(top: -20, right: -10, child: blob(100, amber, 0.10)),
              Positioned(bottom: -15, left: -10, child: blob(90, violet, 0.09)),
              Positioned(top: 20, left: 30, child: blob(70, teal, 0.08)),

              // ── Main Content ─────────────────────────────────────────
              Column(
                children: [
                  Text(
                    "SYSTEMIC BIO-RESPONSE",
                    textAlign: TextAlign.center,
                    style: _style(11, c.textTertiary,
                        weight: FontWeight.w700, letterSpacing: 2.0),
                  ),
                  const SizedBox(height: 20),

                  // ── Node Row ──────────────────────────────────────────
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: nodes
                        .map((n) => Expanded(
                              child: _HoloNode(
                                label: n.label,
                                impact: n.impact,
                                icon: n.icon,
                                baseColor: n.baseColor,
                                pulseValue: _pulseAnim.value,
                              ),
                            ))
                        .toList(),
                  ),

                  const SizedBox(height: 16),

                  // ── Scan Line ─────────────────────────────────────────
                  Container(
                    height: 1,
                    margin: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          teal.withValues(alpha: 0),
                          teal.withValues(alpha: 0.3 * _pulseAnim.value),
                          violet.withValues(alpha: 0.25 * _pulseAnim.value),
                          violet.withValues(alpha: 0),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    "Predictive signal transduction analysis",
                    textAlign: TextAlign.center,
                    style: _style(11, c.textTertiary,
                        fontStyle: FontStyle.italic, letterSpacing: 0.5),
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
    final c = context.zc;
    final impactColor = _impactColor(c, impact);
    // Mix: base glow color with the impact status color
    final glowColor = Color.lerp(baseColor, impactColor, 0.5)!;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Outer glow ring
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: glowColor.withValues(alpha: 0.2 + 0.15 * pulseValue), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: glowColor.withValues(alpha: 0.12 * pulseValue),
                blurRadius: 16,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Center(
            // Inner icon circle
            child: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: glowColor.withValues(alpha: 0.12),
              ),
              child: Icon(icon, color: glowColor, size: 18),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
          decoration: BoxDecoration(
            color: c.bgSunken,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: _style(11, c.textSecondary, weight: FontWeight.w700, letterSpacing: 0.5),
          ),
        ),
        const SizedBox(height: 4),
        // Impact status dot
        Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: impactColor,
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
    final c = context.zc;

    return GestureDetector(
      onTap: () => setState(() => _isExpanded = !_isExpanded),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: zyndioCard(context, radius: 22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const ZyndioIconTile(glyph: ZyndioGlyph.sparkle, tint: ZyndioTint.violet, size: 30),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    "INTELLIGENCE INSIGHT",
                    style: _style(12, c.textTertiary,
                        weight: FontWeight.w700, letterSpacing: 1.3),
                  ),
                ),
                Icon(
                  _isExpanded ? LucideIcons.chevronUp : LucideIcons.chevronDown,
                  color: c.textTertiary,
                  size: 18,
                ),
              ],
            ),
            const SizedBox(height: 12),
            AnimatedSize(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
              alignment: Alignment.topLeft,
              child: Text(
                widget.insight,
                maxLines: _isExpanded ? null : 2,
                overflow: _isExpanded ? TextOverflow.visible : TextOverflow.ellipsis,
                style: _style(15, c.textPrimary, weight: FontWeight.w500, height: 1.5),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Toxin Radar header
// ─────────────────────────────────────────────────────────────────────────────

/// "TOXIN RADAR · n threats" banner above the toxin list.
class LensToxinRadarHeader extends StatelessWidget {
  const LensToxinRadarHeader({super.key, required this.count});
  final int count;

  @override
  Widget build(BuildContext context) {
    final c = context.zc;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: c.statusCriticalSubtle,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(LucideIcons.shieldAlert, color: c.statusCritical, size: 16),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              "TOXIN RADAR",
              style: _style(12, c.statusCritical,
                  weight: FontWeight.w700, letterSpacing: 1.2),
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              "$count threats",
              textAlign: TextAlign.end,
              style: _style(13, c.statusCritical),
            ),
          ),
        ],
      ),
    );
  }
}
