import 'dart:async';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../config/theme.dart';
import '../../data/health_repository.dart';
import '../../services/wearable_daily/wearable_daily_sync.dart';
import '../../widgets/tc025/tc025_widgets.dart';
import '../../utils/platform_info.dart';

class ConnectWearableScreen extends StatefulWidget {
  const ConnectWearableScreen({super.key});

  @override
  State<ConnectWearableScreen> createState() => _ConnectWearableScreenState();
}

class _ConnectWearableScreenState extends State<ConnectWearableScreen> {
  final HealthRepository _healthRepository = HealthRepository();
  bool _isLoading = false;
  bool _isAuthorized = false;
  String _statusMessage = '';
  bool _showHealthConnectHint = false;

  @override
  void initState() {
    super.initState();
    _checkStatus();
  }

  Future<void> _checkStatus() async {
    await _healthRepository.configure();
    // Check persistence + actual permissions
    bool linked = await _healthRepository.isLinked();
    if (linked) {
        setState(() => _isAuthorized = true);
        return;
    }

    // Fallback to permission check
    bool authorized = await _healthRepository.hasPermissions();
    if (authorized) {
         await _healthRepository.setLinked(true); // Sync state
         if (mounted) setState(() => _isAuthorized = true);
    }
  }

  Future<void> _connect() async {
    setState(() {
      _isLoading = true;
      _statusMessage = ''; // Clear status while requesting
      _showHealthConnectHint = false;
    });

    try {
      // On Android, check if Health Connect is installed first
      if (PlatformInfo.isAndroid) {
        final hcStatus = await _healthRepository.getHealthConnectStatus();
        if (hcStatus == 'not_installed') {
          if (mounted) {
            setState(() {
              _statusMessage = 'Health Connect is not installed. It is required to sync health data from your wearable.';
              _showHealthConnectHint = true;
              _isLoading = false;
            });
          }
          return;
        } else if (hcStatus == 'needs_update') {
          if (mounted) {
            setState(() {
              _statusMessage = 'Health Connect needs to be updated. Please update it from the Play Store.';
              _showHealthConnectHint = true;
              _isLoading = false;
            });
          }
          return;
        }
      }

      bool success = await _healthRepository.requestUnifiedPermissions();
      if (success) {
          await _healthRepository.setLinked(true);
          // APP-07: upload to the clinic - 90-day backfill, in the background.
          unawaited(WearableDailySync.instance.onConnected());
      }
      
      if (mounted) {
        setState(() {
            _isAuthorized = success;
            if (success) {
              _statusMessage = 'Connected. Importing your last 90 days of health data in the background.';
            } else if (PlatformInfo.isAndroid) {
              _statusMessage = 'Health permissions were not granted. Please tap Connect again and allow all requested permissions. On Samsung devices, make sure Health Connect is syncing with Samsung Health.';
              _showHealthConnectHint = true;
            } else {
              _statusMessage = 'Permission denied or cancelled. Please try again and allow health data access in the prompt.';
            }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
            _statusMessage = 'Error connecting: $e';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
            _isLoading = false;
        });
      }
    }
  }

  Future<void> _disconnect() async {
      setState(() => _isLoading = true);
      // We can't revoke OS permissions programmatically, but we can unlink the app logic
      await _healthRepository.setLinked(false);
      
      if (mounted) {
          setState(() {
              _isAuthorized = false;
              _statusMessage = 'Disconnected. Dashboard will not sync.';
              _showHealthConnectHint = false;
              _isLoading = false;
          });
      }
  }

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).extension<ZyndioColors>()!;
    return ZyndioDetailScaffold(
      title: 'Connect Wearable',
      body: LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: (constraints.maxHeight - 20).clamp(0, double.infinity)),
            child: IntrinsicHeight(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Spacer(),
                  const Center(
                    child: ZyndioIconTile(icon: LucideIcons.activity, tint: ZyndioTint.blue, size: 72),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Sync Health Data',
                    textAlign: TextAlign.center,
                    style: ZyndioType.title1.copyWith(color: c.textPrimary),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Connect Zyndio to your device\'s health records to unlock personalized longevity insights based on your activity and sleep.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: ZyndioType.family,
                      fontSize: 15,
                      height: 22 / 15,
                      color: c.textSecondary,
                    ),
                  ),
                  const Spacer(),
                  const SizedBox(height: 24),
                  if (_statusMessage.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: _isAuthorized ? c.statusSuccessSubtle : c.statusCriticalSubtle,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Text(
                          _statusMessage,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontFamily: ZyndioType.family,
                            color: _isAuthorized ? c.statusSuccess : c.statusCritical,
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                            height: 20 / 14,
                          ),
                        ),
                      ),
                    ),
                  // Health Connect install/update button for Android
                  if (_showHealthConnectHint && PlatformInfo.isAndroid)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: ZyndioOutlineButton(
                        icon: LucideIcons.externalLink,
                        label: 'Install Health Connect',
                        onTap: () async {
                          final uri = Uri.parse('https://play.google.com/store/apps/details?id=com.google.android.apps.healthdata');
                          if (await canLaunchUrl(uri)) {
                            await launchUrl(uri, mode: LaunchMode.externalApplication);
                          }
                        },
                      ),
                    ),
                  if (_isAuthorized)
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: OutlinedButton(
                        onPressed: _isLoading ? null : _disconnect,
                        style: OutlinedButton.styleFrom(
                          backgroundColor: c.bgSurface,
                          foregroundColor: c.statusCritical,
                          disabledBackgroundColor: c.bgSurface,
                          side: BorderSide(color: c.borderSubtle, width: 1.5),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
                          textStyle: const TextStyle(
                            fontFamily: ZyndioType.family,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        child: _isLoading
                            ? SizedBox(
                                height: 22,
                                width: 22,
                                child: CircularProgressIndicator(strokeWidth: 2.4, color: c.statusCritical),
                              )
                            : const Text('Disconnect'),
                      ),
                    )
                  else
                    ZyndioGradientButton(
                      label: 'Connect Health Data',
                      trailingArrow: false,
                      loading: _isLoading,
                      onTap: _isLoading ? null : _connect,
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
