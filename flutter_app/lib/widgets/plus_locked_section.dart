import 'dart:ui';
import 'package:flutter/material.dart';
import '../screens/settings/paywall_screen.dart';
import '../services/revenue_cat_service.dart';

/// A reusable widget that gates content behind a Plus subscription.
/// Redesigned with a "white minimal" aesthetic to match the app theme.
class PlusLockedSection extends StatelessWidget {
  final Widget child;
  final bool isLocked;
  final String? featureName;
  final String? subtitle;

  const PlusLockedSection({
    super.key,
    required this.child,
    required this.isLocked,
    this.featureName,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    if (!isLocked) return child;

    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 220),
      child: Stack(
        children: [
          // 1. Child content rendered underneath (blurred)
          IgnorePointer(child: child),

          // 2. Minimalist White Glassmorphism overlay
          Positioned.fill(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(28),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.85),
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(
                      color: const Color(0xFFF1F5F9), // Slate 100
                      width: 1.5,
                    ),
                  ),
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24.0),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Minimalist Star Icon
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFC), // Slate 50
                              shape: BoxShape.circle,
                              border: Border.all(color: const Color(0xFFE2E8F0)),
                            ),
                            child: const Icon(
                              Icons.lock_outline_rounded,
                              color: Color(0xFF3B82F6), // Zyndio Blue
                              size: 24,
                            ),
                          ),
                          const SizedBox(height: 16),
                          
                          // Feature Title
                          Text(
                            featureName ?? 'Zyndio Plus',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF0F172A), // Slate 900
                              letterSpacing: -0.4,
                            ),
                          ),
                          const SizedBox(height: 6),
                          
                          // Subtitle
                          Text(
                            subtitle ?? 'Unlock this premium feature',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 14,
                              color: Color(0xFF64748B), // Slate 500
                              fontWeight: FontWeight.w500,
                              height: 1.4,
                            ),
                          ),
                          const SizedBox(height: 24),
                          
                          // Minimalist Pill Button
                          GestureDetector(
                            onTap: () => PaywallScreen.show(context),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                              decoration: BoxDecoration(
                                color: const Color(0xFF0F172A), // Slate 900 - Minimal black/dark contrast
                                borderRadius: BorderRadius.circular(100),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.1),
                                    blurRadius: 10,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: const Text(
                                'Unlock with Plus',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14,
                                  letterSpacing: 0.1,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A minimal white upsell banner shown when rate limit is hit.
class PlusRateLimitBanner extends StatelessWidget {
  final String message;
  final String? ctaLabel;

  const PlusRateLimitBanner({
    super.key,
    required this.message,
    this.ctaLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          const Icon(Icons.lock_outline_rounded, color: Color(0xFF3B82F6), size: 18),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                fontSize: 13,
                color: Color(0xFF1E293B),
                fontWeight: FontWeight.w600,
                letterSpacing: -0.1,
              ),
            ),
          ),
          const SizedBox(width: 12),
          GestureDetector(
            onTap: () => PaywallScreen.show(context),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Text(
                ctaLabel ?? 'Upgrade',
                style: const TextStyle(
                  color: Color(0xFF0F172A),
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}


