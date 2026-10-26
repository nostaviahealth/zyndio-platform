import 'package:flutter/material.dart';

import '../../config/theme.dart';
import 'demo_card.dart';

/// C25 Document summary card: thumbnail + title/lab name/page count/
/// collected date. Static — the report metadata never changes once uploaded.
class DocSummaryCard extends StatelessWidget {
  const DocSummaryCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.collectedLabel,
  });

  final String title;
  final String subtitle;
  final String collectedLabel;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<ZyndioColors>()!;
    return DemoCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 52,
            decoration: BoxDecoration(color: colors.bgSunken, borderRadius: BorderRadius.circular(8)),
            child: Icon(Icons.description_outlined, color: colors.textTertiary, size: ZyndioSize.iconSmall),
          ),
          const SizedBox(width: ZyndioSpace.s12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: ZyndioType.headline.copyWith(color: colors.textPrimary)),
                const SizedBox(height: ZyndioSpace.s4),
                Text(subtitle, style: ZyndioType.footnote.copyWith(color: colors.textTertiary)),
                Text(collectedLabel, style: ZyndioType.footnote.copyWith(color: colors.textTertiary)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
