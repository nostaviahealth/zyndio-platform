import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../config/theme.dart';
import '../../widgets/app_card.dart';
import '../../providers/auth_provider.dart';
import '../../providers/patient_provider.dart';
// <--- Added Import
import '../../providers/module_order_provider.dart';
import '../../widgets/onboarding_overlay.dart'; // <--- Added
import '../health_data/my_lab_records_screen.dart';
import '../../providers/purchase_provider.dart';
import 'paywall_screen.dart';
import '../../widgets/dynamic_branding_icon.dart';
import '../../services/branding_service.dart';
import '../../services/notification_service.dart';
import '../../providers/organization_provider.dart';
/// Settings screen matching React Settings.tsx
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:badges/badges.dart' as badges;
import '../../providers/notification_provider.dart';


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
    final info = await PackageInfo.fromPlatform();
    if (mounted) {
      setState(() {
        _appVersion = '${info.appName} v${info.version} (${info.buildNumber})';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final patientProfile = ref.watch(patientProfileProvider).value;

    return Scaffold(
      backgroundColor: context.nc.scaffoldBg,
      body: SafeArea(
        bottom: false,
        child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  GestureDetector(
                    onTap: () => context.pop(),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: context.nc.inputFill,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(LucideIcons.chevronLeft, color: context.nc.iconDefault, size: 20),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Settings',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                      color: context.nc.textPrimary,
                      letterSpacing: -1.0,
                    ),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: () => context.push('/notifications'),
                    child: Consumer(
                      builder: (context, ref, child) {
                        final unreadCount = ref.watch(unreadNotificationCountProvider);
                        return badges.Badge(
                          position: badges.BadgePosition.topEnd(top: -2, end: -2),
                          showBadge: unreadCount > 0,
                          badgeContent: Text(
                            unreadCount.toString(),
                            style: const TextStyle(color: Colors.white, fontSize: 10),
                          ),
                          child: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: context.nc.inputFill,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(LucideIcons.bell, color: context.nc.iconDefault, size: 20),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20), // Added space below header
              // Membership Section
              Consumer(
                builder: (context, ref, _) {
                  final purchaseState = ref.watch(purchaseProvider);
                  final isPlus = purchaseState.isPlus;
                  
                  return _MembershipCard(
                    isPlus: isPlus,
                    onUpgrade: () => PaywallScreen.show(context),
                    onManage: () => PaywallScreen.showCustomerCenter(),
                  );
                },
              ),
              const SizedBox(height: 24),

              // Profile Section
              const _SectionHeader(title: 'Profile'),
              const SizedBox(height: 12),
              
              // Profile Card (Moved here, linked to Edit Profile)
              Consumer(
                builder: (context, ref, _) {
                  final profile = ref.watch(patientProfileProvider).value;
                  final user = ref.watch(currentUserProvider);
                  return _ProfileCard(
                    name: profile?.name ?? 'User',
                    email: user?.email ?? 'No email provided',
                    avatarUrl: profile?.avatarUrl,
                    onTap: () => context.push('/settings/edit_profile'),
                    onAvatarTap: () async {
                      final picker = ImagePicker();
                      final image = await picker.pickImage(
                        source: ImageSource.gallery,
                        imageQuality: 80,
                      );
                      
                      if (image != null) {
                        // 2. Crop Image
                        final croppedFile = await ImageCropper().cropImage(
                          sourcePath: image.path,
                          maxWidth: 256, // Keep it light for Base64 storage
                          maxHeight: 256,
                          compressFormat: ImageCompressFormat.jpg,
                          compressQuality: 70,
                          aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1), // Force Square
                          uiSettings: [
                            AndroidUiSettings(
                              toolbarTitle: 'Crop Profile Photo',
                              toolbarColor: BrandColors.dark,
                              toolbarWidgetColor: Colors.white,
                              initAspectRatio: CropAspectRatioPreset.square,
                              lockAspectRatio: true,
                            ),
                            IOSUiSettings(
                              title: 'Crop Profile Photo',
                              aspectRatioLockEnabled: true,
                              resetAspectRatioEnabled: false,
                              rotateButtonsHidden: true,
                              rotateClockwiseButtonHidden: true,
                              aspectRatioPickerButtonHidden: true,
                              resetButtonHidden: true,
                            ),
                          ],
                        );

                        if (croppedFile != null) {
                          try {
                            // 3. Upload Cropped Image
                            await ref.read(patientProfileProvider.notifier).updateAvatar(XFile(croppedFile.path));
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Profile photo updated')),
                              );
                            }
                          } catch (e) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Failed to upload: $e')),
                              );
                            }
                          }
                        }
                      }
                    },
                  );
                },
              ),
              const SizedBox(height: 8),
              
              _SettingsCard(
                icon: LucideIcons.trophy,
                title: 'Leagues & Rewards',
                subtitle: 'View your badges and monthly progress',
                onTap: () => context.push('/settings/leagues'),
                isProminent: true,
              ),

              _SettingsCard(
                icon: LucideIcons.target,
                title: 'Activity Goals',
                subtitle: 'Set daily Move, Training, and Steps targets',
                onTap: () => context.push('/settings/activity_goals'),
              ),
              _SettingsCard(
                icon: LucideIcons.utensilsCrossed,
                title: 'Nutrition Goals',
                subtitle: 'Set daily Energy and Macro targets',
                onTap: () => context.push('/settings/nutrition_goals'),
              ),
          /* Hiding for now per user request
          _SettingsCard(
            icon: LucideIcons.scanLine,
            title: 'Digital Twin',
            subtitle: 'View your personalized anatomical model',
            onTap: () => context.push('/settings/digital_twin'),
          ),
          */
          _SettingsCard(
            icon: LucideIcons.dna,
            title: 'Longevity Profile',
            subtitle: 'Complete your 6-Pillar assessment',
            onTap: () => context.pushNamed('questionnaire'),
          ),
          _SettingsCard(
            icon: LucideIcons.barChart2,
            title: 'Meditation Stats',
            subtitle: 'View your meditation history and progress',
            onTap: () => context.push('/settings/meditation_stats'),
          ),
          /* Hiding per user request
          _SettingsCard(
            icon: LucideIcons.activity,
            title: 'Timeline',
            subtitle: 'View your historical health journey',
            onTap: () => context.push('/settings/timeline'),
          ),
          */
          _SettingsCard(
            icon: LucideIcons.fileSpreadsheet,
            title: 'My Lab Records',
            subtitle: 'View your uploaded lab reports',
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (c) => const MyLabRecordsScreen())),
          ),
          _SettingsCard(
            icon: LucideIcons.fileDown,
            title: 'Export Health Data',
            subtitle: 'Generate a clinical PDF snapshot for your doctor',
            onTap: () => context.push('/settings/export_health_data'),
          ),
          Consumer(
            builder: (context, ref, _) {
              final selectedOrg = ref.watch(selectedOrganizationProvider);
              return _SettingsCard(
                icon: LucideIcons.building,
                title: 'Organization',
                subtitle: 'Selected: $selectedOrg',
                onTap: () {
                  showModalBottomSheet(
                    context: context,
                    backgroundColor: context.nc.cardSurface,
                    shape: const RoundedRectangleBorder(
                      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                    ),
                    builder: (ctx) {
                      return SafeArea(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const SizedBox(height: 16),
                            const Text(
                              'Select Organization',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 16),
                            ListTile(
                              title: const Text('Default', style: TextStyle(color: Colors.white)),
                              trailing: selectedOrg == 'Default' ? const Icon(Icons.check, color: Color(0xFF007AFF)) : null,
                              onTap: () {
                                ref.read(patientProfileProvider.notifier).updateProfile(organization: 'Default');
                                Navigator.pop(ctx);
                              },
                            ),
                            ListTile(
                              title: const Text('Test01', style: TextStyle(color: Colors.white)),
                              trailing: selectedOrg == 'Test01' ? const Icon(Icons.check, color: Color(0xFF007AFF)) : null,
                              onTap: () {
                                ref.read(patientProfileProvider.notifier).updateProfile(organization: 'Test01');
                                Navigator.pop(ctx);
                              },
                            ),
                            ListTile(
                              title: const Text('Test02', style: TextStyle(color: Colors.white)),
                              trailing: selectedOrg == 'Test02' ? const Icon(Icons.check, color: Color(0xFF007AFF)) : null,
                              onTap: () {
                                ref.read(patientProfileProvider.notifier).updateProfile(organization: 'Test02');
                                Navigator.pop(ctx);
                              },
                            ),
                            const SizedBox(height: 16),
                          ],
                        ),
                      );
                    },
                  );
                },
              );
            },
          ),
          const SizedBox(height: 24),


          // Intelligence Section
          const _SectionHeader(title: 'Intelligence'),
          const SizedBox(height: 12),
          _SettingsCard(
            icon: LucideIcons.brain,
            title: 'AI Memories',
            subtitle: 'View and manage what the AI remembers about you',
            onTap: () => context.push('/settings/memories'),
          ),
          const SizedBox(height: 24),

          // Integrations Section
          const _SectionHeader(title: 'Integrations'),
          const SizedBox(height: 12),
          _SettingsCard(
            icon: LucideIcons.watch,
            title: 'Connections',
            subtitle: 'Sync with Apple Health & WHOOP',
            onTap: () => context.pushNamed('connections'),
          ),
          const SizedBox(height: 24),


          // Notifications Section
          const _SectionHeader(title: 'Notifications'),
          const SizedBox(height: 12),
          _SettingsSwitchCard(
            icon: LucideIcons.bell,
            title: 'Push Notifications',
            subtitle: 'Real-time health alerts and reminders',
            value: true, 
            onChanged: (value) async {
              if (value) {
                final granted = await NotificationService().requestPermissions();
                if (granted) {
                  await NotificationService().initialize();
                  await NotificationService().syncTokenToSupabase();
                }
              }
            },
          ),

          const SizedBox(height: 24),

          // Dashboard Customization Section
          const _SectionHeader(title: 'Dashboard Customization'),
          const SizedBox(height: 12),
          Consumer(
            builder: (context, ref, _) {
              final moduleOrder = ref.watch(moduleOrderProvider);
              return AppCard(
                padding: const EdgeInsets.all(0),
                child: Column(
                  children: [
                    const Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Row(
                        children: [
                          Icon(LucideIcons.layoutDashboard, color: BrandColors.slate400, size: 20),
                          SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Intelligence Modules Order', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 16)),
                                SizedBox(height: 4),
                                Text('Drag to reorder dashboard cards', style: TextStyle(color: BrandColors.slate500, fontSize: 12)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1, color: BrandColors.slate800),
                    ReorderableListView(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      onReorder: (oldIndex, newIndex) {
                        ref.read(moduleOrderProvider.notifier).reorder(oldIndex, newIndex);
                      },
                      children: [
                        for (int i = 0; i < moduleOrder.length; i++)
                          ListTile(
                            key: ValueKey(moduleOrder[i].name),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                            leading: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: context.nc.scaffoldBg,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text('${i + 1}', style: const TextStyle(color: BrandColors.slate400, fontWeight: FontWeight.bold)),
                            ),
                            title: Text(moduleOrder[i].displayName, style: const TextStyle(color: Colors.white, fontSize: 14)),
                            trailing: const Icon(LucideIcons.gripVertical, color: BrandColors.slate500),
                          ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
          
          const SizedBox(height: 24),

          // Appearance Section
          const _SectionHeader(title: 'Appearance'),
          const SizedBox(height: 12),
          /* Hiding Dark Mode toggle per user request - App is now Dark Mode only
          Consumer(
            builder: (context, ref, _) {
              final isDark = ref.watch(darkModeProvider);
              return _SettingsSwitchCard(
                icon: LucideIcons.moon,
                title: 'Dark Mode',
                subtitle: 'Premium intelligence dark theme',
                value: isDark,
                onChanged: (value) => ref.read(darkModeProvider.notifier).toggleDarkMode(),
              );
            },
          ),
          */
            /* Hiding Immersive Background toggle per user request
            Consumer(
            builder: (context, ref, _) {
              final isImmersive = ref.watch(themeProvider);
              return _SettingsSwitchCard(
                icon: LucideIcons.image,
                title: 'Immersive Background',
                subtitle: 'Use dynamic background image',
                value: isImmersive,
                onChanged: (value) => ref.read(themeProvider.notifier).toggleTheme(),
              );
            },
          ),
          */
          /* Hiding per user request
          Consumer(
            builder: (context, ref, _) {
              final isSwipeTimeline = ref.watch(timelineViewProvider);
              return _SettingsSwitchCard(
                icon: LucideIcons.layers,
                title: 'Card Stack Timeline',
                subtitle: 'Swipeable card experience',
                value: isSwipeTimeline,
                onChanged: (value) => ref.read(timelineViewProvider.notifier).toggleView(),
              );
            },
          ),
          */
          

          const SizedBox(height: 16),

          // App Icon Selector
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 4, vertical: 8),
            child: Text("APP ICON", style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: BrandColors.slate500, letterSpacing: 1)),
          ),
          Consumer(
            builder: (context, ref, _) {
              final isPlus = ref.watch(purchaseProvider).isPlus;
              
              return FutureBuilder<String>(
                future: BrandingService().getActiveIconName(),
                builder: (context, snapshot) {
                  final activeIcon = snapshot.data ?? 'Default';
                  
                  return Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: _AppIconCard(
                              title: 'Default',
                              iconAsset: 'assets/icons/app_icon.png',
                              isSelected: activeIcon == 'Default',
                              onTap: () => BrandingService().updateAppIcon(false, persist: true).then((_) {
                                if (context.mounted) setState(() {});
                              }),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Stack(
                              children: [
                                _AppIconCard(
                                  title: 'N PLUS',
                                  iconAsset: 'assets/icons/plus_logo.png',
                                  isSelected: activeIcon == 'PremiumBrand',
                                  isLocked: false, // Unlocked for testing
                                  onTap: () {
                                    BrandingService().updateAppIcon(true, persist: true).then((_) {
                                      if (context.mounted) setState(() {});
                                    });
                                  },
                                ),
                                // Lock removed for testing
                              ],
                            ),
                          ),
                        ],
                      ),
                      // Premium membership requirements temporarily removed for verification
                    ],
                  );
                },
              );
            },
          ),
          
          const SizedBox(height: 16),
          
          /* Hiding Intelligence Theme selector per user request
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 4, vertical: 8),
            child: Text("INTELLIGENCE THEME", style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: BrandColors.slate500, letterSpacing: 1)),
          ),
          Consumer(
             builder: (context, ref, _) {
                final aiTheme = ref.watch(aiThemeProvider);
                return Row(
                  children: [
                    Expanded(
                      child: _ThemeOptionCard(
                        title: 'Zyndio Blue',
                        color: const Color(0xFF3B82F6),
                        isSelected: aiTheme == AIThemeMode.classic,
                        onTap: () => ref.read(aiThemeProvider.notifier).toggleTheme(AIThemeMode.classic),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _ThemeOptionCard(
                        title: 'Radiance',
                        gradient: const LinearGradient(colors: [Color(0xFFF59E0B), Color(0xFFA855F7), Color(0xFF3B82F6)]),
                        isSelected: aiTheme == AIThemeMode.siri,
                        onTap: () => ref.read(aiThemeProvider.notifier).toggleTheme(AIThemeMode.siri),
                      ),
                    ),
                  ],
                );
             }
          ),
          */
          const SizedBox(height: 24),

          // Support Section
          const _SectionHeader(title: 'Support'),
          const SizedBox(height: 12),
          _SettingsCard(
            icon: LucideIcons.helpCircle,
            title: 'Help Center',
            subtitle: 'FAQs and support',
            onTap: () => context.push('/settings/help'),
          ),
          _SettingsCard(
            icon: LucideIcons.helpCircle,
            title: 'Review Onboarding',
            subtitle: 'See the new app introduction',
            onTap: () {
              showGeneralDialog(
                context: context,
                barrierDismissible: false,
                barrierColor: Colors.black.withOpacity(0.5),
                transitionDuration: const Duration(milliseconds: 400),
                pageBuilder: (context, anim1, anim2) => const OnboardingOverlay(),
              );
            },
          ),
          _SettingsCard(
            icon: LucideIcons.mail,
            title: 'Contact Us',
            subtitle: 'Get in touch with our team',
            onTap: () => _sendEmail('support@zyndio.example', 'Support Request'),
          ),
           const SizedBox(height: 24),

          // Legal Section
          const _SectionHeader(title: 'Legal'),
          const SizedBox(height: 12),
          _SettingsCard(
            icon: LucideIcons.fileText,
            title: 'Terms of Service',
            subtitle: 'Read our terms and conditions',
             onTap: () => context.push('/settings/terms'),
          ),
          _SettingsCard(
            icon: LucideIcons.lock,
            title: 'Privacy Policy',
            subtitle: 'How we handle your data',
             onTap: () => context.push('/settings/privacy'),
          ),
          _SettingsCard(
            icon: LucideIcons.rotateCcw,
            title: 'Refund Policy',
            subtitle: 'Cancellations and refunds',
             onTap: () => context.push('/settings/refund'),
          ),
          _SettingsCard(
            icon: LucideIcons.fileSignature,
            title: 'Telehealth Consent',
            subtitle: 'Informed consent for care',
             onTap: () => context.push('/settings/consent'),
          ),
          _SettingsCard(
            icon: LucideIcons.scale,
            title: 'Open Source Licenses',
            subtitle: 'Third-party software notices',
             onTap: () => showLicensePage(
               context: context,
               applicationName: 'Zyndio',
               applicationLegalese: '© 2026 Zyndio. All rights reserved.',
               useRootNavigator: true,
             ),
          ),
          const SizedBox(height: 24),

          // Actions
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () async {
                 // Sign out
                await ref.read(authNotifierProvider.notifier).signOut();
                if (context.mounted) {
                  context.go('/login');
                }
              },
              icon: Icon(LucideIcons.logOut, color: context.nc.textSecondary),
              label: Text(
                'Sign Out',
                style: TextStyle(color: context.nc.textSecondary),
              ),
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: context.nc.divider),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          
          // Delete Account (Compliance)
          SizedBox(
            width: double.infinity,
            child: TextButton(
               onPressed: () => _showDeleteAccountDialog(context),
               child: const Text('Delete Account', style: TextStyle(color: BrandColors.red500)),
            ),
          ),
          
          const SizedBox(height: 24),

          // App Version
          Center(
            child: Text(
              _appVersion.isEmpty ? 'Zyndio' : _appVersion,
              style: const TextStyle(
                fontSize: 12,
                color: BrandColors.slate400,
              ),
            ),
          ),
          const SizedBox(height: 40),
        ],
      ),
          ),
        ),
    );
  }

  // --- Handlers ---
  
  Future<void> _launchURL(String urlString) async {
    final url = Uri.parse(urlString);
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication); // Open in real browser
    } else {
       if (mounted) {
         ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not open $urlString')));
       }
    }
  }

  Future<void> _sendEmail(String email, String subject) async {
      final Uri emailLaunchUri = Uri(
        scheme: 'mailto',
        path: email,
        query: _encodeQueryParameters(<String, String>{
          'subject': subject,
        }),
      );
      if (await canLaunchUrl(emailLaunchUri)) {
          await launchUrl(emailLaunchUri);
      } else {
           if (mounted) {
             ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not open email client')));
           }
      }
  }
  
  String? _encodeQueryParameters(Map<String, String> params) {
    return params.entries
        .map((e) => '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}')
        .join('&');
  }

  void _showDeleteAccountDialog(BuildContext context) {
    showDialog(
      context: context,
      useRootNavigator: true, // Fix for hidden dialog
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Account', style: TextStyle(color: BrandColors.red500)),
        content: const Text(
          'This action is permanent. Do you want to request account deletion? This will open your email client to send a deletion request to our support team.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: BrandColors.slate500)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _sendEmail('support@zyndio.example', 'Urgent: Delete My Account Request');
            },
            child: const Text('Request Deletion', style: TextStyle(color: BrandColors.red500, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}

// ... Keep _SectionHeader and _SettingsCard classes ...
class _SectionHeader extends StatelessWidget {
  final String title;

  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: context.nc.textTertiary,
          letterSpacing: 1.5,
        ),
      ),
    );
  }
}

