import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'config/theme.dart';
import 'config/routes.dart';
import 'widgets/in_app_alert_banner.dart';
import 'providers/alert_provider.dart';
import 'providers/wearable_sync_provider.dart';
import 'providers/dark_mode_provider.dart';
import 'services/notification_scheduler.dart';
import 'services/watch_service.dart';

/// Main Zyndio App Widget
class BrandHealthApp extends ConsumerWidget {
  const BrandHealthApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    final isDark = ref.watch(darkModeProvider);

    // Register the alert notifier for global access in the scheduler
    // This allows background/logic code to trigger in-app banners
    NotificationScheduler().registerAlertNotifier(ref.read(alertProvider.notifier));

    // Trigger initial Apple Watch sync if on iOS
    // We do this after a small delay to ensure providers are ready
    WidgetsBinding.instance.addPostFrameCallback((_) {
      WatchService.initialize(ref);
      ref.read(wearableSyncProvider.notifier).sync();
    });

    return MaterialApp.router(
      title: 'Zyndio',
      debugShowCheckedModeBanner: false,
      theme: BrandTheme.lightTheme,
      darkTheme: BrandTheme.darkTheme,
      themeMode: isDark ? ThemeMode.dark : ThemeMode.light,
      routerConfig: router,
      builder: (context, child) {
        // Update system UI overlay based on theme
        final brightness = isDark ? Brightness.light : Brightness.dark;
        SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: brightness,
          statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
          systemNavigationBarColor: Colors.transparent,
          systemNavigationBarIconBrightness: brightness,
          systemNavigationBarContrastEnforced: false,
        ));
        // Wrap with AlertWrapper so in-app alerts appear above all screens
        return AlertWrapper(child: child ?? const SizedBox.shrink());
      },
    );
  }
}
