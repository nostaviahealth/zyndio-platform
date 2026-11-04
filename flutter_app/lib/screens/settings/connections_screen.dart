import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../config/theme.dart';
import '../../services/wearable_daily/device_health_connector.dart';

/// APP-07: Apple Health (iOS) / Health Connect (Android) connect on the
/// device and then upload daily data to wearable_daily. Cloud wearables
/// (WHOOP etc.) have no server integration yet - the old button called a
/// `functions/v1/connect` endpoint that does not exist - so they are shown as
/// not available instead of failing.
class ConnectionsScreen extends StatefulWidget {
  const ConnectionsScreen({super.key, this.connector});

  /// Test seam; defaults to [HealthStoreConnector].
  final DeviceHealthConnector? connector;

  @override
  State<ConnectionsScreen> createState() => _ConnectionsScreenState();
}

const connectedHealthStoreMessage =
    'Connected. Importing your last 90 days of health data in the background.';

class _ConnectionsScreenState extends State<ConnectionsScreen> {
  bool _isConnecting = false;
  late final DeviceHealthConnector _connector = widget.connector ?? HealthStoreConnector();

  bool get _isAndroid => defaultTargetPlatform == TargetPlatform.android;
  String get _storeName => _isAndroid ? 'Health Connect' : 'Apple Health';

  Future<void> _connectHealthStore() async {
    setState(() => _isConnecting = true);
    final result = await _connector.connect();
    if (!mounted) return;
    setState(() => _isConnecting = false);
    final message = switch (result) {
      DeviceHealthConnectResult.connected => connectedHealthStoreMessage,
      DeviceHealthConnectResult.denied =>
        'Health permissions were not granted. Tap Connect again and allow access.',
      DeviceHealthConnectResult.healthConnectNotInstalled =>
        'Health Connect is not installed. Install it from the Play Store, then tap Connect again.',
      DeviceHealthConnectResult.healthConnectNeedsUpdate =>
        'Health Connect needs an update. Update it from the Play Store, then tap Connect again.',
      DeviceHealthConnectResult.failed => 'Could not connect. Please try again.',
    };
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.nc.scaffoldBg,
      appBar: AppBar(
        title: Text('Connections', style: TextStyle(color: context.nc.textPrimary)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: context.nc.textPrimary),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Wearable Integrations',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w900,
                color: context.nc.textPrimary,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Connect your devices to sync your health and sleep data automatically.',
              style: TextStyle(
                fontSize: 16,
                color: context.nc.textTertiary,
              ),
            ),
            const SizedBox(height: 48),
            _buildConnectionButton(
              key: const Key('connect-health-store'),
              title: 'Connect $_storeName',
              icon: LucideIcons.activity,
              color: const Color(0xFFEF4444),
              onPressed: _connectHealthStore,
            ),
            const SizedBox(height: 16),
            _buildConnectionButton(
              key: const Key('connect-whoop'),
              title: 'WHOOP (not available yet)',
              icon: LucideIcons.watch,
              color: Colors.white, // Whoop color scheme mostly dark, use white icon for contrast
              onPressed: null,
            ),
            if (_isConnecting)
              const Padding(
                padding: EdgeInsets.only(top: 32.0),
                child: Center(
                  child: CircularProgressIndicator(color: BrandColors.emerald500),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildConnectionButton({
    Key? key,
    required String title,
    required IconData icon,
    required Color color,
    required VoidCallback? onPressed,
  }) {
    return SizedBox(
      key: key,
      width: double.infinity,
      height: 64,
      child: ElevatedButton(
        onPressed: _isConnecting ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: context.nc.cardSurface,
          foregroundColor: context.nc.textPrimary,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: context.nc.cardBorder),
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: context.nc.isDark ? color.withOpacity(0.2) : color,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: context.nc.isDark ? color : Colors.white),
            ),
            const SizedBox(width: 16),
            Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const Spacer(),
            const Icon(LucideIcons.chevronRight, color: BrandColors.slate500),
          ],
        ),
      ),
    );
  }
}
