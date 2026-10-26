import 'package:flutter/material.dart';

import '../../config/theme.dart';
import 'demo_card.dart';

/// C12 Info card: full width, padding 16, icon 24 + gap 12, static.
class InfoCard extends StatelessWidget {
  const InfoCard({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<ZyndioColors>()!;
    return DemoCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, size: ZyndioSize.icon, color: colors.textSecondary),
          const SizedBox(width: ZyndioSpace.s12),
          Expanded(
            child: Text(
              message,
              style: ZyndioType.subhead.copyWith(color: colors.textSecondary),
            ),
          ),
        ],
      ),
    );
  }
}
