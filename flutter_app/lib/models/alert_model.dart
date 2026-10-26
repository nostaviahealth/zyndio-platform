/// In-App Alert System — Model & Types
///
/// Defines the complete taxonomy of alerts that Zyndio can surface.
/// Each alert type maps to a distinct visual style, icon, and haptic pattern.

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

// ─── ALERT CATEGORY ─────────────────────────────────────────────────────────

/// High-level categories that determine the visual styling of the alert.
enum AlertCategory {
  /// Protocol-related: reminders, task completions, phase transitions.
  protocol,

  /// AI-generated health insights or coaching nudges.
  insight,

  /// Achievement milestones: streaks, bio-age improvements, goals hit.
  achievement,

  /// Warnings: low recovery, abnormal readings, device disconnections.
  warning,

  /// System-level: sync success, upload confirmations, subscription events.
  system,
}

// ─── ALERT PRIORITY ─────────────────────────────────────────────────────────

/// Controls queueing order and auto-dismiss duration.
enum AlertPriority {
  /// Low: purely informational, auto-dismiss in 3s.
  low,

  /// Normal: standard alerts, auto-dismiss in 4s.
  normal,

  /// High: important updates, auto-dismiss in 6s, haptic feedback.
  high,

  /// Critical: warnings/errors, persists until dismissed, strong haptic.
  critical,
}

// ─── ALERT MODEL ────────────────────────────────────────────────────────────

class AppAlert {
  final String id;
  final String title;
  final String message;
  final AlertCategory category;
  final AlertPriority priority;
  final String? actionRoute;
  final String? actionLabel;
  final String? undoActionId; // NEW: ID to trigger an undo callback
  final DateTime timestamp;

  const AppAlert({
    required this.id,
    required this.title,
    required this.message,
    this.category = AlertCategory.system,
    this.priority = AlertPriority.normal,
    this.actionRoute,
    this.actionLabel,
    this.undoActionId,
    required this.timestamp,
  });

  /// Auto-dismiss duration based on priority.
  Duration get autoDismissDuration {
    switch (priority) {
      case AlertPriority.low:
        return const Duration(seconds: 3);
      case AlertPriority.normal:
        return const Duration(seconds: 4);
      case AlertPriority.high:
        return const Duration(seconds: 6);
      case AlertPriority.critical:
        return const Duration(seconds: 10);
    }
  }

  /// Whether this alert should use haptic feedback.
  bool get shouldHaptic =>
      priority == AlertPriority.high || priority == AlertPriority.critical;
}

// ─── VISUAL CONFIG ──────────────────────────────────────────────────────────

/// Maps each [AlertCategory] to its visual identity.
class AlertVisualConfig {
  final IconData icon;
  final Color primaryColor;
  final Color backgroundColor;
  final List<Color> gradientColors;

  const AlertVisualConfig({
    required this.icon,
    required this.primaryColor,
    required this.backgroundColor,
    required this.gradientColors,
  });

  /// Factory that returns the visual config for a given category.
  static AlertVisualConfig fromCategory(AlertCategory category) {
    switch (category) {
      case AlertCategory.protocol:
        return const AlertVisualConfig(
          icon: LucideIcons.clipboardCheck,
          primaryColor: Color(0xFF3B82F6), // Blue 500
          backgroundColor: Color(0xFFEFF6FF), // Blue 50
          gradientColors: [Color(0xFF3B82F6), Color(0xFF6366F1)],
        );
      case AlertCategory.insight:
        return const AlertVisualConfig(
          icon: LucideIcons.brain,
          primaryColor: Color(0xFFA855F7), // Purple 500
          backgroundColor: Color(0xFFFAF5FF), // Purple 50
          gradientColors: [Color(0xFFA855F7), Color(0xFF6366F1), Color(0xFF3B82F6)],
        );
      case AlertCategory.achievement:
        return const AlertVisualConfig(
          icon: LucideIcons.trophy,
          primaryColor: Color(0xFFF59E0B), // Amber 500
          backgroundColor: Color(0xFFFFFBEB), // Amber 50
          gradientColors: [Color(0xFFF59E0B), Color(0xFF10B981)],
        );
      case AlertCategory.warning:
        return const AlertVisualConfig(
          icon: LucideIcons.alertTriangle,
          primaryColor: Color(0xFFEF4444), // Red 500
          backgroundColor: Color(0xFFFEF2F2), // Red 50
          gradientColors: [Color(0xFFEF4444), Color(0xFFF97316)],
        );
      case AlertCategory.system:
        return const AlertVisualConfig(
          icon: LucideIcons.checkCircle,
          primaryColor: Color(0xFF10B981), // Emerald 500
          backgroundColor: Color(0xFFECFDF5), // Emerald 50
          gradientColors: [Color(0xFF10B981), Color(0xFF34D399)],
        );
    }
  }
}
