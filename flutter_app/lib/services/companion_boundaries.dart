import 'package:flutter/foundation.dart';

import '../config/supabase_config.dart';

/// APP-09: the companion works inside Zyndio's clinical boundaries. Before a
/// message reaches the AI it is routed:
///   * emergency language  -> emergency guidance on screen + an `emergency`
///     escalation, which alerts the clinic's escalation contact;
///   * a clinical question (dosing, medication changes, side effects,
///     diagnosis) -> handed to the care team as a `clinical_question`
///     escalation; the AI never answers it;
///   * anything else -> the AI companion, as before.
enum CompanionRoute { emergency, careTeam, companion }

final _emergencyPattern = RegExp(
  r"\b(chest pain|heart attack|stroke|suicid\w*|kill myself|end my life|hurt myself|self[- ]harm|"
  r"can'?t breathe|cannot breathe|trouble breathing|bleeding out|unconscious|overdos\w*|"
  r"seizure|anaphyla\w*|emergency|911)\b",
  caseSensitive: false,
);

final _selfHarmPattern = RegExp(
  r'\b(suicid\w*|kill myself|end my life|hurt myself|self[- ]harm)\b',
  caseSensitive: false,
);

final _clinicalPattern = RegExp(
  r'\b(dose|doses|dosing|dosage|prescri\w*|medication|medicine|'
  r'semaglutide|tirzepatide|ozempic|wegovy|mounjaro|zepbound|metformin|'
  r'side effects?|symptoms?|diagnos\w*|should i (?:stop|start|skip|increase|decrease|double)|'
  r'(?:stop|start|skip|increase|decrease|double) (?:my|the) (?:dose|shot|injection|medication|meds|pill))\b',
  caseSensitive: false,
);

CompanionRoute routeCompanionMessage(String text) {
  if (_emergencyPattern.hasMatch(text)) return CompanionRoute.emergency;
  if (_clinicalPattern.hasMatch(text)) return CompanionRoute.careTeam;
  return CompanionRoute.companion;
}

/// Shown when emergency language is detected. US-facing (Zyndio patients are
/// US adults); 988 is added for self-harm language.
String emergencyGuidance(String text) {
  final buffer = StringBuffer(
    'If this is an emergency, call 911 or go to the nearest emergency room now. '
    'I am an AI companion and can\'t help in an emergency. '
    'Your Zyndio care team has been alerted.',
  );
  if (_selfHarmPattern.hasMatch(text)) {
    buffer.write(' If you are thinking about harming yourself, call or text 988 '
        '(Suicide & Crisis Lifeline) any time.');
  }
  return buffer.toString();
}

const careTeamHandoffReply =
    'That\'s a question for your Zyndio care team, so I\'ve passed it to them. '
    'They\'ll get back to you in the app. If it feels urgent, contact your clinic '
    'directly, or call 911 in an emergency.';

const careTeamHandoffFailedReply =
    'That\'s a question for your Zyndio care team, but I couldn\'t reach them just now. '
    'Please contact your clinic directly, or call 911 in an emergency.';

/// Files the escalation for the care team (RLS: the patient's own row; the
/// database sets the clinic and status). Returns false when it couldn't be
/// filed. The message text is never logged.
Future<bool> fileCompanionEscalation(CompanionRoute route, String text) async {
  if (route == CompanionRoute.companion) return false;
  final client = SupabaseConfig.client;
  final patientId = SupabaseConfig.currentUser?.id;
  if (client == null || patientId == null) return false;
  final trimmed = text.trim();
  try {
    await client.from('companion_escalations').insert({
      'patient_id': patientId,
      'kind': route == CompanionRoute.emergency ? 'emergency' : 'clinical_question',
      'question': trimmed.length > 4000 ? trimmed.substring(0, 4000) : trimmed,
    });
    return true;
  } catch (e) {
    debugPrint('Companion escalation could not be filed (${e.runtimeType})');
    return false;
  }
}
