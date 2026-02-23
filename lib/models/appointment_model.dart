import 'package:cloud_firestore/cloud_firestore.dart';

enum AppointmentStatus { pending, confirmed, completed, cancelled, noShow }

extension AppointmentStatusExt on AppointmentStatus {
  String get value => this == AppointmentStatus.noShow ? 'no_show' : name;
  static AppointmentStatus fromString(String? v) {
    switch (v?.toLowerCase()) {
      case 'pending': return AppointmentStatus.pending;
      case 'confirmed': return AppointmentStatus.confirmed;
      case 'completed': return AppointmentStatus.completed;
      case 'cancelled': return AppointmentStatus.cancelled;
      case 'no_show':
      case 'noShow': return AppointmentStatus.noShow;
      default: return AppointmentStatus.pending;
    }
  }
}

class AppointmentModel {
  final String id;
  final String patientId;
  final String doctorId;
  final String? roomId;
  final DateTime appointmentDate;
  final String startTime;
  final String endTime;
  final AppointmentStatus status;
  final String? service;
  final double? costAmount;
  final String? notes;
  final String? createdByUserId;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const AppointmentModel({
    required this.id,
    required this.patientId,
    required this.doctorId,
    this.roomId,
    required this.appointmentDate,
    required this.startTime,
    required this.endTime,
    this.status = AppointmentStatus.pending,
    this.service,
    this.costAmount,
    this.notes,
    this.createdByUserId,
    this.createdAt,
    this.updatedAt,
  });

  factory AppointmentModel.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? {};
    Timestamp? dateTs = d['appointmentDate'] as Timestamp?;
    return AppointmentModel(
      id: doc.id,
      patientId: d['patientId'] as String? ?? '',
      doctorId: d['doctorId'] as String? ?? '',
      roomId: d['roomId'] as String?,
      appointmentDate: dateTs?.toDate() ?? DateTime.now(),
      startTime: d['startTime'] as String? ?? '',
      endTime: d['endTime'] as String? ?? '',
      status: AppointmentStatusExt.fromString(d['status'] as String?),
      service: d['service'] as String?,
      costAmount: (d['costAmount'] as num?)?.toDouble(),
      notes: d['notes'] as String?,
      createdByUserId: d['createdByUserId'] as String?,
      createdAt: (d['createdAt'] as Timestamp?)?.toDate(),
      updatedAt: (d['updatedAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'patientId': patientId,
      'doctorId': doctorId,
      'roomId': roomId,
      'appointmentDate': Timestamp.fromDate(appointmentDate),
      'startTime': startTime,
      'endTime': endTime,
      'status': status.value,
      'service': service,
      'costAmount': costAmount,
      'notes': notes,
      'createdByUserId': createdByUserId,
      'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  AppointmentModel copyWith({AppointmentStatus? status}) {
    return AppointmentModel(
      id: id,
      patientId: patientId,
      doctorId: doctorId,
      roomId: roomId,
      appointmentDate: appointmentDate,
      startTime: startTime,
      endTime: endTime,
      status: status ?? this.status,
      service: service,
      costAmount: costAmount,
      notes: notes,
      createdByUserId: createdByUserId,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
    );
  }
}
