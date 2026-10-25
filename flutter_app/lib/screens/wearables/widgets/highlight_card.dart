import 'package:flutter/material.dart';
import '../../../../config/theme.dart';

import 'dashboard_card_style.dart';

class HighlightCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final String insight;
  final Widget child;
  final VoidCallback? onTap;

  const HighlightCard({
    super.key,
    required this.title,
    required this.icon,
    required this.color,
    required this.insight,
    required this.child,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      // width: 320, // Removed for vertical stack flexibility
      // margin: const EdgeInsets.only(right: 16), // Removed for vertical stack
      decoration: DashboardCardStyle.decorationOf(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(icon, size: 18, color: color),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
          
          // Insight Text (Apple Health Style: Bold statement)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              insight,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600, // Semi-bold for readability
                color: BrandColors.dark,
                height: 1.4,
              ),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          
          const SizedBox(height: 8),
          
          // Chart Content (Dynamic Height)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
            child: child,
          ),
        ],
      ),
    );
  }
}
