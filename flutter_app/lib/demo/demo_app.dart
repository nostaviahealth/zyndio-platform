import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/theme.dart';
import 'data/fixtures.dart';
import 'demo_ready_web.dart' if (dart.library.io) 'demo_ready_io.dart'
    as ready;
import 'router/demo_state.dart';
import 'screens/flow_router.dart';
import 'screens/consent/consent_controller.dart';
import 'screens/consent/consent_state.dart';
import 'screens/consent/consent_view.dart';
import 'screens/lab_review/lab_review_controller.dart';
import 'screens/lab_review/lab_review_state.dart';
import 'screens/lab_review/lab_review_view.dart';
import 'screens/lab_trends/lab_trends_controller.dart';
import 'screens/lab_trends/lab_trends_state.dart';
import 'screens/lab_trends/lab_trends_view.dart';
import 'screens/lab_upload/lab_upload_controller.dart';
import 'screens/lab_upload/lab_upload_state.dart';
import 'screens/lab_upload/lab_upload_view.dart';
import 'screens/signin/signin_controller.dart';
import 'screens/signin/signin_state.dart';
import 'screens/signin/signin_view.dart';

export 'demo_build_flag.dart';

class DemoApp extends StatelessWidget {
  const DemoApp({super.key, this.initialParams});

  /// Overrides the params normally parsed from `Uri.base` — lets widget
  /// tests drive `?flow=journey` without a real browser URL.
  final DemoRouteParams? initialParams;

  @override
  Widget build(BuildContext context) {
    final params = initialParams ??
        DemoRouteParams.fromQueryParameters(Uri.base.queryParameters);
    return MaterialApp(
      title: 'Zyndio Demo',
      debugShowCheckedModeBanner: false,
      theme: BrandTheme.lightTheme,
      darkTheme: BrandTheme.darkTheme,
      themeMode: params.themeMode,
      builder: (context, child) {
        final mediaQuery = MediaQuery.of(context);
        return MediaQuery(
          data: mediaQuery.copyWith(disableAnimations: true),
          child: child!,
        );
      },
      home: _DemoHome(params: params),
    );
  }
}

class _DemoHome extends StatefulWidget {
  const _DemoHome({required this.params});

  final DemoRouteParams params;

  @override
  State<_DemoHome> createState() => _DemoHomeState();
}

class _DemoHomeState extends State<_DemoHome> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance
        .addPostFrameCallback((_) => ready.setDemoReadyFlag());
  }

  @override
  Widget build(BuildContext context) {
    if (widget.params.flow == 'journey') {
      return const DemoJourneyFlow();
    }
    final screen = widget.params.screen;
    // TC-029 (BUG-2): native builds have no web URL, so `?flow=`/`?screen=`
    // are both absent and screen choice fell through to the "coming soon"
    // placeholder. With no deep-link selected, open the real app entry — the
    // sign-in journey — instead. Web deep-links (?flow=journey, ?screen=…,
    // and the screenshot harness, which always passes a screen) are unchanged.
    if (screen == null && widget.params.flow == null) {
      return const DemoJourneyFlow();
    }
    if (screen == 'signin') {
      // A `state` query param (the screenshot harness) renders a fixed
      // fixture state; otherwise the view is wired to the live controller
      // so the demo build is actually usable, not just a screenshot target.
      if (widget.params.state != null) {
        return SignInView(state: signInStateForQueryState(widget.params.state));
      }
      return const _InteractiveSignIn();
    }
    if (screen == 'consent') {
      if (widget.params.state != null) {
        return ConsentView(state: consentStateForQueryState(widget.params.state));
      }
      return const _InteractiveConsent();
    }
    if (screen == 'lab-upload') {
      if (widget.params.state != null) {
        return LabUploadView(state: labUploadStateForQueryState(widget.params.state));
      }
      return const _InteractiveLabUpload();
    }
    if (screen == 'lab-review') {
      if (widget.params.state != null) {
        return LabReviewView(state: labReviewStateForQueryState(widget.params.state));
      }
      return const _InteractiveLabReview();
    }
    if (screen == 'lab-trends') {
      if (widget.params.state != null) {
        return LabTrendsView(state: labTrendsStateForQueryState(widget.params.state));
      }
      return const _InteractiveLabTrends();
    }

    final colors = Theme.of(context).extension<ZyndioColors>()!;
    final label = screen == null
        ? 'Zyndio demo — coming soon'
        : 'Screen "$screen" coming soon';
    return Scaffold(
      backgroundColor: colors.bgCanvas,
      body: Center(
        child: Text(
          label,
          style: ZyndioType.body.copyWith(color: colors.textPrimary),
        ),
      ),
    );
  }
}

class _InteractiveSignIn extends ConsumerWidget {
  const _InteractiveSignIn();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(signInControllerProvider);
    final controller = ref.read(signInControllerProvider.notifier);
    return SignInView(
      state: state,
      onEmailChanged: controller.updateEmail,
      onSendCode: controller.sendCode,
      onCodeChanged: controller.updateCode,
      onContinue: controller.submitCode,
      onSendNewCode: controller.sendCode,
      onBack: controller.backToEmail,
    );
  }
}

class _InteractiveConsent extends ConsumerWidget {
  const _InteractiveConsent();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(consentControllerProvider);
    final controller = ref.read(consentControllerProvider.notifier);
    return ConsentView(
      state: state,
      onToggleDoc: controller.toggleDoc,
      onTogglePartner: controller.togglePartnerSharing,
      onSubmit: controller.submit,
    );
  }
}

class _InteractiveLabUpload extends ConsumerWidget {
  const _InteractiveLabUpload();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(labUploadControllerProvider);
    final controller = ref.read(labUploadControllerProvider.notifier);
    return LabUploadView(
      state: state,
      onUploadAnyway: controller.confirmUploadAnyway,
      onCancelDuplicate: controller.cancelDuplicate,
      onPickPdf: () => controller.addFile(demoLabFileName, demoLabFileBytes()),
    );
  }
}

class _InteractiveLabReview extends ConsumerWidget {
  const _InteractiveLabReview();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(labReviewControllerProvider);
    final controller = ref.read(labReviewControllerProvider.notifier);
    return LabReviewView(state: state, onSave: controller.save);
  }
}

class _InteractiveLabTrends extends ConsumerStatefulWidget {
  const _InteractiveLabTrends();

  @override
  ConsumerState<_InteractiveLabTrends> createState() => _InteractiveLabTrendsState();
}

class _InteractiveLabTrendsState extends ConsumerState<_InteractiveLabTrends> {
  @override
  void initState() {
    super.initState();
    // Deferred past this build/mount: Riverpod disallows writing a provider
    // from initState (the widget tree is still building at that point).
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => ref.read(labTrendsControllerProvider.notifier).refresh(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(labTrendsControllerProvider);
    return LabTrendsView(state: state);
  }
}
