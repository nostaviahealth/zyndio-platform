import 'package:flutter/material.dart';

import '../../config/supabase_config.dart';
import '../../widgets/partner_outcomes_consent_card.dart';

/// APP-03 screen. The server checks the current document, version, and that
/// the caller is the patient. This screen does not decide the hash.
class PartnerOutcomesConsentScreen extends StatefulWidget {
  const PartnerOutcomesConsentScreen({super.key, this.onUpdateConsent});

  final PartnerOutcomeConsentUpdater? onUpdateConsent;

  @override
  State<PartnerOutcomesConsentScreen> createState() =>
      _PartnerOutcomesConsentScreenState();
}

class _PartnerOutcomesConsentScreenState
    extends State<PartnerOutcomesConsentScreen> {
  bool _authorized = false;
  String _consentVersion = 'v1.0';
  DateTime? _updatedAt;

  @override
  void initState() {
    super.initState();
    _loadCurrentAuthorisation();
  }

  Future<void> _loadCurrentAuthorisation() async {
    final client = SupabaseConfig.client;
    final user = client?.auth.currentUser;
    if (client == null || user == null) return;
    try {
      final row = await client
          .from('partner_outcome_authorisations')
          .select('authorized, consent_version, updated_at, revoked_at')
          .eq('patient_id', user.id)
          .maybeSingle();
      if (!mounted || row == null) return;
      final isAuth = (row['authorized'] as bool? ?? false) &&
          row['revoked_at'] == null;
      final ver = (row['consent_version'] as String?)?.trim();
      final rawUpdated = row['updated_at'] as String?;
      setState(() {
        _authorized = isAuth;
        if (ver != null && ver.isNotEmpty) {
          _consentVersion = ver;
        }
        if (rawUpdated != null) {
          _updatedAt = DateTime.tryParse(rawUpdated);
        }
      });
    } catch (_) {
      // Fall back to default state if offline or unlinked.
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Partner outcomes')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          PartnerOutcomesConsentCard(
            initialAuthorized: _authorized,
            consentVersion: _consentVersion,
            updatedAt: _updatedAt,
            onUpdateConsent:
                widget.onUpdateConsent ?? _persistPartnerOutcomeAuthorisation,
          ),
        ],
      ),
    );
  }
}

Future<void> _persistPartnerOutcomeAuthorisation({
  required bool authorized,
  required String consentVersion,
  required String consentText,
}) async {
  final client = SupabaseConfig.client;
  if (client == null || client.auth.currentUser == null) {
    throw Exception('Sign in is required before this authorisation can be saved.');
  }
  await client.rpc('set_partner_outcome_authorisation', params: {
    'p_authorized': authorized,
    'p_consent_version': consentVersion,
    'p_consent_text': consentText,
  });
}
