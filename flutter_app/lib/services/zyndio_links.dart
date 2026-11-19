import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// Zyndio's own web destinations that the app links out to.
class ZyndioLinks {
  ZyndioLinks._();

  /// The main Zyndio website (client brief: always one tap away).
  static final Uri website = Uri.parse('https://www.zyndio.com');

  /// The patient portal (sign-in for members).
  static final Uri patientPortal = Uri.parse('https://member.zyndio.com');

  /// The Precision Nutrition supplement line.
  static final Uri supplements = Uri.parse('https://www.zyndio.com/supplements');
}

/// Opens [url]; returns whether it opened. Swappable in tests.
typedef ZyndioUrlOpener = Future<bool> Function(Uri url);

Future<bool> _defaultOpener(Uri url) async {
  final opened = await launchUrl(
    url,
    // An in-app browser sheet (Custom Tabs / Safari view) keeps the patient
    // inside the app; the web build opens a new tab.
    mode: kIsWeb ? LaunchMode.platformDefault : LaunchMode.inAppBrowserView,
  );
  // On iOS the Safari view reports `false` only when the patient closed it
  // before the first load finished: it did open, so that's not an error. A
  // real failure there throws instead.
  if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) return true;
  return opened;
}

@visibleForTesting
ZyndioUrlOpener zyndioUrlOpener = _defaultOpener;

@visibleForTesting
void resetZyndioUrlOpener() => zyndioUrlOpener = _defaultOpener;

/// Opens a Zyndio web page in the in-app browser, with a short message if the
/// device can't open it (no browser, offline).
Future<void> openZyndioLink(BuildContext context, Uri url) async {
  final messenger = ScaffoldMessenger.maybeOf(context);
  var opened = false;
  try {
    opened = await zyndioUrlOpener(url);
  } catch (_) {
    opened = false;
  }
  if (!opened) {
    messenger?.showSnackBar(
      SnackBar(
        content: Text("Couldn't open ${url.host}. Check your connection and try again."),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
