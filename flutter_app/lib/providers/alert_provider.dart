/// In-App Alert System — State Management
///
/// Manages the active alert queue and provides a global API for any part
/// of the app to trigger alerts. Uses Riverpod for state management.

import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/alert_model.dart';

// ─── ALERT STATE ────────────────────────────────────────────────────────────

class AlertState {
  /// The currently displayed alert (null if nothing is showing).
  final AppAlert? activeAlert;

  /// Queue of pending alerts waiting to be shown.
  final List<AppAlert> queue;

  /// History of all alerts shown in this session (most recent first).
  final List<AppAlert> history;

  const AlertState({
    this.activeAlert,
    this.queue = const [],
    this.history = const [],
  });

  AlertState copyWith({
    AppAlert? activeAlert,
    List<AppAlert>? queue,
    List<AppAlert>? history,
    bool clearActive = false,
  }) {
    return AlertState(
      activeAlert: clearActive ? null : (activeAlert ?? this.activeAlert),
      queue: queue ?? this.queue,
      history: history ?? this.history,
    );
  }

  bool get hasActive => activeAlert != null;
  int get unreadCount => history.length;
}

// ─── ALERT NOTIFIER ─────────────────────────────────────────────────────────

class AlertNotifier extends Notifier<AlertState> {
  Timer? _autoDismissTimer;

  @override
  AlertState build() {
    ref.onDispose(() => _autoDismissTimer?.cancel());
    return const AlertState();
  }

  // ── PUBLIC API ──

  /// Show an alert. If another alert is active, queue this one.
  void show({
    required String title,
    required String message,
    AlertCategory category = AlertCategory.system,
    AlertPriority priority = AlertPriority.normal,
    String? actionRoute,
    String? actionLabel,
    String? undoActionId,
  }) {
    final alert = AppAlert(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      title: title,
      message: message,
      category: category,
      priority: priority,
      actionRoute: actionRoute,
      actionLabel: actionLabel,
      undoActionId: undoActionId,
      timestamp: DateTime.now(),
    );

    if (state.hasActive) {
      // If incoming alert is higher priority, replace the active one.
      if (priority.index > (state.activeAlert?.priority.index ?? 0)) {
        // Move current active to front of queue
        final newQueue = [state.activeAlert!, ...state.queue];
        state = state.copyWith(
          activeAlert: alert,
          queue: newQueue,
          history: [alert, ...state.history],
        );
        _startAutoDismiss(alert);
      } else {
        // Queue it based on priority (higher priority = closer to front)
        final newQueue = [...state.queue, alert];
        newQueue.sort((a, b) => b.priority.index.compareTo(a.priority.index));
        state = state.copyWith(queue: newQueue);
      }
    } else {
      // No active alert, show immediately
      state = state.copyWith(
        activeAlert: alert,
        history: [alert, ...state.history],
      );
      _startAutoDismiss(alert);
    }

    // Haptic feedback for important alerts
    if (alert.shouldHaptic) {
      HapticFeedback.mediumImpact();
    } else {
      HapticFeedback.lightImpact();
    }
  }

  /// Convenience methods for each alert category

  void showProtocolAlert(String title, String message, {String? actionRoute}) {
    show(
      title: title,
      message: message,
      category: AlertCategory.protocol,
      priority: AlertPriority.normal,
      actionRoute: actionRoute,
      actionLabel: 'View Protocol',
    );
  }

  void showInsight(String title, String message, {String? actionRoute, String? undoActionId}) {
    show(
      title: title,
      message: message,
      category: AlertCategory.insight,
      priority: AlertPriority.normal,
      actionRoute: actionRoute,
      actionLabel: 'See Details',
      undoActionId: undoActionId,
    );
  }

  void showAchievement(String title, String message) {
    show(
      title: title,
      message: message,
      category: AlertCategory.achievement,
      priority: AlertPriority.high,
    );
  }

  void showWarning(String title, String message, {String? actionRoute}) {
    show(
      title: title,
      message: message,
      category: AlertCategory.warning,
      priority: AlertPriority.critical,
      actionRoute: actionRoute,
      actionLabel: 'Review',
    );
  }

  void showSystemAlert(String title, String message) {
    show(
      title: title,
      message: message,
      category: AlertCategory.system,
      priority: AlertPriority.low,
    );
  }

  /// Dismiss the currently active alert and show the next in queue.
  void dismiss() {
    _autoDismissTimer?.cancel();

    if (state.queue.isNotEmpty) {
      final nextQueue = List<AppAlert>.from(state.queue);
      final next = nextQueue.removeAt(0);
      state = AlertState(
        activeAlert: next,
        queue: nextQueue,
        history: [next, ...state.history],
      );
      _startAutoDismiss(next);
    } else {
      state = state.copyWith(clearActive: true);
    }
  }

  /// Clear all alerts (active + queue).
  void clearAll() {
    _autoDismissTimer?.cancel();
    state = state.copyWith(clearActive: true, queue: []);
  }

  /// Clear history.
  void clearHistory() {
    state = state.copyWith(history: []);
  }

  // ── PRIVATE ──

  void _startAutoDismiss(AppAlert alert) {
    _autoDismissTimer?.cancel();
    _autoDismissTimer = Timer(alert.autoDismissDuration, () {
      // Only dismiss if this specific alert is still the active one
      if (state.activeAlert?.id == alert.id) {
        dismiss();
      }
    });
  }
}

// ─── PROVIDERS ──────────────────────────────────────────────────────────────

final alertProvider = NotifierProvider<AlertNotifier, AlertState>(() {
  return AlertNotifier();
});

/// Convenience provider for just the active alert (reduces rebuilds).
final activeAlertProvider = Provider<AppAlert?>((ref) {
  return ref.watch(alertProvider).activeAlert;
});

/// Convenience provider for alert history.
final alertHistoryProvider = Provider<List<AppAlert>>((ref) {
  return ref.watch(alertProvider).history;
});
