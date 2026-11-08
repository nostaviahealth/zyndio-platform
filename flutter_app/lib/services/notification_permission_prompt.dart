import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'notification_service.dart';

/// Anything that can show the OS notification permission prompt.
abstract class NotificationPermissionRequester {
  Future<bool> requestPermissions();
}

/// Asks for notification permission once, after the patient is signed in and
/// inside the app - never at launch on the sign-in screen (it used to fire
/// from AppDelegate and NotificationService.initialize before sign-in).
///
/// The "asked" flag is stored before prompting, so a crash or a dismissed
/// dialog never turns into a prompt on every launch. Patients can still turn
/// notifications on later from Settings.
class NotificationPermissionPrompt {
  NotificationPermissionPrompt(this._prefs, this._requester);

  static const askedKey = 'notification_permission_asked_v1';

  final Future<SharedPreferences> Function() _prefs;
  final NotificationPermissionRequester _requester;

  /// Returns true if the prompt was shown on this call.
  Future<bool> maybeAskOnce() async {
    try {
      final prefs = await _prefs();
      if (prefs.getBool(askedKey) ?? false) return false;
      await prefs.setBool(askedKey, true);
      await _requester.requestPermissions();
      return true;
    } catch (e) {
      debugPrint('Notification permission prompt skipped: $e');
      return false;
    }
  }
}

final notificationPermissionPromptProvider = Provider<NotificationPermissionPrompt>(
  (ref) => NotificationPermissionPrompt(SharedPreferences.getInstance, NotificationService()),
);
