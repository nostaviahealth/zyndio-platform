import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/demo_backend.dart';
import '../data/fixtures.dart';
import 'consent/consent_controller.dart';
import 'consent/consent_view.dart';
import 'lab_review/lab_review_controller.dart';
import 'lab_review/lab_review_view.dart';
import 'lab_trends/lab_trends_controller.dart';
import 'lab_trends/lab_trends_view.dart';
import 'lab_upload/lab_upload_controller.dart';
import 'lab_upload/lab_upload_view.dart';
import 'signin/signin_controller.dart';
import 'signin/signin_view.dart';

enum _JourneyStep { signIn, consent, labUpload, labReview, labTrends }

/// The `?flow=journey` path (Step 6): a sequential walk through the real
/// patient journey — sign-in -> consent -> lab upload -> lab review -> lab
/// trends. Each step is driven by the same controllers the single-screen
/// `?screen=` routes use, through the real [ZyndioRepository]/`DemoBackend`,
/// never a shortcut: the session that unlocks consent/labs/trends comes only
/// from a real [SignInController.submitCode] success here, so
/// `requireDemoSession`'s auto-sign-in fallback is never exercised on this
/// path.
class DemoJourneyFlow extends ConsumerStatefulWidget {
  const DemoJourneyFlow({super.key});

  @override
  ConsumerState<DemoJourneyFlow> createState() => _DemoJourneyFlowState();
}

class _DemoJourneyFlowState extends ConsumerState<DemoJourneyFlow> {
  _JourneyStep _step = _JourneyStep.signIn;

  void _advance(_JourneyStep next) => setState(() => _step = next);

  @override
  Widget build(BuildContext context) {
    switch (_step) {
      case _JourneyStep.signIn:
        return _SignInStep(onSignedIn: () => _advance(_JourneyStep.consent));
      case _JourneyStep.consent:
        return _ConsentStep(onAgreed: () => _advance(_JourneyStep.labUpload));
      case _JourneyStep.labUpload:
        return _LabUploadStep(onUploaded: () => _advance(_JourneyStep.labReview));
      case _JourneyStep.labReview:
        return _LabReviewStep(onSaved: () => _advance(_JourneyStep.labTrends));
      case _JourneyStep.labTrends:
        return const _LabTrendsStep();
    }
  }
}

class _SignInStep extends ConsumerWidget {
  const _SignInStep({required this.onSignedIn});

  final VoidCallback onSignedIn;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(signInControllerProvider);
    final controller = ref.read(signInControllerProvider.notifier);
    return SignInView(
      state: state,
      onEmailChanged: controller.updateEmail,
      onSendCode: controller.sendCode,
      onCodeChanged: controller.updateCode,
      onContinue: () {
        if (controller.submitCode() == CodeVerifyResult.success) onSignedIn();
      },
      onSendNewCode: controller.sendCode,
      onBack: controller.backToEmail,
    );
  }
}

class _ConsentStep extends ConsumerWidget {
  const _ConsentStep({required this.onAgreed});

  final VoidCallback onAgreed;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(consentControllerProvider);
    final controller = ref.read(consentControllerProvider.notifier);
    return ConsentView(
      state: state,
      onToggleDoc: controller.toggleDoc,
      onTogglePartner: controller.togglePartnerSharing,
      onSubmit: () {
        if (controller.submit()) onAgreed();
      },
    );
  }
}

class _LabUploadStep extends ConsumerWidget {
  const _LabUploadStep({required this.onUploaded});

  final VoidCallback onUploaded;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(labUploadControllerProvider);
    final controller = ref.read(labUploadControllerProvider.notifier);
    return LabUploadView(
      state: state,
      onUploadAnyway: controller.confirmUploadAnyway,
      onCancelDuplicate: controller.cancelDuplicate,
      onPickPdf: () {
        controller.addFile(demoLabFileName, demoLabFileBytes());
        onUploaded();
      },
    );
  }
}

class _LabReviewStep extends ConsumerWidget {
  const _LabReviewStep({required this.onSaved});

  final VoidCallback onSaved;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(labReviewControllerProvider);
    final controller = ref.read(labReviewControllerProvider.notifier);
    return LabReviewView(state: state, onSave: controller.save, onDone: onSaved);
  }
}

class _LabTrendsStep extends ConsumerStatefulWidget {
  const _LabTrendsStep();

  @override
  ConsumerState<_LabTrendsStep> createState() => _LabTrendsStepState();
}

class _LabTrendsStepState extends ConsumerState<_LabTrendsStep> {
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
