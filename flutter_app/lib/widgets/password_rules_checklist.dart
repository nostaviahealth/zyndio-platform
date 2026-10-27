import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../config/theme.dart';

/// Port of components/admin-auth/PasswordRules.tsx for the patient app
/// (TC-012 Ava sign-up/reset screens): same five rules, same symbol set, so
/// the client-side checklist never disagrees with GoTrue's
/// password_requirements = lower_upper_letters_digits_symbols
/// (supabase/config.toml) or public.password_is_blocked().
const int kMinPasswordLength = 12;

final RegExp _symbolRe = RegExp(r'''[!@#$%^&*()_+\-=\[\]{};':"\\|,.<>/?`~]''');

const Color _ruleMetGreen = Color(0xFF22C55E);

class PasswordRuleChecks {
  const PasswordRuleChecks({
    required this.length,
    required this.hasCase,
    required this.digit,
    required this.symbol,
  });

  final bool length;
  final bool hasCase;
  final bool digit;
  final bool symbol;

  bool get allClientRulesMet => length && hasCase && digit && symbol;
}

PasswordRuleChecks checkPasswordRules(String password) {
  return PasswordRuleChecks(
    length: password.length >= kMinPasswordLength,
    hasCase: password.contains(RegExp(r'[a-z]')) && password.contains(RegExp(r'[A-Z]')),
    digit: password.contains(RegExp(r'[0-9]')),
    symbol: _symbolRe.hasMatch(password),
  );
}

/// Live checklist shown under the password field. Collapses to a single
/// "Your password meets every rule" line once every client-checkable rule
/// passes (Ava copy rule 2) - "not commonly used" only turns green once the
/// server has confirmed it (passed in via [commonPasswordOk]; null = not
/// checked yet, so it stays grey).
class PasswordRulesChecklist extends StatelessWidget {
  const PasswordRulesChecklist({
    super.key,
    required this.password,
    this.commonPasswordOk,
    this.showInvalid = false,
  });

  final String password;
  final bool? commonPasswordOk;
  final bool showInvalid;

  @override
  Widget build(BuildContext context) {
    final nc = context.nc;
    final checks = checkPasswordRules(password);

    if (checks.allClientRulesMet && commonPasswordOk == true) {
      return const Text(
        'Your password meets every rule',
        style: TextStyle(color: _ruleMetGreen, fontSize: 13),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        _rule(nc, '12+ characters', checks.length),
        _rule(nc, 'Upper and lower case letters', checks.hasCase),
        _rule(nc, 'A number', checks.digit),
        _rule(nc, 'A symbol', checks.symbol),
        _rule(nc, 'Not commonly used', commonPasswordOk, serverChecked: true),
      ],
    );
  }

  Widget _rule(BrandThemeColors nc, String label, bool? met, {bool serverChecked = false}) {
    final failedOnSubmit = showInvalid && met == false;
    final color = met == true
        ? _ruleMetGreen
        : failedOnSubmit
            ? BrandColors.red500
            : nc.textTertiary;
    final icon = met == true
        ? LucideIcons.check
        : failedOnSubmit
            ? LucideIcons.x
            : LucideIcons.circle;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 8),
          Text(label, style: TextStyle(color: color, fontSize: 13)),
        ],
      ),
    );
  }
}
