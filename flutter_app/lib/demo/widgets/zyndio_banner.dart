import 'package:flutter/material.dart';

import '../../config/theme.dart';

/// C35 Banner: full width, radius 16, icon + text, announced via a live
/// region. Colour is never the only signal — every variant pairs an icon
/// with explicit words.
enum BannerVariant { error, warning, success, info }

class ZyndioBanner extends StatelessWidget {
  const ZyndioBanner({super.key, required this.variant, required this.message});

  final BannerVariant variant;
  final String message;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<ZyndioColors>()!;
    final (Color fg, Color bg, IconData icon) = switch (variant) {
      BannerVariant.error => (
          colors.statusCritical,
          colors.statusCriticalSubtle,
          Icons.warning_amber_rounded,
        ),
      BannerVariant.warning => (
          colors.statusWarning,
          colors.statusWarningSubtle,
          Icons.warning_amber_rounded,
        ),
      BannerVariant.success => (
          colors.statusSuccess,
          colors.statusSuccessSubtle,
          Icons.check_circle_outline,
        ),
      BannerVariant.info => (
          colors.brandOnSubtle,
          colors.brandSubtle,
          Icons.info_outline,
        ),
    };
    return Semantics(
      liveRegion: true,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(
          horizontal: ZyndioSpace.s16,
          vertical: ZyndioSpace.s12,
        ),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(ZyndioRadius.md),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: ZyndioSize.icon - 4, color: fg),
            const SizedBox(width: ZyndioSpace.s12),
            Expanded(
              child: Text(
                message,
                style: ZyndioType.subhead.copyWith(color: fg),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
