import 'package:flutter/material.dart';

import '../../config/theme.dart';
import 'demo_card.dart';
import 'zyndio_switch.dart';

/// C17 Optional consent card: title + body + trailing switch. Hit area is
/// the whole card, role switch, off by default.
class OptionalCard extends StatelessWidget {
  const OptionalCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.value,
    this.onChanged,
  });

  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<ZyndioColors>()!;
    return Semantics(
      toggled: value,
      label: title,
      child: InkWell(
        onTap: () => onChanged?.call(!value),
        borderRadius: BorderRadius.circular(ZyndioRadius.lg),
        child: DemoCard(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: ZyndioType.headline.copyWith(color: colors.textPrimary)),
                    const SizedBox(height: ZyndioSpace.s4),
                    Text(subtitle, style: ZyndioType.subhead.copyWith(color: colors.textSecondary)),
                  ],
                ),
              ),
              const SizedBox(width: ZyndioSpace.s12),
              // A token-driven switch (not Material's Switch) so the off-state
              // knob stays an outlined, full-height circle in dark mode —
              // Material's Switch can't draw that and shrinks the off thumb
              // to a small dot. Colour comes entirely from ZyndioColors.
              ExcludeSemantics(
                child: IgnorePointer(
                  child: ZyndioSwitch(value: value, onChanged: (_) {}),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
