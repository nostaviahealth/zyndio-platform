import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../widgets/tc025/tc025_widgets.dart';

/// Today tab. Full build in A6.
class TodayScreen extends ConsumerWidget {
  const TodayScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return const ZyndioTabScaffold(
      title: 'Today',
      subtitle: "Here's your health overview for today.",
      children: [],
    );
  }
}
