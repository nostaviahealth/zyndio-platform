import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../screens/settings/edit_profile_screen.dart';
import '../screens/settings/connect_wearable_screen.dart';
import '../screens/settings/connections_screen.dart';
import '../screens/wearables/sleep_dashboard_screen.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../screens/auth/login_screen.dart';
import '../screens/auth/signup_screen.dart';
import '../screens/auth/verify_email_screen.dart';
import '../screens/auth/forgot_password_screen.dart';
import '../screens/auth/reset_password_screen.dart';
import '../screens/auth/delete_account_screen.dart';
import '../screens/auth/link_record_screen.dart';

import '../screens/health_data/health_data_screen.dart';

import '../screens/health_data/lab_report_upload_screen.dart';

import '../screens/today/today_screen.dart';
import '../screens/progress/progress_screen.dart';
import '../screens/biomarkers/biomarkers_screen.dart';
import '../screens/care/care_screen.dart';
import '../providers/feature_flags_provider.dart';

import '../screens/protocol/protocol_screen.dart';
import '../screens/protocol/protocols_list_screen.dart';
import '../screens/intelligence/digital_twin_screen.dart'; // <--- Added Import
import '../screens/settings/settings_screen.dart';
import '../screens/settings/legal_screens.dart';
import '../screens/chat/chat_screen.dart';
import '../screens/chat/chat_history_screen.dart';
import '../widgets/main_shell.dart';
import '../providers/auth_provider.dart';
import '../screens/protocol/weekly_menu_screen.dart';
import '../screens/meditation/meditation_hub_screen.dart';
import '../screens/settings/meditation_stats_screen.dart';
import '../screens/settings/lens_history_screen.dart';
import '../screens/settings/questionnaire_screen.dart';
import '../screens/settings/activity_goals_screen.dart'; // New Import
import '../screens/settings/export_health_data_screen.dart'; // Export Health Data
import '../screens/settings/leagues_screen.dart'; // <--- Added Import
import '../screens/lens/lens_screen.dart';
import '../screens/notifications/notification_screen.dart';
import '../screens/common/coming_soon_screen.dart'; // <--- Added Import
import '../screens/settings/timeline_history_screen.dart';
import '../screens/settings/nutrition_goals_screen.dart';
import '../screens/settings/ai_memories_screen.dart';
import '../screens/home/cycle_tracking_screen.dart';
import '../services/ai_consent_service.dart';
import '../services/analytics_service.dart';
import '../screens/shop/shop_home_screen.dart';
import '../screens/shop/shop_product_list_screen.dart';
import '../screens/shop/shop_product_detail_screen.dart';
import '../screens/appointments/appointments_hub_screen.dart';
import '../screens/appointments/doctor_detail_screen.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>();

/// Pure TC-025 redirect rules. Returns the path to redirect to, or null to stay.
///
/// * With [patientExtrasEnabled] off (the default), Shop / Meditate / Cycle
///   deep links land on Today (specs §11, A4) — no error screen, nothing deleted.
/// * The old tab paths keep working as redirects to their new homes (A3).
String? tc025Redirect(String loc, {required bool patientExtrasEnabled}) {
  if (!patientExtrasEnabled &&
      (loc == '/shop' ||
          loc.startsWith('/shop/') ||
          loc == '/meditate' ||
          loc == '/cycle')) {
    return '/';
  }
  if (loc == '/protocol') return '/my-plan';
  if (loc == '/health_data') return '/biomarkers';
  if (loc == '/wearables') return '/';
  return null;
}

