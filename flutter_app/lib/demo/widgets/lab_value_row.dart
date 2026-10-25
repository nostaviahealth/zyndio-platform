import 'package:flutter/material.dart';

import '../../config/theme.dart';
import 'badge.dart';

/// C27 Lab value row: name on the left, headline value + footnote unit on
/// the right (tabular figures). A value with [needsReviewReason] gets the
/// "Needs review" badge and reason text under the name — it never hides or
/// alters the extracted number itself.
class LabValueRow extends StatelessWidget {
  const LabValueRow({
    super.key,
    required this.name,
    required this.value,
    required this.unit,
    this.needsReviewReason,
  });

  final String name;
  final String value;
  final String unit;
  final String? needsReviewReason;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<ZyndioColors>()!;
    final reason = needsReviewReason;
    final needsReview = reason != null;
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: ZyndioSize.rowMin),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: ZyndioSpace.s16, vertical: ZyndioSpace.s8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(name, style: ZyndioType.body.copyWith(color: colors.textPrimary)),
                  if (needsReview) ...[
                    const SizedBox(height: ZyndioSpace.s4),
                    Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: ZyndioSpace.s8,
                      children: [
                        const ZyndioBadge(label: 'Needs review', variant: BadgeVariant.warn),
                        Text(reason, style: ZyndioType.footnote.copyWith(color: colors.textTertiary)),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: ZyndioSpace.s12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(value, style: ZyndioType.numeric(ZyndioType.headline).copyWith(color: colors.textPrimary)),
                const SizedBox(width: ZyndioSpace.s4),
                Text(unit, style: ZyndioType.footnote.copyWith(color: colors.textTertiary)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
