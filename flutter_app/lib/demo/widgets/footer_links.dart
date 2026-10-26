import 'package:flutter/material.dart';

import '../../config/theme.dart';

/// C13 Footer links: 3 links >=44 high, pinned 28 from the bottom.
class FooterLinks extends StatelessWidget {
  const FooterLinks({
    super.key,
    this.onTerms,
    this.onPrivacy,
    this.onHelp,
  });

  final VoidCallback? onTerms;
  final VoidCallback? onPrivacy;
  final VoidCallback? onHelp;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<ZyndioColors>()!;
    Widget link(String label, VoidCallback? onTap) {
      return TextButton(
        onPressed: onTap ?? () {},
        style: TextButton.styleFrom(foregroundColor: colors.textSecondary),
        child: Text(label, style: ZyndioType.subhead.copyWith(color: colors.textSecondary)),
      );
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        link('Terms', onTerms),
        link('Privacy', onPrivacy),
        link('Help', onHelp),
      ],
    );
  }
}
