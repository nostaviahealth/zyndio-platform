import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/purchase_provider.dart';

/// A widget that dynamically switches between the standard Zyndio logo
/// and the premium "N PLUS" logo based on the user's subscription tier.
/// 
/// It also applies a background-removal effect (BlendMode.screen) to the
/// Plus logo to ensure it looks integrated on dark surfaces.
class DynamicBrandingIcon extends ConsumerWidget {
  final double size;
  final bool showGlow;

  const DynamicBrandingIcon({
    super.key,
    this.size = 44,
    this.showGlow = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final purchaseState = ref.watch(purchaseProvider);
    final isPremium = purchaseState.isPlus;

    if (isPremium) {
      return _buildPlusIcon(context);
    } else {
      return _buildStandardIcon(context);
    }
  }

  Widget _buildPlusIcon(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        if (showGlow)
          Container(
            width: size * 1.3,
            height: size * 1.3,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  const Color(0xFF60A5FA).withOpacity(0.15), // Reduced from 0.35
                  Colors.transparent,
                ],
              ),
            ),
          ),
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(size * 0.25),
            boxShadow: showGlow ? [
              BoxShadow(
                color: const Color(0xFF60A5FA).withOpacity(0.20), // Reduced from 0.5
                blurRadius: size * 0.4,
                spreadRadius: 2,
              ),
            ] : null,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(size * 0.25),
            child: Image.asset(
              'assets/icons/plus_logo_transparent.png',
              fit: BoxFit.cover,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStandardIcon(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(size * 0.25),
        border: Border.all(
          color: Colors.white.withOpacity(0.2),
          width: 1.0,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(size * 0.25),
        child: Image.asset(
          'assets/icons/app_icon.png',
          fit: BoxFit.contain,
        ),
      ),
    );
  }
}
