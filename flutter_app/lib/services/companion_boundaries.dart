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

final _emergencyPhrases = <RegExp>[
  RegExp(r'\bchest pain\b', caseSensitive: false),
  RegExp(r'\bchest hurts\b', caseSensitive: false),
  RegExp(r'\bheart attack\b', caseSensitive: false),
  RegExp(r'\bstroke\b', caseSensitive: false),
  RegExp(r'\bsuicid\w*\b', caseSensitive: false),
  RegExp(r'\bkill myself\b', caseSensitive: false),
  RegExp(r'\bend my life\b', caseSensitive: false),
  RegExp(r'\bhurt myself\b', caseSensitive: false),
  RegExp(r'\bself[- ]harm\b', caseSensitive: false),
  RegExp(r'\bwant to die\b', caseSensitive: false),
  RegExp(r"\bcan'?t breathe\b", caseSensitive: false),
  RegExp(r'\bcannot breathe\b', caseSensitive: false),
  RegExp(r'\btrouble breathing\b', caseSensitive: false),
  RegExp(r"\bcan'?t catch my breath\b", caseSensitive: false),
  RegExp(r'\bcannot catch my breath\b', caseSensitive: false),
  RegExp(r'\bshortness of breath\b', caseSensitive: false),
  RegExp(r'\bbleeding out\b', caseSensitive: false),
  RegExp(r'\bunconscious\b', caseSensitive: false),
  RegExp(r'\boverdos\w*\b', caseSensitive: false),
  RegExp(r'\btook all my pills\b', caseSensitive: false),
  RegExp(r'\bseizure\b', caseSensitive: false),
  RegExp(r'\banaphyla\w*\b', caseSensitive: false),
  RegExp(r'\bemergency\b', caseSensitive: false),
  RegExp(r'\b911\b', caseSensitive: false),
];

final _negationBefore = RegExp(
  r"(?:no|not|without|never|don'?t|do not|doesn'?t|does not)\b(?:\s+\w+){0,4}\s*$",
  caseSensitive: false,
);

final _selfHarmPattern = RegExp(
  r"\b(suicid\w*|kill myself|end my life|hurt myself|self[- ]harm|want to die)\b",
  caseSensitive: false,
);

bool textLooksLikeEmergency(String text) {
  for (final phrase in _emergencyPhrases) {
    for (final match in phrase.allMatches(text)) {
      final hit = match.group(0)!.toLowerCase();
      final startsWithCant = hit.startsWith("can't") || hit.startsWith('cant') || hit.startsWith('cannot');
      if (!startsWithCant && _negationBefore.hasMatch(text.substring(0, match.start))) {
        continue;
      }
      return true;
    }
  }
  return false;
}

final _clinicalPattern = RegExp(
  r'\b(dose|doses|dosing|dosage|prescri\w*|medication|medicine|'
  r'semaglutide|tirzepatide|ozempic|wegovy|mounjaro|zepbound|metformin|'
  r'side effects?|symptoms?|diagnos\w*|should i (?:stop|start|skip|increase|decrease|double)|'
  r'(?:stop|start|skip|increase|decrease|double) (?:my|the) (?:dose|shot|injection|medication|meds|pill))\b',
  caseSensitive: false,
);

CompanionRoute routeCompanionMessage(String text) {
  if (textLooksLikeEmergency(text)) return CompanionRoute.emergency;
  if (_clinicalPattern.hasMatch(text)) return CompanionRoute.careTeam;
  return CompanionRoute.companion;
}

/// One turn the model, the session summary, and a retry are allowed to see.
class CompanionTurn {
  const CompanionTurn({required this.role, required this.text, required this.withheld});

  final String role;
  final String text;
  final bool withheld;
}

/// Escalated turns never enter a model request, a summary, or a retry.
List<CompanionTurn> turnsForModel(List<CompanionTurn> turns) =>
    [for (final turn in turns) if (!turn.withheld) turn];

/// Persisted text for an escalated turn is empty, so a reload cannot replay it.
String textForPersistence({required String text, required bool withheld}) => withheld ? '' : text;

/// Emergency guidance does not name a country or a hotline. The product has
/// no configured geography for emergency numbers. [filed] only says whether a
/// row was saved. It never claims a person was alerted.
String emergencyGuidance(String text, {required bool filed}) {
  final buffer = StringBuffer(
    'If this is an emergency, contact your local emergency services or go to the nearest emergency room now. '
    'I am an AI companion and cannot help in an emergency. ',
  );
  if (filed) {
    buffer.write(
      'I saved a copy for your care team. That does not mean anyone has seen it, '
      'and it is not confirmation that an alert was delivered.',
    );
  } else {
    buffer.write(
      'I could not save this for your care team. Nothing was filed and nobody was notified.',
    );
  }
  if (_selfHarmPattern.hasMatch(text)) {
    buffer.write(' If you are thinking about harming yourself, contact local emergency or crisis services now.');
  }
  return buffer.toString();
}

const careTeamHandoffReply =
    'That\'s a question for your Zyndio care team, so I\'ve passed it to them. '
    'They\'ll get back to you in the app. If it feels urgent, contact your clinic '
    'directly, or contact local emergency services.';

const careTeamHandoffFailedReply =
    'That\'s a question for your Zyndio care team, but I couldn\'t reach them just now. '
    'Please contact your clinic directly, or contact local emergency services.';

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
