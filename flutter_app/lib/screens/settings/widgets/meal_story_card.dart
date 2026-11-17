import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../config/theme.dart';
import '../../../models/food_analysis.dart';
import '../../../models/food_log.dart';
import '../../../widgets/tc025/tc025_widgets.dart';

/// A specialized 9:16 layout for Instagram/social sharing.
/// Not shown in the primary UI; strictly used for image capture.
///
/// The story is a fixed-size image, so it always renders from the dark token
/// set ([ZyndioColors.dark]) and ignores the device text scale: the captured
/// picture looks the same whoever shares it, and never overflows.
class MealStoryCard extends StatelessWidget {
  final FoodLog log;
  final FoodAnalysis data;
  final String imageUrl;

  const MealStoryCard({
    super.key,
    required this.log,
    required this.data,
    required this.imageUrl,
  });

  static const ZyndioColors _c = ZyndioColors.dark;

  static TextStyle _style(
    double size,
    Color color, {
    FontWeight weight = FontWeight.w400,
    double? height,
    double? letterSpacing,
  }) =>
      TextStyle(
        fontFamily: ZyndioType.family,
        fontSize: size,
        fontWeight: weight,
        height: height,
        letterSpacing: letterSpacing,
        color: color,
      );

  Widget _divider() => Container(width: 1, height: 36, color: _c.borderSubtle);