/// App Router Configuration
/// Matches the React app routing structure
final routerProvider = Provider<GoRouter>((ref) {
  // Use select to only rebuild the router if the user ID or auth state genuinely changes
  // This prevents sudden "Home" redirects during background token refreshes
  final isLoggedIn = ref.watch(authStateProvider.select((v) => v.value != null));
  final isDemoMode = ref.watch(isDemoModeProvider);
  final aiConsent = ref.watch(aiConsentProvider);
  final flags = ref.watch(featureFlagsProvider);

  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: '/',
    debugLogDiagnostics: true,
    observers: [
      if (AnalyticsService().observer != null)
        AnalyticsService().observer!,
    ],
    redirect: (context, state) {
      // TC-025 legacy-path + patient-extras redirects (A3/A4).
      final tc = tc025Redirect(state.matchedLocation,
          patientExtrasEnabled: flags.patientExtrasEnabled);
      if (tc != null) return tc;

      // In demo mode, always allow access (skip auth check)
      if (isDemoMode) {
        return null;
      }

      final isLoggedInState = isLoggedIn;
      final isLoggingIn = state.matchedLocation == '/login';
      final isSigningUp = state.matchedLocation == '/signup';
      // TC-012: verify-email/forgot-password/reset-password all happen
      // before (or without) a session - a freshly signed-up patient has no
      // session until they verify and sign in, so these must be reachable
      // without tripping the "not logged in -> /login" redirect below.
      final isPatientPreAuthPage = state.matchedLocation == '/verify-email' ||
          state.matchedLocation == '/forgot-password' ||
          state.matchedLocation == '/reset-password';
      final isAuthPage = isLoggingIn || isSigningUp || isPatientPreAuthPage;

      // If not logged in and not on auth page, redirect to login
      if (!isLoggedInState && !isAuthPage) {
        return '/login';
      }

      // If logged in and on auth page, redirect to home
      if (isLoggedInState && isAuthPage) {
        return '/';
      }

      // ── AI CONSENT CHECK ──
      // If logged in but hasn't consented to AI, redirect to home to trigger onboarding
      if (aiConsent.isLoading) return null; // Wait for data before redirecting
      
      final hasConsented = aiConsent.value ?? false;
      
      if (isLoggedInState && !hasConsented && !isAuthPage) {
         if (state.uri.toString() != '/?onboarding=true' && state.matchedLocation != '/') {
           return '/?onboarding=true';
         }
      }

      return null;
    },
    routes: [

      // Auth routes (no shell)
      GoRoute(
        path: '/login',
        name: 'login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/signup',
        name: 'signup',
        builder: (context, state) => const SignupScreen(),
      ),
      GoRoute(
        path: '/verify-email',
        name: 'verify-email',
        builder: (context, state) {
          final email = state.extra is String ? state.extra as String : null;
          final token = state.uri.queryParameters['token'];
          return VerifyEmailScreen(email: email, token: token);
        },
      ),
      GoRoute(
        path: '/forgot-password',
        name: 'forgot-password',
        builder: (context, state) => const ForgotPasswordScreen(),
      ),
      GoRoute(
        path: '/reset-password',
        name: 'reset-password',
        builder: (context, state) =>
            ResetPasswordScreen(token: state.uri.queryParameters['token']),
      ),
      GoRoute(
        path: '/delete-account',
        name: 'delete-account',
        builder: (context, state) => const DeleteAccountScreen(),
      ),
      GoRoute(
        path: '/link-record',
        name: 'link-record',
        builder: (context, state) => const LinkRecordScreen(),
      ),

      // Main app routes with the 5-tab bottom navigation shell (TC-025).
      // Branch order must match widgets/main_shell.dart _kTabs:
      // 0 Today · 1 Progress · 2 Biomarkers · 3 My Plan · 4 Care.
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) => MainShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/',
                name: 'home',
                pageBuilder: (context, state) => NoTransitionPage(
                  child: const TodayScreen(),
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/progress',
                name: 'progress',
                pageBuilder: (context, state) => NoTransitionPage(
                  child: const ProgressScreen(),
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/biomarkers',
                name: 'biomarkers',
                pageBuilder: (context, state) => NoTransitionPage(
                  child: const BiomarkersScreen(),
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/my-plan',
                name: 'my_plan',
                pageBuilder: (context, state) => NoTransitionPage(
                  child: const ProtocolScreen(),
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/care',
                name: 'care',
                pageBuilder: (context, state) => NoTransitionPage(
                  child: const CareScreen(),
                ),
              ),
            ],
          ),
        ],
      ),

      // Lab upload + legacy Labs panels kept reachable as standalone routes
      // (their old /health_data tab is now /biomarkers; see the redirect below).
      GoRoute(
        path: '/health_data/upload',
        name: 'upload_report',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const LabReportUploadScreen(),
      ),
      GoRoute(
        path: '/health_data/gut-microbiome',
        name: 'gut_microbiome_panel',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const HealthDataScreen(reportType: 'Gut Microbiome'),
      ),
      GoRoute(
        path: '/health_data/genetic',
        name: 'genetic_panel',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const HealthDataScreen(reportType: 'Genetic'),
      ),
      GoRoute(
        path: '/health_data/biological-age',
        name: 'biological_age_panel',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const HealthDataScreen(reportType: 'Biological Age'),
      ),
      GoRoute(
        path: '/health_data/heavy-metals',
        name: 'heavy_metals_panel',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const HealthDataScreen(reportType: 'Heavy Metals'),
      ),
      GoRoute(
        path: '/health_data/toxicity',
        name: 'toxicity_panel',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const HealthDataScreen(reportType: 'Toxicity'),
      ),
      GoRoute(
        path: '/settings',
        name: 'settings',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const SettingsScreen(),
        routes: [
          GoRoute(
            path: 'edit_profile',
            name: 'edit_profile',
            builder: (context, state) => const EditProfileScreen(),
          ),
          GoRoute(
            path: 'activity_goals',
            name: 'activity_goals',
            builder: (context, state) => const ActivityGoalsScreen(),
          ),
          GoRoute(
            path: 'export_health_data',
            name: 'export_health_data',
            builder: (context, state) => const ExportHealthDataScreen(),
          ),
          GoRoute(
            path: 'privacy',
            name: 'privacy',
            builder: (context, state) => const PrivacyPolicyScreen(),
          ),
          GoRoute(
            path: 'terms',
            name: 'terms',
            builder: (context, state) => const TermsOfServiceScreen(),
          ),
          GoRoute(
            path: 'refund',
            name: 'refund',
            builder: (context, state) => const RefundPolicyScreen(),
          ),
          GoRoute(
            path: 'consent',
            name: 'consent',
            builder: (context, state) => const InformedConsentScreen(),
          ),
          GoRoute(
            path: 'help',
            name: 'help',
            builder: (context, state) => const HelpCenterScreen(),
          ),
          GoRoute(
            path: 'meditation_stats',
            name: 'meditation_stats',
            builder: (context, state) => const MeditationStatsScreen(),
          ),
          GoRoute(
            path: 'timeline',
            name: 'timeline',
            builder: (context, state) => const TimelineHistoryScreen(),
          ),
          GoRoute(
            path: 'leagues',
            name: 'leagues',
            builder: (context, state) => const LeaguesScreen(),
          ),
          GoRoute(
            path: 'memories',
            name: 'memories',
            builder: (context, state) => const AIMemoriesScreen(),
          ),
        ],
      ),
      GoRoute(
        path: '/weekly-menu',
        name: 'weekly_menu',
        builder: (context, state) => const WeeklyMenuScreen(),
      ),
      GoRoute(
        path: '/protocols',
        name: 'protocols',
        builder: (context, state) => const ProtocolsListScreen(),
      ),
      GoRoute(
        path: '/chat',
        name: 'chat',
        builder: (context, state) {
          final initialMessage = state.uri.queryParameters['initialMessage'];
          return ChatScreen(initialMessage: initialMessage);
        },
      ),
      GoRoute(
        path: '/chat-history',
        name: 'chat_history',
        builder: (context, state) => const ChatHistoryScreen(),
      ),
      GoRoute(
        path: '/lens',
        name: 'lens',
        builder: (context, state) => const LensScreen(),
      ),
      GoRoute(
        path: '/food-log',
        name: 'lens_history',
        builder: (context, state) => const LensHistoryScreen(),
      ),
      GoRoute(
        path: '/notifications',
        name: 'notifications',
        builder: (context, state) => const NotificationScreen(),
      ),
      GoRoute(
        path: '/coming-soon',
        name: 'coming_soon',
        builder: (context, state) {
          final title = state.uri.queryParameters['title'] ?? 'Feature';
          return ComingSoonScreen(featureName: title);
        },
      ),
      GoRoute(
        path: '/questionnaire',
        name: 'questionnaire',
        builder: (context, state) => const QuestionnaireScreen(),
      ),
      GoRoute(
        path: '/connect-wearable',
        name: 'connect_wearable',
        parentNavigatorKey: _rootNavigatorKey, // Force root navigator
        builder: (context, state) => const ConnectWearableScreen(),
      ),
      GoRoute(
        path: '/settings/connections',
        name: 'connections',
        parentNavigatorKey: _rootNavigatorKey, // Force root navigator
        builder: (context, state) => const ConnectionsScreen(),
      ),
      GoRoute(
        path: '/wearables/sleep_dashboard',
        name: 'sleep_dashboard',
        parentNavigatorKey: _rootNavigatorKey, // Force root navigator
        builder: (context, state) => const SleepDashboardScreen(),
      ),
      GoRoute(
        path: '/settings/digital_twin',
        name: 'digital_twin',
        builder: (context, state) => const DigitalTwinScreen(),
      ),
      GoRoute(
        path: '/settings/nutrition_goals',
        name: 'nutrition_goals',
        builder: (context, state) => const NutritionGoalsScreen(),
      ),
      GoRoute(
        path: '/meditate',
        name: 'meditate',
        builder: (context, state) => const MeditationHubScreen(),
      ),
      GoRoute(
        path: '/cycle',
        name: 'cycle',
        builder: (context, state) => const CycleTrackingScreen(),
      ),
      GoRoute(
        path: '/shop',
        name: 'shop',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const ShopHomeScreen(),
        routes: [
          GoRoute(
            path: 'products/:category',
            name: 'shop_products',
            builder: (context, state) => ShopProductListScreen(
              category: state.pathParameters['category'] ?? 'all',
            ),
          ),
          GoRoute(
            path: 'product/:id',
            name: 'shop_product_detail',
            builder: (context, state) => ShopProductDetailScreen(
              productId: state.pathParameters['id'] ?? '',
            ),
          ),
        ],
      ),
      GoRoute(
        path: '/appointments',
        name: 'appointments',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const AppointmentsHubScreen(),
        routes: [
          GoRoute(
            path: 'doctor/:id',
            name: 'doctor_detail',
            builder: (context, state) => DoctorDetailScreen(
              doctorId: state.pathParameters['id'] ?? '',
            ),
          ),
        ],
      ),
    ],
    errorBuilder: (context, state) => ComingSoonScreen(
      featureName: 'Page: ${state.uri.path}',
    ),
  );
});
