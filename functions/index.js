const functions = require('firebase-functions');
const admin = require('firebase-admin');

admin.initializeApp();

const db = admin.firestore();
const auth = admin.auth();
const messaging = admin.messaging();

const AWDA_EMAIL_SUFFIX = '@awda.com';

function palindromeFromCounter(n) {
  const s = String(n);
  if (s.length <= 1) return s;
  const rev = s.slice(0, -1).split('').reverse().join('');
  return s + rev;
}

/** Get next patient code (symmetric number) and increment counter. Use in migration when user has no code. */
async function getNextPatientCode() {
  const counterRef = db.collection('counters').doc('patient_code');
  return db.runTransaction(async (tx) => {
    const snap = await tx.get(counterRef);
    const next = ((snap.exists && snap.data().value) || 0) + 1;
    tx.set(counterRef, { value: next }, { merge: true });
    return palindromeFromCounter(next);
  });
}

/**
 * Callable: Create a Firebase Auth account for a staff-created patient.
 * email = {code}@awda.com, password = code. Returns { uid }.
 * Caller must then create Firestore users/{uid} and patient_profiles/{uid}.
 */
exports.createPatientAuthAccount = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'Must be signed in');
  }
  const code = data && data.code;
  if (!code || typeof code !== 'string' || code.trim() === '') {
    throw new functions.https.HttpsError('invalid-argument', 'code is required');
  }
  const email = `${String(code).trim()}${AWDA_EMAIL_SUFFIX}`;
  const password = String(code).trim();
  try {
    const userRecord = await auth.createUser({
      email,
      password,
      emailVerified: false,
    });
    return { uid: userRecord.uid };
  } catch (err) {
    if (err.code === 'auth/email-already-exists') {
      throw new functions.https.HttpsError('already-exists', 'Patient login already exists for this code');
    }
    throw new functions.https.HttpsError('internal', err.message);
  }
});

/**
 * Callable: Migrate one staff-created patient (Firestore-only) to have Auth login.
 * oldUserId = Firestore users doc id. User must have email like patient_*@awda.local (staff-created).
 * Assigns patientCode if missing, creates Auth (code@awda.com / code), creates users/newUid, migrates profile and all refs, deletes old docs.
 */
exports.migrateStaffCreatedPatient = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'Must be signed in');
  }
  const oldUserId = data && data.oldUserId;
  if (!oldUserId || typeof oldUserId !== 'string') {
    throw new functions.https.HttpsError('invalid-argument', 'oldUserId is required');
  }

  const userRef = db.collection('users').doc(oldUserId);
  const userSnap = await userRef.get();
  if (!userSnap.exists) {
    throw new functions.https.HttpsError('not-found', 'User not found');
  }
  const userData = userSnap.data();
  const email = (userData.email || '').toLowerCase();
  if (!email.includes('@awda.local')) {
    throw new functions.https.HttpsError(
      'invalid-argument',
      'User is not a staff-created patient (email must be @awda.local)'
    );
  }
  const roles = userData.roles || [];
  if (!roles.includes('patient')) {
    throw new functions.https.HttpsError('invalid-argument', 'User is not a patient');
  }

  let code = (userData.patientCode || '').trim();
  if (!code) {
    code = await getNextPatientCode();
    await userRef.update({
      patientCode: code,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });
  }

  const loginEmail = `${code}${AWDA_EMAIL_SUFFIX}`;
  const loginPassword = code;

  let newUid;
  try {
    const userRecord = await auth.createUser({
      email: loginEmail,
      password: loginPassword,
      emailVerified: false,
    });
    newUid = userRecord.uid;
  } catch (err) {
    if (err.code === 'auth/email-already-exists') {
      const existing = await auth.getUserByEmail(loginEmail);
      newUid = existing.uid;
    } else {
      throw new functions.https.HttpsError('internal', err.message);
    }
  }

  const newUserData = {
    ...userData,
    email: loginEmail,
    patientCode: code,
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  };
  delete newUserData.createdAt;
  await db.collection('users').doc(newUid).set({
    ...newUserData,
    createdAt: userData.createdAt || admin.firestore.FieldValue.serverTimestamp(),
  });

  const profileRef = db.collection('patient_profiles').doc(oldUserId);
  const profileSnap = await profileRef.get();
  if (profileSnap.exists) {
    const profileData = profileSnap.data();
    await db.collection('patient_profiles').doc(newUid).set({
      ...profileData,
      userId: newUid,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });
  } else {
    await db.collection('patient_profiles').doc(newUid).set({
      userId: newUid,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    }, { merge: true });
  }

  const batch = db.batch();

  const appointmentsSnap = await db.collection('appointments').where('patientId', '==', oldUserId).get();
  appointmentsSnap.docs.forEach((d) => batch.update(d.ref, { patientId: newUid }));

  const sessionsSnap = await db.collection('sessions').where('patientId', '==', oldUserId).get();
  sessionsSnap.docs.forEach((d) => batch.update(d.ref, { patientId: newUid }));

  const incomeSnap = await db.collection('income_records').where('patientId', '==', oldUserId).get();
  incomeSnap.docs.forEach((d) => batch.update(d.ref, { patientId: newUid }));

  const docsSnap = await db.collection('patient_documents').where('patientId', '==', oldUserId).get();
  docsSnap.docs.forEach((d) => batch.update(d.ref, { patientId: newUid }));

  await batch.commit();

  const deleteBatch = db.batch();
  deleteBatch.delete(userRef);
  if (profileSnap.exists) deleteBatch.delete(profileRef);
  await deleteBatch.commit();

  return { newUid, code };
});

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
