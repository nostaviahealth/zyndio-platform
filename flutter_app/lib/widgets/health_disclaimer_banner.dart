import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../config/theme.dart';
import 'tc025/tc025_widgets.dart';

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
    final c = context.zc;
    final z = context.z25;
    // Minimal footer link style
    return Center(
      child: GestureDetector(
        onTap: () => _showDisclaimerSheet(context),
        child: Container(
          constraints: const BoxConstraints(minHeight: 36),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: z.badgeNeutralBg,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(LucideIcons.info, size: 14, color: c.textTertiary),
              const SizedBox(width: 8),
              // Flexible: large accessibility text wraps instead of
              // overflowing a narrow phone.
              Flexible(
                child: Text(
                  "Health Disclaimer",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: ZyndioType.family,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: z.badgeNeutralText,
                  ),
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
      builder: (context) {
        final c = context.zc;
        final dark = Theme.of(context).brightness == Brightness.dark;
        return Container(
          decoration: BoxDecoration(
            color: c.bgSurface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            border: dark
                ? Border(top: BorderSide(color: c.borderSubtle))
                : null,
          ),
          child: SafeArea(
            top: false,
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
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
                        color: c.borderSubtle,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  Row(
                    children: [
                      const ZyndioIconTile(
                        icon: LucideIcons.shieldAlert,
                        tint: ZyndioTint.blue,
                        size: 44,
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Text(
                          "Health Disclaimer",
                          style: ZyndioType.title3.copyWith(
                            fontWeight: FontWeight.w700,
                            color: c.textPrimary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    message,
                    style: ZyndioType.subhead.copyWith(
                      height: 22 / 15,
                      color: c.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 24),
                  ZyndioOutlineButton(
                    label: "I Understand",
                    onTap: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
          ),
        );
      },
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
