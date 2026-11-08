import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../config/theme.dart';
import '../../demo_login/demo_login.dart';
import '../../providers/auth_provider.dart';
import '../../providers/feature_flags_provider.dart';
import '../../providers/patient_provider.dart';
import '../../providers/programme_journey_provider.dart';
import '../../providers/purchase_provider.dart';
import '../../services/milestone_reminders.dart';
import '../../services/notification_service.dart';
import '../../widgets/tc025/tc025_widgets.dart';
import '../health_data/my_lab_records_screen.dart';
import 'paywall_screen.dart';

/// Profile & settings (opened from the avatar on every tab).
///
/// Organised around the programme: who you are, your records, privacy and
/// sharing (including the separate, revocable partner-outcomes authorisation,
/// APP-03), notifications, help, then sign out and account deletion (APP-11).
/// Consumer extras (membership, leagues, goals, shop, meditation) appear only
/// when the patient-extras flag is on.
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  String _appVersion = '';

  @override
  void initState() {
    super.initState();
    _loadVersion();
  }

  Future<void> _loadVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      if (mounted) {
        setState(() => _appVersion = 'Zyndio ${info.version} (${info.buildNumber})');
      }
    } catch (_) {
      // Version line falls back to "Zyndio".
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).extension<ZyndioColors>()!;
    final extras = ref.watch(featureFlagsProvider).patientExtrasEnabled;
    return Scaffold(
      backgroundColor: context.z25.screenBg,
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
          children: [
            _Header(onBack: () => context.pop()),
            const SizedBox(height: 16),
            _ProfileCard(onEditPhoto: _changePhoto),
            const SizedBox(height: 24),
            if (extras) ...[
              const _MembershipRow(),
              const SizedBox(height: 24),
            ],
            const ZyndioSectionLabel('Your records'),
            _Group(rows: [
              _Row(
                icon: LucideIcons.flaskConical,
                title: 'My lab records',
                subtitle: 'Reports you and your clinic have added',
                onTap: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => const MyLabRecordsScreen())),
              ),
              _Row(
                icon: LucideIcons.activity,
                title: 'Connected health data',
                subtitle: 'Apple Health or Health Connect',
                onTap: () => context.pushNamed('connections'),
              ),
              _Row(
                icon: LucideIcons.link,
                title: 'Link clinic record',
                subtitle: 'Connect this account to your clinic record',
                onTap: () => context.push('/link-record'),
              ),
              _Row(
                icon: LucideIcons.download,
                title: 'Export health data',
                subtitle: 'A PDF summary to share with your doctor',
                onTap: () => context.push('/settings/export_health_data'),
              ),
            ]),
            const SizedBox(height: 24),
            const ZyndioSectionLabel('Privacy and sharing'),
            _Group(rows: [
              _Row(
                icon: LucideIcons.share2,
                title: 'Partner outcomes sharing',
                subtitle: 'Optional. Change your choice at any time.',
                onTap: () => context.push('/settings/partner_outcomes'),
              ),
              _Row(
                icon: LucideIcons.fileSignature,
                title: 'Telehealth consent',
                subtitle: 'Informed consent for care',
                onTap: () => context.push('/settings/consent'),
              ),
              _Row(
                icon: LucideIcons.lock,
                title: 'Privacy Notice',
                onTap: () => context.push('/settings/privacy'),
              ),
              _Row(
                icon: LucideIcons.fileText,
                title: 'Terms of Service',
                onTap: () => context.push('/settings/terms'),
              ),
            ]),
            const SizedBox(height: 24),
            const ZyndioSectionLabel('Notifications'),
            _Group(rows: [
              _Row(
                icon: LucideIcons.inbox,
                title: 'Notification inbox',
                onTap: () => context.push('/notifications'),
              ),
              _Row(
                icon: LucideIcons.bellRing,
                title: 'Allow notifications',
                subtitle: 'Reminders for your scans and labs. No health details are shown.',
                onTap: _allowNotifications,
              ),
            ]),
            const SizedBox(height: 24),
            if (extras) ...[
              const _ExtrasToolsSection(),
              const SizedBox(height: 24),
            ],
            const MoreFromZyndioSection(),
            const ZyndioSectionLabel('Help'),
            _Group(rows: [
              _Row(
                icon: LucideIcons.lifeBuoy,
                title: 'Help centre',
                subtitle: 'Answers to common questions',
                onTap: () => context.push('/settings/help'),
              ),
              _Row(
                icon: LucideIcons.mail,
                title: 'Contact support',
                subtitle: 'For app questions. Clinical questions go to your care team.',
                onTap: () => _sendEmail('support@zyndio.example', 'Support request'),
              ),
              _Row(
                icon: LucideIcons.scale,
                title: 'Open source licences',
                onTap: () => showLicensePage(
                  context: context,
                  applicationName: 'Zyndio',
                  applicationLegalese: '© 2026 Zyndio. All rights reserved.',
                  useRootNavigator: true,
                ),
              ),
            ]),
            const SizedBox(height: 28),
            _SignOutButton(onTap: _signOut),
            const SizedBox(height: 16),
            _DeleteAccountCard(onTap: () => context.push('/delete-account')),
            const SizedBox(height: 24),
            Center(
              child: Text(
                _appVersion.isEmpty ? 'Zyndio' : _appVersion,
                style: TextStyle(
                  fontFamily: ZyndioType.family,
                  fontSize: 12,
                  color: c.textTertiary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Handlers ──────────────────────────────────────────────────────────────

  Future<void> _signOut() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sign out?'),
        content: const Text(
            'Your records stay safe. Sign in again with your clinic invite or email.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Sign out')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    if (kDemoLoginEnabled) ref.read(demoSessionProvider.notifier).end();
    try {
      await ref.read(authNotifierProvider.notifier).signOut();
    } catch (_) {
      // The session is cleared locally either way; the sign-in screen follows.
    }
    if (mounted) context.go('/login');
  }

  Future<void> _allowNotifications() async {
    final messenger = ScaffoldMessenger.of(context);
    bool granted = false;
    try {
      granted = await NotificationService().requestPermissions();
      if (granted) {
        await NotificationService().initialize();
        // Scan-and-labs reminders can be scheduled now that they're allowed.
        final journey = ref.read(programmeJourneyProvider);
        final scheduler = ref.read(milestoneReminderSchedulerProvider);
        if (journey != null && scheduler != null) {
          await syncMilestoneReminders(journey, scheduler);
        }
        await NotificationService().syncTokenToSupabase();
      }
    } catch (_) {
      granted = false;
    }
    messenger.showSnackBar(SnackBar(
      content: Text(granted
          ? 'Notifications are on.'
          : "Notifications are off. You can turn them on for Zyndio in your phone's Settings."),
    ));
  }

  Future<void> _changePhoto() async {
    final messenger = ScaffoldMessenger.of(context);
    final image = await ImagePicker()
        .pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (image == null) return;
    final cropped = await ImageCropper().cropImage(
      sourcePath: image.path,
      maxWidth: 256,
      maxHeight: 256,
      compressFormat: ImageCompressFormat.jpg,
      compressQuality: 70,
      aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
      uiSettings: [
        AndroidUiSettings(
          toolbarTitle: 'Crop profile photo',
          initAspectRatio: CropAspectRatioPreset.square,
          lockAspectRatio: true,
        ),
        IOSUiSettings(
          title: 'Crop profile photo',
          aspectRatioLockEnabled: true,
          resetAspectRatioEnabled: false,
          rotateButtonsHidden: true,
          rotateClockwiseButtonHidden: true,
          aspectRatioPickerButtonHidden: true,
          resetButtonHidden: true,
        ),
      ],
    );
    if (cropped == null) return;
    try {
      await ref
          .read(patientProfileProvider.notifier)
          .updateAvatar(XFile(cropped.path));
      messenger.showSnackBar(
          const SnackBar(content: Text('Profile photo updated')));
    } catch (_) {
      messenger.showSnackBar(const SnackBar(
          content: Text("Couldn't update your photo. Please try again.")));
    }
  }

  Future<void> _sendEmail(String email, String subject) async {
    final uri = Uri(
      scheme: 'mailto',
      path: email,
      query: 'subject=${Uri.encodeComponent(subject)}',
    );
    final messenger = ScaffoldMessenger.of(context);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      messenger.showSnackBar(
          const SnackBar(content: Text('Could not open your email app')));
    }
  }
}

