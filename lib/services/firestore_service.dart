import 'package:cloud_firestore/cloud_firestore.dart';
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

  Future<void> updateUserFcmToken(String uid, String? token) async {
    await _firestore.collection('users').doc(uid).set({
      'fcmToken': token,
      'fcmTokenUpdatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
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

  Future<void> updateAppointmentStatus(String id, AppointmentStatus status) async {
    await _firestore.collection('appointments').doc(id).update({
      'status': status.value,
      'updatedAt': FieldValue.serverTimestamp(),
    });
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

  // Sessions (for a patient)
  Future<List<SessionModel>> getSessionsForPatient(String patientId) async {
    final snapshot = await _firestore
        .collection('sessions')
        .where('patientId', isEqualTo: patientId)
        .orderBy('sessionDate', descending: true)
        .get();
    return snapshot.docs.map((d) => SessionModel.fromFirestore(d as DocumentSnapshot<Map<String, dynamic>>)).toList();
  }

  // Patient profile
  Future<PatientProfileModel?> getPatientProfile(String userId) async {
    final doc = await _firestore.collection('patient_profiles').doc(userId).get();
    if (!doc.exists) return null;
    return PatientProfileModel.fromFirestore(doc);
  }

  Future<void> savePatientProfile(PatientProfileModel profile) async {
    await _firestore.collection('patient_profiles').doc(profile.id).set({
      'userId': profile.userId,
      'dateOfBirth': profile.dateOfBirth,
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

  Future<void> addExpenseRecord(ExpenseRecordModel record) async {
    await _firestore.collection('expense_records').add(record.toFirestore());
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
    required String invitedBy,
  }) async {
    await _firestore.collection('invites').add({
      'email': email.trim().toLowerCase(),
      'role': role,
      'fullNameAr': fullNameAr,
      'fullNameEn': fullNameEn,
      'invitedBy': invitedBy,
      'used': false,
      'createdAt': FieldValue.serverTimestamp(),
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
  Future<List<AuditLogModel>> getAuditLogs({int limit = 100}) async {
    final snapshot = await _firestore
        .collection('audit_log')
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .get();
    return snapshot.docs.map((d) => AuditLogModel.fromFirestore(d as DocumentSnapshot<Map<String, dynamic>>)).toList();
  }

  // Admin dashboard stats
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
    return {
      'totalUsers': users.length,
      'activeUsers': users.where((u) => u.isActive).length,
      'todayAppointments': todayAppointments.length,
      'weekAppointments': weekAppointments.length,
      'totalPatients': patients,
      'totalDoctors': doctors.length,
      'openTodos': openTodos,
    };
  }
}
