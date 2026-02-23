import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'firestore_service.dart';
import '../models/appointment_model.dart';
import '../models/user_model.dart';

/// Handles FCM (push) and local scheduled reminders for appointments/todos.
/// Call [init] after Firebase init; call [refreshTokenAndScheduleReminders] after login.
class NotificationService {
  static final NotificationService _instance = NotificationService._();
  factory NotificationService() => _instance;

  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _local = FlutterLocalNotificationsPlugin();
  final FirestoreService _firestore = FirestoreService();
  static const String _channelId = 'awda_reminders';
  static const String _channelName = 'Reminders';

  NotificationService._();

  bool _localInitialized = false;

  /// Initialize FCM and local notifications. Call from main() after Firebase.initializeApp.
  Future<void> init() async {
    await _initLocalNotifications();
    _setupFcmHandlers();
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  }

  Future<void> _initLocalNotifications() async {
    if (_localInitialized) return;
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
    );
    const initSettings = InitializationSettings(android: android, iOS: ios);
    await _local.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTap,
    );
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      await _local
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(
            const AndroidNotificationChannel(
              _channelId,
              _channelName,
              description: 'Appointment and task reminders',
              importance: Importance.defaultImportance,
            ),
          );
    }
    _localInitialized = true;
  }

  void _setupFcmHandlers() {
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      if (message.notification != null && !kIsWeb) {
        _local.show(
          message.hashCode,
          message.notification!.title,
          message.notification!.body,
          const NotificationDetails(
            android: AndroidNotificationDetails(
              _channelId,
              _channelName,
              channelDescription: 'Reminders',
            ),
            iOS: DarwinNotificationDetails(),
          ),
        );
      }
    });
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      // Could navigate to /appointments or /my-appointments based on payload
    });
  }

  void _onNotificationTap(NotificationResponse response) {
    // App opened from local notification; could navigate by payload
  }

  /// Request permission (iOS/macOS/Web), get FCM token, save to Firestore, and schedule local reminders.
  /// Call after user is logged in (uid required).
  Future<void> refreshTokenAndScheduleReminders(String? uid) async {
    if (uid == null || uid.isEmpty) return;
    try {
      final settings = await _fcm.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      if (settings.authorizationStatus == AuthorizationStatus.denied) return;
      final token = await _fcm.getToken();
      if (token != null) await _firestore.updateUserFcmToken(uid, token);
      if (!kIsWeb) await _scheduleRemindersForUser(uid);
    } catch (_) {}
  }

  /// Clear FCM token on logout (optional).
  Future<void> clearToken(String uid) async {
    try {
      await _firestore.updateUserFcmToken(uid, null);
    } catch (_) {}
  }

  /// Schedule local notifications for upcoming appointments and overdue/pending todos.
  Future<void> _scheduleRemindersForUser(String uid) async {
    if (!_localInitialized) return;
    await _cancelAllScheduled();
    final user = await _firestore.getUser(uid);
    if (user == null) return;

    final now = DateTime.now();
    final dayStart = DateTime(now.year, now.month, now.day);

    // Patient: my appointments in next 7 days → remind day before or morning of
    if (user.hasRole(UserRole.patient)) {
      final appointments = await _firestore.getAppointments(
        patientId: uid,
        from: dayStart,
        to: dayStart.add(const Duration(days: 8)),
      );
      for (final a in appointments) {
        if (a.status != AppointmentStatus.cancelled) {
          final reminderAt = _reminderTimeForAppointment(a);
          if (reminderAt.isAfter(now)) {
            await _scheduleLocal(
              id: a.id.hashCode.abs() % 100000,
              title: 'Appointment reminder',
              body: 'Session on ${a.appointmentDate.day}/${a.appointmentDate.month} at ${a.startTime}',
              scheduledDate: reminderAt,
            );
          }
        }
      }
    }

    // Doctor: appointments for this doctor in next 7 days
    if (user.hasRole(UserRole.doctor)) {
      final doc = await _firestore.getDoctorByUserId(uid);
      if (doc != null) {
        final appointments = await _firestore.getAppointments(
          doctorId: doc.id,
          from: dayStart,
          to: dayStart.add(const Duration(days: 8)),
        );
        for (final a in appointments) {
          if (a.status != AppointmentStatus.cancelled) {
            final reminderAt = _reminderTimeForAppointment(a);
            if (reminderAt.isAfter(now)) {
              await _scheduleLocal(
                id: ('doc_${a.id}').hashCode.abs() % 100000 + 50000,
                title: 'Appointment reminder',
                body: 'Session on ${a.appointmentDate.day}/${a.appointmentDate.month} at ${a.startTime}',
                scheduledDate: reminderAt,
              );
            }
          }
        }
      }
    }

    // Admin/staff: todos with reminder in future
    if (user.canAccessFeature('admin_todos')) {
      final todos = await _firestore.getAdminTodos(includeCompleted: false);
      for (final t in todos) {
        if (t.reminderAt != null && t.reminderAt!.isAfter(now)) {
          await _scheduleLocal(
            id: ('todo_${t.id}').hashCode.abs() % 100000 + 100000,
            title: 'To-do reminder',
            body: t.title,
            scheduledDate: t.reminderAt!,
          );
        }
      }
    }
  }

  DateTime _reminderTimeForAppointment(AppointmentModel a) {
    final appointmentDay = DateTime(a.appointmentDate.year, a.appointmentDate.month, a.appointmentDate.day);
    final now = DateTime.now();
    final tomorrow = DateTime(now.year, now.month, now.day).add(const Duration(days: 1));
    if (appointmentDay.isAtSameMomentAs(DateTime(now.year, now.month, now.day))) {
      return appointmentDay.add(const Duration(hours: 7)); // 7 AM same day
    }
    if (appointmentDay.isAfter(now)) {
      return tomorrow.add(const Duration(hours: 18)); // 6 PM day before
    }
    return now.add(const Duration(minutes: 1));
  }

  Future<void> _scheduleLocal({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledDate,
  }) async {
    try {
      await _local.zonedSchedule(
        id,
        title,
        body,
        tz.TZDateTime.from(scheduledDate, tz.local),
        const NotificationDetails(
          android: AndroidNotificationDetails(
            _channelId,
            _channelName,
            channelDescription: 'Reminders',
          ),
          iOS: DarwinNotificationDetails(),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
      );
    } catch (_) {}
  }

  Future<void> _cancelAllScheduled() async {
    await _local.cancelAll();
  }

  /// Call after loading appointments/todos so reminders stay in sync.
  Future<void> rescheduleRemindersForUser(String? uid) async {
    if (uid != null && !kIsWeb) await _scheduleRemindersForUser(uid);
  }
}

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Optional: ensure Firebase is initialized in background isolate
}
