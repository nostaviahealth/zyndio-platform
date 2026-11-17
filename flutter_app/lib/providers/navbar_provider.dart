import 'package:flutter_riverpod/flutter_riverpod.dart';

final navbarVisibleProvider = NotifierProvider<NavbarVisibleNotifier, bool>(() => NavbarVisibleNotifier());

class NavbarVisibleNotifier extends Notifier<bool> {
  @override
  bool build() => true;

  // Screens toggle the tab bar from dispose()/microtasks; after the provider
  // container itself is gone (app teardown, hot restart) that's a no-op
  // rather than an UnmountedRefException.
  void hide() => setVisible(false);
  void show() => setVisible(true);
  void setVisible(bool visible) {
    if (!ref.mounted) return;
    state = visible;
  }
}
