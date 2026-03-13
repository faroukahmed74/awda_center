import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'firestore_service.dart';
import 'notification_service_stub.dart' if (dart.library.html) 'notification_service_web.dart' as web_notif;
import '../models/appointment_model.dart';
import '../models/user_model.dart';

/// Localized notification strings by locale ('en' or 'ar'). Used when no BuildContext.
Map<String, String> _notificationStrings(String locale) {
  final isAr = locale == 'ar';
  return {
    'reminderTitle': isAr ? 'تذكير موعد' : 'Appointment reminder',
    'reminderBody': isAr ? 'جلسة في {date} الساعة {time}' : 'Session on {date} at {time}',
    'confirmed': isAr ? 'تم تأكيد الموعد' : 'Appointment confirmed',
    'completed': isAr ? 'تم إكمال الموعد' : 'Appointment completed',
    'cancelled': isAr ? 'تم إلغاء الموعد' : 'Appointment cancelled',
    'noShow': isAr ? 'تم تسجيل عدم الحضور' : 'Appointment marked no-show',
    'todoTitle': isAr ? 'تذكير مهمة' : 'To-do reminder',
  };
}

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
    _setupTokenRefreshListener();
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  }

  /// When FCM token rotates (e.g. web, reinstall), update Firestore so Cloud Functions can still send.
  void _setupTokenRefreshListener() {
    _fcm.onTokenRefresh.listen((String newToken) async {
      if (newToken.isEmpty) return;
      try {
        final uid = await _currentUserIdForTokenRefresh();
        if (uid != null && uid.isNotEmpty) {
          await _firestore.updateUserFcmToken(uid, newToken);
        }
      } catch (e, st) {
        if (kDebugMode) debugPrint('NotificationService onTokenRefresh error: $e\n$st');
      }
    });
  }

  /// Returns current user id if available (from Auth is not accessible here; we use a simple approach).
  Future<String?> _currentUserIdForTokenRefresh() async {
    try {
      final user = await FirebaseAuth.instance.currentUser;
      return user?.uid;
    } catch (_) {
      return null;
    }
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
      if (message.notification == null) return;
      final title = message.notification!.title ?? 'Notification';
      final body = message.notification!.body ?? '';
      if (kIsWeb) {
        web_notif.showWebNotification(title, body);
      } else {
        _local.show(
          message.hashCode,
          title,
          body,
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

  /// Web: VAPID key from Firebase Console → Project Settings → Cloud Messaging → Web Push certificates.
  static const String webVapidKey =
      'BDOGjkgl3Q_cM7BL3pS3v2nsRceQnGykmdYyEfcDqr0hmTV2Q1n_Rzp4Cly58bUofOcaTYUacTuUTMX-SoAAcuM';

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
      // On web, token can take a moment; retry once after delay if needed.
      String? token;
      if (kIsWeb && webVapidKey.isNotEmpty) {
        token = await _fcm.getToken(vapidKey: webVapidKey);
        if (token == null) {
          await Future.delayed(const Duration(milliseconds: 800));
          token = await _fcm.getToken(vapidKey: webVapidKey);
        }
      } else {
        token = await _fcm.getToken();
      }
      if (token != null && token.isNotEmpty) {
        await _firestore.updateUserFcmToken(uid, token);
      }
      if (!kIsWeb) await _scheduleRemindersForUser(uid);
    } catch (e, st) {
      if (kDebugMode) debugPrint('NotificationService refreshToken error: $e\n$st');
    }
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
      final strings = _notificationStrings(user.locale ?? 'en');
      final dateTimeTemplate = strings['reminderBody']!;
      final appointments = await _firestore.getAppointments(
        patientId: uid,
        from: dayStart,
        to: dayStart.add(const Duration(days: 8)),
      );
      for (final a in appointments) {
        if (a.status != AppointmentStatus.cancelled) {
          final reminderAt = _reminderTimeForAppointment(a);
          if (reminderAt.isAfter(now)) {
            final dateStr = '${a.appointmentDate.day}/${a.appointmentDate.month}';
            final body = dateTimeTemplate
                .replaceAll('{date}', dateStr)
                .replaceAll('{time}', a.startTime);
            await _scheduleLocal(
              id: a.id.hashCode.abs() % 100000,
              title: strings['reminderTitle']!,
              body: body,
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
        final strings = _notificationStrings(user.locale ?? 'en');
        final dateTimeTemplate = strings['reminderBody']!;
        final appointments = await _firestore.getAppointments(
          doctorId: doc.id,
          from: dayStart,
          to: dayStart.add(const Duration(days: 8)),
        );
        for (final a in appointments) {
          if (a.status != AppointmentStatus.cancelled) {
            final reminderAt = _reminderTimeForAppointment(a);
            if (reminderAt.isAfter(now)) {
              final dateStr = '${a.appointmentDate.day}/${a.appointmentDate.month}';
              final body = dateTimeTemplate
                  .replaceAll('{date}', dateStr)
                  .replaceAll('{time}', a.startTime);
              await _scheduleLocal(
                id: ('doc_${a.id}').hashCode.abs() % 100000 + 50000,
                title: strings['reminderTitle']!,
                body: body,
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
      final strings = _notificationStrings(user.locale ?? 'en');
      for (final t in todos) {
        if (t.reminderAt != null && t.reminderAt!.isAfter(now)) {
          await _scheduleLocal(
            id: ('todo_${t.id}').hashCode.abs() % 100000 + 100000,
            title: strings['todoTitle']!,
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
