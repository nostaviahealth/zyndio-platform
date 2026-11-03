import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/feature_flags_provider.dart';
import 'notification_service.dart';

/// TC-025 C5 (Q23): Shop / Meditate / Cycle reminders when the patient-extras
/// flag is off.
///
/// * Every scheduled local notification whose payload routes to an extras
///   feature is cancelled - by id, chosen by its payload route, never
///   `cancelAll` - on startup with the flag off and whenever the flag turns
///   from on to off.
/// * A tap on a stale extras notification (flag off) or on a notification with
///   an unknown / non-route payload lands on Today (`/`).

/// True when [route] is a Shop, Meditate or Cycle route. Mirrors the extras
/// set in `tc025Redirect` (config/routes.dart).
bool isExtrasRoute(String? route) {
  final path = _pathOf(route);
  if (path == null) return false;
  return path == '/shop' ||
      path.startsWith('/shop/') ||
      path == '/meditate' ||
      path == '/cycle';
}

/// Where a tapped notification with [payload] should take the patient.
/// Unknown or non-route payloads (null, empty, `task:<id>`, raw FCM data) and,
/// with the extras flag off, any extras route resolve to Today (`/`).
String resolveNotificationTapRoute(String? payload,
    {required bool patientExtrasEnabled}) {
  final path = _pathOf(payload);
  if (path == null) return '/';
  if (!patientExtrasEnabled && isExtrasRoute(path)) return '/';
  return payload!.trim();
}

String? _pathOf(String? payload) {
  final p = payload?.trim();
  if (p == null || p.isEmpty || !p.startsWith('/') || p.startsWith('//')) {
    return null;
  }
  final uri = Uri.tryParse(p);
  if (uri == null || uri.hasScheme || uri.hasAuthority) return null;
  return uri.path;
}

/// The two notification-layer calls the guard needs, so tests can fake them.
abstract class PendingNotificationCanceller {
  Future<List<PendingNotificationRequest>> pending();
  Future<void> cancel(int id);
}

class _ServiceCanceller implements PendingNotificationCanceller {
  @override
  Future<List<PendingNotificationRequest>> pending() =>
      NotificationService().pendingNotificationRequests();
  @override
  Future<void> cancel(int id) => NotificationService().cancel(id);
}

final pendingNotificationCancellerProvider =
    Provider<PendingNotificationCanceller>((ref) => _ServiceCanceller());

class ExtrasReminderGuard {
  ExtrasReminderGuard(this._notifications);

  final PendingNotificationCanceller _notifications;
  Future<void> _last = Future<void>.value();

  /// Completes when the most recent cancellation pass has finished.
  Future<void> get idle => _last;

  /// [previous] is null at startup. Cancels when the flag is off at startup
  /// or has just turned from on to off; never when it is on.
  Future<void> onExtrasFlag({required bool? previous, required bool current}) {
    if (current) return _last;
    if (previous == false) return _last; // already off, already cancelled
    return _last = _last.then((_) => _cancelExtras());
  }

  Future<void> _cancelExtras() async {
    try {
      final pending = await _notifications.pending();
      for (final r in pending) {
        if (isExtrasRoute(r.payload)) {
          await _notifications.cancel(r.id);
        }
      }
    } catch (e) {
      debugPrint('Extras reminder cancel skipped: $e');
    }
  }
}

/// Watches the patient-extras flag from startup (fireImmediately) and cancels
/// extras reminders while it is off. Read once from the app widget.
final extrasReminderGuardProvider = Provider<ExtrasReminderGuard>((ref) {
  final guard = ExtrasReminderGuard(ref.watch(pendingNotificationCancellerProvider));
  ref.listen<bool>(
    featureFlagsProvider.select((f) => f.patientExtrasEnabled),
    (previous, next) => guard.onExtrasFlag(previous: previous, current: next),
    fireImmediately: true,
  );
  return guard;
});
