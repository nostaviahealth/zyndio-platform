import 'package:flutter/material.dart';

import '../../config/supabase_config.dart';
import '../../widgets/partner_outcomes_consent_card.dart';

/// APP-03 screen. The server checks the current document, version, and that
/// the caller is the patient. This screen does not decide the hash.
class PartnerOutcomesConsentScreen extends StatelessWidget {
  const PartnerOutcomesConsentScreen({super.key, this.onUpdateConsent});

  final PartnerOutcomeConsentUpdater? onUpdateConsent;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Partner outcomes')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          PartnerOutcomesConsentCard(
            initialAuthorized: false,
            onUpdateConsent: onUpdateConsent ?? _persistPartnerOutcomeAuthorisation,
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
