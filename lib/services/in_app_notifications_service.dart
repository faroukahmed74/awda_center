import '../core/date_format.dart';
import '../models/admin_todo_model.dart';
import '../models/app_notification.dart';
import '../models/appointment_model.dart';
import '../models/audit_log_model.dart';
import '../models/user_model.dart';
import 'firestore_service.dart';

/// Fetches in-app notifications for the current user based on role (appointments, audit log, todos).
class InAppNotificationsService {
  final FirestoreService _firestore = FirestoreService();

  static const List<String> _appointmentAuditActions = [
    'appointment_created',
    'appointment_confirmed',
    'appointment_cancelled',
    'appointment_completed',
    'appointment_no_show',
    'appointment_updated',
  ];

  Future<List<AppNotification>> getNotifications(UserModel user) async {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final weekEnd = todayStart.add(const Duration(days: 7));

    // Run independent data sources in parallel to reduce total wait time
    final results = await Future.wait([
      _getAppointmentsNotifications(user, todayStart, weekEnd),
      _getAuditAndStatusNotifications(user),
      _getTodosNotifications(user),
    ]);

    final list = <AppNotification>[
      ...results[0],
      ...results[1],
      ...results[2],
    ];
    list.sort((a, b) => b.time.compareTo(a.time));
    return list.take(50).toList();
  }

  Future<List<AppNotification>> _getAppointmentsNotifications(
    UserModel user,
    DateTime todayStart,
    DateTime weekEnd,
  ) async {
    if (user.hasRole(UserRole.patient)) {
      final appointments = await _firestore.getAppointments(
        from: todayStart,
        to: weekEnd,
        patientId: user.id,
      );
      return _appointmentsToNotifications(appointments, true);
    }
    if (user.hasRole(UserRole.doctor)) {
      final doctor = await _firestore.getDoctorByUserId(user.id);
      if (doctor == null) return [];
      final appointments = await _firestore.getAppointments(
        from: todayStart,
        to: weekEnd,
        doctorId: doctor.id,
      );
      return _appointmentsToNotifications(appointments, false);
    }
    if (user.canAccessFeature('appointments')) {
      final appointments = await _firestore.getAppointments(
        from: todayStart,
        to: weekEnd,
      );
      return _appointmentsToNotifications(appointments, false).take(15).toList();
    }
    return [];
  }

  /// For admin: one getAuditLogs(60), then build both appointment-status and audit notifications.
  Future<List<AppNotification>> _getAuditAndStatusNotifications(UserModel user) async {
    if (!user.hasRole(UserRole.admin)) return [];
    final logs = await _firestore.getAuditLogs(limit: 60);
    final statusNotifs = await _appointmentStatusNotificationsFromLogs(user, logs);
    final list = <AppNotification>[
      ...statusNotifs,
      ..._auditLogsToNotifications(logs.take(15).toList()),
    ];
    return list;
  }

  Future<List<AppNotification>> _getTodosNotifications(UserModel user) async {
    if (!user.canAccessAdminTodos) return [];
    final todos = await _firestore.getAdminTodos(includeCompleted: false);
    return _todosToNotifications(todos);
  }

  /// Builds appointment-status notifications from pre-fetched audit logs (avoids duplicate getAuditLogs).
  Future<List<AppNotification>> _appointmentStatusNotificationsFromLogs(
    UserModel user,
    List<AuditLogModel> logs,
  ) async {
    final appointmentLogs = logs
        .where((l) =>
            l.entityType == 'appointment' &&
            l.entityId != null &&
            _appointmentAuditActions.contains(l.action))
        .take(25)
        .toList();
    if (appointmentLogs.isEmpty) return [];

    String? doctorIdForUser;
    if (user.hasRole(UserRole.doctor)) {
      final doctor = await _firestore.getDoctorByUserId(user.id);
      doctorIdForUser = doctor?.id;
    }

    // Fetch all appointments in parallel instead of sequentially
    final appointmentFutures = appointmentLogs
        .map((log) => _firestore.getAppointmentById(log.entityId!));
    final appointments = await Future.wait(appointmentFutures);

    final result = <AppNotification>[];
    for (var i = 0; i < appointmentLogs.length; i++) {
      final log = appointmentLogs[i];
      final appointment = appointments[i];
      if (appointment == null) continue;

      final isPatient = user.id == appointment.patientId;
      final isDoctor = doctorIdForUser == appointment.doctorId;
      final hasAppointmentsAccess = user.canAccessFeature('appointments');
      if (!isPatient && !isDoctor && !hasAppointmentsAccess) continue;

      final time = log.createdAt ?? appointment.updatedAt ?? appointment.appointmentDate;
      final dateStr = AppDateFormat.mediumDate().format(appointment.appointmentDate);
      final timeStr = '${appointment.startTime} - ${appointment.endTime}';
      final title = _appointmentActionLabel(log.action);
      result.add(AppNotification(
        id: 'status_${log.id}',
        type: AppNotificationType.appointment,
        title: title,
        subtitle: '${appointment.servicesDisplay} · $dateStr $timeStr'.trim(),
        time: time,
        route: '/appointments',
      ));
    }
    return result;
  }