// ── Parts ───────────────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  const _Header({required this.onBack});
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).extension<ZyndioColors>()!;
    return Row(
      children: [
        Semantics(
          button: true,
          label: 'Back',
          onTap: onBack,
          child: ExcludeSemantics(
            child: InkResponse(
              onTap: onBack,
              radius: 24,
              child: Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                decoration: zyndioCard(context, radius: 22),
                child: Icon(LucideIcons.chevronLeft,
                    size: 22, color: c.textPrimary),
              ),
            ),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Semantics(
            header: true,
            child: Text(
              'Profile & settings',
              style: TextStyle(
                fontFamily: ZyndioType.family,
                fontSize: 24,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.5,
                color: c.textPrimary,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ProfileCard extends ConsumerWidget {
  const _ProfileCard({required this.onEditPhoto});
  final VoidCallback onEditPhoto;

  ImageProvider? _photo(String? url) {
    if (url == null || url.isEmpty) return null;
    if (url.startsWith('data:image')) {
      try {
        return MemoryImage(base64Decode(url.split(',').last));
      } catch (_) {
        return null;
      }
    }
    return NetworkImage(url);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = Theme.of(context).extension<ZyndioColors>()!;
    final profile = ref.watch(patientProfileProvider).value;
    final email = ref.watch(currentUserProvider)?.email;
    final name = (profile?.name ?? '').trim();
    final initials = zyndioInitials(name);
    final photo = _photo(profile?.avatarUrl);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: zyndioCard(context),
      child: Row(
        children: [
          Semantics(
            button: true,
            label: 'Change profile photo',
            onTap: onEditPhoto,
            child: ExcludeSemantics(
              child: GestureDetector(
                onTap: onEditPhoto,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      width: 68,
                      height: 68,
                      padding: const EdgeInsets.all(3),
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: ZyndioGradients.brand,
                      ),
                      child: CircleAvatar(
                        backgroundColor: c.bgSurface,
                        backgroundImage: photo,
                        child: photo != null
                            ? null
                            : initials.isEmpty
                                ? Icon(LucideIcons.user,
                                    size: 28, color: c.textPrimary)
                                : Text(
                                    initials,
                                    style: TextStyle(
                                      fontFamily: ZyndioType.family,
                                      fontSize: 22,
                                      fontWeight: FontWeight.w700,
                                      color: c.textPrimary,
                                    ),
                                  ),
                      ),
                    ),
                    Positioned(
                      right: -2,
                      bottom: -2,
                      child: Container(
                        width: 26,
                        height: 26,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: c.bgSurface,
                          border: Border.all(color: c.borderSubtle),
                        ),
                        child: Icon(LucideIcons.camera,
                            size: 14, color: c.textPrimary),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name.isEmpty ? 'Your profile' : name,
                  style: TextStyle(
                    fontFamily: ZyndioType.family,
                    fontSize: 19,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.3,
                    color: c.textPrimary,
                  ),
                ),
                if (email != null && email.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    email,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: ZyndioType.family,
                      fontSize: 14,
                      color: c.textSecondary,
                    ),
                  ),
                ],
                const SizedBox(height: 10),
                Semantics(
                  button: true,
                  label: 'Edit profile',
                  onTap: () => context.push('/settings/edit_profile'),
                  child: ExcludeSemantics(
                    child: GestureDetector(
                      onTap: () => context.push('/settings/edit_profile'),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: context.z25.tileBg,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          'Edit profile',
                          style: TextStyle(
                            fontFamily: ZyndioType.family,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: c.textPrimary,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A grouped card of rows separated by hairlines (one card per section).
class _Group extends StatelessWidget {
  const _Group({required this.rows});
  final List<_Row> rows;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).extension<ZyndioColors>()!;
    return Container(
      decoration: zyndioCard(context, radius: 22),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: Column(
          children: [
            for (var i = 0; i < rows.length; i++) ...[
              if (i > 0)
                Divider(
                    height: 1,
                    thickness: 1,
                    indent: 66,
                    color: c.borderSubtle),
              rows[i],
            ],
          ],
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({
    required this.icon,
    required this.title,
    this.subtitle,
    required this.onTap,
    this.destructive = false,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).extension<ZyndioColors>()!;
    final fg = destructive ? c.statusCritical : c.textPrimary;
    return Semantics(
      button: true,
      label: [title, if (subtitle != null) subtitle].join(', '),
      onTap: onTap,
      child: ExcludeSemantics(
        child: InkWell(
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 60),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: context.z25.tileBg,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(icon, size: 18, color: fg),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          title,
                          style: TextStyle(
                            fontFamily: ZyndioType.family,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: fg,
                          ),
                        ),
                        if (subtitle != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            subtitle!,
                            style: TextStyle(
                              fontFamily: ZyndioType.family,
                              fontSize: 13,
                              height: 18 / 13,
                              color: c.textSecondary,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(LucideIcons.chevronRight,
                      size: 18, color: c.textTertiary),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SignOutButton extends StatelessWidget {
  const _SignOutButton({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).extension<ZyndioColors>()!;
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: onTap,
        icon: Icon(LucideIcons.logOut, size: 18, color: c.textPrimary),
        label: Text(
          'Sign out',
          style: TextStyle(
            fontFamily: ZyndioType.family,
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: c.textPrimary,
          ),
        ),
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(0, 52),
          side: BorderSide(color: c.borderStrong),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(999)),
        ),
      ),
    );
  }
}

/// APP-11 / Apple 5.1.1(v): the deletion request, with the legal-records
/// wording on the next screen.
class _DeleteAccountCard extends StatelessWidget {
  const _DeleteAccountCard({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).extension<ZyndioColors>()!;
    return Container(
      decoration: zyndioCard(context, radius: 22),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _Row(
              icon: LucideIcons.trash2,
              title: 'Delete account',
              destructive: true,
              onTap: onTap,
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
              child: Text(
                'Permanently deletes your Zyndio app account and the data you added in the app.',
                style: TextStyle(
                  fontFamily: ZyndioType.family,
                  fontSize: 13,
                  height: 18 / 13,
                  color: c.textTertiary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Membership (in-app subscription), only with the patient-extras flag.
class _MembershipRow extends ConsumerWidget {
  const _MembershipRow();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isPlus = ref.watch(purchaseProvider).isPlus;
    return _Group(rows: [
      _Row(
        icon: LucideIcons.sparkles,
        title: isPlus ? 'Manage membership' : 'Membership',
        subtitle: isPlus ? 'Your plan and billing' : 'See what membership adds',
        onTap: () => isPlus
            ? PaywallScreen.showCustomerCenter()
            : PaywallScreen.show(context),
      ),
    ]);
  }
}

/// Wellness tools outside the clinical programme, only with the
/// patient-extras flag.
class _ExtrasToolsSection extends StatelessWidget {
  const _ExtrasToolsSection();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const ZyndioSectionLabel('Wellness tools'),
        _Group(rows: [
          _Row(
            icon: LucideIcons.target,
            title: 'Activity goals',
            onTap: () => context.push('/settings/activity_goals'),
          ),
          _Row(
            icon: LucideIcons.utensilsCrossed,
            title: 'Nutrition goals',
            onTap: () => context.push('/settings/nutrition_goals'),
          ),
          _Row(
            icon: LucideIcons.dna,
            title: 'Longevity profile',
            onTap: () => context.pushNamed('questionnaire'),
          ),
          _Row(
            icon: LucideIcons.history,
            title: 'Timeline',
            onTap: () => context.push('/settings/timeline'),
          ),
          _Row(
            icon: LucideIcons.brain,
            title: 'AI memories',
            onTap: () => context.push('/settings/memories'),
          ),
          _Row(
            icon: LucideIcons.trophy,
            title: 'Leagues and rewards',
            onTap: () => context.push('/settings/leagues'),
          ),
          _Row(
            icon: LucideIcons.chartBar,
            title: 'Meditation stats',
            onTap: () => context.push('/settings/meditation_stats'),
          ),
        ]),
      ],
    );
  }
}

/// TC-025 A4: "More from Zyndio" settings section — Shop, Meditate and Cycle
/// Tracking, shown only when the patient-extras flag is on (off by default for
/// the 7 Nov build). With the flag off this renders nothing, so there is no
/// entry point for these anywhere; their deep links redirect to Today (see
/// config/routes.dart). Cycle Tracking shows only for a patient whose profile
/// records a female sex.
class MoreFromZyndioSection extends ConsumerWidget {
  const MoreFromZyndioSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(featureFlagsProvider).patientExtrasEnabled) {
      return const SizedBox.shrink();
    }
    final isFemale =
        ref.watch(patientProfileProvider).value?.questionnaireData?['gender'] ==
            'Female';
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const ZyndioSectionLabel('More from Zyndio'),
          _Group(rows: [
            _Row(
              icon: LucideIcons.shoppingBag,
              title: 'Shop',
              subtitle: 'Supplements and products from Zyndio',
              onTap: () => context.push('/shop'),
            ),
            _Row(
              icon: LucideIcons.flower,
              title: 'Meditate',
              subtitle: 'Guided meditations and breathing',
              onTap: () => context.push('/meditate'),
            ),
            if (isFemale)
              _Row(
                icon: LucideIcons.heartPulse,
                title: 'Cycle Tracking',
                subtitle: 'Track your menstrual cycle',
                onTap: () => context.push('/cycle'),
              ),
          ]),
        ],
      ),
    );
  }
}
