import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../providers/purchase_provider.dart';
import '../screens/settings/paywall_screen.dart';

/// Service to track "Aha Moments" and trigger the paywall strategically.
class ConversionService {
  static const String _kAhaMomentCountKey = 'aha_moment_count';
  static const int _kThreshold = 3;

  final Ref _ref;

  ConversionService(this._ref);

  /// Records a successful, high-value user action.
  /// If the count reaches the threshold, the paywall is triggered.
  Future<void> recordAhaMoment(BuildContext context) async {
    // 1. Check if user is already Plus. If so, don't show paywall.
    final purchaseState = _ref.read(purchaseProvider);
    if (purchaseState.isPlus) return;

    // 2. Increment count
    final prefs = await SharedPreferences.getInstance();
    final currentCount = prefs.getInt(_kAhaMomentCountKey) ?? 0;
    final newCount = currentCount + 1;
    await prefs.setInt(_kAhaMomentCountKey, newCount);

    debugPrint('🚀 [Conversion] Aha Moment recorded: $newCount/$_kThreshold');

    // 3. Trigger paywall on 3rd success
    if (newCount == _kThreshold) {
      if (context.mounted) {
        debugPrint('🎯 [Conversion] Threshold reached. Triggering Paywall.');
        PaywallScreen.show(context);
      }
    }
  }

  /// Resets the counter (e.g., for testing or after a purchase).
  Future<void> resetCounter() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kAhaMomentCountKey);
  }
}

final conversionServiceProvider = Provider<ConversionService>((ref) {
  return ConversionService(ref);
});
