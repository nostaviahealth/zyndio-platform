import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../providers/purchase_provider.dart';

/// Service responsible for managing the app's branding, 
/// specifically switching the launcher icon based on user tier.
/// 
/// IMPLEMENTATION NOTE: This service uses a native MethodChannel ('com.zyndio/branding')
/// to ensure stable icon switching on both iOS and Android without relying on
/// fragile third-party packages or defunct repositories.
class BrandingService {
  static final BrandingService _instance = BrandingService._internal();
  factory BrandingService() => _instance;
  BrandingService._internal();

  static const String _iconPrefsKey = 'user_app_icon_preference';
  
  /// Native bridge for launcher icon management
  static const MethodChannel _brandingChannel = MethodChannel('com.zyndio/branding');

  /// Updates the app launcher icon based on manual user choice or automatic tier sync.
  Future<void> updateAppIcon(bool usePlusIcon, {bool persist = false}) async {
    try {
      final String? currentIconName = await getActiveIconName();
      final String targetIconName = usePlusIcon ? 'PremiumBrand' : 'Default';

      // Avoid redundant changes
      if (currentIconName == targetIconName || (currentIconName == 'Default' && targetIconName == 'Default')) {
        // Still update storage if requested
        if (persist) await _storePreference(targetIconName);
        return;
      }

      debugPrint('🎨 BrandingService: Switching app icon to $targetIconName via Native Bridge');
      
      // Call native implementation (iOS setAlternateIconName / Android activity-alias)
      await _brandingChannel.invokeMethod('setAlternateIconName', {
        'iconName': targetIconName == 'Default' ? null : targetIconName,
      });
      
      if (persist) await _storePreference(targetIconName);
      debugPrint('✅ BrandingService: Native icon switch successful');
    } on PlatformException catch (e) {
      debugPrint('❌ BrandingService: Native switch failed: ${e.message}');
    } catch (e) {
      debugPrint('❌ BrandingService: Unexpected error: $e');
    }
  }

  /// Synchronizes the app icon with the user's tier, respecting manual choices for Plus users.
  Future<void> syncIconWithTier(bool isPlus) async {
    if (!isPlus) {
      // Force default for free users
      await updateAppIcon(false, persist: false);
    } else {
      // For Plus users, respect their stored preference (default to PremiumBrand)
      final prefs = await SharedPreferences.getInstance();
      final preference = prefs.getString(_iconPrefsKey) ?? 'PremiumBrand';
      await updateAppIcon(preference == 'PremiumBrand', persist: false);
    }
  }

  Future<void> _storePreference(String iconName) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_iconPrefsKey, iconName);
  }

  Future<String> getActiveIconName() async {
    try {
      final String? name = await _brandingChannel.invokeMethod('getAlternateIconName');
      return name ?? 'Default';
    } catch (e) {
      debugPrint('⚠️ BrandingService: Could not get active icon name: $e');
      return 'Default';
    }
  }
}

/// Provider for the BrandingService
final brandingServiceProvider = Provider<BrandingService>((ref) {
  return BrandingService();
});
