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
import 'notification_permission_prompt.dart' show NotificationPermissionRequester;

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

/// APP-10: the only text a notification ever shows on the lock screen or in a
/// banner. Callers still describe the event in `title`/`body`, but that text
/// can carry health details (heart rate, AI coaching, lab results), so it is
/// never displayed; the patient reads it in the app after signing in.
@visibleForTesting
const kNotificationTitle = 'Zyndio';
@visibleForTesting
const kNotificationBody = 'You have a new update in the Zyndio app.';

class NotificationService implements NotificationPermissionRequester {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  FirebaseMessaging? get _fcm => firebaseConfigured ? FirebaseMessaging.instance : null;
  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();

  bool _isInitialized = false;

  /// Callback for when a notification action is tapped in the foreground
  /// Set this from the app's main widget to handle task completion / snoozing
  static void Function(String actionId, String? payload)? onActionReceived;

  /// TC-025 C5: called with the payload when the notification BODY is tapped.
  /// The app routes it via `resolveNotificationTapRoute` (stale extras and
  /// unknown payloads land on Today). A tap that arrives before the app has
  /// registered this callback (cold start from a notification) is kept and
  /// delivered on registration.
  static void Function(String? payload)? get onNotificationTap => _onNotificationTap;
  static set onNotificationTap(void Function(String? payload)? cb) {
    _onNotificationTap = cb;
    if (cb != null && _hasPendingTap) {
      final p = _pendingTapPayload;
      _hasPendingTap = false;
      _pendingTapPayload = null;
      _deliverTap(p);
    }
  }

  static void Function(String? payload)? _onNotificationTap;
  static bool _hasPendingTap = false;
  static String? _pendingTapPayload;

  static void _deliverTap(String? payload) {
    final cb = _onNotificationTap;
    if (cb == null) {
      _hasPendingTap = true;
      _pendingTapPayload = payload;
      return;
    }
    try {
      cb(payload);
    } catch (e) {
      debugPrint('Notification tap routing failed: $e');
    }
  }

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

    // 1. No permission request here: initialize() runs at launch, before the
    // patient has signed in. The prompt comes once, in context, from
    // NotificationPermissionPrompt (MainShell) - App Store guideline 4.5.4.

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
      onDidReceiveNotificationResponse: handleNotificationResponse,
      onDidReceiveBackgroundNotificationResponse: _onNotificationActionBackground,
    );

    // TC-025 C5: a cold start from a notification body tap is routed the same
    // way as a tap while running (held until the app registers the router).
    try {
      final launch = await _localNotifications.getNotificationAppLaunchDetails();
      final response = launch?.notificationResponse;
      if (launch?.didNotificationLaunchApp == true &&
          response != null &&
          (response.actionId == null || response.actionId!.isEmpty)) {
        _deliverTap(response.payload);
      }
    } catch (e) {
      debugPrint('Notification launch details unavailable: $e');
    }

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
        // No message data or text in logs: it may carry health details.
        debugPrint('Got a message whilst in the foreground: ${message.messageId}');

        if (message.notification != null) {
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
      RemoteMessage? initialMessage;
      try {
        // firebase_messaging can leave this call hanging if the iOS plugin
        // registers after launch. Startup must not wait forever.
        initialMessage = await fcm.getInitialMessage().timeout(const Duration(seconds: 3));
      } on TimeoutException {
        debugPrint('getInitialMessage timed out; startup continues');
        initialMessage = null;
      }
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
  @visibleForTesting
  void handleNotificationResponse(NotificationResponse details) {
    final actionId = details.actionId;
    final payload = details.payload;

    debugPrint('Notification response received');

    if (actionId != null && actionId.isNotEmpty) {
      // User tapped an ACTION BUTTON (not just the notification body)
      onActionReceived?.call(actionId, payload);
    } else {
      // User tapped the notification body itself
      debugPrint('Notification tapped');
      _deliverTap(payload);
    }
  }

  /// Request permissions for notifications
  @override
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

  /// Show a local notification immediately. `title` and `body` are never
  /// displayed; see [kNotificationBody].
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
      kNotificationTitle,
      kNotificationBody,
      platformChannelSpecifics,
      payload: payload,
    );
  }

  /// Schedule a local notification at an exact DateTime with optional category.
  /// `title` and `body` are never displayed; see [kNotificationBody].
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
        kNotificationTitle,
        kNotificationBody,
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
        kNotificationTitle,
        kNotificationBody,
        tz.TZDateTime.from(scheduledDate, tz.local),
        platformChannelSpecifics,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
        payload: payload,
      );
    }
  }

  /// Pending scheduled local notifications (id + payload), for targeted
  /// cancellation (TC-025 C5).
  Future<List<PendingNotificationRequest>> pendingNotificationRequests() =>
      _localNotifications.pendingNotificationRequests();

  /// Cancel one scheduled/shown local notification by id (TC-025 C5).
  Future<void> cancel(int id) => _localNotifications.cancel(id);

  /// Cancel all pending scheduled notifications
  Future<void> cancelAllScheduled() async {
    await _localNotifications.cancelAll();
    debugPrint('Cleared all pending scheduled notifications');
  }
}
