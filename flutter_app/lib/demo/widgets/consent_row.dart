import 'package:flutter/material.dart';

import '../../config/theme.dart';

/// C16 Consent row: checkbox + title/subline + Read/Retry link. Hit area is
/// the whole row (except the link), role checkbox, state announced.
class ConsentRow extends StatelessWidget {
  const ConsentRow({
    super.key,
    required this.title,
    required this.subline,
    required this.checked,
    this.hasError = false,
    this.showRequiredError = false,
    this.onToggle,
    this.onLinkTap,
  });

  final String title;
  final String subline;
  final bool checked;
  final bool hasError;
  final bool showRequiredError;
  final VoidCallback? onToggle;
  final VoidCallback? onLinkTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<ZyndioColors>()!;
    final subtitleText = showRequiredError
        ? 'Required to continue'
        : (hasError ? "Couldn't load this document" : subline);
    final subtitleColor = (hasError || showRequiredError) ? colors.statusCritical : colors.textTertiary;

    return Semantics(
      checked: checked,
      label: title,
      child: InkWell(
        onTap: hasError ? null : onToggle,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: ZyndioSize.rowMin),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: ZyndioSpace.s16,
              vertical: ZyndioSpace.s8,
            ),
            child: Row(
              children: [
                _Checkbox(checked: checked, hasError: showRequiredError, colors: colors),
                const SizedBox(width: ZyndioSpace.s12),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: ZyndioType.headline.copyWith(color: colors.textPrimary)),
                      Semantics(
                        liveRegion: showRequiredError,
                        child: Text(
                          subtitleText,
                          style: ZyndioType.footnote.copyWith(
                            color: subtitleColor,
                            fontWeight: showRequiredError ? FontWeight.w600 : FontWeight.w400,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: onLinkTap,
                  style: TextButton.styleFrom(minimumSize: const Size(ZyndioSize.touchMin, ZyndioSize.touchMin)),
                  child: Text(hasError ? 'Retry' : 'Read'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Checkbox extends StatelessWidget {
  const _Checkbox({required this.checked, required this.hasError, required this.colors});

  final bool checked;
  final bool hasError;
  final ZyndioColors colors;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: Container(
        width: ZyndioSize.checkbox,
        height: ZyndioSize.checkbox,
        decoration: BoxDecoration(
          color: checked ? colors.brandPrimary : colors.bgSurface,
          borderRadius: BorderRadius.circular(6),
          border: checked
              ? null
              : Border.all(
                  color: hasError ? colors.statusCritical : colors.borderStrong,
                  width: ZyndioBorder.control,
                ),
        ),
        child: checked ? Icon(Icons.check, size: 18, color: colors.brandOnPrimary) : null,
      ),
    );
  }
}
