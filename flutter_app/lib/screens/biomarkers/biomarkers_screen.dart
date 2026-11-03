import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../widgets/tc025/tc025_widgets.dart';

/// Biomarkers tab (renamed Labs). Full build in A7.
class BiomarkersScreen extends ConsumerWidget {
  const BiomarkersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return const ZyndioTabScaffold(
      title: 'Biomarkers',
      children: [],
    );
  }
}
