import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../config/theme.dart';

/// C11 Code input: one text field (oneTimeCode autofill) painted as 6 cells.
/// A screen reader sees a single field, "Verification code, n of 6 digits
/// entered" — not six separate inputs.
class CodeInput extends StatefulWidget {
  const CodeInput({
    super.key,
    required this.value,
    this.onChanged,
    this.autofocus = false,
    this.hasError = false,
  });

  final String value;
  final ValueChanged<String>? onChanged;
  final bool autofocus;
  final bool hasError;

  static const int cellCount = 6;

  @override
  State<CodeInput> createState() => _CodeInputState();
}

class _CodeInputState extends State<CodeInput> {
  late final TextEditingController _controller = TextEditingController(text: widget.value);
  final FocusNode _focusNode = FocusNode();

  @override
  void didUpdateWidget(covariant CodeInput oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value != _controller.text) {
      _controller.value = TextEditingValue(
        text: widget.value,
        selection: TextSelection.collapsed(offset: widget.value.length),
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<ZyndioColors>()!;
    final filledCount = widget.value.length;
    return Semantics(
      textField: true,
      label: 'Verification code, $filledCount of ${CodeInput.cellCount} digits entered',
      child: SizedBox(
        height: ZyndioSize.otpCellHeight,
        child: Stack(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: List.generate(CodeInput.cellCount, (i) {
                final isCurrent = i == filledCount && filledCount < CodeInput.cellCount;
                final char = i < widget.value.length ? widget.value[i] : '';
                final borderColor = widget.hasError
                    ? colors.statusCritical
                    : (isCurrent ? colors.focusRing : colors.borderStrong);
                return ExcludeSemantics(
                  child: Container(
                    width: ZyndioSize.otpCellWidth,
                    height: ZyndioSize.otpCellHeight,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: colors.bgSurface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: borderColor,
                        width: isCurrent || widget.hasError ? ZyndioBorder.focus : ZyndioBorder.hairline,
                      ),
                    ),
                    child: Text(
                      char,
                      style: ZyndioType.headline.copyWith(
                        fontSize: 24,
                        fontWeight: FontWeight.w600,
                        color: colors.textPrimary,
                        fontFeatures: ZyndioType.tabular,
                      ),
                    ),
                  ),
                );
              }),
            ),
            Positioned.fill(
              child: ExcludeSemantics(
                child: Opacity(
                  opacity: 0,
                  child: TextField(
                    controller: _controller,
                    focusNode: _focusNode,
                    autofocus: widget.autofocus,
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(CodeInput.cellCount),
                    ],
                    autofillHints: const [AutofillHints.oneTimeCode],
                    decoration: const InputDecoration(counterText: '', border: InputBorder.none),
                    onChanged: widget.onChanged,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
