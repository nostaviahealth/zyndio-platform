import 'package:url_launcher/url_launcher.dart';

import '../data/health_data_repository.dart';

/// Makes a signed link for a stored report file (`pdf_path`).
typedef LabReportLinkSigner = Future<String?> Function(String pdfPath);

/// Hands a link to the platform viewer. True when it opened.
typedef LabReportLinkLauncher = Future<bool> Function(Uri link);

/// TC-039: the one way the app opens a lab report's file.
///
/// - Every open asks storage for a NEW signed link
///   ([HealthDataRepository.signedLabReportUrl]: 5 minutes, checked against
///   the caller's storage access). Links are never cached, stored, logged or
///   shown; only the report's `pdf_path` is kept.
/// - Expired links: a link is used the moment it is made, and opening the
///   report again always makes a fresh one. If the hand-off fails, one more
///   fresh link is tried before giving up.
/// - Returns false (the caller shows a fixed error) when storage refuses -
///   e.g. a path in another patient's folder - or the viewer can't open it.
class LabReportFileOpener {
  LabReportFileOpener._();

  static const maxAttempts = 2;

  /// Overridable in tests.
  static LabReportLinkSigner signer = HealthDataRepository.signedLabReportUrl;
  static LabReportLinkLauncher launcher = _launch;

  static Future<bool> _launch(Uri link) =>
      launchUrl(link, mode: LaunchMode.externalApplication);

  static Future<bool> open(String pdfPath) async {
    for (var attempt = 0; attempt < maxAttempts; attempt++) {
      final String? link;
      try {
        link = await signer(pdfPath);
      } catch (_) {
        continue;
      }
      // null: refused or unreachable (indistinguishable here) - try once more.
      if (link == null) continue;
      final uri = Uri.tryParse(link);
      if (uri == null || !uri.isAbsolute) continue;
      try {
        if (await launcher(uri)) return true;
      } catch (_) {}
    }
    return false;
  }

  /// Restores the real signer and launcher (tests).
  static void resetForTest() {
    signer = HealthDataRepository.signedLabReportUrl;
    launcher = _launch;
  }
}