class _ProfileCard extends StatelessWidget {
  final String name;
  final String email;
  final String? avatarUrl;
  final VoidCallback? onTap;
  final VoidCallback? onAvatarTap;

  const _ProfileCard({
    required this.name,
    required this.email,
    this.avatarUrl,
    this.onTap,
    this.onAvatarTap,
  });

  ImageProvider? _getAvatarProvider() {
    if (avatarUrl == null || avatarUrl!.isEmpty) return null;
    if (avatarUrl!.startsWith('data:image')) {
      try {
        final base64String = avatarUrl!.split(',').last;
        return MemoryImage(base64Decode(base64String));
      } catch (e) {
        debugPrint('Error decoding base64 avatar: $e');
        return null;
      }
    }
    return NetworkImage(avatarUrl!);
  }

  @override
  Widget build(BuildContext context) {
    final avatarProvider = _getAvatarProvider();
    
    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.all(16),
      borderRadius: BorderRadius.circular(24),
      child: Row(
        children: [
          GestureDetector(
            onTap: onAvatarTap,
            child: Stack(
              children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: context.nc.inputFill,
                    shape: BoxShape.circle,
                    image: avatarProvider != null
                        ? DecorationImage(
                            image: avatarProvider,
                            fit: BoxFit.cover,
                          )
                        : null,
                    border: Border.all(color: context.nc.cardSurface, width: 3),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        blurRadius: 15,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: avatarProvider == null
                      ? Center(
                          child: Text(
                            name.isNotEmpty ? name[0].toUpperCase() : 'U',
                            style: const TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.w800,
                              color: BrandColors.slate500,
                            ),
                          ),
                        )
                      : null,
                ),
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: context.nc.textPrimary,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(LucideIcons.camera, size: 12, color: context.nc.scaffoldBg),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: context.nc.textPrimary,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  email,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    color: BrandColors.slate500,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: context.nc.inputFill,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              LucideIcons.chevronRight,
              size: 20,
              color: BrandColors.slate400,
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingsCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool isProminent;

  const _SettingsCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.isProminent = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        decoration: BoxDecoration(
          color: context.nc.cardSurface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: context.nc.cardBorder, width: 1),
          boxShadow: [
            BoxShadow(
              color: context.nc.shadowColor,
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: context.nc.inputFill,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(icon, size: 20, color: context.nc.iconDefault),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: context.nc.textPrimary,
                            letterSpacing: -0.2,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          subtitle,
                          style: TextStyle(
                            fontSize: 12,
                            color: context.nc.textTertiary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    LucideIcons.chevronRight,
                    size: 18,
                    color: context.nc.textTertiary,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SettingsSwitchCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _SettingsSwitchCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: AppCard(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8), // Slightly less vertical padding
        borderRadius: BorderRadius.circular(12),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: context.nc.inputFill,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, size: 18, color: context.nc.iconDefault),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: context.nc.textPrimary,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: context.nc.textTertiary,
                    ),
                  ),
                ],
              ),
            ),
            Switch(
              value: value, 
              onChanged: onChanged,
              activeThumbColor: BrandColors.emerald500,
            ),
          ],
        ),
      ),
    );
  }
}

