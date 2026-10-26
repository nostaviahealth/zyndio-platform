import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import '../providers/ai_theme_provider.dart';
import '../config/theme.dart';
import 'intelligence_glow_wrapper.dart';

class AskIntelligenceButton extends ConsumerWidget {
  final VoidCallback onTap;
  final String label;

  const AskIntelligenceButton({
    super.key,
    required this.onTap,
    this.label = 'Ask Intelligence',
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final aiTheme = ref.watch(aiThemeProvider);
    final isSiri = aiTheme == AIThemeMode.siri;

    if (!isSiri) {
      return InkWell(
        onTap: () {
          HapticFeedback.lightImpact();
          onTap();
        },
        child: Center(
          child: Container(
            height: 52,
            width: double.infinity,
            decoration: BoxDecoration(
              color: context.nc.isDark ? context.nc.cardSurfaceElevated : Colors.white,
              borderRadius: BorderRadius.circular(26),
              border: Border.all(color: context.nc.cardBorder.withValues(alpha: context.nc.isDark ? 0.3 : 1.0), width: 1),
              boxShadow: [
                BoxShadow(
                  color: (context.nc.isDark ? Colors.black : Colors.black).withOpacity(0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: context.nc.isDark ? Colors.white : const Color(0xFF007AFF),
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.3,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return IntelligenceGlowWrapper(
      borderRadius: 26,
      blurSigma: 10,
      child: GestureDetector(
        onTap: () {
          HapticFeedback.lightImpact();
          onTap();
        },
        child: Container(
          height: 52,
          width: double.infinity,
          decoration: BoxDecoration(
            color: context.nc.isDark ? context.nc.cardSurfaceElevated : Colors.white,
            borderRadius: BorderRadius.circular(26),
            border: Border.all(color: context.nc.cardBorder.withValues(alpha: context.nc.isDark ? 0.3 : 1.0)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: context.nc.isDark ? Colors.white : const Color(0xFF007AFF),
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.3,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
