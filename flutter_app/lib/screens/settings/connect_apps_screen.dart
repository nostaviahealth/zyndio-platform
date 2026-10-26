import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../config/theme.dart';
import '../../data/health_repository.dart';

class ConnectAppsScreen extends ConsumerStatefulWidget {
  const ConnectAppsScreen({super.key});

  @override
  ConsumerState<ConnectAppsScreen> createState() => _ConnectAppsScreenState();
}

class _ConnectAppsScreenState extends ConsumerState<ConnectAppsScreen> {
  bool _isGoogleFitConnected = false;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _checkStatus();
  }

  Future<void> _checkStatus() async {
    final repo = HealthRepository();
    // Verify if already connected historically
    bool linked = await repo.isLinked();
    if (linked) {
      if (mounted) setState(() => _isGoogleFitConnected = true);
    } else {
      bool authorized = await repo.hasPermissions();
      if (authorized) {
        await repo.setLinked(true);
        if (mounted) setState(() => _isGoogleFitConnected = true);
      }
    }
  }

  void _handleConnect() async {
    setState(() => _isLoading = true);
    try {
      final repo = HealthRepository();
      // Fire permission request for Google Fit / Android Health
      final granted = await repo.requestExtensivePermissions();
      if (mounted) {
        if (granted) {
          await repo.setLinked(true);
          setState(() {
            _isGoogleFitConnected = true;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Successfully connected and synced all data!')),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Permission denied or cancelled by user.')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
         ScaffoldMessenger.of(context).showSnackBar(
           SnackBar(content: Text('Connection failed: $e')),
         );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.nc.scaffoldBg,
      appBar: AppBar(
        title: Text('Google Fit & Health Connect', style: TextStyle(color: context.nc.textPrimary, fontSize: 18, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: context.nc.textPrimary),
        centerTitle: true,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: context.nc.cardSurface,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: BrandColors.emerald500.withOpacity(0.15),
                      blurRadius: 30,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: const Icon(LucideIcons.heartPulse, size: 64, color: BrandColors.emerald500),
              ),
              const SizedBox(height: 32),
              Text(
                'Sync with Google Fit',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: context.nc.textPrimary,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Connect Zyndio to Google Fit to instantly sync your daily activity, heart rate, sleep, and health vitals into your dashboard.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15,
                  color: context.nc.textSecondary,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 48),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _isLoading || _isGoogleFitConnected ? null : _handleConnect,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _isGoogleFitConnected ? BrandColors.emerald500 : BrandColors.indigo500,
                    foregroundColor: context.nc.textOnDark,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: _isLoading 
                      ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : Text(
                    _isGoogleFitConnected ? 'Connected' : 'Connect Google Fit',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
