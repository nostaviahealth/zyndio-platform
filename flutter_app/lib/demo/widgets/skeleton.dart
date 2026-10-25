import 'package:flutter/material.dart';

import '../../config/theme.dart';

/// C36 Skeleton: a bg.sunken block (r8) matching a final layout's row height,
/// so nothing jumps once real content arrives. No shimmer under Reduce
/// Motion (static).
class Skeleton extends StatelessWidget {
  const Skeleton({super.key, this.width, this.height = 16});

  final double? width;
  final double height;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<ZyndioColors>()!;
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: colors.bgSunken,
        borderRadius: BorderRadius.circular(8),
      ),
    );
  }
}
