import 'package:flutter/material.dart';

import '../../config/theme.dart';
import 'demo_card.dart';

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
              ExcludeSemantics(child: _SwitchVisual(value: value, colors: colors)),
            ],
          ),
        ),
      ),
    );
  }
}

class _SwitchVisual extends StatelessWidget {
  const _SwitchVisual({required this.value, required this.colors});

  final bool value;
  final ZyndioColors colors;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      width: ZyndioSize.switchWidth,
      height: ZyndioSize.switchHeight,
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: value ? colors.brandPrimary : colors.bgSunken,
        borderRadius: BorderRadius.circular(ZyndioSize.switchHeight / 2),
        border: value ? null : Border.all(color: colors.borderStrong, width: ZyndioBorder.hairline),
      ),
      child: AnimatedAlign(
        duration: const Duration(milliseconds: 150),
        alignment: value ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          width: ZyndioSize.switchHeight - 4,
          height: ZyndioSize.switchHeight - 4,
          decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
        ),
      ),
    );
  }
}
