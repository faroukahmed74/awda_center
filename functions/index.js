const functions = require('firebase-functions');
const admin = require('firebase-admin');

admin.initializeApp();

const db = admin.firestore();
const messaging = admin.messaging();

const notificationTitles = {
  en: { confirmed: 'Appointment confirmed', completed: 'Appointment completed', cancelled: 'Appointment cancelled', no_show: 'Appointment marked no-show', pending: 'New pending appointment' },
  ar: { confirmed: 'تم تأكيد الموعد', completed: 'تم إكمال الموعد', cancelled: 'تم إلغاء الموعد', no_show: 'تم تسجيل عدم الحضور', pending: 'موعد جديد قيد الانتظار' },
};

function getBodyTemplate(locale) {
  return locale === 'ar' ? 'جلسة في %s الساعة %s' : 'Session on %s at %s';
}

/**
 * When a new appointment is created (patient request) with status pending,
 * send FCM to all secretaries and admins so they see pending sessions.
 */
async function sendPendingNotificationToSecretaries(appointmentId, after) {
  const appointmentDate = after.appointmentDate;
  const startTime = after.startTime || '';
  const endTime = after.endTime || '';
  const dateStr = appointmentDate && appointmentDate.toDate
    ? appointmentDate.toDate().toLocaleDateString()
    : '';
  const timeStr = dateStr ? `${startTime}${endTime ? ` - ${endTime}` : ''}` : '';

  const tokensByLocale = { en: [], ar: [] };
  const usersSnap = await db.collection('users').get();
  usersSnap.docs.forEach((doc) => {
    const d = doc.data();
    const token = d.fcmToken;
    if (!token) return;
    const roles = d.roles || [];
    const permissions = d.permissions || [];
    const isSecretary = roles.includes('secretary') || roles.includes('admin');
    const hasAppointments = permissions.includes('appointments') || roles.includes('admin') || roles.includes('secretary');
    if (isSecretary || hasAppointments) {
      const locale = (d.locale === 'ar' ? 'ar' : 'en');
      tokensByLocale[locale].push(token);
    }
  });

  const titleEn = notificationTitles.en.pending;
  const titleAr = notificationTitles.ar.pending;
  const bodyEn = dateStr ? `Session on ${dateStr} at ${timeStr}` : 'A patient requested a new appointment.';
  const bodyAr = dateStr ? `جلسة في ${dateStr} الساعة ${timeStr}` : 'طلب مريض موعداً جديداً.';

  const data = { type: 'appointment_pending', appointmentId, status: 'pending' };

  const baseUrl = 'https://awdacenter-eb0a8.web.app';
  for (const locale of ['en', 'ar']) {
    const tokens = [...new Set(tokensByLocale[locale])];
    if (tokens.length === 0) continue;
    const title = locale === 'ar' ? titleAr : titleEn;
    const body = locale === 'ar' ? bodyAr : bodyEn;
    const message = {
      notification: { title, body },
      data,
      tokens,
      android: { priority: 'high' },
      apns: { payload: { aps: { sound: 'default' } } },
      webpush: {
        notification: { title, body, icon: '/icons/Icon-192.png' },
        fcmOptions: { link: baseUrl + '/#/appointments' },
      },
    };
    try {
      await messaging.sendEachForMulticast(message);
    } catch (err) {
      console.error('FCM pending secretaries error:', err);
    }
  }
}

/**
 * When an appointment's status is updated to confirmed, completed, or cancelled,
 * send FCM to the patient, the doctor, and all secretaries (localized in EN/AR).
 */
