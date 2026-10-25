import 'package:flutter/material.dart';

import '../../config/theme.dart';

/// C29 Segmented control: full width x44, pill track bg.sunken, segments
/// equal width, role tablist. The demo trend ranges (3M/6M/1Y/All) don't
/// change the fixture data shown — selecting a segment is a visual-only
/// affordance here, same as the other demo screens' non-wired controls.
class SegmentedControl extends StatelessWidget {
  const SegmentedControl({
    super.key,
    required this.segments,
    required this.selectedIndex,
    this.onChanged,
  });

  final List<String> segments;
  final int selectedIndex;
  final ValueChanged<int>? onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<ZyndioColors>()!;
    return Semantics(
      container: true,
      label: 'Trend range',
      child: Container(
        height: ZyndioSize.segmentedHeight,
        padding: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          color: colors.bgSunken,
          borderRadius: BorderRadius.circular(ZyndioRadius.button),
        ),
        child: Row(
          children: [
            for (var i = 0; i < segments.length; i++)
              Expanded(
                child: _Segment(
                  label: segments[i],
                  selected: i == selectedIndex,
                  onTap: () => onChanged?.call(i),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Segment extends StatelessWidget {
  const _Segment({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<ZyndioColors>()!;
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(ZyndioRadius.button),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: ZyndioSize.touchMin),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: selected ? colors.bgSurface : Colors.transparent,
              borderRadius: BorderRadius.circular(ZyndioRadius.button),
              boxShadow: selected ? ZyndioShadow.cardFor(Theme.of(context).brightness) : null,
            ),
            child: Center(
              child: ExcludeSemantics(
                child: Text(
                  label,
                  style: ZyndioType.footnote.copyWith(
                    fontWeight: FontWeight.w600,
                    color: selected ? colors.textPrimary : colors.textSecondary,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
