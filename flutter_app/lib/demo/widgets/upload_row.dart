import 'package:flutter/material.dart';

import '../../config/theme.dart';
import 'badge.dart';
import 'progress_bar.dart';

/// C21 Upload status row: leading icon/spinner slot (24), title + status
/// (footnote), trailing badge or Retry link. [progress] adds the 4pt
/// determinate bar 8 below, for the "uploading" state.
class UploadRow extends StatelessWidget {
  const UploadRow({
    super.key,
    required this.title,
    required this.status,
    required this.leading,
    this.badgeLabel,
    this.badgeVariant,
    this.progress,
    this.onRetry,
  });

  final String title;
  final String status;
  final Widget leading;
  final String? badgeLabel;
  final BadgeVariant? badgeVariant;
  final double? progress;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<ZyndioColors>()!;
    return Semantics(
      label: '$title, $status',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(minHeight: ZyndioSize.rowMin),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: ZyndioSpace.s16, vertical: ZyndioSpace.s8),
              child: Row(
                children: [
                  SizedBox(width: ZyndioSize.icon, height: ZyndioSize.icon, child: leading),
                  const SizedBox(width: ZyndioSpace.s12),
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title, style: ZyndioType.headline.copyWith(color: colors.textPrimary)),
                        Text(status, style: ZyndioType.footnote.copyWith(color: colors.textTertiary)),
                      ],
                    ),
                  ),
                  if (badgeLabel != null) ...[
                    const SizedBox(width: ZyndioSpace.s12),
                    ZyndioBadge(label: badgeLabel!, variant: badgeVariant ?? BadgeVariant.brand),
                  ],
                  if (onRetry != null)
                    TextButton(
                      onPressed: onRetry,
                      style: TextButton.styleFrom(
                        minimumSize: const Size(ZyndioSize.touchMin, ZyndioSize.touchMin),
                      ),
                      child: const Text('Retry'),
                    ),
                ],
              ),
            ),
          ),
          if (progress != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(ZyndioSpace.s16, 0, ZyndioSpace.s16, ZyndioSpace.s8),
              child: ProgressBar(value: progress!),
            ),
        ],
      ),
    );
  }
}
