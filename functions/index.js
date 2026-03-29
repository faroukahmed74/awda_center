const functions = require('firebase-functions');
const admin = require('firebase-admin');

admin.initializeApp();

const db = admin.firestore();
const auth = admin.auth();
const messaging = admin.messaging();

const AWDA_EMAIL_SUFFIX = '@awda.com';
const MIGRATION_PASSWORD = 'AwdaMigrate2024!';

/**
 * Callable: Delete a user from Firebase Auth. Only callable by admin or supervisor.
 * Used when admin deletes a user so their Auth account is removed and they cannot sign in again.
 */
exports.deleteAuthUser = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'Must be signed in');
  }
  const uidToDelete = data && data.uid;
  if (!uidToDelete || typeof uidToDelete !== 'string') {
    throw new functions.https.HttpsError('invalid-argument', 'uid is required');
  }
  const callerUid = context.auth.uid;
  const callerSnap = await db.collection('users').doc(callerUid).get();
  if (!callerSnap.exists) {
    throw new functions.https.HttpsError('permission-denied', 'Caller user not found');
  }
  const roles = callerSnap.data().roles || [];
  if (!roles.includes('admin') && !roles.includes('supervisor')) {
    throw new functions.https.HttpsError('permission-denied', 'Only admin or supervisor can delete users from Auth');
  }
  if (callerUid === uidToDelete) {
    throw new functions.https.HttpsError('invalid-argument', 'Cannot delete your own Auth account this way');
  }
  try {
    await auth.deleteUser(uidToDelete);
    return { success: true };
  } catch (err) {
    if (err.code === 'auth/user-not-found') {
      return { success: true };
    }
    throw new functions.https.HttpsError('internal', err.message);
  }
});

/**
 * Callable: Create a Firebase Auth account for a patient (email + password). Used when staff adds a patient.
 * Returns { uid }. Caller must then create Firestore users/{uid} and patient_profiles/{uid}.
 */
exports.createPatientWithEmail = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'Must be signed in');
  }
  const email = data && data.email;
  const password = data && data.password;
  if (!email || typeof email !== 'string' || email.trim() === '') {
    throw new functions.https.HttpsError('invalid-argument', 'email is required');
  }
  if (!password || typeof password !== 'string' || password.length < 6) {
    throw new functions.https.HttpsError('invalid-argument', 'password must be at least 6 characters');
  }
  const emailTrimmed = String(email).trim();
  try {
    const userRecord = await auth.createUser({
      email: emailTrimmed,
      password: String(password),
      emailVerified: false,
    });
    return { uid: userRecord.uid };
  } catch (err) {
    if (err.code === 'auth/email-already-exists') {
      throw new functions.https.HttpsError('already-exists', 'An account with this email already exists');
    }
    throw new functions.https.HttpsError('internal', err.message);
  }
});

/**
 * Callable: Migrate one staff-created patient (Firestore-only) to have Auth login.
 * oldUserId = Firestore users doc id. User must have email like *@awda.local (staff-created).
 * Creates Auth with migrated_<oldUserId>@awda.com and a fixed migration password; does not use patientCode.
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

  const loginEmail = `migrated_${oldUserId}${AWDA_EMAIL_SUFFIX}`;

  let newUid;
  try {
    const userRecord = await auth.createUser({
      email: loginEmail,
      password: MIGRATION_PASSWORD,
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
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  };
  delete newUserData.patientCode;
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

  return { newUid };
});

const notificationTitlesAr = {
  confirmed: 'تم تأكيد الموعد',
  completed: 'تم إكمال الموعد',
  cancelled: 'تم إلغاء الموعد',
  no_show: 'تم تسجيل عدم الحضور',
  pending: 'موعد جديد قيد الانتظار',
};

/**
 * Legacy field on users/{uid} plus all tokens in users/{uid}/fcm_tokens/*.
 * @param {string} uid
 * @returns {Promise<string[]>}
 */
async function getFcmTokensForUser(uid) {
  if (!uid) return [];
  const out = new Set();
  try {
    const userSnap = await db.collection('users').doc(uid).get();
    if (userSnap.exists) {
      const legacy = userSnap.data().fcmToken;
      if (legacy && typeof legacy === 'string' && legacy.trim()) {
        out.add(legacy.trim());
      }
    }
    const sub = await db.collection('users').doc(uid).collection('fcm_tokens').get();
    sub.docs.forEach((d) => {
      const t = d.data().token;
      if (t && typeof t === 'string' && t.trim()) out.add(t.trim());
    });
  } catch (e) {
    console.warn('getFcmTokensForUser', uid, e);
  }
  return [...out];
}

