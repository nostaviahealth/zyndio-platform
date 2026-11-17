// Robustness gate: every screen a patient can reach (default flags, see the
// screen map in PROJECT_STATUS.md) must build, settle and scroll end to end
// without a single framework error — no exceptions, no RenderFlex overflow,
// no "A RenderFlex overflowed" stripes — on:
//   * a small phone (iPhone SE, 320 × 568) and a current one (402 × 874),
//   * light and dark themes,
//   * default text and large accessibility text (up to 2.0×, which the
//     theme promises to support — see ZyndioType).
// Screens get the same fictional demo data the "Explore the demo" login uses,
// and no Supabase client, so any code that assumes a live backend at build
// time fails here instead of on a patient's phone.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zyndio_patient/config/theme.dart';
import 'package:zyndio_patient/data/lab_submission.dart';
import 'package:zyndio_patient/demo_login/demo_login.dart';
import 'package:zyndio_patient/screens/auth/code_sign_in_screen.dart';
import 'package:zyndio_patient/screens/auth/delete_account_screen.dart';
import 'package:zyndio_patient/screens/auth/link_record_screen.dart';
import 'package:zyndio_patient/screens/biomarkers/biomarkers_screen.dart';
import 'package:zyndio_patient/screens/care/care_screen.dart';
import 'package:zyndio_patient/screens/chat/chat_history_screen.dart';
import 'package:zyndio_patient/screens/chat/chat_screen.dart';
import 'package:zyndio_patient/screens/common/coming_soon_screen.dart';
import 'package:zyndio_patient/screens/common/service_unavailable_screen.dart';
import 'package:zyndio_patient/screens/lens/lens_screen.dart';
import 'package:zyndio_patient/models/food_log.dart';
import 'package:zyndio_patient/screens/settings/meal_detail_screen.dart';
import 'package:zyndio_patient/screens/settings/paywall_screen.dart';
import 'package:zyndio_patient/screens/health_data/health_data_screen.dart';
import 'package:zyndio_patient/screens/health_data/lab_report_submitted_screen.dart';
import 'package:zyndio_patient/screens/health_data/lab_report_upload_screen.dart';
import 'package:zyndio_patient/screens/health_data/my_lab_records_screen.dart';
import 'package:zyndio_patient/screens/health_data/report_detail_screen.dart';
import 'package:zyndio_patient/screens/my_plan/my_plan_screen.dart';
import 'package:zyndio_patient/screens/notifications/notification_screen.dart';
import 'package:zyndio_patient/screens/onboarding/consent_screen.dart';
import 'package:zyndio_patient/screens/onboarding/profile_setup_screen.dart';
import 'package:zyndio_patient/screens/progress/progress_screen.dart';
import 'package:zyndio_patient/screens/protocol/protocol_detail_screen.dart';
import 'package:zyndio_patient/screens/protocol/protocol_screen.dart';
import 'package:zyndio_patient/screens/protocol/protocols_list_screen.dart';
import 'package:zyndio_patient/screens/protocol/weekly_menu_screen.dart';
import 'package:zyndio_patient/screens/settings/connect_wearable_screen.dart';
import 'package:zyndio_patient/screens/settings/connections_screen.dart';
import 'package:zyndio_patient/screens/settings/edit_profile_screen.dart';
import 'package:zyndio_patient/screens/settings/export_health_data_screen.dart';
import 'package:zyndio_patient/screens/settings/legal_screens.dart';
import 'package:zyndio_patient/screens/settings/lens_history_screen.dart';
import 'package:zyndio_patient/screens/settings/partner_outcomes_consent_screen.dart';
import 'package:zyndio_patient/screens/settings/settings_screen.dart';
import 'package:zyndio_patient/screens/today/today_screen.dart';

class _DemoOn extends DemoSession {
  @override
  bool build() => true;
}

class _Config {
  const _Config(this.name, this.size, this.brightness, this.textScale);
  final String name;
  final Size size;
  final Brightness brightness;
  final double textScale;
}

const _configs = [
  _Config('SE light 1.0x', Size(320, 568), Brightness.light, 1.0),
  _Config('SE dark 1.3x', Size(320, 568), Brightness.dark, 1.3),
  _Config('17 light 1.0x', Size(402, 874), Brightness.light, 1.0),
  _Config('17 dark 2.0x', Size(402, 874), Brightness.dark, 2.0),
];

