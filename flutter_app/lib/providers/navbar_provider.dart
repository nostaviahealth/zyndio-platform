import 'package:flutter_riverpod/flutter_riverpod.dart';

final navbarVisibleProvider = NotifierProvider<NavbarVisibleNotifier, bool>(() => NavbarVisibleNotifier());

class NavbarVisibleNotifier extends Notifier<bool> {
  @override
  bool build() => true;

  void hide() => state = false;
  void show() => state = true;
  void setVisible(bool visible) => state = visible;
}
