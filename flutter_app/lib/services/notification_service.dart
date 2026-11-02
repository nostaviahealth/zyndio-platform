import 'dart:async';
import 'dart:io';
import 'package:permission_handler/permission_handler.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../config/firebase_config.dart';
import '../config/supabase_config.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter_timezone/flutter_timezone.dart';

/// Background message handler for FCM.
/// Must be a top-level function.
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint('Handling a background message: ${message.messageId}');
}

/// Callback for handling notification action buttons in the background.
/// Must be a top-level function.
@pragma('vm:entry-point')
void _onNotificationActionBackground(NotificationResponse details) {
  debugPrint('Background notification action: ${details.actionId} | payload: ${details.payload}');
  // Background actions are handled natively — this is the Flutter-side hook
}

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  FirebaseMessaging? get _fcm => firebaseConfigured ? FirebaseMessaging.instance : null;
  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();

  bool _isInitialized = false;

  /// Callback for when a notification action is tapped in the foreground
  /// Set this from the app's main widget to handle task completion / snoozing
  static void Function(String actionId, String? payload)? onActionReceived;

  Future<void> initialize() async {
    if (_isInitialized) return;

    // Initialize Timezone for local scheduling
    tz.initializeTimeZones();
    try {
      final String timeZoneName = (await FlutterTimezone.getLocalTimezone()).identifier;
      tz.setLocalLocation(tz.getLocation(timeZoneName));
    } catch (e) {
      debugPrint('Could not initialize timezone location, fallback mapping used: $e');
    }

    // 1. Request permissions (iOS/Android 13+)
    await requestPermissions();

    // 2. Configure Local Notifications with Interactive Actions
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@drawable/ic_stat_zyndio');
    
    // Define iOS notification categories with action buttons
    final DarwinInitializationSettings initializationSettingsDarwin =
        DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
      notificationCategories: [
        // Task Reminder: ✅ Done / ⏰ Snooze
        DarwinNotificationCategory(
          'TASK_REMINDER',
          actions: <DarwinNotificationAction>[
            DarwinNotificationAction.plain(
              'MARK_DONE',
              '✅ Done',
              options: <DarwinNotificationActionOption>{
                DarwinNotificationActionOption.foreground,
              },
            ),
            DarwinNotificationAction.plain(
              'SNOOZE',
              '⏰ Snooze 15m',
            ),
          ],
          options: <DarwinNotificationCategoryOption>{
            DarwinNotificationCategoryOption.hiddenPreviewShowTitle,
          },
        ),
        // Daily Anchor: just a tap-to-open
        DarwinNotificationCategory(
          'DAILY_ANCHOR',
          actions: <DarwinNotificationAction>[
            DarwinNotificationAction.plain(
              'VIEW',
              '📱 Open App',
              options: <DarwinNotificationActionOption>{
                DarwinNotificationActionOption.foreground,
              },
            ),
          ],
          options: <DarwinNotificationCategoryOption>{
            DarwinNotificationCategoryOption.hiddenPreviewShowTitle,
          },
        ),
      ],
    );

    final InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsDarwin,
    );

    await _localNotifications.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: _handleNotificationResponse,
      onDidReceiveBackgroundNotificationResponse: _onNotificationActionBackground,
    );

    // Programmatically create required Android Notification Channels
    if (Platform.isAndroid) {
      final androidPlugin = _localNotifications
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      if (androidPlugin != null) {
        try {
          await androidPlugin.createNotificationChannel(
            const AndroidNotificationChannel(
              'zyndio_general',
              'General Notifications',
              description: 'Notifications for health updates and reminders',
              importance: Importance.max,
              playSound: true,
              enableVibration: true,
            ),
          );
          await androidPlugin.createNotificationChannel(
            const AndroidNotificationChannel(
              'zyndio_scheduled',
              'Scheduled Notifications',
              description: 'Scheduled reminders and health alerts',
              importance: Importance.max,
              playSound: true,
              enableVibration: true,
            ),
          );
          debugPrint('✅ Android notification channels programmatically registered');
        } catch (e) {
          debugPrint('⚠️ Failed to programmatically register Android notification channels: $e');
        }
      }
    }

    // 3. Set up FCM Handlers (only when Firebase is configured for this build)
    if (firebaseConfigured) {
      final fcm = _fcm!;

      // Configure foreground presentation options for Android
      await fcm.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );

      // Foreground messages
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        debugPrint('Got a message whilst in the foreground!');
        debugPrint('Message data: ${message.data}');

        if (message.notification != null) {
          debugPrint('Message also contained a notification: ${message.notification?.title}');
          showLocalNotification(
            id: message.hashCode,
            title: message.notification?.title ?? 'Notification',
            body: message.notification?.body ?? '',
            payload: message.data.toString(),
          );
        }
      });

      // Background messages handled via top-level function
      FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

      // App opened from background/terminated state
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        debugPrint('App opened from notification!');
        // Handle navigation based on message.data
      });

      // Handle initial message if app was terminated
      RemoteMessage? initialMessage = await fcm.getInitialMessage();
      if (initialMessage != null) {
        debugPrint('App opened from terminated state via notification!');
      }

      // 4. Listen for token refresh
      fcm.onTokenRefresh.listen((newToken) {
        syncTokenToSupabase(newToken);
      });
    } else {
      debugPrint('⚠️ Firebase not configured — push notifications disabled, local notifications only');
    }

    // 5. Initial sync if user is already logged in
    await syncTokenToSupabase();

    _isInitialized = true;
    debugPrint('✅ NotificationService fully initialized with interactive actions');
  }

  /// Handle taps and action button responses
  void _handleNotificationResponse(NotificationResponse details) {
    final actionId = details.actionId;
    final payload = details.payload;

    debugPrint('🔔 Notification response — action: $actionId, payload: $payload');

    if (actionId != null && actionId.isNotEmpty) {
      // User tapped an ACTION BUTTON (not just the notification body)
      onActionReceived?.call(actionId, payload);
    } else {
      // User tapped the notification body itself
      debugPrint('Notification tapped: $payload');
      // Navigation could be handled here via a global navigator key
    }
  }

  /// Request permissions for notifications
  Future<bool> requestPermissions() async {
    // 1. Android Specific: Request POST_NOTIFICATIONS (Android 13+) 
    // and SCHEDULE_EXACT_ALARM (Android 12+) via permission_handler
    if (Platform.isAndroid) {
      await Permission.notification.request();
      if (await Permission.scheduleExactAlarm.isDenied) {
        await Permission.scheduleExactAlarm.request();
      }
    }

    // 2. FCM/iOS Permission Request
    if (!firebaseConfigured) {
      debugPrint('⚠️ Firebase not configured — skipping FCM permission request');
      return true;
    }

    NotificationSettings settings = await _fcm!.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      debugPrint('User granted permission');
      return true;
    } else if (settings.authorizationStatus == AuthorizationStatus.provisional) {
      debugPrint('User granted provisional permission');
      return true;
    } else {
      debugPrint('User declined or has not accepted permission');
      return false;
    }
  }

  /// Get the current FCM token
  Future<String?> getFcmToken() async {
    if (!firebaseConfigured) return null;
    try {
      return await _fcm!.getToken();
    } catch (e) {
      debugPrint('Error getting FCM token: $e');
      return null;
    }
  }

  /// Sync the FCM token to patient_accounts
  Future<void> syncTokenToSupabase([String? token]) async {
    final fcmToken = token ?? await getFcmToken();
    if (fcmToken == null) return;

    final user = SupabaseConfig.currentUser;
    if (user == null) return;

    try {
      final client = SupabaseConfig.client;
      if (client == null) return;

      await client.from('patient_accounts').upsert({
        'patient_id': user.id,
        'fcm_token': fcmToken,
        'updated_at': DateTime.now().toIso8601String(),
      }, onConflict: 'patient_id');

      debugPrint('FCM Token synced to Supabase');
    } catch (e) {
      debugPrint('Error syncing FCM token: $e');
    }
  }

  /// Show a local notification immediately
  Future<void> showLocalNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
    String? categoryIdentifier,
  }) async {
    final AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      'zyndio_general',
      'General Notifications',
      channelDescription: 'Notifications for health updates and reminders',
      importance: Importance.max,
      priority: Priority.high,
      showWhen: true,
      actions: categoryIdentifier == 'TASK_REMINDER' ? <AndroidNotificationAction>[
        const AndroidNotificationAction('MARK_DONE', '✅ Done'),
        const AndroidNotificationAction('SNOOZE', '⏰ Snooze 15m'),
      ] : null,
    );
    
    final DarwinNotificationDetails iOSDetails = DarwinNotificationDetails(
      categoryIdentifier: categoryIdentifier,
    );
    
    final NotificationDetails platformChannelSpecifics =
        NotificationDetails(
          android: androidPlatformChannelSpecifics,
          iOS: iOSDetails,
        );
    
    await _localNotifications.show(
      id,
      title,
      body,
      platformChannelSpecifics,
      payload: payload,
    );
  }

  /// Schedule a local notification at an exact DateTime with optional category
  Future<void> scheduleNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledDate,
    String? payload,
    String? categoryIdentifier,
  }) async {
    // Only schedule if the date is in the future
    if (scheduledDate.isBefore(DateTime.now())) {
      return; 
    }
    
    final AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      'zyndio_scheduled',
      'Scheduled Notifications',
      channelDescription: 'Scheduled reminders and health alerts',
      importance: Importance.max,
      priority: Priority.high,
      actions: categoryIdentifier == 'TASK_REMINDER' ? <AndroidNotificationAction>[
        const AndroidNotificationAction('MARK_DONE', '✅ Done'),
        const AndroidNotificationAction('SNOOZE', '⏰ Snooze 15m'),
      ] : null,
    );
    
    final DarwinNotificationDetails iOSDetails = DarwinNotificationDetails(
      categoryIdentifier: categoryIdentifier,
    );
    
    final NotificationDetails platformChannelSpecifics =
        NotificationDetails(
          android: androidPlatformChannelSpecifics,
          iOS: iOSDetails,
        );
    
    try {
      await _localNotifications.zonedSchedule(
        id,
        title,
        body,
        tz.TZDateTime.from(scheduledDate, tz.local),
        platformChannelSpecifics,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
        payload: payload,
      );
    } catch (e) {
      debugPrint('⚠️ Exact scheduling failed: $e. Falling back to inexact scheduling.');
      // Fallback for Android 13/14+ if SCHEDULE_EXACT_ALARM permission is missing
      await _localNotifications.zonedSchedule(
        id,
        title,
        body,
        tz.TZDateTime.from(scheduledDate, tz.local),
        platformChannelSpecifics,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
        payload: payload,
      );
    }
  }

  /// Cancel all pending scheduled notifications
  Future<void> cancelAllScheduled() async {
    await _localNotifications.cancelAll();
    debugPrint('Cleared all pending scheduled notifications');
  }
}
