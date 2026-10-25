import 'package:flutter/material.dart';

/// Parses the `?screen=&state=&mode=` query params the screenshot harness
/// drives `DemoApp` with. A single route, no SPA deep-link fallback needed.
class DemoRouteParams {
  const DemoRouteParams({this.screen, this.state, this.mode});

  factory DemoRouteParams.fromQueryParameters(Map<String, String> params) {
    return DemoRouteParams(
      screen: params['screen'],
      state: params['state'],
      mode: params['mode'],
    );
  }

  final String? screen;
  final String? state;
  final String? mode;

  ThemeMode get themeMode => mode == 'dark' ? ThemeMode.dark : ThemeMode.light;
}
