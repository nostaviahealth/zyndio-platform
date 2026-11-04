import 'package:flutter/material.dart';

/// Callback signature for persisting the patient's APP-03 partner outcome
/// sharing authorisation (e.g. via Supabase RPC
/// `public.set_partner_outcome_authorisation`).
typedef PartnerOutcomeConsentUpdater = Future<void> Function({
  required bool authorized,
  required String consentVersion,
  required String consentText,
});

/// APP-03: Separate, Revocable Authorisation to Share Outcomes with the
/// Body Composition Partner (DEXASCAN).
///
/// Clearly explains to the patient:
/// 1. What is shared (clinician-reviewed milestone outcomes only).
/// 2. Who receives it (the body composition partner, e.g. DEXASCAN).
/// 3. That this authorisation is optional, separate from clinic care, and can
///    be revoked at any time to immediately stop future outcome deliveries.
class PartnerOutcomesConsentCard extends StatefulWidget {
  final bool initialAuthorized;
  final String partnerName;
  final String consentVersion;
  final DateTime? updatedAt;
  final PartnerOutcomeConsentUpdater? onUpdateConsent;

  static const String defaultConsentText =
      'I authorise Zyndio to share my clinician-reviewed milestone outcomes with DEXASCAN.';

  const PartnerOutcomesConsentCard({
    super.key,
    required this.initialAuthorized,
    this.partnerName = 'DEXASCAN',
    this.consentVersion = 'v1.0',
    this.updatedAt,
    this.onUpdateConsent,
  });

  @override
  State<PartnerOutcomesConsentCard> createState() =>
      _PartnerOutcomesConsentCardState();
}

class _PartnerOutcomesConsentCardState
    extends State<PartnerOutcomesConsentCard> {
  late bool _authorized;
  bool _isSaving = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _authorized = widget.initialAuthorized;
  }

  @override
  void didUpdateWidget(covariant PartnerOutcomesConsentCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialAuthorized != widget.initialAuthorized && !_isSaving) {
      _authorized = widget.initialAuthorized;
    }
  }

  String get _consentStatement =>
      'I authorise Zyndio to share my clinician-reviewed milestone outcomes with ${widget.partnerName}.';

  Future<void> _handleToggle(bool nextValue) async {
    if (_isSaving) return;

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    try {
      if (widget.onUpdateConsent != null) {
        await widget.onUpdateConsent!(
          authorized: nextValue,
          consentVersion: widget.consentVersion,
          consentText: _consentStatement,
        );
      }
      if (!mounted) return;
      setState(() {
        _authorized = nextValue;
        _isSaving = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isSaving = false;
        _errorMessage =
            'Could not update your partner sharing preference. Please try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final surfaceColor = isDark ? const Color(0xFF10141F) : Colors.white;
    final borderColor =
        isDark ? const Color(0xFF283042) : const Color(0xFFD8DEE8);
    final primaryText =
        isDark ? const Color(0xFFEEF1F8) : const Color(0xFF030616);
    final secondaryText =
        isDark ? const Color(0xFFA6B0C3) : const Color(0xFF48556A);

    return Semantics(
      container: true,
      label:
          'Body composition partner outcome sharing authorisation (${widget.partnerName})',
      child: Container(
        key: const Key('partner-outcomes-consent-card'),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: surfaceColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: borderColor),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Share milestone outcomes with ${widget.partnerName}',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: primaryText,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        key: const Key('partner-consent-status-badge'),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: _authorized
                              ? const Color(0xFFE6F4EA)
                              : const Color(0xFFF3F5F8),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          _authorized
                              ? 'Authorised (${widget.consentVersion})'
                              : 'Not authorised',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: _authorized
                                ? const Color(0xFF137333)
                                : const Color(0xFF48556A),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                if (_isSaving)
                  const SizedBox(
                    key: Key('partner-consent-saving-indicator'),
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else
                  Switch.adaptive(
                    key: const Key('partner-consent-switch'),
                    value: _authorized,
                    onChanged: _handleToggle,
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              _consentStatement,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: primaryText,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Optional and separate from your clinic care. You can revoke this authorisation at any time; revoking immediately stops future outcome deliveries to ${widget.partnerName} and does not affect your clinical treatment.',
              key: const Key('partner-consent-revocation-disclosure'),
              style: TextStyle(
                fontSize: 13,
                height: 1.45,
                color: secondaryText,
              ),
            ),
            if (_errorMessage != null) ...[
              const SizedBox(height: 12),
              Container(
                key: const Key('partner-consent-error-banner'),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFFCE8E6),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _errorMessage!,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFFB31412),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                key: const Key('partner-consent-action-button'),
                onPressed: _isSaving ? null : () => _handleToggle(!_authorized),
                child: Text(
                  _authorized
                      ? 'Revoke authorisation'
                      : 'Authorise outcome sharing',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
