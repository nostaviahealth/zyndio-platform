import 'package:flutter/material.dart';
import 'dashboard_card_style.dart';
import '../../../widgets/intelligence_glow_wrapper.dart';

/// A coaching insight card that shows an AI-generated health tip.
/// Matches the WHOOP "COACHING" section in the reference screenshot.
class CoachingInsightCard extends StatelessWidget {
  final String insight;

  const CoachingInsightCard({
    super.key,
    required this.insight,
  });

  @override
  Widget build(BuildContext context) {
    return IntelligenceGlowWrapper(
      child: Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: DashboardCardStyle.decorationOf(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Image.asset(
            'assets/images/intelligence_logo_text.png',
            height: 14,
            fit: BoxFit.contain,
          ),
          const SizedBox(height: 10),
          Text(
            insight,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: Color(0xFF1E293B),
              height: 1.5,
            ),
          ),
        ],
      ),
    ));
  }
}
