import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../config/theme.dart';
import '../../services/wearable_daily/device_health_connector.dart';
import '../../widgets/tc025/tc025_widgets.dart';

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
    final c = context.zc;
    final dark = Theme.of(context).brightness == Brightness.dark;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      // A transparent bar reads as "dark" to Flutter, which would switch to
      // white status bar icons over this light page (and keep them on the
      // page underneath after going back). Match the theme instead.
      value: dark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
      child: ZyndioDetailScaffold(
        title: 'Connections',
        children: [
          Text(
            'Wearable Integrations',
            style: ZyndioType.title2.copyWith(color: c.textPrimary),
          ),
          const SizedBox(height: 8),
          Text(
            'Connect your devices to sync your health and sleep data automatically.',
            style: TextStyle(
              fontFamily: ZyndioType.family,
              fontSize: 15,
              height: 22 / 15,
              color: c.textSecondary,
            ),
          ),
          const SizedBox(height: 24),
          _buildConnectionButton(
            context,
            key: const Key('connect-health-store'),
            title: 'Connect $_storeName',
            icon: LucideIcons.activity,
            onPressed: _connectHealthStore,
          ),
          const SizedBox(height: 12),
          _buildConnectionButton(
            context,
            key: const Key('connect-whoop'),
            title: 'WHOOP (not available yet)',
            icon: LucideIcons.watch,
            onPressed: null,
          ),
          if (_isConnecting)
            Padding(
              padding: const EdgeInsets.only(top: 32.0),
              child: Center(
                child: CircularProgressIndicator(color: c.brandPrimary),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildConnectionButton(
    BuildContext context, {
    Key? key,
    required String title,
    required IconData icon,
    required VoidCallback? onPressed,
  }) {
    final c = context.zc;
    final enabled = !_isConnecting && onPressed != null;
    final fg = enabled ? c.textPrimary : c.textTertiary;
    final shape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(22));
    return SizedBox(
      key: key,
      width: double.infinity,
      height: 72,
      child: DecoratedBox(
        decoration: zyndioCard(context, radius: 22),
        child: ElevatedButton(
          onPressed: _isConnecting ? null : onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            disabledBackgroundColor: Colors.transparent,
            foregroundColor: c.textPrimary,
            disabledForegroundColor: c.textTertiary,
            shadowColor: Colors.transparent,
            surfaceTintColor: Colors.transparent,
            elevation: 0,
            padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
            shape: shape,
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: context.z25.tileBg,
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 20, color: enabled ? c.brandPrimary : c.textTertiary),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  title,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: ZyndioType.family,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: fg,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              Icon(LucideIcons.chevronRight, size: 20, color: c.textTertiary),
            ],
          ),
        ),
      ),
    );
  }
}