/// Every screen reachable with default flags, built with demo data.
final Map<String, Widget Function()> _screens = {
  // Tabs (MainShell gives them their Scaffold in the app)
  'Today': () => const Scaffold(body: TodayScreen()),
  'Progress': () => const Scaffold(body: ProgressScreen()),
  'Biomarkers': () => const Scaffold(body: BiomarkersScreen()),
  'My Plan': () => const Scaffold(body: MyPlanScreen()),
  'Care': () => const Scaffold(body: CareScreen()),
  // Pushed from the tabs
  'Profile & settings': () => const SettingsScreen(),
  'Lab results': () => const HealthDataScreen(),
  'Report detail': () => ReportDetailScreen(report: demoLabReports().first),
  'My lab records': () => const MyLabRecordsScreen(),
  'Lab upload': () => const LabReportUploadScreen(),
  'Lab submitted (analyzed)': () => const LabReportSubmittedScreen(
      submission: LabSubmission(outcome: LabSubmissionOutcome.analyzed)),
  'Lab submitted (needs review)': () => const LabReportSubmittedScreen(
      submission: LabSubmission(
          outcome: LabSubmissionOutcome.needsReview, needsReviewCount: 2)),
  'DEXA report': () => DexaReportPage(scans: demoBodyScans()),
  'Your plan': () => const ProtocolScreen(),
  'Plan detail': () => ProtocolDetailScreen(protocol: demoPlan()),
  'All plans': () => const ProtocolsListScreen(),
  'Weekly menu': () => const WeeklyMenuScreen(),
  'Food log': () => const LensHistoryScreen(),
  'AI companion': () => const ChatScreen(),
  'Chat history': () => const ChatHistoryScreen(),
  'Notifications': () => const NotificationScreen(),
  'Edit profile': () => const EditProfileScreen(),
  'Export health data': () => const ExportHealthDataScreen(),
  'Connections': () => const ConnectionsScreen(),
  'Connect wearable': () => const ConnectWearableScreen(),
  'Link clinic record': () => const LinkRecordScreen(),
  'Partner outcomes': () => const PartnerOutcomesConsentScreen(),
  'Privacy notice': () => const PrivacyPolicyScreen(),
  'Terms of service': () => const TermsOfServiceScreen(),
  'Telehealth consent': () => const InformedConsentScreen(),
  'Help centre': () => const HelpCenterScreen(),
  'Delete account': () => const DeleteAccountScreen(),
  'Subscription details': () => const SubscriptionDetailsScreen(),
  'Paywall': () => const PaywallScreen(),
  'Meal scanner (Lens)': () => const LensScreen(),
  'Meal detail': () => MealDetailScreen(
      log: FoodLog(
          id: 'f1',
          userId: 'u1',
          mealType: 'lunch',
          loggedAt: DateTime(2026, 11, 16, 13, 5),
          analysis: const {
            'name': 'Grilled salmon bowl',
            'calories': 540,
            'protein': 38,
            'carbs': 46,
            'fat': 21,
          })),
  'Service unavailable': () => const ServiceUnavailableScreen(),
  'Coming soon (dead link)': () =>
      const ComingSoonScreen(featureName: 'Page: /missing'),
  // Signed-out and onboarding
  'Sign in': () => const CodeSignInScreen(),
  'Onboarding consent': () => const OnboardingConsentScreen(),
  'Onboarding profile': () => const OnboardingProfileScreen(),
};

/// Errors reported through FlutterError.onError, with the widget that
/// caused them (file:line), captured as they happen.
final List<String> _reported = [];

String _describe(FlutterErrorDetails d) {
  final text = d.toString();
  final summary = d.exceptionAsString().split('\n').first;
  final where = RegExp(r'(lib/[\w/]+\.dart:\d+)').firstMatch(text)?.group(1) ?? '?';
  return '$summary  @ $where';
}

/// Drains every error the framework reported (overflows, exceptions).
List<String> _drainErrors(WidgetTester tester) {
  final errors = <String>[..._reported];
  _reported.clear();
  for (Object? e = tester.takeException(); e != null; e = tester.takeException()) {
    if (errors.isEmpty) errors.add(e.toString().split('\n').first);
  }
  return errors;
}

Future<void> _settle(WidgetTester tester) async {
  // Bounded pumping: some screens animate forever (rings, shimmer), so
  // pumpAndSettle would time out without meaning anything is wrong.
  for (var i = 0; i < 12; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  for (final entry in _screens.entries) {
    for (final cfg in _configs) {
      testWidgets('${entry.key} renders cleanly · ${cfg.name}', (tester) async {
        final original = FlutterError.onError;
        FlutterError.onError = (d) {
          _reported.add(_describe(d));
          original?.call(d);
        };
        tester.view.physicalSize = cfg.size * 3;
        tester.view.devicePixelRatio = 3;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final router = GoRouter(
          initialLocation: '/screen',
          routes: [
            GoRoute(path: '/', builder: (c, s) => const Scaffold(body: Text('HOME'))),
            GoRoute(path: '/screen', builder: (c, s) => entry.value()),
          ],
          errorBuilder: (c, s) => const Scaffold(body: Text('ROUTE')),
        );

        await tester.pumpWidget(ProviderScope(
          overrides: [
            ...demoLoginOverrides(),
            demoSessionProvider.overrideWith(_DemoOn.new),
          ],
          child: MaterialApp.router(
            debugShowCheckedModeBanner: false,
            theme: BrandTheme.lightTheme,
            darkTheme: BrandTheme.darkTheme,
            themeMode: cfg.brightness == Brightness.dark
                ? ThemeMode.dark
                : ThemeMode.light,
            routerConfig: router,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: TextScaler.linear(cfg.textScale)),
              child: child!,
            ),
          ),
        ));
        await _settle(tester);
        final errors = _drainErrors(tester);

        // Scroll every vertical list to the end so lazily built rows (and
        // their overflows) are exercised too.
        for (var pass = 0; pass < 6; pass++) {
          final scrollables = find.byWidgetPredicate(
              (w) => w is Scrollable && w.axisDirection == AxisDirection.down);
          if (scrollables.evaluate().isEmpty) break;
          await tester.drag(scrollables.first, const Offset(0, -600),
              warnIfMissed: false);
          await _settle(tester);
          errors.addAll(_drainErrors(tester));
        }

        // Unmount and let timers drain: leaked timers/streams surface here.
        await tester.pumpWidget(const SizedBox());
        await tester.pump(const Duration(seconds: 2));
        errors.addAll(_drainErrors(tester));

        FlutterError.onError = original;
        expect(errors, isEmpty, reason: errors.join('\n'));
      });
    }
  }
}
