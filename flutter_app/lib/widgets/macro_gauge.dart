import 'package:flutter/material.dart';

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
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  "METABOLIC POWER",
                   style: TextStyle(
                     fontSize: 10, 
                     fontWeight: FontWeight.w900, 
                     color: Colors.white.withValues(alpha: 0.5),
                     letterSpacing: 1.2,
                   )
                ),
                RichText(
                  text: TextSpan(
                    style: const TextStyle(color: Colors.white, fontFamily: 'SF Pro Display'),
                    children: [
                      TextSpan(
                        text: totalCal.round().toString(),
                        style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, letterSpacing: -1),
                      ),
                      TextSpan(
                        text: " KCAL",
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Colors.white.withValues(alpha: 0.5)),
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
            color: const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(height / 2),
          ),
          clipBehavior: Clip.antiAlias,
          child: Row(
            children: [
              if (pPerc > 0)
                _buildSegment(pPerc, const Color(0xFF10B981), "Protein"),
              if (cPerc > 0)
                _buildSegment(cPerc, const Color(0xFF3B82F6), "Carbs"),
              if (fPerc > 0)
                _buildSegment(fPerc, const Color(0xFFF59E0B), "Fats"),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSegment(double percent, Color color, String label) {
    return Expanded(
      flex: (percent * 1000).round(),
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
