import 'package:flutter/material.dart';

import '../config/theme.dart';
import 'tc025/tc025_widgets.dart';

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
    final c = context.zc;
    final z = context.z25;

    return Semantics(
      container: true,
      label:
          'Body composition partner outcome sharing authorisation (${widget.partnerName})',
      child: Container(
        key: const Key('partner-outcomes-consent-card'),
        padding: const EdgeInsets.all(20),
        decoration: zyndioCard(context, radius: 22),
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
                          fontFamily: ZyndioType.family,
                          fontSize: 17,
                          height: 24 / 17,
                          fontWeight: FontWeight.w600,
                          letterSpacing: -0.2,
                          color: c.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        key: const Key('partner-consent-status-badge'),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: _authorized
                              ? c.statusSuccessSubtle
                              : z.badgeNeutralBg,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          _authorized
                              ? 'Authorised (${widget.consentVersion})'
                              : 'Not authorised',
                          style: TextStyle(
                            fontFamily: ZyndioType.family,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: _authorized
                                ? c.statusSuccess
                                : z.badgeNeutralText,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                if (_isSaving)
                  Padding(
                    padding: const EdgeInsets.all(4),
                    child: SizedBox(
                      key: const Key('partner-consent-saving-indicator'),
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: c.brandPrimary,
                      ),
                    ),
                  )
                else
                  Switch.adaptive(
                    key: const Key('partner-consent-switch'),
                    value: _authorized,
                    onChanged: _handleToggle,
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              _consentStatement,
              style: TextStyle(
                fontFamily: ZyndioType.family,
                fontSize: 15,
                height: 22 / 15,
                fontWeight: FontWeight.w500,
                color: c.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Optional and separate from your clinic care. You can revoke this authorisation at any time; revoking immediately stops future outcome deliveries to ${widget.partnerName} and does not affect your clinical treatment.',
              key: const Key('partner-consent-revocation-disclosure'),
              style: TextStyle(
                fontFamily: ZyndioType.family,
                fontSize: 14,
                height: 20 / 14,
                color: c.textSecondary,
              ),
            ),
            if (_errorMessage != null) ...[
              const SizedBox(height: 12),
              Container(
                key: const Key('partner-consent-error-banner'),
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: z.critBg,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  _errorMessage!,
                  style: TextStyle(
                    fontFamily: ZyndioType.family,
                    fontSize: 14,
                    height: 20 / 14,
                    color: z.critText,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 16),
            ZyndioOutlineButton(
              key: const Key('partner-consent-action-button'),
              onTap: _isSaving ? null : () => _handleToggle(!_authorized),
              label: _authorized
                  ? 'Revoke authorisation'
                  : 'Authorise outcome sharing',
            ),
          ],
        ),
      ),
    );
  }
}