  BoxDecoration get _panel => BoxDecoration(
        color: _c.bgSurface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _c.borderSubtle),
      );

  @override
  Widget build(BuildContext context) {
    return MediaQuery.withNoTextScaling(
      child: AspectRatio(
        aspectRatio: 9 / 16,
        child: Container(
          color: _c.bgCanvas,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── HERO PHOTO (60%) ──────────────────────────────────────
              Expanded(
                flex: 56,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    // Meal Photo
                    if (imageUrl.isNotEmpty)
                      Image.network(
                        imageUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(color: _c.bgSunken),
                      )
                    else
                      Container(
                        color: _c.bgSunken,
                        alignment: Alignment.center,
                        child: const ZyndioIconTile(
                            glyph: ZyndioGlyph.bowl, tint: ZyndioTint.green, size: 96),
                      ),

                    // Silk gradient bottom fade
                    Positioned.fill(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            stops: const [0.0, 0.5, 0.8, 1.0],
                            colors: [
                              _c.bgCanvas.withValues(alpha: 0),
                              _c.bgCanvas.withValues(alpha: 0),
                              _c.bgCanvas.withValues(alpha: 0.6),
                              _c.bgCanvas,
                            ],
                          ),
                        ),
                      ),
                    ),

                    // Zyndio Certified Badge (top left)
                    Positioned(
                      top: 28,
                      left: 20,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          gradient: ZyndioGradients.brand,
                          borderRadius: BorderRadius.circular(999),
                          boxShadow: [
                            BoxShadow(
                              color: ZyndioTint.violet.colors.last.withValues(alpha: 0.4),
                              blurRadius: 12,
                              spreadRadius: 1,
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(LucideIcons.shieldCheck, color: Colors.white, size: 12),
                            const SizedBox(width: 6),
                            Text(
                              'ZYNDIO CERTIFIED',
                              style: _style(10, Colors.white,
                                  weight: FontWeight.w800, letterSpacing: 1.0),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // ── DATA SECTION (40%) ────────────────────────────────────
              Expanded(
                flex: 44,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(22, 16, 22, 28),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Food Name
                      Text(
                        data.foodName,
                        style: _style(22, _c.textPrimary,
                            weight: FontWeight.w700, letterSpacing: -0.5, height: 1.2),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${data.calories} kcal',
                        style: _style(13, _c.textSecondary),
                      ),
                      const SizedBox(height: 12),

                      // Score + Macros — unified card with 4 equal columns
                      Container(
                        decoration: _panel,
                        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
                        child: Row(
                          children: [
                            // Score Column
                            Expanded(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    '${data.score}',
                                    style: _style(30, _scoreColor(data.score),
                                        weight: FontWeight.w700, height: 1.0),
                                  ),
                                  Text(
                                    'SCORE',
                                    style: _style(9, _c.textTertiary,
                                        weight: FontWeight.w600, letterSpacing: 1.0),
                                  ),
                                ],
                              ),
                            ),

                            _divider(),

                            // Macros columns
                            Expanded(child: _buildMacro('PROTEIN', data.macros.protein, ZyndioTint.blue.colors.first)),
                            _divider(),
                            Expanded(child: _buildMacro('CARBS', data.macros.carbs, ZyndioTint.amber.colors.first)),
                            _divider(),
                            Expanded(child: _buildMacro('FAT', data.macros.fat, ZyndioTint.green.colors.first)),
                          ],
                        ),
                      ),

                      const SizedBox(height: 12),

                      // Bio-Intelligence Stats Card
                      Container(
                        decoration: _panel,
                        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
                        child: Row(
                          children: [
                            // Circadian
                            Expanded(
                              child: _buildStatPill(
                                'CIRCADIAN',
                                data.circadianMatch.match == 'Unknown'
                                    ? '—'
                                    : data.circadianMatch.match,
                                _circadianColor(data.circadianMatch.match),
                              ),
                            ),
                            _divider(),
                            // Processing
                            Expanded(
                              child: _buildStatPill(
                                'PROCESSING',
                                data.upfAnalysis.level == 'Unknown'
                                    ? '—'
                                    : _shortenProcessingMode(data.upfAnalysis.level),
                                _upfColor(data.upfAnalysis.score),
                              ),
                            ),
                            _divider(),
                            // Toxins
                            Expanded(
                              child: _buildStatPill(
                                'TOXINS',
                                data.toxins.isEmpty ? 'None' : '${data.toxins.length} found',
                                data.toxins.isEmpty ? _c.statusSuccess : _c.statusCritical,
                              ),
                            ),
                            _divider(),
                            // Longevity
                            Expanded(
                              child: _buildStatPill(
                                'LONGEVITY',
                                data.longevityImpact.longevityCredit == 0
                                    ? '—'
                                    : (data.longevityImpact.longevityCredit > 0
                                        ? '+${data.longevityImpact.longevityCredit}'
                                        : '${data.longevityImpact.longevityCredit}'),
                                data.longevityImpact.longevityCredit >= 0
                                    ? _c.statusSuccess
                                    : _c.statusCritical,
                              ),
                            ),
                          ],
                        ),
                      ),

                      const Spacer(),

                      // Branding Footer — app icon + Zyndio
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(0.5),
                            decoration: BoxDecoration(
                              border: Border.all(color: _c.borderSubtle),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.asset(
                                'assets/icons/app_icon.png',
                                width: 28,
                                height: 28,
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            'Zyndio',
                            style: _style(14, _c.textSecondary,
                                weight: FontWeight.w700, letterSpacing: 0.5),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMacro(String label, int amount, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 5),
            Flexible(
              child: Text(
                '${amount}g',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: _style(17, _c.textPrimary, weight: FontWeight.w700),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          label,
          maxLines: 1,
          style: _style(9, _c.textTertiary, weight: FontWeight.w600, letterSpacing: 0.8),
        ),
      ],
    );
  }

  String _shortenProcessingMode(String level) {
    if (level.contains('Minimally')) return 'Minimal';
    if (level.contains('Ultra')) return 'Ultra';
    if (level.contains('Whole')) return 'Whole';
    return 'Processed';
  }

  Widget _buildStatPill(String label, String value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(
                value,
                style: _style(13, value == '—' ? _c.textTertiary : color,
                    weight: FontWeight.w700),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          label,
          maxLines: 1,
          style: _style(8, _c.textTertiary, weight: FontWeight.w600, letterSpacing: 0.6),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Color _scoreColor(int score) {
    if (score >= 80) return _c.statusSuccess;
    if (score >= 50) return _c.statusWarning;
    return _c.statusCritical;
  }

  Color _circadianColor(String match) {
    switch (match.toLowerCase()) {
      case 'excellent': return _c.statusSuccess;
      case 'good':      return _c.brandPrimary;
      case 'fair':      return _c.statusWarning;
      default:          return _c.statusCritical;
    }
  }

  Color _upfColor(int score) {
    if (score <= 2) return _c.statusSuccess;
    if (score <= 5) return _c.statusWarning;
    return _c.statusCritical;
  }
}
