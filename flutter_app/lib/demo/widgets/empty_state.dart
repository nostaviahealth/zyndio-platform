import 'package:flutter/material.dart';

import '../../config/theme.dart';
import 'demo_card.dart';

/// C37 Empty state: inside a card, padding 32 24, centred. Always gives the
/// next step via [message].
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<ZyndioColors>()!;
    return DemoCard(
      padding: const EdgeInsets.symmetric(horizontal: ZyndioSpace.s24, vertical: ZyndioSpace.s32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: ZyndioSize.icon, color: colors.textTertiary),
          const SizedBox(height: ZyndioSpace.s8),
          Text(
            title,
            textAlign: TextAlign.center,
            style: ZyndioType.headline.copyWith(color: colors.textPrimary),
          ),
          const SizedBox(height: ZyndioSpace.s4),
          Text(
            message,
            textAlign: TextAlign.center,
            style: ZyndioType.subhead.copyWith(color: colors.textSecondary),
          ),
        ],
      ),
    );
  }
}
