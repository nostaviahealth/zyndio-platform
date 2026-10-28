/// Ava copy-deck masking for patient-facing emails
/// (e.g. `jordan.rivera@example.com` -> `j•••••@example.com`).
String maskEmail(String email) {
  final atIndex = email.indexOf('@');
  if (email.isEmpty || atIndex <= 0) return email;
  return '${email[0]}•••••${email.substring(atIndex)}';
}