  String _appointmentActionLabel(String action) {
    switch (action) {
      case 'appointment_created':
        return 'Appointment created';
      case 'appointment_confirmed':
        return 'Appointment confirmed';
      case 'appointment_cancelled':
        return 'Appointment cancelled';
      case 'appointment_completed':
        return 'Appointment completed';
      case 'appointment_no_show':
        return 'Appointment marked no-show';
      case 'appointment_updated':
        return 'Appointment updated';
      default:
        return action.replaceAll('_', ' ');
    }
  }

  List<AppNotification> _appointmentsToNotifications(
    List<AppointmentModel> appointments,
    bool forPatient,
  ) {
    final filtered = appointments
        .where((a) => a.status != AppointmentStatus.cancelled)
        .toList();
    filtered.sort((a, b) {
      int c = a.appointmentDate.compareTo(b.appointmentDate);
      if (c != 0) return c;
      return a.startTime.compareTo(b.startTime);
    });
    return filtered.map((a) {
      final dateStr = AppDateFormat.mediumDate().format(a.appointmentDate);
      final timeStr = '${a.startTime} - ${a.endTime}';
      // Use when the appointment was created/updated for the "when" line, not the scheduled date
      final when = a.updatedAt ?? a.createdAt ?? a.appointmentDate;
      return AppNotification(
        id: 'appointment_${a.id}',
        type: AppNotificationType.appointment,
        title: a.hasServices ? a.servicesDisplay : (forPatient ? 'Appointment' : 'Session'),
        subtitle: '$dateStr · $timeStr',
        time: when,
        route: '/appointments',
      );
    }).toList();
  }

  List<AppNotification> _auditLogsToNotifications(List<AuditLogModel> logs) {
    return logs.map((l) {
      final actionLabel = _actionLabel(l.action);
      final by = l.userEmail ?? l.userId;
      final time = l.createdAt ?? DateTime.now();
      return AppNotification(
        id: 'audit_${l.id}',
        type: AppNotificationType.audit,
        title: actionLabel,
        subtitle: by,
        time: time,
        route: '/audit-log',
      );
    }).toList();
  }

  String _actionLabel(String action) {
    switch (action) {
      case 'user_roles_updated':
        return 'User roles updated';
      case 'user_deactivated':
        return 'User deactivated';
      case 'document_deleted':
        return 'Document deleted';
      case 'appointment_created':
        return 'Appointment created';
      case 'appointment_confirmed':
        return 'Appointment confirmed';
      case 'appointment_updated':
        return 'Appointment updated';
      case 'appointment_cancelled':
        return 'Appointment cancelled';
      case 'appointment_completed':
        return 'Appointment completed';
      case 'appointment_no_show':
        return 'Appointment marked no-show';
      default:
        return action.replaceAll('_', ' ');
    }
  }

  List<AppNotification> _todosToNotifications(List<AdminTodoModel> todos) {
    return todos.map((t) {
      final due = t.dueDate != null
          ? ' · ${AppDateFormat.mediumDate().format(t.dueDate!)}'
          : '';
      return AppNotification(
        id: 'todo_${t.id}',
        type: AppNotificationType.todo,
        title: t.title,
        subtitle: (t.description ?? '').isEmpty ? 'To-do' : t.description! + due,
        time: t.createdAt ?? t.dueDate ?? DateTime.now(),
        route: '/admin-todos',
      );
    }).toList();
  }
}
