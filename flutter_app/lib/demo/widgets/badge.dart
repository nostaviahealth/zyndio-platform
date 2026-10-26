import 'package:flutter/material.dart';

import '../../config/theme.dart';

/// C22 Badge: caption 12/16 600, padding 2 8, pill.
enum BadgeVariant { ok, warn, err, brand }

class ZyndioBadge extends StatelessWidget {
  const ZyndioBadge({super.key, required this.label, required this.variant});

  final String label;
  final BadgeVariant variant;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<ZyndioColors>()!;
    final (Color fg, Color bg) = switch (variant) {
      BadgeVariant.ok => (colors.statusSuccess, colors.statusSuccessSubtle),
      BadgeVariant.warn => (colors.statusWarning, colors.statusWarningSubtle),
      BadgeVariant.err => (colors.statusCritical, colors.statusCriticalSubtle),
      BadgeVariant.brand => (colors.brandOnSubtle, colors.brandSubtle),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: ZyndioSpace.s8, vertical: 2),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(ZyndioRadius.pill)),
      child: Text(
        label,
        style: ZyndioType.caption.copyWith(color: fg, fontWeight: FontWeight.w600),
      ),
    );
  }
}
