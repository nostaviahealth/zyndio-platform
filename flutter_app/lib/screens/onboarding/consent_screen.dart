import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../config/theme.dart';
import '../../demo/widgets/consent_row.dart';
import '../../demo/widgets/step_progress.dart';
import '../../providers/auth_provider.dart';
import '../../providers/onboarding_provider.dart';
import '../auth/widgets/patient_auth_chrome.dart';

/// APP-02 onboarding step 1: agree to Zyndio's terms, privacy notice and
/// consent to use health data. Each is recorded server-side as its own
/// consents row with the document, version and time
/// (`grant_patient_consents`). The app stays on this step until every
/// required document is agreed; a newer version brings the patient back.
/// Layout follows the demo build's consent screen (screen 02).
class OnboardingConsentScreen extends ConsumerStatefulWidget {
  const OnboardingConsentScreen({super.key});

  @override
  ConsumerState<OnboardingConsentScreen> createState() => _OnboardingConsentScreenState();
}

class _OnboardingConsentScreenState extends ConsumerState<OnboardingConsentScreen> {
  final Set<String> _checked = {};
  bool _showRequired = false;
  bool _saving = false;
  String? _error;

  Future<void> _submit(List<ConsentDocument> docs) async {
    if (_saving) return;
    if (docs.any((d) => !_checked.contains(d.consentType))) {
      setState(() => _showRequired = true);
      return;
    }
    final repo = ref.read(patientOnboardingRepositoryProvider);
    if (repo == null) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await repo.grantConsents(docs);
      ref.invalidate(onboardingStatusProvider);
    } on OnboardingException catch (e) {
      if (!mounted) return;
      setState(() {
        if (e.code == 'consent_version_stale') {
          // A newer version was published while this screen was open:
          // reload and ask again rather than record agreement to old text.
          _checked.clear();
          _error = 'One of these documents was just updated. Please review it again.';
          ref.invalidate(onboardingStatusProvider);
        } else {
          _error = "We couldn't save your agreement. Check your connection and try again.";
        }
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = "We couldn't save your agreement. Check your connection and try again.");
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _read(ConsentDocument doc) {
    final c = zcOf(context);
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: c.bgSurface,
      builder: (context) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.8,
        builder: (context, controller) => ListView(
          controller: controller,
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
          children: [
            Text(doc.title, style: ZyndioType.title2.copyWith(color: c.textPrimary)),
            const SizedBox(height: 4),
            Text('Version ${doc.version}',
                style: ZyndioType.footnote.copyWith(color: c.textTertiary)),
            if (doc.isPlaceholder) ...[
              const SizedBox(height: 16),
              const AuthStatusBanner(
                tone: AuthBannerTone.warning,
                message: 'Placeholder text. Zyndio will supply the final wording before launch.',
              ),
            ],
            const SizedBox(height: 16),
            Text(doc.body, style: ZyndioType.callout.copyWith(color: c.textPrimary)),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = zcOf(context);
    final status = ref.watch(onboardingStatusProvider);
    final docs = status.value?.missingConsents ?? const <ConsentDocument>[];

    Widget body;
    if (status.isLoading && !status.hasValue) {
      body = const Padding(
        padding: EdgeInsets.symmetric(vertical: 32),
        child: Center(child: CircularProgressIndicator()),
      );
    } else if (status.hasError && !status.hasValue) {
      body = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const AuthStatusBanner(
            message: "We couldn't load the documents. Check your connection and try again.",
          ),
          const SizedBox(height: 16),
          AuthPrimaryButton(
            label: 'Try again',
            onPressed: () => ref.invalidate(onboardingStatusProvider),
          ),
        ],
      );
    } else {
      body = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_error != null) ...[
            AuthStatusBanner(message: _error!),
            const SizedBox(height: 16),
          ],
          Container(
            decoration: BoxDecoration(
              color: c.bgSurface,
              borderRadius: BorderRadius.circular(ZyndioRadius.md),
              border: Border.all(color: c.borderSubtle),
            ),
            child: Column(
              children: [
                for (var i = 0; i < docs.length; i++) ...[
                  ConsentRow(
                    key: Key('consent-${docs[i].consentType}'),
                    title: docs[i].title,
                    subline: docs[i].summary.isNotEmpty
                        ? docs[i].summary
                        : 'Version ${docs[i].version}',
                    checked: _checked.contains(docs[i].consentType),
                    showRequiredError:
                        _showRequired && !_checked.contains(docs[i].consentType),
                    onToggle: () => setState(() {
                      final t = docs[i].consentType;
                      _checked.contains(t) ? _checked.remove(t) : _checked.add(t);
                    }),
                    onLinkTap: () => _read(docs[i]),
                  ),
                  if (i != docs.length - 1)
                    Divider(height: 1, color: c.borderSubtle, indent: 16, endIndent: 16),
                ],
              ],
            ),
          ),
          const SizedBox(height: 24),
          AuthPrimaryButton(
            label: 'Agree and continue',
            loading: _saving,
            onPressed: () => _submit(docs),
          ),
          const SizedBox(height: 12),
          Text(
            'We keep a record of each version you agree to and when.',
            textAlign: TextAlign.center,
            style: ZyndioType.caption.copyWith(color: c.textTertiary),
          ),
        ],
      );
    }

    return PatientAuthShell(
      title: 'Before we begin',
      subtitle:
          'Please review and agree to how Zyndio cares for you and handles your health information.',
      hero: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Step 1 of 2', style: ZyndioType.footnote.copyWith(color: c.textTertiary)),
          const SizedBox(height: 8),
          const StepProgress(value: 0.5),
        ],
      ),
      body: body,
      footer: AuthSecondaryButton(
        label: 'Sign out',
        outlined: false,
        onPressed: () => ref.read(authNotifierProvider.notifier).signOut(),
      ),
    );
  }
}
