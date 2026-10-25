import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/theme.dart';
import 'demo_ready_web.dart' if (dart.library.io) 'demo_ready_io.dart'
    as ready;
import 'router/demo_state.dart';
import 'screens/signin/signin_controller.dart';
import 'screens/signin/signin_state.dart';
import 'screens/signin/signin_view.dart';

export 'demo_build_flag.dart';

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
    final screen = widget.params.screen;
    if (screen == 'signin') {
      // A `state` query param (the screenshot harness) renders a fixed
      // fixture state; otherwise the view is wired to the live controller
      // so the demo build is actually usable, not just a screenshot target.
      if (widget.params.state != null) {
        return SignInView(state: signInStateForQueryState(widget.params.state));
      }
      return const _InteractiveSignIn();
    }

    final colors = Theme.of(context).extension<ZyndioColors>()!;
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

class _InteractiveSignIn extends ConsumerWidget {
  const _InteractiveSignIn();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(signInControllerProvider);
    final controller = ref.read(signInControllerProvider.notifier);
    return SignInView(
      state: state,
      onEmailChanged: controller.updateEmail,
      onSendCode: controller.sendCode,
      onCodeChanged: controller.updateCode,
      onContinue: controller.submitCode,
      onSendNewCode: controller.sendCode,
      onBack: controller.backToEmail,
    );
  }
}
