/// Stub implementation for non-web platforms
/// This file is used when dart.library.js is NOT available (iOS, Android, etc.)

void callCloseOAuthBrowser() {
  // No-op on non-web platforms
  // The actual browser closing is handled by url_launcher's closeInAppWebView()
}
