import 'package:cloud_firestore/cloud_firestore.dart';

class SessionModel {
  final String id;
  final String? appointmentId;
  final String patientId;
  final String doctorId;
  final DateTime sessionDate;
  final String startTime;
  final String endTime;
  final String? sessionType;
  final String? service;
  final double? feesAmount;
  final double? discountPercent;
  final String? vas;
  final String? rom;
  final String? functionNote;
  final String? notes;
  final String? progressNotes;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const SessionModel({
    required this.id,
    this.appointmentId,
    required this.patientId,
    required this.doctorId,
    required this.sessionDate,
    required this.startTime,
    required this.endTime,
    this.sessionType,
    this.service,
    this.feesAmount,
    this.discountPercent,
    this.vas,
    this.rom,
    this.functionNote,
    this.notes,
    this.progressNotes,
    this.createdAt,
    this.updatedAt,
  });

  factory SessionModel.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? {};
    Timestamp? dateTs = d['sessionDate'] as Timestamp?;
    return SessionModel(
      id: doc.id,
      appointmentId: d['appointmentId'] as String?,
      patientId: d['patientId'] as String? ?? '',
      doctorId: d['doctorId'] as String? ?? '',
      sessionDate: dateTs?.toDate() ?? DateTime.now(),
      startTime: d['startTime'] as String? ?? '',
      endTime: d['endTime'] as String? ?? '',
      sessionType: d['sessionType'] as String?,
      service: d['service'] as String?,
      feesAmount: (d['feesAmount'] as num?)?.toDouble(),
      discountPercent: (d['discountPercent'] as num?)?.toDouble(),
      vas: d['vas'] as String?,
      rom: d['rom'] as String?,
      functionNote: d['functionNote'] as String?,
      notes: d['notes'] as String?,
      progressNotes: d['progressNotes'] as String?,
      createdAt: (d['createdAt'] as Timestamp?)?.toDate(),
      updatedAt: (d['updatedAt'] as Timestamp?)?.toDate(),
    );
  }
}
