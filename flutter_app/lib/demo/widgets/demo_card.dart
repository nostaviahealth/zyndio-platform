import 'package:flutter/material.dart';

import '../../config/theme.dart';

/// C15 Card: bg.surface, 1pt border.subtle, radius 16, shadow.card
/// (light mode only; dark mode separates via border + bg.surface/bg.canvas).
class DemoCard extends StatelessWidget {
  const DemoCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(ZyndioSpace.s16),
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<ZyndioColors>()!;
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: colors.bgSurface,
        borderRadius: BorderRadius.circular(ZyndioRadius.lg),
        border: Border.all(color: colors.borderSubtle),
        boxShadow: ZyndioShadow.cardFor(Theme.of(context).brightness),
      ),
      child: child,
    );
  }
}
