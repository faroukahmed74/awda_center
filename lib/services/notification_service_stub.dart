// Stub for non-web: browser notifications are not available.

/// No-op on mobile/desktop. On web, use notification_service_web.dart.
Future<void> showWebNotification(String title, String body) async {
  // Not used on this platform.
}
