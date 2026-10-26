import 'package:flutter/material.dart';

import '../../config/theme.dart';

/// C26 Identity check line: a 24pt-high success row confirming the report's
/// name/DOB match the signed-in account. A mismatch never uses this widget —
/// it shows a warning [ZyndioBanner] instead.
class IdentityLine extends StatelessWidget {
  const IdentityLine({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<ZyndioColors>()!;
    return Row(
      children: [
        Icon(Icons.check, size: 20, color: colors.statusSuccess),
        const SizedBox(width: ZyndioSpace.s8),
        Expanded(
          child: Text(
            message,
            style: ZyndioType.subhead.copyWith(color: colors.statusSuccess, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }
}
