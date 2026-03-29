import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'firestore_service.dart';
import 'notification_service_stub.dart' if (dart.library.html) 'notification_service_web.dart' as web_notif;
import '../models/appointment_model.dart';
import '../models/user_model.dart';

/// Arabic-only strings for scheduled local notifications (aligned with server push language).
Map<String, String> _notificationStringsAr() {
  return {
    'reminderTitle': 'تذكير موعد',
    'reminderBody': 'جلسة في {date} الساعة {time}',
    'reminderToday': 'موعدك اليوم الساعة {time}',
    'reminderOneHour': 'الموعد خلال ساعة ({time})',
    'todoTitle': 'تذكير مهمة',
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
        final uid = _currentUserIdForTokenRefresh();
        if (uid != null && uid.isNotEmpty) {
          final installationId = await _firestore.getOrCreateFcmInstallationId();
          await _firestore.registerFcmToken(uid, newToken, installationId);
        }
      } catch (e, st) {
        if (kDebugMode) debugPrint('NotificationService onTokenRefresh error: $e\n$st');
      }
    });
  }

  /// Current user id when token refreshes (sync API).
  String? _currentUserIdForTokenRefresh() {
    try {
      return FirebaseAuth.instance.currentUser?.uid;
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
        final installationId = await _firestore.getOrCreateFcmInstallationId();
        await _firestore.registerFcmToken(uid, token, installationId);
      }
      if (!kIsWeb) await _scheduleRemindersForUser(uid);
    } catch (e, st) {
      if (kDebugMode) debugPrint('NotificationService refreshToken error: $e\n$st');
    }
  }

  /// Removes this device's FCM token on logout (other devices keep receiving pushes).
  Future<void> clearToken(String uid) async {
    try {
      final installationId = await _firestore.getOrCreateFcmInstallationId();
      await _firestore.removeFcmTokenForDevice(uid, installationId);
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
      final strings = _notificationStringsAr();
      final appointments = await _firestore.getAppointments(
        patientId: uid,
        from: dayStart,
        to: dayStart.add(const Duration(days: 32)),
      );
      for (final a in appointments) {
        if (a.status != AppointmentStatus.cancelled) {
          await _scheduleAppointmentReminders(
            a,
            strings,
            now,
            viewerIsPatient: true,
          );
        }
      }
    }

    // Doctor: appointments for this doctor in next 7 days
    if (user.hasRole(UserRole.doctor)) {
      final doc = await _firestore.getDoctorByUserId(uid);
      if (doc != null) {
        final strings = _notificationStringsAr();
        final appointments = await _firestore.getAppointments(
          doctorId: doc.id,
          from: dayStart,
          to: dayStart.add(const Duration(days: 32)),
        );
        for (final a in appointments) {
          if (a.status != AppointmentStatus.cancelled) {
            await _scheduleAppointmentReminders(
              a,
              strings,
              now,
              idPrefix: 'doc_',
              viewerIsPatient: false,
            );
          }
        }
      }
    }

    // Admin/staff: todos with reminder in future
    if (user.canAccessFeature('admin_todos')) {
      final todos = await _firestore.getAdminTodos(includeCompleted: false);
      final strings = _notificationStringsAr();
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

  /// Parses [a.startTime] (HH:mm) on the appointment calendar day in local time.
  DateTime? _appointmentStartLocal(AppointmentModel a) {
    final parts = a.startTime.split(':');
    if (parts.length < 2) return null;
    final h = int.tryParse(parts[0].trim()) ?? 0;
    final m = int.tryParse(parts[1].trim()) ?? 0;
    return DateTime(a.appointmentDate.year, a.appointmentDate.month, a.appointmentDate.day, h, m);
  }

  int _reminderNotificationId(String appointmentId, String kind, {String idPrefix = ''}) {
    return ('$idPrefix${appointmentId}_$kind').hashCode & 0x7FFFFFFF;
  }

  /// Extra lines aligned with Cloud Function FCM bodies (Arabic): doctor (for patients), services, package + session.
  Future<String> _enrichAppointmentReminderBody({
    required AppointmentModel a,
    required String baseBody,
    required bool viewerIsPatient,
  }) async {
    final parts = <String>[baseBody];
    try {
      if (viewerIsPatient && a.doctorId.isNotEmpty) {
        final doc = await _firestore.getDoctorById(a.doctorId);
        final dn = doc?.displayName?.trim();
        if (dn != null && dn.isNotEmpty) {
          parts.add('الطبيب: $dn');
        }
      }
      if (a.hasServices) {
        parts.add('الخدمات: ${a.servicesDisplay}');
      }
      if (a.packageId != null && a.packageId!.isNotEmpty && a.patientId.isNotEmpty) {
        final pkg = await _firestore.getPackageById(a.packageId!);
        if (pkg != null) {
          final name = (pkg.nameAr?.trim().isNotEmpty ?? false) ? pkg.nameAr! : (pkg.nameEn ?? pkg.id);
          final total = pkg.numberOfSessions > 0 ? pkg.numberOfSessions : 1;
          final all = await _firestore.getAppointments(patientId: a.patientId);
          final samePkg = all.where((x) => x.packageId == a.packageId).toList();
          samePkg.sort((x, y) {
            final c = x.appointmentDate.compareTo(y.appointmentDate);
            if (c != 0) return c;
            return x.startTime.compareTo(y.startTime);
          });
          final idx = samePkg.indexWhere((x) => x.id == a.id);
          if (idx >= 0) {
            final n = idx + 1;
            parts.add('الباقة: $name (جلسة $n من $total)');
          } else {
            parts.add('الباقة: $name');
          }
        }
      }
    } catch (_) {}
    return parts.join('\n');
  }

  /// Same day at 08:00 (morning of appointment) and 1 hour before start — when still in the future.
  Future<void> _scheduleAppointmentReminders(
    AppointmentModel a,
    Map<String, String> strings,
    DateTime now, {
    String idPrefix = '',
    bool viewerIsPatient = false,
  }) async {
    final start = _appointmentStartLocal(a);
    if (start == null) return;

    // 1) One hour before session
    final oneHourBefore = start.subtract(const Duration(hours: 1));
    if (oneHourBefore.isAfter(now)) {
      final base = strings['reminderOneHour']!.replaceAll('{time}', a.startTime);
      final body = await _enrichAppointmentReminderBody(
        a: a,
        baseBody: base,
        viewerIsPatient: viewerIsPatient,
      );
      await _scheduleLocal(
        id: _reminderNotificationId(a.id, '1h', idPrefix: idPrefix),
        title: strings['reminderTitle']!,
        body: body,
        scheduledDate: oneHourBefore,
      );
    }

    // 2) Morning of appointment day (08:00), only if before session time
    final dayOf = DateTime(a.appointmentDate.year, a.appointmentDate.month, a.appointmentDate.day, 8, 0);
    if (dayOf.isBefore(start) && dayOf.isAfter(now)) {
      final base = strings['reminderToday']!.replaceAll('{time}', a.startTime);
      final body = await _enrichAppointmentReminderBody(
        a: a,
        baseBody: base,
        viewerIsPatient: viewerIsPatient,
      );
      await _scheduleLocal(
        id: _reminderNotificationId(a.id, 'day', idPrefix: idPrefix),
        title: strings['reminderTitle']!,
        body: body,
        scheduledDate: dayOf,
      );
    }
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
