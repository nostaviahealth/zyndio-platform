import 'package:flutter/material.dart';

import '../config/theme.dart';
import 'tc025/tc025_widgets.dart';

class MacroGauge extends StatelessWidget {
  final double protein;
  final double carbs;
  final double fats;
  final double height;
  final bool showCalories;

  const MacroGauge({
    super.key,
    required this.protein,
    required this.carbs,
    required this.fats,
    this.height = 12,
    this.showCalories = true,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.zc;

    // Calorie calculation
    final pCal = protein * 4;
    final cCal = carbs * 4;
    final fCal = fats * 9;
    final totalCal = pCal + cCal + fCal;

    if (totalCal <= 0) return const SizedBox.shrink();

    // Percentages
    final pPerc = pCal / totalCal;
    final cPerc = cCal / totalCal;
    final fPerc = fCal / totalCal;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showCalories)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            // Wrap: the label and the total sit on one line when they fit and
            // stack on a narrow phone or with large accessibility text.
            child: Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.end,
              spacing: 12,
              runSpacing: 4,
              children: [
                Text(
                  "METABOLIC POWER",
                  style: TextStyle(
                    fontFamily: ZyndioType.family,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.3,
                    color: c.textTertiary,
                  ),
                ),
                Text.rich(
                  TextSpan(
                    style: TextStyle(
                      fontFamily: ZyndioType.family,
                      color: c.textPrimary,
                    ),
                    children: [
                      TextSpan(
                        text: totalCal.round().toString(),
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.5,
                          fontFeatures: ZyndioType.tabular,
                        ),
                      ),
                      TextSpan(
                        text: " KCAL",
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.6,
                          color: c.textTertiary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

        // The Linear Bar
        Container(
          height: height,
          width: double.infinity,
          decoration: BoxDecoration(
            color: context.z25.segmentBg,
            borderRadius: BorderRadius.circular(height / 2),
          ),
          clipBehavior: Clip.antiAlias,
          child: Row(
            children: [
              if (pPerc > 0)
                _buildSegment(pPerc, ZyndioTint.green.colors.last, "Protein"),
              if (cPerc > 0)
                _buildSegment(cPerc, ZyndioTint.blue.colors.last, "Carbs"),
              if (fPerc > 0)
                _buildSegment(fPerc, ZyndioTint.amber.colors.last, "Fats"),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSegment(double percent, Color color, String label) {
    return Expanded(
      // Never 0: a zero-flex child would be laid out unbounded and throw.
      flex: (percent * 1000).round().clamp(1, 1000),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 0.5),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }
}