/**
 * Rich FCM body (Arabic only): date/time, doctor, services, package + session index.
 * @param {FirebaseFirestore.DocumentData} after
 * @param {string} appointmentId
 * @returns {Promise<string>}
 */
async function buildAppointmentBodyAr(after, appointmentId) {
  const appointmentDate = after.appointmentDate;
  const startTime = after.startTime || '';
  const endTime = after.endTime || '';
  const timeStr = endTime ? `${startTime} - ${endTime}` : startTime;

  const dateAr =
    appointmentDate && appointmentDate.toDate
      ? appointmentDate.toDate().toLocaleDateString('ar-EG')
      : '';

  let doctorName = '';
  if (after.doctorId) {
    const docSnap = await db.collection('doctors').doc(after.doctorId).get();
    if (docSnap.exists) {
      doctorName = String(docSnap.data().displayName || '').trim();
    }
  }

  const services = Array.isArray(after.services)
    ? after.services.filter((s) => s && String(s).trim())
    : [];
  const servicesStr = services.map((s) => String(s).trim()).join(', ');

  let pkgAr = '';
  if (after.packageId && after.patientId) {
    const pkgSnap = await db.collection('packages').doc(after.packageId).get();
    if (pkgSnap.exists) {
      const pkg = pkgSnap.data();
      const nameAr = String(pkg.nameAr || '').trim() || String(pkg.nameEn || '').trim() || after.packageId;
      const totalSessions = pkg.numberOfSessions && pkg.numberOfSessions > 0 ? pkg.numberOfSessions : 1;
      let sessionNum = null;
      try {
        const apptsSnap = await db.collection('appointments').where('patientId', '==', after.patientId).get();
        const rows = apptsSnap.docs
          .map((d) => ({ id: d.id, ...d.data() }))
          .filter((r) => r.packageId === after.packageId);
        rows.sort((a, b) => {
          const ad = a.appointmentDate && a.appointmentDate.toDate ? a.appointmentDate.toDate().getTime() : 0;
          const bd = b.appointmentDate && b.appointmentDate.toDate ? b.appointmentDate.toDate().getTime() : 0;
          if (ad !== bd) return ad - bd;
          return String(a.startTime || '').localeCompare(String(b.startTime || ''));
        });
        const idx = rows.findIndex((r) => r.id === appointmentId);
        if (idx >= 0) sessionNum = idx + 1;
      } catch (e) {
        console.warn('buildAppointmentBodyAr session index', e);
      }
      if (sessionNum != null) {
        pkgAr = `الباقة: ${nameAr} (جلسة ${sessionNum} من ${totalSessions})`;
      } else {
        pkgAr = `الباقة: ${nameAr}`;
      }
    }
  }

  const linesAr = [];
  if (dateAr && timeStr) {
    linesAr.push(`جلسة في ${dateAr} الساعة ${timeStr}`);
  }
  if (doctorName) {
    linesAr.push(`الطبيب: ${doctorName}`);
  }
  if (servicesStr) {
    linesAr.push(`الخدمات: ${servicesStr}`);
  }
  if (pkgAr) linesAr.push(pkgAr);

  const fallbackAr = 'افتح التطبيق للتفاصيل.';
  return linesAr.length ? linesAr.join('\n') : fallbackAr;
}

const APPOINTMENTS_WEB_URL = 'https://awdacenter-eb0a8.web.app/#/appointments';

/**
 * @param {string} title
 * @param {string} body
 * @param {string[]} tokens
 * @param {Record<string, string>} data
 */
async function sendMulticastAr(title, body, tokens, data) {
  const unique = [...new Set((tokens || []).filter((t) => t && typeof t === 'string'))];
  if (unique.length === 0) return;
  const dataOut = { title: String(title), body: String(body) };
  Object.keys(data || {}).forEach((k) => {
    const v = data[k];
    dataOut[k] = v == null ? '' : String(v);
  });
  for (let i = 0; i < unique.length; i += 500) {
    const chunk = unique.slice(i, i + 500);
    const message = {
      notification: { title, body },
      data: dataOut,
      tokens: chunk,
      android: { priority: 'high' },
      apns: { payload: { aps: { sound: 'default' } } },
      webpush: {
        notification: { title, body, icon: '/icons/Icon-192.png' },
        fcmOptions: { link: APPOINTMENTS_WEB_URL },
      },
    };
    try {
      const res = await messaging.sendEachForMulticast(message);
      if (res.failureCount > 0) {
        console.warn('FCM multicast partial failure:', res.failureCount);
      }
    } catch (err) {
      console.error('FCM multicast error:', err);
    }
  }
}

