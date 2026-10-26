import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../config/theme.dart';

/// Health and wellness disclaimer banner for health-related screens
/// Required for App Store/Play Store compliance
class HealthDisclaimerBanner extends StatelessWidget {
  final String message;
  final bool compact;

  const HealthDisclaimerBanner({
    super.key,
    required this.message,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    // Redesigned: Minimal footer link style
    return Center(
      child: GestureDetector(
        onTap: () => _showDisclaimerSheet(context),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: context.nc.isDark 
                ? context.nc.cardSurfaceElevated.withValues(alpha: 0.8) 
                : BrandColors.slate100.withOpacity(0.5),
            borderRadius: BorderRadius.circular(20),
            border: context.nc.isDark 
                ? Border.all(color: context.nc.cardBorder.withValues(alpha: 0.2)) 
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                LucideIcons.info, 
                size: 14, 
                color: context.nc.textTertiary
              ),
              const SizedBox(width: 8),
              Text(
                "Health Disclaimer",
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: context.nc.textSecondary,
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showDisclaimerSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      useRootNavigator: true, 
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: context.nc.isDark ? const Color(0xFF121212) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          border: context.nc.isDark ? Border(top: BorderSide(color: context.nc.cardBorder.withValues(alpha: 0.2))) : null,
        ),
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40, 
                height: 4, 
                margin: const EdgeInsets.only(bottom: 24),
                decoration: BoxDecoration(
                  color: context.nc.isDark ? context.nc.divider : BrandColors.slate200,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: BrandColors.blue500.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(LucideIcons.shieldAlert, color: BrandColors.blue600, size: 24),
                ),
                const SizedBox(width: 16),
                Text(
                  "Health Disclaimer",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: context.nc.textPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              message,
              style: TextStyle(
                fontSize: 15,
                height: 1.6,
                color: context.nc.textSecondary,
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: context.nc.isDark ? context.nc.cardSurfaceElevated : BrandColors.slate100,
                  foregroundColor: context.nc.textPrimary,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: const Text("I Understand", style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Pre-defined disclaimer messages for consistency
class DisclaimerMessages {
  static const String generalHealth = 
      'The App is NOT a medical device and does NOT provide medical advice, diagnosis, or treatment. Always seek the advice of your physician or other qualified health provider with any questions you may have regarding a medical condition.';
  
  static const String diseaseRisk = 
      'AI insights are based on general health patterns and data analysis algorithms, not personalized clinical judgment. While we strive for accuracy, AI results may contain errors. Consult with a medical professional for evaluation.';
  
  static const String protocol = 
      'Information is for educational purposes only. Always consult with a medical professional before starting any new supplement, diet, or exercise regimen suggested by the App.';
  
  static const String aiInsights = 
      'AI-generated insights • Informational Only';
  
  static const String notForEmergencies = 
      'The App is not intended for use in medical emergencies. If you are experiencing a medical emergency, call your local emergency services (e.g., 102/112 in India) immediately.';
}