class _ThemeOptionCard extends StatelessWidget {
  final String title;
  final Color? color;
  final Gradient? gradient;
  final bool isSelected;
  final VoidCallback onTap;

  const _ThemeOptionCard({
    required this.title,
    this.color,
    this.gradient,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: context.nc.cardSurface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? context.nc.textPrimary : context.nc.divider,
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected 
              ? [BoxShadow(color: context.nc.shadowColor, blurRadius: 8, offset: const Offset(0, 4))]
              : [],
        ),
        child: Column(
          children: [
            Container(
              width: 48, height: 48,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color,
                gradient: gradient,
              ),
              child: isSelected 
                  ? Icon(LucideIcons.check, color: Colors.white)
                  : null,
            ),
            const SizedBox(height: 12),
            Text(title, style: TextStyle(
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              color: isSelected ? context.nc.textPrimary : context.nc.textSecondary,
              fontSize: 13,
            ))
          ],
        ),
      ),
    );
  }
}

class _MembershipCard extends StatelessWidget {
  final bool isPlus;
  final VoidCallback onUpgrade;
  final VoidCallback onManage;

  const _MembershipCard({
    required this.isPlus,
    required this.onUpgrade,
    required this.onManage,
  });

  @override
  Widget build(BuildContext context) {
    if (!isPlus) {
      return GestureDetector(
        onTap: onUpgrade,
        child: Container(
          width: double.infinity,
          height: 84,
          decoration: BoxDecoration(
            // "Super Zyndio" Cosmic Gradient (matching SuperGrok)
            gradient: const LinearGradient(
              colors: [
                Color(0xFF1D4ED8), // Vivid Blue
                Color(0xFF1E3A8A), // Deep Indigo
                Color(0xFF1E1B4B), // Midnight Blue
              ],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
            borderRadius: BorderRadius.circular(40),
            border: Border.all(
              color: Colors.white.withOpacity(0.15),
              width: 1.0,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF1D4ED8).withOpacity(0.2),
                blurRadius: 15,
                spreadRadius: 2,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(40),
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Starry/Glow background effect
                Positioned(
                  left: 10,
                  top: -10,
                  child: Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          const Color(0xFF60A5FA).withOpacity(0.2),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),
                
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      // Dynamic Branding Icon (Autoswitches for Plus/Pro/Ultimate)
                      const DynamicBrandingIcon(
                        size: 48,
                        showGlow: true,
                      ),
                      const SizedBox(width: 10),
                      
                      // Text Container
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Zyndio Plus',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                                letterSpacing: -0.2,
                              ),
                            ),
                            Text(
                              'Smart. Personal. Pro.',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: Colors.white.withOpacity(0.7),
                                letterSpacing: 0.1,
                              ),
                            ),
                          ],
                        ),
                      ),
                      
