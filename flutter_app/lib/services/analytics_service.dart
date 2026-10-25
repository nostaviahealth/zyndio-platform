import 'dart:io';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:facebook_app_events/facebook_app_events.dart';
import 'package:app_tracking_transparency/app_tracking_transparency.dart';
import 'package:flutter/foundation.dart';

class AnalyticsService {
  static final AnalyticsService _instance = AnalyticsService._internal();
  factory AnalyticsService() => _instance;
  AnalyticsService._internal();

  bool _isReady = false;
  FirebaseAnalytics? _analytics;
  final FacebookAppEvents _facebookAppEvents = FacebookAppEvents();

  /// Get the analytics observer for GoRouter (safe even before init)
  FirebaseAnalyticsObserver? get observer {
    if (!_isReady || _analytics == null) return null;
    return FirebaseAnalyticsObserver(analytics: _analytics!);
  }

  /// Initialize Analytics — call AFTER Firebase.initializeApp()
  Future<void> initialize() async {
    try {
      debugPrint('🚀 Analytics: Initializing...');
      
      // Initialize Firebase
      _analytics = FirebaseAnalytics.instance;
      await _analytics!.setAnalyticsCollectionEnabled(true);
      
      // Initialize Facebook (Meta) SDK
      // Note: facebook_app_events handles initialization automatically in the native layer
      // but we force these flags here to ensure the Advertiser ID is collected.
      await _facebookAppEvents.setAdvertiserTracking(enabled: true);
      await _facebookAppEvents.setAutoLogAppEventsEnabled(true);
      await _facebookAppEvents.setGraphApiVersion("v18.0");
      await _facebookAppEvents.activateApp();
      await _facebookAppEvents.flush();
      
      _isReady = true;
      debugPrint('✅ Analytics: Ready (Firebase + Meta)');
      debugPrint('📣 Analytics: activateApp and flush() called');
      
      // Attempt to request ATT on start if iOS
      if (!kIsWeb && Platform.isIOS) {
        await requestTrackingAuthorization();
      }
    } catch (e) {
      debugPrint('❌ Analytics: Initialization failed: $e');
      _isReady = false;
    }
  }

  /// Track a conversion event (Purchase/Subscription)
  Future<void> logPurchase({
    required String productId,
    required double price,
    required String currency,
  }) async {
    if (!_isReady) return;
    
    // Log to Firebase
    await _analytics?.logEvent(
      name: 'purchase_complete',
      parameters: {
        'product_id': productId,
        'value': price,
        'currency': currency,
      },
    );

    // Log to Facebook
    await _facebookAppEvents.logPurchase(
      amount: price,
      currency: currency,
      parameters: {
        'product_id': productId,
      },
    );
  }

  /// Track when a user signs up
  Future<void> logSignUp(String method) async {
    if (!_isReady) return;
    
    // Log to Firebase
    await _analytics?.logSignUp(signUpMethod: method);
    
    // Log to Facebook
    await _facebookAppEvents.logEvent(
      name: 'fb_mobile_complete_registration',
      parameters: {
        'registration_method': method,
      },
    );
  }

  /// Track core feature usage
  Future<void> logFeatureUse(String featureName, {Map<String, dynamic>? parameters}) async {
    if (!_isReady) return;
    
    // Log to Firebase
    await _analytics?.logEvent(
      name: 'feature_use',
      parameters: {
        'feature_name': featureName,
        ...?parameters,
      },
    );

    // Log to Facebook
    await _facebookAppEvents.logEvent(
      name: 'feature_use',
      parameters: {
        'feature_name': featureName,
        ...?parameters,
      },
    );
  }

  /// Set user properties (e.g., Plus user status)
  Future<void> setUserIsPlus(bool isPlus) async {
    if (!_isReady) return;
    
    // Set for Firebase
    await _analytics?.setUserProperty(name: 'is_plus_user', value: isPlus.toString());
    
    // Log property change to Facebook
    await _facebookAppEvents.logEvent(
      name: 'user_property_update',
      parameters: {'is_plus_user': isPlus ? 1 : 0},
    );
  }

  /// Specifically for iOS: Request Tracking Authorization
  Future<void> requestTrackingAuthorization() async {
    if (kIsWeb || !Platform.isIOS) return;

    try {
      final status = await AppTrackingTransparency.trackingAuthorizationStatus;
      if (status == TrackingStatus.notDetermined) {
        debugPrint('🍎 Analytics: Requesting ATT Authorization...');
        await Future.delayed(const Duration(milliseconds: 500)); // Small delay for system to be ready
        await AppTrackingTransparency.requestTrackingAuthorization();
        debugPrint('✅ Analytics: ATT Authorization requested');
        
        // Re-trigger Facebook tracking now that we (hopefully) have permission
        await _facebookAppEvents.setAdvertiserTracking(enabled: true);
        await _facebookAppEvents.activateApp();
        await _facebookAppEvents.flush();
      }
    } catch (e) {
      debugPrint('❌ Analytics: ATT request failed: $e');
    }
  }
}
