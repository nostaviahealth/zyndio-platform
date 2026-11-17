import 'package:flutter/foundation.dart';

/// Web-safe platform checks.
///
/// `dart:io`'s `Platform.isIOS` throws "Unsupported operation" on web, which
/// crashed Today in the web build. These read Flutter's
/// [defaultTargetPlatform] instead: false on web, and overridable in widget
/// tests via `debugDefaultTargetPlatformOverride`.
abstract final class PlatformInfo {
  /// A native iOS build (iPhone/iPad), not iOS Safari.
  static bool get isIOS => !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

  /// A native Android build, not Chrome on Android.
  static bool get isAndroid => !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
}
