import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../providers/purchase_provider.dart';
import '../screens/settings/paywall_screen.dart';

enum PlusFeature {
  glucoseStability,
  systemBalance,
  diseaseRisk,
  forYouTimeline,
  digitalTwinSimulation,
}

/// A reusable overlay for locking features behind a Plus subscription.
class PlusLockedOverlay extends ConsumerWidget {
  final Widget child;
  final String title;
  final String subtitle;
  final VoidCallback? onUpgradeTap;
  final double blurSigma;

  const PlusLockedOverlay({
    super.key,
    required this.child,
    this.title = 'Unlock with Plus',
    this.subtitle = 'Professional insights require a Plus subscription.',
    this.onUpgradeTap,
    this.blurSigma = 4.0,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isPlus = ref.watch(purchaseProvider).isPlus;

    if (isPlus) return child;

    return Stack(
      children: [
        // The original feature, blurred
        AbsorbPointer(
          child: ImageFiltered(
            imageFilter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
            child: child,
          ),
        ),
        
        // The lock overlay
        Positioned.fill(
          child: Container(
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.05),
              borderRadius: BorderRadius.circular(24),
            ),
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.6),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.white.withOpacity(0.4)),
                      ),
                      child: const Icon(
                        LucideIcons.lock,
                        color: Color(0xFF0F172A),
                        size: 20,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      title,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Color(0xFF0F172A),
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: const Color(0xFF0F172A).withOpacity(0.7),
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: onUpgradeTap ?? () => PaywallScreen.show(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0F172A),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: const Text(
                        'Upgrade to Plus',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// Convenience Providers

final canAccessGlucoseStabilityProvider = Provider<bool>((ref) {
  return ref.watch(purchaseProvider).isPlus;
});

final canAccessSystemBalanceProvider = Provider<bool>((ref) {
  return ref.watch(purchaseProvider).isPlus;
});

final canAccessDiseaseRiskProvider = Provider<bool>((ref) {
  return ref.watch(purchaseProvider).isPlus;
});

final canAccessForYouTimelineProvider = Provider<bool>((ref) {
  return ref.watch(purchaseProvider).isPlus;
});

final canAccessSimulationsProvider = Provider<bool>((ref) {
  return ref.watch(purchaseProvider).isPlus;
});
