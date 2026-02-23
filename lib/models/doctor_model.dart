import 'package:cloud_firestore/cloud_firestore.dart';

class DoctorModel {
  final String id;
  final String userId;
  final String? displayName;
  final String? specializationAr;
  final String? specializationEn;
  final String? qualificationsAr;
  final String? qualificationsEn;
  final String? bio;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const DoctorModel({
    required this.id,
    required this.userId,
    this.displayName,
    this.specializationAr,
    this.specializationEn,
    this.qualificationsAr,
    this.qualificationsEn,
    this.bio,
    this.createdAt,
    this.updatedAt,
  });

  factory DoctorModel.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? {};
    return DoctorModel(
      id: doc.id,
      userId: d['userId'] as String? ?? '',
      displayName: d['displayName'] as String?,
      specializationAr: d['specializationAr'] as String?,
      specializationEn: d['specializationEn'] as String?,
      qualificationsAr: d['qualificationsAr'] as String?,
      qualificationsEn: d['qualificationsEn'] as String?,
      bio: d['bio'] as String?,
      createdAt: (d['createdAt'] as Timestamp?)?.toDate(),
      updatedAt: (d['updatedAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'displayName': displayName,
      'specializationAr': specializationAr,
      'specializationEn': specializationEn,
      'qualificationsAr': qualificationsAr,
      'qualificationsEn': qualificationsEn,
      'bio': bio,
      'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }
}

class DoctorAvailabilityModel {
  final String id;
  final String doctorId;
  final int dayOfWeek; // 1 = Monday, 7 = Sunday
  final String startTime;
  final String endTime;
  final int slotDurationMinutes;
  final bool isActive;

  const DoctorAvailabilityModel({
    required this.id,
    required this.doctorId,
    required this.dayOfWeek,
    required this.startTime,
    required this.endTime,
    this.slotDurationMinutes = 30,
    this.isActive = true,
  });

  factory DoctorAvailabilityModel.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? {};
    return DoctorAvailabilityModel(
      id: doc.id,
      doctorId: d['doctorId'] as String? ?? '',
      dayOfWeek: d['dayOfWeek'] as int? ?? 1,
      startTime: d['startTime'] as String? ?? '09:00',
      endTime: d['endTime'] as String? ?? '17:00',
      slotDurationMinutes: d['slotDurationMinutes'] as int? ?? 30,
      isActive: d['isActive'] as bool? ?? true,
    );
  }
}