/**
 * When an appointment is created, notify the patient and assigned doctor (FCM).
 * Pending: patient sees "request received"; doctor sees "new request". Otherwise "booked".
 */
async function sendAppointmentBookedToPatientAndDoctor(appointmentId, after) {
  const status = after && after.status;
  if (status === 'cancelled') return;

  const patientId = after.patientId;
  const doctorId = after.doctorId;

  const isPending = status === 'pending';
  const titlePatientAr = isPending ? 'تم إرسال طلب الموعد' : 'تم حجز الموعد';
  const titleDoctorAr = isPending ? 'طلب موعد جديد' : 'موعد جديد';

  const bodyAr = await buildAppointmentBodyAr(after, appointmentId);

  const data = {
    type: 'appointment_booked',
    appointmentId,
    status: status || '',
  };

  if (patientId) {
    const tokens = await getFcmTokensForUser(patientId);
    await sendMulticastAr(titlePatientAr, bodyAr, tokens, data);
  }

  if (doctorId) {
    const doctorSnap = await db.collection('doctors').doc(doctorId).get();
    if (doctorSnap.exists) {
      const userId = doctorSnap.data().userId;
      if (userId && userId !== patientId) {
        const tokens = await getFcmTokensForUser(userId);
        await sendMulticastAr(titleDoctorAr, bodyAr, tokens, data);
      }
    }
  }
}

async function sendPendingNotificationToSecretaries(appointmentId, after) {
  const bodyAr = await buildAppointmentBodyAr(after, appointmentId);

  let assignedDoctorUserId = null;
  if (after.doctorId) {
    const ds = await db.collection('doctors').doc(after.doctorId).get();
    if (ds.exists) assignedDoctorUserId = ds.data().userId || null;
  }

  const allTokens = [];
  const usersSnap = await db.collection('users').get();
  for (const doc of usersSnap.docs) {
    if (assignedDoctorUserId && doc.id === assignedDoctorUserId) continue;
    const d = doc.data();
    const roles = d.roles || [];
    const permissions = d.permissions || [];
    const isSecretary = roles.includes('secretary') || roles.includes('admin');
    const hasAppointments = permissions.includes('appointments') || roles.includes('admin') || roles.includes('secretary');
    if (!isSecretary && !hasAppointments) continue;
    const tokens = await getFcmTokensForUser(doc.id);
    allTokens.push(...tokens);
  }

  const titleAr = notificationTitlesAr.pending;
  const data = { type: 'appointment_pending', appointmentId, status: 'pending' };
  await sendMulticastAr(titleAr, bodyAr, allTokens, data);
}

/**
 * When an appointment's status is updated to confirmed, completed, or cancelled,
 * send FCM to the patient, the doctor, and all secretaries (Arabic only).
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

    const allTokens = [];

    if (patientId) {
      allTokens.push(...(await getFcmTokensForUser(patientId)));
    }

    if (doctorId) {
      const doctorSnap = await db.collection('doctors').doc(doctorId).get();
      if (doctorSnap.exists) {
        const userId = doctorSnap.data().userId;
        if (userId) {
          allTokens.push(...(await getFcmTokensForUser(userId)));
        }
      }
    }

    const usersSnap = await db.collection('users').get();
    const added = new Set([patientId].filter(Boolean));
    if (doctorId) {
      const ds = await db.collection('doctors').doc(doctorId).get();
      if (ds.exists && ds.data().userId) added.add(ds.data().userId);
    }
    for (const doc of usersSnap.docs) {
      const uid = doc.id;
      if (added.has(uid)) continue;
      const d = doc.data();
      const roles = d.roles || [];
      const permissions = d.permissions || [];
      const isSecretary = roles.includes('secretary') || roles.includes('admin');
      const hasAppointments = permissions.includes('appointments') || roles.includes('admin') || roles.includes('secretary');
      if (!isSecretary && !hasAppointments) continue;
      added.add(uid);
      allTokens.push(...(await getFcmTokensForUser(uid)));
    }

    const titleAr = notificationTitlesAr[newStatus] || 'تحديث الموعد';
    const bodyAr = await buildAppointmentBodyAr(after, appointmentId);

    const data = { type: 'appointment_status', appointmentId, status: newStatus };
    await sendMulticastAr(titleAr, bodyAr, allTokens, data);
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
    if (status === 'pending') {
      await sendPendingNotificationToSecretaries(context.params.appointmentId, after);
    }
    if (status !== 'cancelled') {
      await sendAppointmentBookedToPatientAndDoctor(context.params.appointmentId, after);
    }
  });
