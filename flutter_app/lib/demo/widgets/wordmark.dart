import 'package:flutter/material.dart';

import '../../config/theme.dart';
import '../demo_build_flag.dart';
import 'dashed_border.dart';

/// C02 Wordmark (PLACEHOLDER). Stands in until Zyndio supplies official
/// brand assets; swapping the brand means replacing this widget wholesale.
class Wordmark extends StatelessWidget {
  const Wordmark({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<ZyndioColors>()!;
    return Semantics(
      label: 'Zyndio',
      container: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              ExcludeSemantics(
                child: Text(
                  'ZYNDIO',
                  style: const TextStyle(
                    fontFamily: ZyndioType.family,
                    fontSize: 26,
                    height: 32 / 26,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 26 * 0.06,
                  ).copyWith(color: colors.textPrimary),
                ),
              ),
              const SizedBox(width: ZyndioSpace.s8),
              ExcludeSemantics(
                excluding: !kDemoBuild,
                child: DashedRoundedBorder(
                  color: colors.borderStrong,
                  radius: 4,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: Text(
                      'PLACEHOLDER',
                      style: const TextStyle(
                        fontFamily: ZyndioType.family,
                        fontSize: 10,
                        height: 16 / 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 10 * 0.08,
                      ).copyWith(color: colors.textSecondary),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: ZyndioSpace.s4),
          ExcludeSemantics(
            child: Text(
              'GLP-1 WEIGHT LOSS CARE',
              style: const TextStyle(
                fontFamily: ZyndioType.family,
                fontSize: 11,
                height: 16 / 11,
                fontWeight: FontWeight.w500,
                letterSpacing: 11 * 0.2,
              ).copyWith(color: colors.textTertiary),
            ),
          ),
        ],
      ),
    );
  }
}
