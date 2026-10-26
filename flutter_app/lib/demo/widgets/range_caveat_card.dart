import 'package:flutter/material.dart';

import '../../config/theme.dart';
import 'demo_card.dart';
import 'message_care_team_button.dart';

/// C32-adjacent range caveat card (always visible on the default trend
/// view, T-BIO-02): describes ranges as general defaults the care team will
/// confirm, never a diagnosis. Optional trailing action ("Message care
/// team") for the above-range edge.
class RangeCaveatCard extends StatelessWidget {
  const RangeCaveatCard({super.key, this.onMessageCareTeam});

  final VoidCallback? onMessageCareTeam;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<ZyndioColors>()!;
    return DemoCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline,
              size: ZyndioSize.icon, color: colors.textSecondary),
          const SizedBox(width: ZyndioSpace.s12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'These are general default ranges. Your Zyndio care team will confirm the ranges used for your care.',
                  style:
                      ZyndioType.footnote.copyWith(color: colors.textSecondary),
                ),
                if (onMessageCareTeam != null) ...[
                  const SizedBox(height: ZyndioSpace.s12),
                  MessageCareTeamButton(onPressed: onMessageCareTeam),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
