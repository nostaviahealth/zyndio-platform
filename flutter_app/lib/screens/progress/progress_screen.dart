import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../widgets/tc025/tc025_widgets.dart';

/// Progress tab — interim for PR A (specs §3.2 Empty state only).
///
/// The body-composition data model, migration and populated states are PR B.
/// Until then we show only the honest empty state under the specced title, with
/// no segments, tiles or sample numbers.
class ProgressScreen extends ConsumerWidget {
  const ProgressScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ZyndioTabScaffold(
      title: 'Body Composition',
      subtitle: 'DEXASCAN · Measurable results. Real progress.',
      children: [
        ZyndioStateCard(
          icon: LucideIcons.activity,
          title: 'No DEXASCAN results yet',
          body:
              'Your body composition will appear here after your baseline scan '
              'has been reviewed by your care team.',
          actionLabel: 'Book my baseline scan',
          onAction: () => context.pushNamed('appointments'),
        ),
      ],
    );
  }
}
