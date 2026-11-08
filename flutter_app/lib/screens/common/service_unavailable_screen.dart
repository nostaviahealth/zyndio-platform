import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../config/theme.dart';

/// Shown when the app could not set up its connection to the Zyndio backend
/// (missing build configuration or a failed Supabase initialisation).
///
/// The router sends every location here in that state instead of letting the
/// patient into the app unauthenticated: the old behaviour treated "Supabase
/// not initialised" as demo mode and skipped every sign-in check.
class ServiceUnavailableScreen extends StatelessWidget {
  const ServiceUnavailableScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.nc.scaffoldBg,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(LucideIcons.cloudOff, size: 48, color: context.nc.textSecondary),
                const SizedBox(height: 24),
                Text(
                  "Zyndio can't connect right now",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w600,
                    color: context.nc.textPrimary,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Close the app and open it again. If this keeps happening, '
                  'contact your clinic.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16, color: context.nc.textSecondary),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
