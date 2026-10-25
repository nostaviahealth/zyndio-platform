/// Default (Henry, 23 Oct 2026; changeable if the client asks): a sign-in
/// code is valid for 10 minutes from the moment it was issued.
class CodeExpiryPolicy {
  const CodeExpiryPolicy({this.validFor = const Duration(minutes: 10)});

  final Duration validFor;

  bool isExpired(DateTime issuedAt, DateTime now) =>
      now.difference(issuedAt) >= validFor;
}
