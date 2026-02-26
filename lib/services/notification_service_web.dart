// Web-only: show FCM notifications using the browser Notification API.
// Imported via conditional import when dart.library.html is available.

import 'dart:html' as html;

/// Shows a browser notification (title, body). Call when FCM message is received in foreground.
/// Permission should already be granted via FirebaseMessaging.requestPermission().
Future<void> showWebNotification(String title, String body) async {
  try {
    if (html.Notification.permission == 'granted') {
      html.Notification(title, body: body);
    }
  } catch (_) {
    // Ignore if Notification fails (e.g. permission denied, not supported).
  }
}
