/// Web-specific implementation using dart:js_interop
/// This file is used when dart.library.js IS available (web platform only)

import 'dart:js_interop' as js;

@js.JS('closeOAuthBrowser')
external void _jsCloseOAuthBrowser();

void callCloseOAuthBrowser() {
  try {
    _jsCloseOAuthBrowser();
  } catch (e) {
    // Silently fail if the JS function is not available
  }
}
