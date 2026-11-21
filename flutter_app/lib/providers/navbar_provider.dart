import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final navbarVisibleProvider = NotifierProvider<NavbarVisibleNotifier, bool>(() => NavbarVisibleNotifier());

class NavbarVisibleNotifier extends Notifier<bool> {
  @override
  bool build() => true;

  void hide() => state = false;
  void show() => state = true;
  void setVisible(bool visible) => state = visible;
}

/// Shows the tab bar again whenever a full page is left (popped or removed)
/// on the navigator it watches.
///
/// Some pages (Health Data, Your plan, the wearable dashboard) hide the tab
/// bar while the patient scrolls down. The flag is global, so without this a
/// page left while scrolled down leaves the bar hidden on the screen beneath;
/// a hidden bar ignores taps, so the patient could not switch tabs at all.
///
/// Pushes are ignored: the page underneath is the one that matters, and pages
/// that hide the bar when they open (AI companion, food log) keep doing so.
/// Dialogs, sheets and menus ([PopupRoute]s) are ignored too, so closing one
/// on a page that keeps the bar hidden does not reveal it.
class NavbarRevealObserver extends NavigatorObserver {
  NavbarRevealObserver(this.reveal);

  /// Called to show the tab bar; normally `navbarVisibleProvider.show`.
  final VoidCallback reveal;

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) => _onPageLeft(route);

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) => _onPageLeft(route);

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) => _onPageLeft(oldRoute);

  void _onPageLeft(Route<dynamic>? route) {
    if (route is! PageRoute) return;
    // Navigators report page changes from inside builds (go_router swaps
    // pages while building, sometimes outside a frame), when Riverpod state
    // must not change. A microtask runs once the current build has finished.
    scheduleMicrotask(reveal);
  }
}
