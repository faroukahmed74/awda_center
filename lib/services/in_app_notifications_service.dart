import 'package:intl/intl.dart' hide TextDirection;

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
    final list = <AppNotification>[];

    // Upcoming appointments (patient, doctor, or users with appointments access)
    if (user.hasRole(UserRole.patient)) {
      final appointments = await _firestore.getAppointments(
        from: todayStart,
        to: weekEnd,
        patientId: user.id,
      );
      list.addAll(_appointmentsToNotifications(appointments, true));
    } else if (user.hasRole(UserRole.doctor)) {
      final doctor = await _firestore.getDoctorByUserId(user.id);
      if (doctor != null) {
        final appointments = await _firestore.getAppointments(
          from: todayStart,
          to: weekEnd,
          doctorId: doctor.id,
        );
        list.addAll(_appointmentsToNotifications(appointments, false));
      }
    } else if (user.canAccessFeature('appointments')) {
      final appointments = await _firestore.getAppointments(
        from: todayStart,
        to: weekEnd,
      );
      list.addAll(_appointmentsToNotifications(appointments, false).take(15));
    }

    // Appointment status changes from audit log — only for users allowed to read audit_log (admin)
    if (user.hasRole(UserRole.admin)) {
      list.addAll(
        await _appointmentStatusNotifications(user),
      );
    }

    // Recent audit log — only admins can read audit_log in Firestore
    if (user.hasRole(UserRole.admin)) {
      final logs = await _firestore.getAuditLogs(limit: 15);
      list.addAll(_auditLogsToNotifications(logs));
    }

    // Open admin todos (admin_todos access)
    if (user.canAccessAdminTodos) {
      final todos = await _firestore.getAdminTodos(includeCompleted: false);
      list.addAll(_todosToNotifications(todos));
    }

    list.sort((a, b) => b.time.compareTo(a.time));
    return list.take(50).toList();
  }

  /// Fetches audit log entries for appointments and returns notifications for the current user (patient/doctor/appointments access).
  Future<List<AppNotification>> _appointmentStatusNotifications(UserModel user) async {
    final logs = await _firestore.getAuditLogs(limit: 60);
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

    final result = <AppNotification>[];
    for (final log in appointmentLogs) {
      final appointment = await _firestore.getAppointmentById(log.entityId!);
      if (appointment == null) continue;

      final isPatient = user.id == appointment.patientId;
      final isDoctor = doctorIdForUser == appointment.doctorId;
      final hasAppointmentsAccess = user.canAccessFeature('appointments');
      if (!isPatient && !isDoctor && !hasAppointmentsAccess) continue;

      final time = log.createdAt ?? appointment.updatedAt ?? appointment.appointmentDate;
      final dateStr = DateFormat.yMMMd().format(appointment.appointmentDate);
      final timeStr = '${appointment.startTime} - ${appointment.endTime}';
      final title = _appointmentActionLabel(log.action);
      result.add(AppNotification(
        id: 'status_${log.id}',
        type: AppNotificationType.appointment,
        title: title,
        subtitle: '${appointment.service ?? ''} · $dateStr $timeStr'.trim(),
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
      final dateStr = DateFormat.yMMMd().format(a.appointmentDate);
      final timeStr = '${a.startTime} - ${a.endTime}';
      return AppNotification(
        id: 'appointment_${a.id}',
        type: AppNotificationType.appointment,
        title: a.service ?? (forPatient ? 'Appointment' : 'Session'),
        subtitle: '$dateStr · $timeStr',
        time: a.appointmentDate,
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
          ? ' · ${DateFormat.yMMMd().format(t.dueDate!)}'
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
