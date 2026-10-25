import 'package:flutter/material.dart';

import '../../config/theme.dart';

/// C03 Fictional data tag: demo-only marker, removed for production builds.
class FictionalDataTag extends StatelessWidget {
  const FictionalDataTag({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<ZyndioColors>()!;
    return Semantics(
      label: 'Fictional data',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: ZyndioSpace.s8, vertical: 2),
        decoration: BoxDecoration(
          color: colors.statusWarningSubtle,
          borderRadius: BorderRadius.circular(ZyndioRadius.pill),
        ),
        child: Text(
          'FICTIONAL DATA',
          style: ZyndioType.caption.copyWith(color: colors.statusWarning, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}
