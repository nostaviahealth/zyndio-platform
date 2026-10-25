import 'package:flutter/material.dart';
import 'package:platform_wearables/platform_wearables.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../config/theme.dart';

class ConnectionsScreen extends StatefulWidget {
  const ConnectionsScreen({super.key});

  @override
  State<ConnectionsScreen> createState() => _ConnectionsScreenState();
}

class _ConnectionsScreenState extends State<ConnectionsScreen> {
  bool _isConnecting = false;

  Future<void> _connectAppleHealth() async {
    setState(() => _isConnecting = true);
    try {
      await Zyndio.connect(BrandProvider.healthKit);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Apple Health connected successfully!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to connect: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isConnecting = false);
    }
  }

  Future<void> _connectWhoop() async {
    setState(() => _isConnecting = true);
    try {
      await Zyndio.connect(
        BrandProvider.whoop, 
        redirectUri: 'zyndiohealth://callback'
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('WHOOP connected successfully!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to connect: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isConnecting = false);
    }
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
              title: 'Connect Apple Health',
              icon: LucideIcons.activity,
              color: const Color(0xFFEF4444),
              onPressed: _connectAppleHealth,
            ),
            const SizedBox(height: 16),
            _buildConnectionButton(
              title: 'Connect WHOOP',
              icon: LucideIcons.watch,
              color: Colors.white, // Whoop color scheme mostly dark, use white icon for contrast
              onPressed: _connectWhoop,
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
    required String title, 
    required IconData icon, 
    required Color color, 
    required VoidCallback onPressed
  }) {
    return SizedBox(
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
