import 'package:flutter/material.dart';

import '../../config/theme.dart';
import 'badge.dart';

/// C28 Metric header: hero value 44/48 tabular + unit title3, trailing badge
/// ("Within default range" / "Above default range" / "Baseline"), meta
/// footnote underneath (e.g. "Oct 14, 2026 · −0.7 points since baseline").
class MetricHeader extends StatelessWidget {
  const MetricHeader({
    super.key,
    required this.value,
    required this.unit,
    required this.badgeLabel,
    required this.badgeVariant,
    required this.meta,
  });

  final String value;
  final String unit;
  final String badgeLabel;
  final BadgeVariant badgeVariant;
  final String meta;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<ZyndioColors>()!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              value,
              style: ZyndioType.numericHero.copyWith(color: colors.textPrimary),
            ),
            const SizedBox(width: ZyndioSpace.s8),
            Padding(
              padding: const EdgeInsets.only(bottom: ZyndioSpace.s4 + 2),
              child: Text(
                unit,
                style: ZyndioType.title3.copyWith(color: colors.textSecondary),
              ),
            ),
            const Spacer(),
            Padding(
              padding: const EdgeInsets.only(bottom: ZyndioSpace.s8),
              child: ZyndioBadge(label: badgeLabel, variant: badgeVariant),
            ),
          ],
        ),
        const SizedBox(height: ZyndioSpace.s4),
        Text(meta, style: ZyndioType.footnote.copyWith(color: colors.textTertiary)),
      ],
    );
  }
}