exports.onAppointmentStatusChange = functions.firestore
  .document('appointments/{appointmentId}')
  .onUpdate(async (change, context) => {
    const before = change.before.data();
    const after = change.after.data();
    const appointmentId = context.params.appointmentId;

    const newStatus = after.status;
    const oldStatus = before && before.status;
    if (oldStatus === newStatus) return;

    const notifyStatuses = ['confirmed', 'completed', 'cancelled', 'no_show'];
    if (!notifyStatuses.includes(newStatus)) return;

    const patientId = after.patientId;
    const doctorId = after.doctorId;
    const appointmentDate = after.appointmentDate;
    const startTime = after.startTime || '';
    const endTime = after.endTime || '';

    const dateStr = appointmentDate && appointmentDate.toDate
      ? appointmentDate.toDate().toLocaleDateString()
      : '';
    const timeStr = dateStr ? `${startTime}${endTime ? ` - ${endTime}` : ''}` : '';

    const tokensByLocale = { en: [], ar: [] };

    async function addToken(uid) {
      if (!uid) return;
      const userSnap = await db.collection('users').doc(uid).get();
      if (!userSnap.exists) return;
      const d = userSnap.data();
      const token = d.fcmToken;
      if (!token) return;
      const locale = (d.locale === 'ar' ? 'ar' : 'en');
      tokensByLocale[locale].push(token);
    }

    if (patientId) await addToken(patientId);

    if (doctorId) {
      const doctorSnap = await db.collection('doctors').doc(doctorId).get();
      if (doctorSnap.exists) {
        const userId = doctorSnap.data().userId;
        if (userId) await addToken(userId);
      }
    }

    const usersSnap = await db.collection('users').get();
    const added = new Set([patientId, doctorId].filter(Boolean));
    usersSnap.docs.forEach((doc) => {
      const uid = doc.id;
      if (added.has(uid)) return;
      const d = doc.data();
      const token = d.fcmToken;
      if (!token) return;
      const roles = d.roles || [];
      const permissions = d.permissions || [];
      const isSecretary = roles.includes('secretary') || roles.includes('admin');
      const hasAppointments = permissions.includes('appointments') || roles.includes('admin') || roles.includes('secretary');
      if (isSecretary || hasAppointments) {
        added.add(uid);
        const locale = (d.locale === 'ar' ? 'ar' : 'en');
        tokensByLocale[locale].push(token);
      }
    });

    const titleEn = notificationTitles.en[newStatus] || 'Appointment update';
    const titleAr = notificationTitles.ar[newStatus] || 'تحديث الموعد';
    const bodyEn = dateStr ? getBodyTemplate('en').replace('%s', dateStr).replace('%s', timeStr) : 'Your appointment status was updated.';
    const bodyAr = dateStr ? getBodyTemplate('ar').replace('%s', dateStr).replace('%s', timeStr) : 'تم تحديث حالة موعدك.';

    const data = { type: 'appointment_status', appointmentId, status: newStatus };

    const baseUrl = 'https://awdacenter-eb0a8.web.app';
    for (const locale of ['en', 'ar']) {
      const tokens = [...new Set(tokensByLocale[locale])];
      if (tokens.length === 0) continue;
      const title = locale === 'ar' ? titleAr : titleEn;
      const body = locale === 'ar' ? bodyAr : bodyEn;
      const message = {
        notification: { title, body },
        data,
        tokens,
        android: { priority: 'high' },
        apns: { payload: { aps: { sound: 'default' } } },
        webpush: {
          notification: { title, body, icon: '/icons/Icon-192.png' },
          fcmOptions: { link: baseUrl + '/#/appointments' },
        },
      };
      try {
        const res = await messaging.sendEachForMulticast(message);
        if (res.failureCount > 0) {
          console.warn(`FCM ${locale} some failed:`, res.responses.filter((r) => !r.success).length);
        }
      } catch (err) {
        console.error(`FCM send ${locale} error:`, err);
      }
    }
  });

/**
 * When a new appointment is created (e.g. patient requests), if status is pending,
 * notify secretaries and admins about the new pending session.
 */
exports.onAppointmentCreated = functions.firestore
  .document('appointments/{appointmentId}')
  .onCreate(async (snap, context) => {
    const after = snap.data();
    const status = after && after.status;
    if (status !== 'pending') return;
    await sendPendingNotificationToSecretaries(context.params.appointmentId, after);
  });
