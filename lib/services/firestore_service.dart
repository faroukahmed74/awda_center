import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'firebase_callable_http.dart';
import '../models/user_model.dart';
import '../models/doctor_model.dart';
import '../models/room_model.dart';
import '../models/appointment_model.dart';
import '../models/session_model.dart';
import '../models/patient_profile_model.dart';
import '../models/income_expense_models.dart';
import '../models/center_requirement_model.dart';
import '../models/admin_todo_model.dart';
import '../models/audit_log_model.dart';
import '../models/service_model.dart';
import '../models/package_model.dart';

class FirestoreService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Users (role filter applied in memory to avoid composite index)
  Stream<QuerySnapshot<Map<String, dynamic>>> usersStream({String? roleFilter}) {
    return _firestore.collection('users').orderBy('createdAt', descending: true).snapshots();
  }

  Future<List<UserModel>> getUsers({String? roleFilter}) async {
    final snapshot = await _firestore.collection('users').orderBy('createdAt', descending: true).get();
    var list = snapshot.docs.map((d) => UserModel.fromFirestore(d)).toList();
    if (roleFilter != null && roleFilter.isNotEmpty) {
      list = list.where((u) => u.roles.contains(roleFilter)).toList();
    }
    return list;
  }

  Future<List<UserModel>> getPatients() async {
    final snapshot = await _firestore.collection('users').orderBy('createdAt', descending: true).get();
    return snapshot.docs
        .map((d) => UserModel.fromFirestore(d))
        .where((u) => u.roles.contains('patient'))
        .toList();
  }

  Future<UserModel?> getUser(String uid) async {
    final doc = await _firestore.collection('users').doc(uid).get();
    if (!doc.exists) return null;
    return UserModel.fromFirestore(doc);
  }

  static const _kFcmInstallationId = 'fcm_installation_id_v1';

  /// Stable id per app install; used as `users/{uid}/fcm_tokens/{id}` document id.
  Future<String> getOrCreateFcmInstallationId() async {
    final prefs = await SharedPreferences.getInstance();
    var id = prefs.getString(_kFcmInstallationId);
    if (id == null || id.isEmpty) {
      id = DateTime.now().microsecondsSinceEpoch.toString();
      await prefs.setString(_kFcmInstallationId, id);
    }
    return id;
  }

  /// Registers this device's FCM token. Other devices keep their own docs under [fcm_tokens].
  Future<void> registerFcmToken(String uid, String token, String installationId) async {
    if (uid.isEmpty || token.isEmpty || installationId.isEmpty) return;
    await _firestore.collection('users').doc(uid).collection('fcm_tokens').doc(installationId).set({
      'token': token,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// Removes this install's token (e.g. logout). Other devices unaffected.
  Future<void> removeFcmTokenForDevice(String uid, String installationId) async {
    if (uid.isEmpty || installationId.isEmpty) return;
    try {
      await _firestore.collection('users').doc(uid).collection('fcm_tokens').doc(installationId).delete();
    } catch (_) {}
  }

  /// Update preferred locale for notifications ('en' or 'ar'). Call from app when locale is known.
  Future<void> updateUserLocale(String uid, String locale) async {
    if (uid.isEmpty) return;
    await _firestore.collection('users').doc(uid).set({
      'locale': locale == 'ar' ? 'ar' : 'en',
    }, SetOptions(merge: true));
  }

  // Doctors
  Stream<QuerySnapshot<Map<String, dynamic>>> doctorsStream() {
    return _firestore.collection('doctors').snapshots();
  }

  Future<List<DoctorModel>> getDoctors() async {
    final snapshot = await _firestore.collection('doctors').get();
    return snapshot.docs.map((d) => DoctorModel.fromFirestore(d)).toList();
  }

  Future<DoctorModel?> getDoctorByUserId(String userId) async {
    final snapshot = await _firestore.collection('doctors').where('userId', isEqualTo: userId).limit(1).get();
    if (snapshot.docs.isEmpty) return null;
    return DoctorModel.fromFirestore(snapshot.docs.first);
  }

  Future<DoctorModel?> getDoctorById(String doctorId) async {
    final doc = await _firestore.collection('doctors').doc(doctorId).get();
    if (!doc.exists) return null;
    return DoctorModel.fromFirestore(doc);
  }

  /// Creates a doctor doc for this user if missing (when admin adds doctor role).
  Future<void> ensureDoctorDocForUser(String userId, String displayName) async {
    final existing = await getDoctorByUserId(userId);
    if (existing != null) return;
    await _firestore.collection('doctors').add({
      'userId': userId,
      'displayName': displayName,
      'specializationAr': null,
      'specializationEn': null,
      'qualificationsAr': null,
      'qualificationsEn': null,
      'certificationsAr': null,
      'certificationsEn': null,
      'bio': null,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> updateDoctor(String doctorId, Map<String, dynamic> data) async {
    await _firestore.collection('doctors').doc(doctorId).update({
      ...data,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<List<DoctorAvailabilityModel>> getDoctorAvailability(String doctorId) async {
    final snapshot = await _firestore
        .collection('doctor_availability')
        .where('doctorId', isEqualTo: doctorId)
        .where('isActive', isEqualTo: true)
        .orderBy('dayOfWeek')
        .get();
    return snapshot.docs.map((d) => DoctorAvailabilityModel.fromFirestore(d as DocumentSnapshot<Map<String, dynamic>>)).toList();
  }

  // Rooms
  Stream<QuerySnapshot<Map<String, dynamic>>> roomsStream() {
    return _firestore.collection('rooms').where('isActive', isEqualTo: true).snapshots();
  }

  Future<List<RoomModel>> getRooms() async {
    final snapshot = await _firestore.collection('rooms').where('isActive', isEqualTo: true).get();
    var list = snapshot.docs.map((d) => RoomModel.fromFirestore(d as DocumentSnapshot<Map<String, dynamic>>)).toList();
    list.sort((a, b) => (a.nameEn ?? a.nameAr ?? a.id).compareTo(b.nameEn ?? b.nameAr ?? b.id));
    return list;
  }

  Future<List<RoomModel>> getAllRooms() async {
    final snapshot = await _firestore.collection('rooms').get();
    var list = snapshot.docs.map((d) => RoomModel.fromFirestore(d as DocumentSnapshot<Map<String, dynamic>>)).toList();
    list.sort((a, b) => (a.nameEn ?? a.nameAr ?? a.id).compareTo(b.nameEn ?? b.nameAr ?? b.id));
    return list;
  }

  Future<void> addRoom(RoomModel room) async {
    await _firestore.collection('rooms').add(room.toFirestore());
  }

  Future<void> updateRoom(String id, Map<String, dynamic> data) async {
    await _firestore.collection('rooms').doc(id).update(data);
  }

  Future<void> deleteRoom(String id) async {
    await _firestore.collection('rooms').doc(id).delete();
  }

  // Services (admin-managed; active ones used in appointment form)
  Stream<QuerySnapshot<Map<String, dynamic>>> servicesStream() {
    return _firestore.collection('services').where('isActive', isEqualTo: true).snapshots();
  }

  Future<List<ServiceModel>> getServices() async {
    final snapshot = await _firestore.collection('services').where('isActive', isEqualTo: true).get();
    var list = snapshot.docs.map((d) => ServiceModel.fromFirestore(d as DocumentSnapshot<Map<String, dynamic>>)).toList();
    list.sort((a, b) => (a.nameEn ?? a.nameAr ?? a.id).compareTo(b.nameEn ?? b.nameAr ?? b.id));
    return list;
  }

  Future<List<ServiceModel>> getAllServices() async {
    final snapshot = await _firestore.collection('services').get();
    var list = snapshot.docs.map((d) => ServiceModel.fromFirestore(d as DocumentSnapshot<Map<String, dynamic>>)).toList();
    list.sort((a, b) => (a.nameEn ?? a.nameAr ?? a.id).compareTo(b.nameEn ?? b.nameAr ?? b.id));
    return list;
  }

  Future<void> addService(ServiceModel service) async {
    await _firestore.collection('services').add(service.toFirestore());
  }

  Future<void> updateService(String id, Map<String, dynamic> data) async {
    await _firestore.collection('services').doc(id).update(data);
  }

  Future<void> deleteService(String id) async {
    await _firestore.collection('services').doc(id).delete();
  }

  // Packages — bundle of services, number of sessions, fixed amount
  Future<List<PackageModel>> getPackages() async {
    final snapshot = await _firestore.collection('packages').get();
    final list = snapshot.docs.map((d) => PackageModel.fromFirestore(d as DocumentSnapshot<Map<String, dynamic>>)).toList();
    list.sort((a, b) => (a.nameEn ?? a.nameAr ?? a.id).compareTo(b.nameEn ?? b.nameAr ?? b.id));
    return list;
  }

  Future<List<PackageModel>> getAllPackages() async {
    final snapshot = await _firestore.collection('packages').get();
    final list = snapshot.docs.map((d) => PackageModel.fromFirestore(d as DocumentSnapshot<Map<String, dynamic>>)).toList();
    list.sort((a, b) => (a.nameEn ?? a.nameAr ?? a.id).compareTo(b.nameEn ?? b.nameAr ?? b.id));
    return list;
  }

  Future<void> addPackage(PackageModel pkg) async {
    await _firestore.collection('packages').add(pkg.toFirestore());
  }

  Future<void> updatePackage(String id, Map<String, dynamic> data) async {
    await _firestore.collection('packages').doc(id).update(data);
  }

  Future<void> deletePackage(String id) async {
    await _firestore.collection('packages').doc(id).delete();
  }

  Future<PackageModel?> getPackageById(String id) async {
    final doc = await _firestore.collection('packages').doc(id).get();
    final data = doc.data();
    if (data == null) return null;
    return PackageModel.fromFirestore(doc);
  }

  // Appointments — use patientId or doctorId; date filter in memory to avoid composite index
  Stream<QuerySnapshot<Map<String, dynamic>>> appointmentsStream({
    String? doctorId,
    String? patientId,
  }) {
    Query<Map<String, dynamic>> q = _firestore.collection('appointments').orderBy('appointmentDate', descending: true);
    if (patientId != null) q = q.where('patientId', isEqualTo: patientId);
    if (doctorId != null) q = q.where('doctorId', isEqualTo: doctorId);
    return q.snapshots();
  }

  Future<List<AppointmentModel>> getAppointments({
    DateTime? from,
    DateTime? to,
    String? doctorId,
    String? patientId,
  }) async {
    Query<Map<String, dynamic>> q = _firestore.collection('appointments').orderBy('appointmentDate', descending: true);
    if (patientId != null) q = q.where('patientId', isEqualTo: patientId);
    if (doctorId != null) q = q.where('doctorId', isEqualTo: doctorId);
    final snapshot = await q.get();
    var list = snapshot.docs.map((d) => AppointmentModel.fromFirestore(d as DocumentSnapshot<Map<String, dynamic>>)).toList();
    if (from != null) list = list.where((a) => !a.appointmentDate.isBefore(from)).toList();
    if (to != null) list = list.where((a) => a.appointmentDate.isBefore(to)).toList();
    return list;
  }

  Future<AppointmentModel?> getAppointmentById(String id) async {
    final doc = await _firestore.collection('appointments').doc(id).get();
    final data = doc.data();
    if (data == null) return null;
    return AppointmentModel.fromFirestore(doc);
  }

  Future<List<AppointmentModel>> getAppointmentsByIds(List<String> appointmentIds) async {
    final ids = appointmentIds.where((id) => id.trim().isNotEmpty).toSet().toList();
    if (ids.isEmpty) return const [];
    final out = <AppointmentModel>[];
    for (var i = 0; i < ids.length; i += 10) {
      final chunk = ids.sublist(i, (i + 10) > ids.length ? ids.length : (i + 10));
      final snapshot = await _firestore
          .collection('appointments')
          .where(FieldPath.documentId, whereIn: chunk)
          .get();
      out.addAll(snapshot.docs.map((d) => AppointmentModel.fromFirestore(d)));
    }
    return out;
  }

  Future<void> updateAppointmentStatus(String id, AppointmentStatus status) async {
    // If an appointment is linked to a package, it should only count once it is attended/completed.
    // For any other status, unlink it so patient profile package progress doesn't count it.
    final update = <String, dynamic>{
      'status': status.value,
      'updatedAt': FieldValue.serverTimestamp(),
    };
    if (status != AppointmentStatus.completed) {
      update['packageId'] = null;
    }
    await _firestore.collection('appointments').doc(id).update(update);
  }

  /// Creates an appointment and returns the new document id.
  Future<String> createAppointment(AppointmentModel appointment) async {
    final ref = await _firestore.collection('appointments').add(appointment.toFirestore());
    return ref.id;
  }

  Future<void> updateAppointment(String id, Map<String, dynamic> data) async {
    await _firestore.collection('appointments').doc(id).update({
      ...data,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Deletes an appointment and any income records linked to it (session income). Admin only.
  Future<void> deleteAppointment(String appointmentId) async {
    final incomeSnap = await _firestore
        .collection('income_records')
        .where('appointmentId', isEqualTo: appointmentId)
        .get();
    for (final doc in incomeSnap.docs) {
      await doc.reference.delete();
    }
    await _firestore.collection('appointments').doc(appointmentId).delete();
  }

  // Sessions (for a patient)
  Future<List<SessionModel>> getSessionsForPatient(String patientId) async {
    final snapshot = await _firestore
        .collection('sessions')
        .where('patientId', isEqualTo: patientId)
        .orderBy('sessionDate', descending: true)
        .get();
    return snapshot.docs.map((d) => SessionModel.fromFirestore(d as DocumentSnapshot<Map<String, dynamic>>)).toList();
  }

  Future<List<SessionModel>> getSessionsByAppointmentIds(List<String> appointmentIds) async {
    final ids = appointmentIds.where((id) => id.trim().isNotEmpty).toSet().toList();
    if (ids.isEmpty) return const [];
    final out = <SessionModel>[];
    for (var i = 0; i < ids.length; i += 10) {
      final chunk = ids.sublist(i, (i + 10) > ids.length ? ids.length : (i + 10));
      final snapshot = await _firestore
          .collection('sessions')
          .where('appointmentId', whereIn: chunk)
          .get();
      out.addAll(
        snapshot.docs.map((d) => SessionModel.fromFirestore(d as DocumentSnapshot<Map<String, dynamic>>)),
      );
    }
    return out;
  }

  Future<SessionModel?> getSession(String sessionId) async {
    final doc = await _firestore.collection('sessions').doc(sessionId).get();
    if (doc.data() == null) return null;
    return SessionModel.fromFirestore(doc);
  }

  Future<void> updateSession(String sessionId, Map<String, dynamic> data) async {
    await _firestore.collection('sessions').doc(sessionId).update({
      ...data,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Deletes a session doc and all relations: if the session has an appointmentId,
  /// deletes that appointment and any income records linked to it.
  Future<void> deleteSessionAndRelations(String sessionId) async {
    final session = await getSession(sessionId);
    if (session == null) return;
    if (session.appointmentId != null && session.appointmentId!.trim().isNotEmpty) {
      await deleteAppointment(session.appointmentId!);
    }
    await _firestore.collection('sessions').doc(sessionId).delete();
  }

  // Patient profile

  /// Returns user ids of staff-created patients (email contains @awda.local). For migration to Auth login.
  Future<List<String>> getStaffCreatedPatientIds() async {
    final snapshot = await _firestore.collection('users').orderBy('createdAt', descending: true).get();
    return snapshot.docs
        .where((doc) {
          final data = doc.data();
          final roles = data['roles'];
          final isPatient = roles is List && roles.contains('patient');
          final email = ((data['email'] as String?) ?? '').toLowerCase();
          return isPatient && email.contains('@awda.local');
        })
        .map((doc) => doc.id)
        .toList();
  }

  /// Migrates one staff-created patient to Auth login. Returns new uid. Throws on failure.
  Future<Map<String, dynamic>> migrateStaffCreatedPatient(String oldUserId) async {
    final data = await callHttpsCallableHttp('migrateStaffCreatedPatient', {'oldUserId': oldUserId});
    if (data.isEmpty) throw Exception('migrateStaffCreatedPatient did not return data');
    return data;
  }

  /// Creates a patient user with Firebase Auth (email + password). Used by staff when adding a patient.
  /// [email] is required. [password] if provided and at least 6 chars is used; otherwise a temporary password is generated.
  /// Returns the new user [uid] and the [password] that was set (so staff can share it with the patient).
  Future<({String uid, String password})> createPatientUser({
    required String? fullNameAr,
    required String? fullNameEn,
    required String? phone,
    String? phone2,
    required String? email,
    String? password,
    String? dateOfBirth,
    int? age,
    String? gender,
  }) async {
    final emailTrimmed = (email ?? '').trim();
    if (emailTrimmed.isEmpty) throw Exception('Email is required to create a patient');
    final pwd = (password != null && password.length >= 6) ? password : _randomTempPassword();
    final data = await callHttpsCallableHttp('createPatientWithEmail', {
      'email': emailTrimmed,
      'password': pwd,
    });
    final uidRaw = data['uid'];
    final uid = uidRaw?.toString();
    if (uid == null || uid.isEmpty) {
      throw Exception('createPatientWithEmail did not return uid');
    }

    await _firestore.collection('users').doc(uid).set({
      'email': emailTrimmed,
      'fullNameAr': fullNameAr?.trim(),
      'fullNameEn': fullNameEn?.trim(),
      'phone': phone?.trim(),
      'phone2': (phone2 != null && phone2.trim().isNotEmpty) ? phone2.trim() : null,
      'roles': ['patient'],
      'permissions': [],
      'isActive': true,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    await _firestore.collection('patient_profiles').doc(uid).set({
      'userId': uid,
      'dateOfBirth': dateOfBirth?.trim(),
      'age': age,
      'gender': (gender != null && gender.trim().isNotEmpty) ? gender.trim() : null,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    return (uid: uid, password: pwd);
  }

  static String _randomTempPassword() {
    final rand = DateTime.now().millisecondsSinceEpoch % 100000;
    return 'Awda${rand.toString().padLeft(5, '0')}!';
  }

  Future<PatientProfileModel?> getPatientProfile(String userId) async {
    final doc = await _firestore.collection('patient_profiles').doc(userId).get();
    if (!doc.exists) return null;
    return PatientProfileModel.fromFirestore(doc);
  }

  Future<void> savePatientProfile(PatientProfileModel profile) async {
    await _firestore.collection('patient_profiles').doc(profile.id).set({
      'userId': profile.userId,
      'dateOfBirth': profile.dateOfBirth,
      'age': profile.age,
      'gender': profile.gender,
      'address': profile.address,
      'occupation': profile.occupation,
      'referredBy': profile.referredBy,
      'maritalStatus': profile.maritalStatus,
      'areasToTreat': profile.areasToTreat,
      'feesType': profile.feesType,
      'diagnosis': profile.diagnosis,
      'followedByDoctorId': profile.followedByDoctorId,
      'medicalHistory': profile.medicalHistory,
      'treatmentProgress': profile.treatmentProgress,
      'progressNotes': profile.progressNotes,
      'chiefComplaint': profile.chiefComplaint,
      'painLevel': profile.painLevel,
      'treatmentGoals': profile.treatmentGoals,
      'contraindications': profile.contraindications,
      'previousTreatment': profile.previousTreatment,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  // Patient documents (images, PDFs, notes — with createdAt/updatedAt)
  Future<List<PatientDocumentModel>> getPatientDocuments(String patientId) async {
    final snapshot = await _firestore
        .collection('patient_documents')
        .where('patientId', isEqualTo: patientId)
        .orderBy('createdAt', descending: true)
        .get();
    return snapshot.docs.map((d) => PatientDocumentModel.fromFirestore(d as DocumentSnapshot<Map<String, dynamic>>)).toList();
  }

  Future<void> addPatientDocument(PatientDocumentModel doc) async {
    await _firestore.collection('patient_documents').add(doc.toFirestore());
  }

  Future<void> updatePatientDocument(String id, Map<String, dynamic> data) async {
    await _firestore.collection('patient_documents').doc(id).update({
      ...data,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> deletePatientDocument(String id) async {
    await _firestore.collection('patient_documents').doc(id).delete();
  }

  // Income & expense
  Stream<QuerySnapshot<Map<String, dynamic>>> incomeRecordsStream() {
    return _firestore.collection('income_records').orderBy('incomeDate', descending: true).snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> expenseRecordsStream() {
    return _firestore.collection('expense_records').orderBy('expenseDate', descending: true).snapshots();
  }

  Future<List<IncomeRecordModel>> getIncomeRecords({DateTime? from, DateTime? to}) async {
    final snapshot = await _firestore.collection('income_records').orderBy('incomeDate', descending: true).get();
    var list = snapshot.docs.map((d) => IncomeRecordModel.fromFirestore(d as DocumentSnapshot<Map<String, dynamic>>)).toList();
    if (from != null) list = list.where((r) => !r.incomeDate.isBefore(from)).toList();
    if (to != null) list = list.where((r) => r.incomeDate.isBefore(to)).toList();
    return list;
  }

  /// Income records for a specific patient (e.g. for patient report PDF).
  Future<List<IncomeRecordModel>> getIncomeRecordsForPatient(String patientId) async {
    final all = await getIncomeRecords();
    final list = all.where((r) => r.patientId == patientId).toList();
    list.sort((a, b) => b.incomeDate.compareTo(a.incomeDate));
    return list;
  }

  Future<List<ExpenseRecordModel>> getExpenseRecords({DateTime? from, DateTime? to}) async {
    final snapshot = await _firestore.collection('expense_records').orderBy('expenseDate', descending: true).get();
    var list = snapshot.docs.map((d) => ExpenseRecordModel.fromFirestore(d as DocumentSnapshot<Map<String, dynamic>>)).toList();
    if (from != null) list = list.where((r) => !r.expenseDate.isBefore(from)).toList();
    if (to != null) list = list.where((r) => r.expenseDate.isBefore(to)).toList();
    return list;
  }

  Future<void> addIncomeRecord(IncomeRecordModel record) async {
    await _firestore.collection('income_records').add(record.toFirestore());
  }

  Future<void> updateIncomeRecord(String id, Map<String, dynamic> data) async {
    await _firestore.collection('income_records').doc(id).update(data);
  }

  Future<void> deleteIncomeRecord(String id) async {
    await _firestore.collection('income_records').doc(id).delete();
  }

  /// All Session income records linked to [appointmentId] (most recent first).
  /// Used to prevent duplicate Session income rows when an appointment is
  /// re-marked as Completed and to dedupe any existing duplicates.
  Future<List<IncomeRecordModel>> getSessionIncomeRecordsByAppointmentId(
    String appointmentId,
  ) async {
    if (appointmentId.trim().isEmpty) return const [];
    final snapshot = await _firestore
        .collection('income_records')
        .where('appointmentId', isEqualTo: appointmentId)
        .get();
    final list = snapshot.docs
        .map((d) => IncomeRecordModel.fromFirestore(
              d as DocumentSnapshot<Map<String, dynamic>>,
            ))
        .where((r) => r.source == 'Session')
        .toList();
    list.sort((a, b) {
      final at = a.createdAt ?? a.incomeDate;
      final bt = b.createdAt ?? b.incomeDate;
      return bt.compareTo(at);
    });
    return list;
  }

  /// Upsert the Session income for [appointmentId]: update the most recent
  /// existing row if one exists, otherwise add [record]. Prevents duplicates
  /// when the same appointment is marked Completed more than once.
  Future<void> upsertSessionIncomeForAppointment(
    String appointmentId,
    IncomeRecordModel record,
  ) async {
    final existing = await getSessionIncomeRecordsByAppointmentId(appointmentId);
    if (existing.isEmpty) {
      await addIncomeRecord(record);
      return;
    }
    final keep = existing.first;
    await updateIncomeRecord(keep.id, {
      'amount': record.amount,
      'currency': record.currency,
      'source': record.source,
      'doctorId': record.doctorId,
      'patientId': record.patientId,
      'notes': record.notes,
      'incomeDate': Timestamp.fromDate(record.incomeDate),
      if (record.sessionPaymentStatus != null)
        'sessionPaymentStatus': record.sessionPaymentStatus,
      'appointmentId': appointmentId,
    });
    for (var i = 1; i < existing.length; i++) {
      await deleteIncomeRecord(existing[i].id);
    }
  }

  Future<void> addExpenseRecord(ExpenseRecordModel record) async {
    await _firestore.collection('expense_records').add(record.toFirestore());
  }

  Future<void> updateExpenseRecord(String id, Map<String, dynamic> data) async {
    await _firestore.collection('expense_records').doc(id).update(data);
  }

  Future<void> deleteExpenseRecord(String id) async {
    await _firestore.collection('expense_records').doc(id).delete();
  }

  // Invites (admin creates; applied when user registers with that email)
  Future<List<Map<String, dynamic>>> getInvites({bool unusedOnly = true}) async {
    Query<Map<String, dynamic>> q = _firestore.collection('invites').orderBy('createdAt', descending: true);
    if (unusedOnly) q = q.where('used', isEqualTo: false);
    final snapshot = await q.get();
    return snapshot.docs.map((d) => {'id': d.id, ...d.data()}).toList();
  }

  Future<void> createInvite({
    required String email,
    required String role,
    String? fullNameAr,
    String? fullNameEn,
    String? phone,
    required String invitedBy,
    // Doctor profile (used when role is doctor and they register)
    String? specializationAr,
    String? specializationEn,
    String? qualificationsAr,
    String? qualificationsEn,
    String? certificationsAr,
    String? certificationsEn,
    String? bio,
  }) async {
    await _firestore.collection('invites').add({
      'email': email.trim().toLowerCase(),
      'role': role,
      'fullNameAr': fullNameAr,
      'fullNameEn': fullNameEn,
      'phone': phone,
      'invitedBy': invitedBy,
      'used': false,
      'createdAt': FieldValue.serverTimestamp(),
      if (specializationAr != null) 'specializationAr': specializationAr,
      if (specializationEn != null) 'specializationEn': specializationEn,
      if (qualificationsAr != null) 'qualificationsAr': qualificationsAr,
      if (qualificationsEn != null) 'qualificationsEn': qualificationsEn,
      if (certificationsAr != null) 'certificationsAr': certificationsAr,
      if (certificationsEn != null) 'certificationsEn': certificationsEn,
      if (bio != null) 'bio': bio,
    });
  }

  Future<Map<String, dynamic>?> getInviteByEmail(String email) async {
    final snapshot = await _firestore
        .collection('invites')
        .where('email', isEqualTo: email.trim().toLowerCase())
        .where('used', isEqualTo: false)
        .limit(1)
        .get();
    if (snapshot.docs.isEmpty) return null;
    final d = snapshot.docs.first;
    return {'id': d.id, ...d.data()};
  }

  Future<void> markInviteUsed(String inviteId) async {
    await _firestore.collection('invites').doc(inviteId).update({'used': true});
  }

  // Center requirements (to-buy list)
  Future<List<CenterRequirementModel>> getCenterRequirements() async {
    final snapshot = await _firestore
        .collection('center_requirements')
        .orderBy('createdAt', descending: true)
        .get();
    return snapshot.docs.map((d) => CenterRequirementModel.fromFirestore(d as DocumentSnapshot<Map<String, dynamic>>)).toList();
  }

  Future<void> addCenterRequirement(CenterRequirementModel r) async {
    await _firestore.collection('center_requirements').add(r.toFirestore());
  }

  Future<void> updateCenterRequirement(String id, Map<String, dynamic> data) async {
    await _firestore.collection('center_requirements').doc(id).update({
      ...data,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> deleteCenterRequirement(String id) async {
    await _firestore.collection('center_requirements').doc(id).delete();
  }

  // Admin to-dos (with reminders)
  Future<List<AdminTodoModel>> getAdminTodos({bool includeCompleted = true}) async {
    final snapshot = await _firestore
        .collection('admin_todos')
        .orderBy('createdAt', descending: true)
        .get();
    var list = snapshot.docs.map((d) => AdminTodoModel.fromFirestore(d as DocumentSnapshot<Map<String, dynamic>>)).toList();
    if (!includeCompleted) list = list.where((t) => !t.completed).toList();
    return list;
  }

  Future<void> addAdminTodo(AdminTodoModel t) async {
    await _firestore.collection('admin_todos').add(t.toFirestore());
  }

  Future<void> updateAdminTodo(String id, Map<String, dynamic> data) async {
    await _firestore.collection('admin_todos').doc(id).update({
      ...data,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> deleteAdminTodo(String id) async {
    await _firestore.collection('admin_todos').doc(id).delete();
  }

  // Audit log (admin read)
  Stream<QuerySnapshot<Map<String, dynamic>>> auditLogsStream({int limit = 100}) {
    return _firestore
        .collection('audit_log')
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots();
  }

  Future<List<AuditLogModel>> getAuditLogs({int limit = 100}) async {
    final snapshot = await _firestore
        .collection('audit_log')
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .get();
    return snapshot.docs.map((d) => AuditLogModel.fromFirestore(d as DocumentSnapshot<Map<String, dynamic>>)).toList();
  }

  // Finance summary (monthly) config: target, rent, receptionist, per-doctor %, commission slices
  static String _financeSummaryDocId(int year, int month) => '${year}_$month';

  Future<Map<String, dynamic>> getFinanceSummaryConfig(int year, int month) async {
    final doc = await _firestore
        .collection('finance_summary_config')
        .doc(_financeSummaryDocId(year, month))
        .get();
    if (!doc.exists) return {};
    return doc.data() ?? {};
  }

  Future<void> setFinanceSummaryConfig(int year, int month, Map<String, dynamic> data) async {
    await _firestore
        .collection('finance_summary_config')
        .doc(_financeSummaryDocId(year, month))
        .set({...data, 'updatedAt': FieldValue.serverTimestamp()}, SetOptions(merge: true));
  }

  // Admin dashboard stats (includes rooms, services, packages counts)
  Future<Map<String, int>> getAdminStats() async {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final todayEnd = todayStart.add(const Duration(days: 1));
    final weekEnd = todayStart.add(const Duration(days: 7));
    final users = await getUsers();
    final todayAppointments = await getAppointments(from: todayStart, to: todayEnd);
    final weekAppointments = await getAppointments(from: todayStart, to: weekEnd);
    final doctors = await getDoctors();
    final patients = users.where((u) => u.roles.contains('patient')).length;
    final openTodos = await getAdminTodos(includeCompleted: false).then((l) => l.length);
    final rooms = await getRooms();
    final services = await getServices();
    final packages = await getPackages();
    return {
      'totalUsers': users.length,
      'activeUsers': users.where((u) => u.isActive).length,
      'todayAppointments': todayAppointments.length,
      'weekAppointments': weekAppointments.length,
      'totalPatients': patients,
      'totalDoctors': doctors.length,
      'openTodos': openTodos,
      'totalRooms': rooms.length,
      'totalServices': services.length,
      'totalPackages': packages.length,
    };
  }

  /// Range: day, week, month, 3months, 6months, 9months, year, custom,
  /// `thisMonth` (full calendar month to date boundary), `anyMonth` (full chosen month).
  /// For [range] == `custom`, pass [customRangeStart] and [customRangeEndInclusive] (calendar dates).
  /// For [range] == `anyMonth`, pass [monthYear] as the first day of that month.
  Future<Map<String, dynamic>> getAdminChartData(
    String range, {
    DateTime? customRangeStart,
    DateTime? customRangeEndInclusive,
    DateTime? monthYear,
  }) async {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);

    late final DateTime rangeStart;
    late final DateTime rangeEndExclusive;

    if (range == 'custom') {
      if (customRangeStart == null || customRangeEndInclusive == null) {
        throw ArgumentError('custom range requires customRangeStart and customRangeEndInclusive');
      }
      rangeStart = DateTime(customRangeStart.year, customRangeStart.month, customRangeStart.day);
      final endInc = DateTime(
        customRangeEndInclusive.year,
        customRangeEndInclusive.month,
        customRangeEndInclusive.day,
      );
      if (endInc.isBefore(rangeStart)) {
        throw ArgumentError('custom range end before start');
      }
      rangeEndExclusive = endInc.add(const Duration(days: 1));
    } else if (range == 'thisMonth') {
      rangeStart = DateTime(now.year, now.month, 1);
      rangeEndExclusive = DateTime(now.year, now.month + 1, 1);
    } else if (range == 'anyMonth') {
      if (monthYear == null) {
        throw ArgumentError('anyMonth requires monthYear (first day of the month)');
      }
      final y = monthYear.year;
      final m = monthYear.month;
      rangeStart = DateTime(y, m, 1);
      rangeEndExclusive = DateTime(y, m + 1, 1);
    } else {
      switch (range) {
        case 'day':
          rangeStart = todayStart;
          break;
        case 'week':
          rangeStart = todayStart.subtract(const Duration(days: 6));
          break;
        case 'month':
          rangeStart = DateTime(now.year, now.month - 1, 1);
          break;
        case '3months':
          rangeStart = DateTime(now.year, now.month - 2, 1);
          break;
        case '6months':
          rangeStart = DateTime(now.year, now.month - 5, 1);
          break;
        case '9months':
          rangeStart = DateTime(now.year, now.month - 8, 1);
          break;
        case 'year':
          rangeStart = DateTime(now.year - 1, now.month, 1);
          break;
        default:
          rangeStart = todayStart.subtract(const Duration(days: 6));
      }
      rangeEndExclusive = now.add(const Duration(days: 1));
    }

    final spanDays = rangeEndExclusive.difference(rangeStart).inDays;

    /// One calendar day bucket (today for preset `day`, or chosen day for custom).
    final isSingleDay = range == 'day' || (range == 'custom' && spanDays <= 1);

    /// One bucket per calendar day: preset week (7) or custom range up to 31 days.
    final isDaySeries =
        range == 'week' || (range == 'custom' && spanDays > 1 && spanDays <= 31);

    final appointments = await getAppointments(from: rangeStart, to: rangeEndExclusive);
    final incomeList = await getIncomeRecords(from: rangeStart, to: rangeEndExclusive);
    final expenseList = await getExpenseRecords(from: rangeStart, to: rangeEndExclusive);

    final totalAppointments = appointments.length;
    final totalIncome = incomeList.fold<double>(0, (s, r) => s + r.amount);
    final totalExpense = expenseList.fold<double>(0, (s, r) => s + r.amount);

    // Appointments series
    final appointmentsSeries = <Map<String, dynamic>>[];
    if (isSingleDay) {
      final d = range == 'day' ? todayStart : rangeStart;
      final count = appointments.where((a) {
        final ad = a.appointmentDate;
        return ad.year == d.year && ad.month == d.month && ad.day == d.day;
      }).length;
      appointmentsSeries.add({'date': d, 'label': _formatDay(d), 'count': count});
    } else if (isDaySeries) {
      if (range == 'week') {
        for (var i = 0; i < 7; i++) {
          final d = rangeStart.add(Duration(days: i));
          final count = appointments.where((a) {
            final ad = a.appointmentDate;
            return ad.year == d.year && ad.month == d.month && ad.day == d.day;
          }).length;
          appointmentsSeries.add({'date': d, 'label': _formatDay(d), 'count': count});
        }
      } else {
        for (var d = rangeStart; d.isBefore(rangeEndExclusive); d = d.add(const Duration(days: 1))) {
          final day = DateTime(d.year, d.month, d.day);
          final count = appointments.where((a) {
            final ad = a.appointmentDate;
            return ad.year == day.year && ad.month == day.month && ad.day == day.day;
          }).length;
          appointmentsSeries.add({'date': day, 'label': _formatDay(day), 'count': count});
        }
      }
    } else {
      var d = DateTime(rangeStart.year, rangeStart.month, 1);
      while (d.isBefore(rangeEndExclusive)) {
        final count = appointments.where((a) => a.appointmentDate.year == d.year && a.appointmentDate.month == d.month).length;
        // Monthly buckets — UI must label as month/year, not as a single calendar day.
        appointmentsSeries.add({'date': d, 'bucket': 'month', 'count': count});
        d = DateTime(d.year, d.month + 1, 1);
      }
    }

    // Income/expense series
    final incomeExpenseSeries = <Map<String, dynamic>>[];
    if (isSingleDay) {
      final d = range == 'day' ? todayStart : rangeStart;
      final income = incomeList
          .where((r) => r.incomeDate.year == d.year && r.incomeDate.month == d.month && r.incomeDate.day == d.day)
          .fold<double>(0, (s, r) => s + r.amount);
      final expense = expenseList
          .where((r) => r.expenseDate.year == d.year && r.expenseDate.month == d.month && r.expenseDate.day == d.day)
          .fold<double>(0, (s, r) => s + r.amount);
      incomeExpenseSeries.add({'year': d.year, 'month': d.month, 'label': _formatDay(d), 'income': income, 'expense': expense});
    } else if (isDaySeries) {
      if (range == 'week') {
        for (var i = 0; i < 7; i++) {
          final d = rangeStart.add(Duration(days: i));
          final income = incomeList
              .where((r) => r.incomeDate.year == d.year && r.incomeDate.month == d.month && r.incomeDate.day == d.day)
              .fold<double>(0, (s, r) => s + r.amount);
          final expense = expenseList
              .where((r) => r.expenseDate.year == d.year && r.expenseDate.month == d.month && r.expenseDate.day == d.day)
              .fold<double>(0, (s, r) => s + r.amount);
          incomeExpenseSeries.add({'year': d.year, 'month': d.month, 'label': _formatDay(d), 'income': income, 'expense': expense});
        }
      } else {
        for (var d = rangeStart; d.isBefore(rangeEndExclusive); d = d.add(const Duration(days: 1))) {
          final day = DateTime(d.year, d.month, d.day);
          final income = incomeList
              .where((r) => r.incomeDate.year == day.year && r.incomeDate.month == day.month && r.incomeDate.day == day.day)
              .fold<double>(0, (s, r) => s + r.amount);
          final expense = expenseList
              .where((r) => r.expenseDate.year == day.year && r.expenseDate.month == day.month && r.expenseDate.day == day.day)
              .fold<double>(0, (s, r) => s + r.amount);
          incomeExpenseSeries.add({'year': day.year, 'month': day.month, 'label': _formatDay(day), 'income': income, 'expense': expense});
        }
      }
    } else {
      var d = DateTime(rangeStart.year, rangeStart.month, 1);
      while (d.isBefore(rangeEndExclusive)) {
        final income = incomeList.where((r) => r.incomeDate.year == d.year && r.incomeDate.month == d.month).fold<double>(0, (s, r) => s + r.amount);
        final expense = expenseList.where((r) => r.expenseDate.year == d.year && r.expenseDate.month == d.month).fold<double>(0, (s, r) => s + r.amount);
        incomeExpenseSeries.add({
          'year': d.year,
          'month': d.month,
          'bucket': 'month',
          'income': income,
          'expense': expense,
        });
        d = DateTime(d.year, d.month + 1, 1);
      }
    }

    final users = await getUsers();
    final usersByRole = <String, int>{};
    for (final u in users) {
      final role = u.roles.isNotEmpty ? u.roles.first : 'patient';
      usersByRole[role] = (usersByRole[role] ?? 0) + 1;
    }

    final appointmentsByStatus = <String, int>{for (final s in AppointmentStatus.values) s.value: 0};
    for (final a in appointments) {
      final k = a.status.value;
      appointmentsByStatus[k] = (appointmentsByStatus[k] ?? 0) + 1;
    }

    final doctors = await getDoctors();
    final doctorDisplayName = <String, String>{
      for (final d in doctors)
        d.id: (d.displayName != null && d.displayName!.trim().isNotEmpty) ? d.displayName!.trim() : d.id,
    };
    final incomeByDoctorAmount = <String, double>{};
    for (final r in incomeList) {
      final id = (r.doctorId != null && r.doctorId!.trim().isNotEmpty) ? r.doctorId!.trim() : '';
      final key = id.isEmpty ? '' : id;
      incomeByDoctorAmount[key] = (incomeByDoctorAmount[key] ?? 0) + r.amount;
    }
    final incomeByDoctor = incomeByDoctorAmount.entries
        .map((e) {
          final id = e.key;
          final name = id.isEmpty ? '' : (doctorDisplayName[id] ?? id);
          return <String, dynamic>{'doctorId': id, 'name': name, 'income': e.value};
        })
        .toList()
      ..sort((a, b) => (b['income'] as double).compareTo(a['income'] as double));

    final expenseByCategoryAmount = <String, double>{};
    for (final r in expenseList) {
      final raw = r.category.trim();
      final key = raw.isEmpty ? '' : raw;
      expenseByCategoryAmount[key] = (expenseByCategoryAmount[key] ?? 0) + r.amount;
    }
    final expensesByCategory = expenseByCategoryAmount.entries
        .map((e) => <String, dynamic>{'category': e.key, 'amount': e.value})
        .toList()
      ..sort((a, b) => (b['amount'] as double).compareTo(a['amount'] as double));

    final expensesByDoctorAmount = <String, double>{};
    for (final r in expenseList) {
      final id = (r.paidByDoctorId != null && r.paidByDoctorId!.trim().isNotEmpty) ? r.paidByDoctorId!.trim() : '';
      expensesByDoctorAmount[id] = (expensesByDoctorAmount[id] ?? 0) + r.amount;
    }
    final expensesByDoctor = expensesByDoctorAmount.entries
        .map((e) {
          final id = e.key;
          final name = id.isEmpty ? '' : (doctorDisplayName[id] ?? id);
          return <String, dynamic>{'doctorId': id, 'name': name, 'expense': e.value};
        })
        .toList()
      ..sort((a, b) => (b['expense'] as double).compareTo(a['expense'] as double));

    final serviceNameCounts = <String, int>{};
    var appointmentsWithoutService = 0;
    for (final a in appointments) {
      if (a.services.isEmpty) {
        appointmentsWithoutService++;
      } else {
        for (final s in a.services) {
          final t = s.trim();
          if (t.isEmpty) continue;
          serviceNameCounts[t] = (serviceNameCounts[t] ?? 0) + 1;
        }
      }
    }
    final appointmentsByService = serviceNameCounts.entries
        .map((e) => <String, dynamic>{'name': e.key, 'count': e.value})
        .toList()
      ..sort((a, b) => (b['count'] as int).compareTo(a['count'] as int));
    if (appointmentsWithoutService > 0) {
      appointmentsByService.add(<String, dynamic>{'name': '', 'count': appointmentsWithoutService});
      appointmentsByService.sort((a, b) => (b['count'] as int).compareTo(a['count'] as int));
    }

    final packageList = await getPackages();
    final packageDisplayName = <String, String>{for (final p in packageList) p.id: p.displayName};
    final packageIdCounts = <String, int>{};
    for (final a in appointments) {
      final pid = a.packageId;
      if (pid == null || pid.trim().isEmpty) continue;
      final k = pid.trim();
      packageIdCounts[k] = (packageIdCounts[k] ?? 0) + 1;
    }
    final appointmentsByPackage = packageIdCounts.entries
        .map((e) => <String, dynamic>{'packageId': e.key, 'name': packageDisplayName[e.key] ?? e.key, 'count': e.value})
        .toList()
      ..sort((a, b) => (b['count'] as int).compareTo(a['count'] as int));

    return {
      'appointmentsByDay': appointmentsSeries,
      'incomeExpenseByMonth': incomeExpenseSeries,
      'usersByRole': usersByRole,
      'appointmentsByStatus': appointmentsByStatus,
      'incomeByDoctor': incomeByDoctor,
      'expensesByCategory': expensesByCategory,
      'expensesByDoctor': expensesByDoctor,
      'appointmentsByService': appointmentsByService,
      'appointmentsByPackage': appointmentsByPackage,
      'periodTotals': {
        'totalAppointments': totalAppointments,
        'totalIncome': totalIncome,
        'totalExpense': totalExpense,
        'totalNet': totalIncome - totalExpense,
      },
      'rangeStart': rangeStart,
      'rangeEnd': rangeEndExclusive,
    };
  }

  static String _formatDay(DateTime d) {
    final dd = d.day.toString().padLeft(2, '0');
    final mm = d.month.toString().padLeft(2, '0');
    return '$dd/$mm/${d.year}';
  }
}
