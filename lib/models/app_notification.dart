/// Unified in-app notification item (appointments, audit log, admin todos).
enum AppNotificationType {
  appointment,
  audit,
  todo,
}

class AppNotification {
  final String id;
  final AppNotificationType type;
  final String title;
  final String subtitle;
  final DateTime time;
  /// Optional route to navigate when tapped (e.g. '/appointments', '/audit-log').
  final String? route;

  const AppNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.subtitle,
    required this.time,
    this.route,
  });
}
