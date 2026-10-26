import 'package:flutter/material.dart';

import '../../config/theme.dart';

/// C24 Progress bar: full width x4, determinate, bg.sunken track + brand fill.
class ProgressBar extends StatelessWidget {
  const ProgressBar({super.key, required this.value});

  /// Fraction complete, 0.0-1.0.
  final double value;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<ZyndioColors>()!;
    return Semantics(
      label: 'Upload progress',
      value: '${(value.clamp(0.0, 1.0) * 100).round()}%',
      child: ClipRRect(
        borderRadius: BorderRadius.circular(ZyndioRadius.pill),
        child: SizedBox(
          height: ZyndioSize.progressHeight,
          width: double.infinity,
          child: Stack(
            children: [
              Container(color: colors.bgSunken),
              FractionallySizedBox(
                widthFactor: value.clamp(0.0, 1.0),
                child: Container(color: colors.brandPrimary),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
