import 'package:flutter/material.dart';

import '../config/theme.dart';
import 'demo_ready_web.dart' if (dart.library.io) 'demo_ready_io.dart'
    as ready;
import 'router/demo_state.dart';

/// True only for the demo entrypoint build; gates the FICTIONAL-DATA tag and
/// the PLACEHOLDER a11y announce. Never set in the production app.
const bool kDemoBuild =
    bool.fromEnvironment('DEMO_BUILD', defaultValue: false);

class DemoApp extends StatelessWidget {
  const DemoApp({super.key});

  @override
  Widget build(BuildContext context) {
    final params =
        DemoRouteParams.fromQueryParameters(Uri.base.queryParameters);
    return MaterialApp(
      title: 'Zyndio Demo',
      debugShowCheckedModeBanner: false,
      theme: BrandTheme.lightTheme,
      darkTheme: BrandTheme.darkTheme,
      themeMode: params.themeMode,
      builder: (context, child) {
        final mediaQuery = MediaQuery.of(context);
        return MediaQuery(
          data: mediaQuery.copyWith(disableAnimations: true),
          child: child!,
        );
      },
      home: _DemoHome(params: params),
    );
  }
}

class _DemoHome extends StatefulWidget {
  const _DemoHome({required this.params});

  final DemoRouteParams params;

  @override
  State<_DemoHome> createState() => _DemoHomeState();
}

class _DemoHomeState extends State<_DemoHome> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance
        .addPostFrameCallback((_) => ready.setDemoReadyFlag());
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<ZyndioColors>()!;
    final screen = widget.params.screen;
    final label = screen == null
        ? 'Zyndio demo — coming soon'
        : 'Screen "$screen" coming soon';
    return Scaffold(
      backgroundColor: colors.bgCanvas,
      body: Center(
        child: Text(
          label,
          style: ZyndioType.body.copyWith(color: colors.textPrimary),
        ),
      ),
    );
  }
}
