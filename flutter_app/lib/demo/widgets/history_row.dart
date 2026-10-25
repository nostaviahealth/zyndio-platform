import 'package:flutter/material.dart';

import '../../config/theme.dart';

/// C33 History row: min 48, date body text.primary, value headline tabular,
/// unit footnote text.tertiary. Gives the same data as the chart, as text.
class HistoryRow extends StatelessWidget {
  const HistoryRow({super.key, required this.date, required this.value, required this.unit});

  final String date;
  final String value;
  final String unit;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<ZyndioColors>()!;
    return Semantics(
      label: '$date, $value $unit',
      child: ExcludeSemantics(
        child: Container(
          constraints: const BoxConstraints(minHeight: ZyndioSize.historyRowMin),
          padding: const EdgeInsets.symmetric(horizontal: ZyndioSpace.s16, vertical: ZyndioSpace.s8),
          child: Row(
            children: [
              Expanded(
                child: Text(date, style: ZyndioType.body.copyWith(color: colors.textPrimary)),
              ),
              Text(
                value,
                style: ZyndioType.headline.copyWith(
                  color: colors.textPrimary,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              const SizedBox(width: ZyndioSpace.s4),
              SizedBox(
                width: ZyndioSpace.s16,
                child: Text(unit, style: ZyndioType.footnote.copyWith(color: colors.textTertiary)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
