import React from 'react';
import { Check } from 'lucide-react';

// 01-sign-in/invite password rules copy (27 Oct 2026, Henry's M8 ruling).
// Shared by invite accept and, once they exist, reset/change password
// screens (TC-011 reuses these helpers - see admin README "Password rules
// copy"). Rule 5 ("not a commonly used password") can't be known
// client-side; it is server-checked (password_is_blocked via accept-invite
// / change-password) and stays grey until the server has had a chance to
// say otherwise.
export interface PasswordRuleChecks {
  length: boolean;
  case: boolean;
  digit: boolean;
  symbol: boolean;
}

// Mirrors GoTrue's password_requirements = "lower_upper_letters_digits_symbols"
// symbol set exactly (supabase/config.toml), so a password the UI marks as
// meeting every rule is never rejected by GoTrue for a character class it
// didn't check for.
const SYMBOL_RE = /[!@#$%^&*()_+\-=[\]{};':"\\|,.<>/?`~]/;

export const MIN_PASSWORD_LENGTH = 12;

export function checkPasswordRules(password: string): PasswordRuleChecks {
  return {
    length: password.length >= MIN_PASSWORD_LENGTH,
    case: /[a-z]/.test(password) && /[A-Z]/.test(password),
    digit: /[0-9]/.test(password),
    symbol: SYMBOL_RE.test(password),
  };
}

export function allClientRulesMet(checks: PasswordRuleChecks): boolean {
  return checks.length && checks.case && checks.digit && checks.symbol;
}

const RULES: { key: keyof PasswordRuleChecks; label: string }[] = [
  { key: 'length', label: 'At least 12 characters' },
  { key: 'case', label: 'An uppercase and a lowercase letter' },
  { key: 'digit', label: 'A number' },
  { key: 'symbol', label: 'A symbol, like ! or #' },
];

export const COMMON_PASSWORD_RULE_LABEL = 'Not a commonly used password';

interface PasswordRulesProps {
  password: string;
  // True once the person has tried to submit at least once - unmet rules
  // turn red instead of staying grey.
  submitted: boolean;
  // True once the server has refused the password as too common
  // (password_too_common). Stays grey until then - the client can't know.
  tooCommon: boolean;
}

const PasswordRules: React.FC<PasswordRulesProps> = ({ password, submitted, tooCommon }) => {
  const checks = checkPasswordRules(password);

  return (
    <ul className="space-y-1 text-sm">
      {RULES.map((rule) => {
        const met = checks[rule.key];
        return (
          <li
            key={rule.key}
            className={`flex items-center gap-1.5 ${
              met ? 'text-emerald-600' : submitted ? 'text-red-600' : 'text-slate-500'
            }`}
          >
            {met && <Check className="h-4 w-4 shrink-0" aria-hidden="true" />}
            <span>{rule.label}</span>
          </li>
        );
      })}
      <li className={`flex items-center gap-1.5 ${tooCommon ? 'text-red-600' : 'text-slate-500'}`}>
        <span>{COMMON_PASSWORD_RULE_LABEL}</span>
      </li>
    </ul>
  );
};

export default PasswordRules;
