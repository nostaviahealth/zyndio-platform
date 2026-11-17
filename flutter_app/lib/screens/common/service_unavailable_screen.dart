import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../config/theme.dart';
import '../../widgets/tc025/tc025_widgets.dart';

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
    final dark = Theme.of(context).brightness == Brightness.dark;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: dark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: context.z25.screenBg,
        body: SafeArea(
          child: LayoutBuilder(
            // Centred when it fits; scrolls with large text on small phones.
            builder: (context, constraints) => SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight:
                      (constraints.maxHeight - 48).clamp(0, double.infinity),
                ),
                child: const Center(
                  child: ZyndioStateCard(
                    icon: LucideIcons.cloudOff,
                    title: "Zyndio can't connect right now",
                    body: 'Close the app and open it again. If this keeps '
                        'happening, contact your clinic.',
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
