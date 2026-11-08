import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'app.dart';
import 'services/notification_service.dart';
import 'services/notification_scheduler.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'config/supabase_config.dart';
import 'services/revenue_cat_service.dart';
import 'services/user_habit_service.dart';
import 'services/analytics_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:platform_wearables/platform_wearables.dart';
late SharedPreferences sharedPrefs;

void main() async {
  runZonedGuarded(() async {
    final widgetsBinding = WidgetsFlutterBinding.ensureInitialized();
    FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);

    // Initialize Firebase
    try {
      await Firebase.initializeApp();
      await AnalyticsService().initialize();
    } catch (e) {
      debugPrint('⚠️ Firebase init failed: $e');
    }

    // Global Flutter error handler — catches widget/rendering errors
    FlutterError.onError = (FlutterErrorDetails details) {
      FlutterError.presentError(details);
      debugPrint('🔴 FlutterError: ${details.exceptionAsString()}');
    };

    // Set preferred orientations
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);

    // Enable edge-to-edge mode so app extends behind status bar
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    
    // Set system UI overlay style - Dark theme to match app
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light, 
        statusBarBrightness: Brightness.dark, 
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarIconBrightness: Brightness.light,
        systemNavigationBarContrastEnforced: false,
      ),
    );

    // Initialize Supabase - MUST complete before running app
    final supabaseInitialized = await SupabaseConfig.initialize();
    debugPrint('✅ Supabase initialized: $supabaseInitialized');

    // Initialize Zyndio Wearables SDK
    try {
      // No wearables secret in the app: cloud calls carry the signed-in
      // patient's own session token (read per call) plus the public anon key.
      await Zyndio.init(
        apiKey: SupabaseConfig.anonKey,
        accessToken: () async => SupabaseConfig.client?.auth.currentSession?.accessToken,
        baseUrl: '${SupabaseConfig.url}/functions/v1'
      );
      debugPrint('✅ Zyndio SDK initialized');
    } catch (e) {
      debugPrint('⚠️ Zyndio SDK init failed: $e');
    }

    sharedPrefs = await SharedPreferences.getInstance();

    // Initialize Notifications (wrapped in try-catch for safety)
    try {
      await NotificationService().initialize();

      // Wire up interactive action buttons (✅ Done / ⏰ Snooze)
      NotificationService.onActionReceived = (actionId, payload) {
        debugPrint('🔔 Action received: $actionId | payload: $payload');
        if (actionId == 'SNOOZE') {
          NotificationScheduler().handleSnooze(
            payload.hashCode,
            'Snoozed Reminder',
            payload ?? 'Check your protocol',
          );
        }
        // MARK_DONE is handled passively — task stays completed in its current state
      };

      // Record wake-up time for predictive morning notifications
      NotificationScheduler().recordWakeUpTime();
      // ── ADAPTIVE EVOLUTION ENGINE: Record App Open ──
      UserHabitService.recordAppOpenEvent(DateTime.now());
    } catch (e) {
      debugPrint('⚠️ Notification/Habit init failed: $e');
    }

    // Initialize RevenueCat
    try {
      await RevenueCatService().initialize();
    } catch (e) {
      debugPrint('⚠️ RevenueCat init failed: $e');
    }

    // Initialization complete - remove splash
    FlutterNativeSplash.remove();

    runApp(
      ProviderScope(
        overrides: [
          // Pass initialization state to providers
          supabaseInitializedProvider.overrideWithValue(supabaseInitialized),
        ],
        child: const BrandHealthApp(),
      ),
    );
  }, (error, stack) {
    // Global catch-all for unhandled async errors (prevents crash-to-homescreen)
    debugPrint('🔴 Uncaught async error: $error');
    debugPrint('🔴 Stack trace: $stack');
  });
}

/// Provider to track if Supabase was successfully initialized
final supabaseInitializedProvider = Provider<bool>((ref) => false);
