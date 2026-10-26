import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../config/theme.dart';
import '../../../models/food_analysis.dart';
import '../../../models/food_log.dart';

/// A specialized 9:16 layout for Instagram/social sharing.
/// Not shown in the primary UI; strictly used for image capture.
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

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 9 / 16,
      child: Container(
        color: const Color(0xFF0A0A0A),
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
                      errorBuilder: (_, __, ___) => Container(color: const Color(0xFF111111)),
                    )
                  else
                    Container(color: const Color(0xFF111111)),

                  // Silk gradient bottom fade
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          stops: const [0.0, 0.5, 0.8, 1.0],
                          colors: [
                            Colors.transparent,
                            Colors.transparent,
                            Colors.black.withOpacity(0.6),
                            const Color(0xFF0A0A0A),
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
                        color: BrandColors.emerald500,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: BrandColors.emerald500.withOpacity(0.4),
                            blurRadius: 12,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(LucideIcons.shieldCheck, color: Colors.white, size: 12),
                          SizedBox(width: 6),
                          Text(
                            'ZYNDIO CERTIFIED',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.0,
                            ),
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
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        letterSpacing: -0.5,
                        height: 1.2,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${data.calories} kcal',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.45),
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Score + Macros — unified card with 4 equal columns
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.white.withOpacity(0.08)),
                      ),
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
                                  style: const TextStyle(
                                    color: BrandColors.emerald500,
                                    fontSize: 30,
                                    fontWeight: FontWeight.bold,
                                    height: 1.0,
                                  ),
                                ),
                                Text(
                                  'SCORE',
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.35),
                                    fontSize: 9,
                                    letterSpacing: 1.0,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          Container(width: 1, height: 36, color: Colors.white.withOpacity(0.08)),

                          // Macros columns
                          Expanded(child: _buildMacro('PROTEIN', data.macros.protein, BrandColors.blue500)),
                          Container(width: 1, height: 36, color: Colors.white.withOpacity(0.08)),
                          Expanded(child: _buildMacro('CARBS', data.macros.carbs, BrandColors.orange500)),
                          Container(width: 1, height: 36, color: Colors.white.withOpacity(0.08)),
                          Expanded(child: _buildMacro('FAT', data.macros.fat, BrandColors.emerald500)),
                        ],
                      ),
                    ),

                    const SizedBox(height: 12),

                    // Bio-Intelligence Stats Card
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.white.withOpacity(0.08)),
                      ),
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
                          Container(width: 1, height: 36, color: Colors.white.withOpacity(0.08)),
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
                          Container(width: 1, height: 36, color: Colors.white.withOpacity(0.08)),
                          // Toxins
                          Expanded(
                            child: _buildStatPill(
                              'TOXINS',
                              data.toxins.isEmpty ? 'None' : '${data.toxins.length} found',
                              data.toxins.isEmpty ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                            ),
                          ),
                          Container(width: 1, height: 36, color: Colors.white.withOpacity(0.08)),
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
                                  ? const Color(0xFF10B981)
                                  : const Color(0xFFEF4444),
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
                            border: Border.all(color: Colors.white.withOpacity(0.1)),
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
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.6),
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.5,
                          ),
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
    );
  }

  Widget _buildMacro(String label, int amount, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '${amount}g',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 17,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withOpacity(0.4),
            fontSize: 9,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.8,
          ),
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
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withOpacity(0.4),
            fontSize: 8,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.6,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Color _circadianColor(String match) {
    switch (match.toLowerCase()) {
      case 'excellent': return const Color(0xFF10B981);
      case 'good':      return const Color(0xFF22D3EE);
      case 'fair':      return const Color(0xFFF59E0B);
      default:          return const Color(0xFFEF4444);
    }
  }

  Color _upfColor(int score) {
    if (score <= 2) return const Color(0xFF10B981);
    if (score <= 5) return const Color(0xFFF59E0B);
    return const Color(0xFFEF4444);
  }
}