                      const SizedBox(width: 12),
                      
                      // Upgrade Pill Button
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1D4ED8), // Vivid Grok Blue
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.2),
                            width: 1.0,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.2),
                              blurRadius: 10,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: const Text(
                          'Upgrade',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.2,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // --- Premium "Plus" Card ---
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
        child: Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: const Color(0xFF0F172A).withOpacity(0.8), // Refined opacity
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: Colors.white.withOpacity(0.08),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Stack(
            children: [
              // Subtle Inner Aurora Glow (Compact & Dimmed)
              Positioned(
                top: -20,
                right: -10,
                child: Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        const Color(0xFF3B82F6).withOpacity(0.06), // Reduced from 0.1
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),

              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    Row(
                      children: [
                        // Compact Brand Icon
                        const DynamicBrandingIcon(
                          size: 48,
                          showGlow: true,
                        ),
                        const SizedBox(width: 10), // Reduced from 14
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'MEMBERSHIP STATUS',
                                style: TextStyle(
                                  fontSize: 9,
                                  letterSpacing: 2.0,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white.withOpacity(0.3), // Slightly dimmer
                                ),
                              ),
                              const SizedBox(height: 4),
                              const Text(
                                'ZYNDIO PLUS',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w900,
                                  color: Color(0xFFE2E8F0), // Solid light slate for less glow
                                  letterSpacing: -0.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    // Compact Manage Button
                    GestureDetector(
                      onTap: onManage,
                      child: Container(
                        width: double.infinity,
                        height: 44,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.white.withOpacity(0.08),
                              Colors.white.withOpacity(0.04),
                            ],
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                          ),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.1),
                            width: 1,
                          ),
                        ),
                        child: const Center(
                          child: Text(
                            'Manage Subscription',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
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
        ),
      ),
    );
  }
}


class _AppIconCard extends StatelessWidget {
  final String title;
  final String iconAsset;
  final bool isSelected;
  final bool isLocked;
  final VoidCallback onTap;

  const _AppIconCard({
    required this.title,
    required this.iconAsset,
    required this.isSelected,
    this.isLocked = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: context.nc.cardSurface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? BrandColors.blue500 : context.nc.divider,
            width: 2,
          ),
          boxShadow: isSelected ? [
            BoxShadow(
              color: BrandColors.blue500.withOpacity(0.1),
              blurRadius: 8,
              offset: const Offset(0, 4),
            )
          ] : null,
        ),
        child: Column(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Opacity(
                opacity: 1.0, // Always opaque for testing
                child: Image.asset(
                  iconAsset,
                  width: 48,
                  height: 48,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isSelected ? BrandColors.blue600 : context.nc.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
