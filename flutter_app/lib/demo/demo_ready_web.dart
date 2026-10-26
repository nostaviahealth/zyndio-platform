import 'dart:js_interop';
import 'dart:js_interop_unsafe';

/// Sets `window.flutterDemoReady = true` so the Playwright screenshot
/// harness can deterministically wait for Flutter's first real frame.
void setDemoReadyFlag() {
  globalContext.setProperty('flutterDemoReady'.toJS, true.toJS);
}
