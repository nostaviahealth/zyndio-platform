import 'package:flutter/material.dart';

import '../../config/theme.dart';

/// Compact "Message care team" pill, shared by the default-state caveat card
/// and the above-range edge so both hug their label instead of stretching to
/// the width of their parent.
class MessageCareTeamButton extends StatelessWidget {
  const MessageCareTeamButton({super.key, required this.onPressed});

  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<ZyndioColors>()!;
    return Align(
      alignment: Alignment.centerLeft,
      child: SizedBox(
        height: ZyndioSize.buttonSmallHeight,
        child: FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: colors.actionSecondary,
            foregroundColor: colors.actionOnSecondary,
            textStyle: ZyndioType.subhead.copyWith(fontWeight: FontWeight.w600),
            padding: const EdgeInsets.symmetric(horizontal: ZyndioSpace.s24),
          ),
          onPressed: onPressed,
          child: const Text('Message care team'),
        ),
      ),
    );
  }
}
