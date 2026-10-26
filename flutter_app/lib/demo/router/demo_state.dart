import 'package:flutter/material.dart';

/// Parses the `?screen=&state=&mode=` query params the screenshot harness
/// drives `DemoApp` with. A single route, no SPA deep-link fallback needed.
class DemoRouteParams {
  const DemoRouteParams({this.screen, this.state, this.mode, this.flow});

  factory DemoRouteParams.fromQueryParameters(Map<String, String> params) {
    return DemoRouteParams(
      screen: params['screen'],
      state: params['state'],
      mode: params['mode'],
      flow: params['flow'],
    );
  }

  final String? screen;
  final String? state;
  final String? mode;

  /// `?flow=journey` selects the real sign-in -> ... -> trends walk
  /// ([DemoJourneyFlow]) instead of the single-screen `?screen=` routes.
  final String? flow;

  ThemeMode get themeMode => mode == 'dark' ? ThemeMode.dark : ThemeMode.light;
}
