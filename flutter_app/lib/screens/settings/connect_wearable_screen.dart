import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../config/theme.dart';
import '../../data/health_repository.dart';
import '../../services/wearable_daily/wearable_daily_sync.dart';

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
      if (Platform.isAndroid) {
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
            } else if (Platform.isAndroid) {
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
    return Scaffold(
      backgroundColor: context.nc.scaffoldBg,
      appBar: AppBar(
        title: Text('Connect Wearable', style: TextStyle(color: context.nc.textPrimary)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: context.nc.textPrimary),
      ),
      body: Container(
        color: context.nc.scaffoldBg,
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(),
              Text(
                'Sync Health Data',
                style: TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.w900,
                  color: context.nc.textPrimary,
                  letterSpacing: -1.2,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Connect Zyndio to your device\'s health records to unlock personalized longevity insights based on your activity and sleep.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  color: BrandColors.slate500,
                  height: 1.6,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const Spacer(),
              if (_statusMessage.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: _isAuthorized ? BrandColors.emerald500.withOpacity(0.1) : BrandColors.red500.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      _statusMessage,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: _isAuthorized ? BrandColors.emerald500 : BrandColors.red500,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
              // Health Connect install/update button for Android
              if (_showHealthConnectHint && Platform.isAndroid)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: OutlinedButton.icon(
                      icon: const Icon(LucideIcons.externalLink, size: 18),
                      label: const Text(
                        'Install Health Connect',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: BrandColors.indigo500,
                        side: const BorderSide(color: BrandColors.indigo500),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: () async {
                        final uri = Uri.parse('https://play.google.com/store/apps/details?id=com.google.android.apps.healthdata');
                        if (await canLaunchUrl(uri)) {
                          await launchUrl(uri, mode: LaunchMode.externalApplication);
                        }
                      },
                    ),
                  ),
                ),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _isLoading 
                    ? null 
                    : (_isAuthorized ? _disconnect : _connect),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _isAuthorized ? BrandColors.red500 : BrandColors.indigo500,
                    foregroundColor: context.nc.textOnDark,
                    elevation: 4,
                    shadowColor: (_isAuthorized ? BrandColors.red500 : BrandColors.indigo500).withOpacity(0.4),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: _isLoading 
                      ? const SizedBox(
                          height: 24, width: 24, 
                          child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white)
                        )
                      : Text(
                          _isAuthorized ? 'Disconnect' : 'Connect Health Data',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}
