import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:go_router/go_router.dart';
import '../../config/theme.dart';
import '../../widgets/tc025/tc025_widgets.dart';

/// Calm placeholder for features that are not built yet. The router's
/// errorBuilder also shows it for dead links, so it must render on any
/// screen size: the card scrolls when large text makes it taller than the
/// viewport, and is centred otherwise.
class ComingSoonScreen extends StatelessWidget {
  /// Shown by the router for any unknown link, sometimes as the first page
  /// (deep link, restored route) with nothing to pop back to: go home then.
  static void _leave(BuildContext context) {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/');
    }
  }

  final String featureName;

  const ComingSoonScreen({
    super.key,
    required this.featureName,
  });

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: dark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: context.z25.screenBg,
        body: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: ZyndioCircleButton(
                    icon: LucideIcons.chevronLeft,
                    label: 'Back',
                    onTap: () => _leave(context),
                  ),
                ),
              ),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) => SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight: (constraints.maxHeight - 56)
                            .clamp(0, double.infinity),
                      ),
                      child: Center(
                        child: ZyndioStateCard(
                          icon: LucideIcons.sparkles,
                          title: '$featureName Coming Soon!',
                          body:
                              "We're working hard to bring this feature to you. Stay tuned for updates!",
                          actionLabel: 'Go Back',
                          onAction: () => _leave(context),
                        ),
                      ),
                    ),
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
