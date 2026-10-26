import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../config/theme.dart';

class ActivitySessionCard extends StatelessWidget {
  final String title;
  final String durationOrDistance;
  final String dateString;
  final Color iconColor;
  final IconData iconData;
  final int badgeNumber; // For the day of the week or session count
  final VoidCallback? onTap;

  const ActivitySessionCard({
    super.key,
    required this.title,
    required this.durationOrDistance,
    required this.dateString,
    this.iconColor = const Color(0xFFF59E0B), // Default orange
    this.iconData = LucideIcons.footprints,
    this.badgeNumber = 1,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: BoxDecoration(
        color: context.nc.cardSurface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: context.nc.shadowColor,
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Stacked Icon with Badge
          SizedBox(
            width: 48,
            height: 48,
            child: Stack(
              children: [
                Align(
                  alignment: Alignment.topLeft,
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: context.nc.cardSurface,
                      border: Border.all(color: context.nc.cardBorder, width: 1.5),
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: Icon(iconData, color: iconColor, size: 20),
                  ),
                ),
                Positioned(
                  bottom: -2,
                  right: -2,
                  child: Container(
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      color: context.nc.cardSurface,
                      shape: BoxShape.circle,
                      border: Border.all(color: context.nc.cardSurface, width: 2),
                    ),
                    child: Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFCC80), // Light orange badge
                        shape: BoxShape.circle,
                        border: Border.all(color: iconColor, width: 1.5),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        badgeNumber.toString(),
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: iconColor,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          // Title and Stat
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: context.nc.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                // Date string below title
                Text(
                  dateString,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: context.nc.textTertiary,
                  ),
                ),
              ],
            ),
          ),
          // Simple trailing chevron
          Icon(LucideIcons.arrowRight, size: 18, color: context.nc.textTertiary),
        ],
      ),
      ),
    );
  }
}
