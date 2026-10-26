import 'package:flutter/material.dart';

import '../../config/theme.dart';

/// C17 optional-consent switch: track 51x31 with a 1px border, and a knob
/// nearly the full track height (25x25, inset 2px) with its own 1px outline
/// — unlike a Material [Switch], the off-state knob stays clearly outlined
/// and full height instead of shrinking to a small dot.
///
/// Purely visual: callers wrap it in [ExcludeSemantics]/[IgnorePointer] and
/// drive toggling from the surrounding hit area (see `optional_card.dart`).
class ZyndioSwitch extends StatelessWidget {
  const ZyndioSwitch({super.key, required this.value, this.onChanged});

  final bool value;
  final ValueChanged<bool>? onChanged;

  static const double _knobSize = ZyndioSize.switchKnob;
  static const double _knobInsetOff = 2.0;
  static const double _knobInsetOn = 22.0;
  static const double _knobTop = 2.0;
  static const double _trackBorderWidth = 1.0;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<ZyndioColors>()!;
    final trackColor = value ? colors.brandPrimary : colors.bgSunken;
    final trackBorderColor = value ? colors.brandPrimary : colors.borderStrong;
    final knobOutlineColor = value ? colors.brandPrimary : colors.borderStrong;
    final duration = ZyndioMotion.of(context);

    return GestureDetector(
      onTap: onChanged == null ? null : () => onChanged!(!value),
      child: Container(
        width: ZyndioSize.switchWidth,
        height: ZyndioSize.switchHeight,
        // No explicit padding: BoxDecoration.border already contributes an
        // implicit inset equal to the border width, matching the CSS
        // border-box containing block the left:2/22 offsets below assume.
        decoration: BoxDecoration(
          color: trackColor,
          borderRadius: BorderRadius.circular(ZyndioRadius.pill),
          border: Border.all(color: trackBorderColor, width: _trackBorderWidth),
        ),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            AnimatedPositioned(
              duration: duration,
              curve: Curves.easeInOut,
              left: value ? _knobInsetOn : _knobInsetOff,
              top: _knobTop,
              child: Container(
                width: _knobSize,
                height: _knobSize,
                decoration: BoxDecoration(
                  color: colors.bgSurface,
                  shape: BoxShape.circle,
                  border: Border.all(color: knobOutlineColor, width: _trackBorderWidth),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
