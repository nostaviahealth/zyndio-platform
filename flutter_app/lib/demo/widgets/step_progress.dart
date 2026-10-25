import 'package:flutter/material.dart';

import '../../config/theme.dart';

/// C14 Step progress: full width x4, bg.sunken track, brand.primary fill.
class StepProgress extends StatelessWidget {
  const StepProgress({super.key, required this.value});

  /// Fraction complete, 0.0-1.0.
  final double value;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<ZyndioColors>()!;
    return Semantics(
      label: 'Step progress',
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
