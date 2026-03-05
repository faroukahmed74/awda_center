import 'package:cloud_firestore/cloud_firestore.dart';

enum AppointmentStatus { pending, confirmed, completed, cancelled, noShow, absentWithCause, absentWithoutCause }

extension AppointmentStatusExt on AppointmentStatus {
  String get value {
    if (this == AppointmentStatus.noShow) return 'no_show';
    if (this == AppointmentStatus.absentWithCause) return 'absent_with_cause';
    if (this == AppointmentStatus.absentWithoutCause) return 'absent_without_cause';
    return name;
  }
  static AppointmentStatus fromString(String? v) {
    switch (v?.toLowerCase()) {
      case 'pending': return AppointmentStatus.pending;
      case 'confirmed': return AppointmentStatus.confirmed;
      case 'completed': return AppointmentStatus.completed;
      case 'cancelled': return AppointmentStatus.cancelled;
      case 'no_show':
      case 'noshow': return AppointmentStatus.noShow;
      case 'absent_with_cause': return AppointmentStatus.absentWithCause;
      case 'absent_without_cause': return AppointmentStatus.absentWithoutCause;
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
  /// Multiple services (e.g. ["Physiotherapy", "Consultation"]). Empty list if none.
  final List<String> services;
  final double? costAmount;
  /// Discount in percent (0–100). Stored amount [costAmount] is after discount.
  final double? discountPercent;
  final String? notes;
  /// True if this booking uses the optional 4th slot (admin/secretary only). Max 3 main + 1 extra per time slot per day.
  final bool isExtraSlot;
  /// When set, this appointment is one session of the linked package (first or later session). Rest of sessions booked later.
  final String? packageId;
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
    List<String>? services,
    this.costAmount,
    this.discountPercent,
    this.notes,
    this.isExtraSlot = false,
    this.packageId,
    this.createdByUserId,
    this.createdAt,
    this.updatedAt,
  }) : services = services ?? const [];

  /// First service or null (backward compat for code that expects single service).
  String? get service => services.isEmpty ? null : services.first;

  /// Comma-separated list for display.
  String get servicesDisplay => services.join(', ');

  bool get hasServices => services.isNotEmpty;

  factory AppointmentModel.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? {};
    Timestamp? dateTs = d['appointmentDate'] as Timestamp?;
    List<String> servicesList = const [];
    if (d['services'] != null && d['services'] is List) {
      servicesList = (d['services'] as List).map((e) => e.toString()).where((e) => e.isNotEmpty).toList();
    } else if (d['service'] != null && (d['service'] as String).trim().isNotEmpty) {
      servicesList = [(d['service'] as String).trim()];
    }
    return AppointmentModel(
      id: doc.id,
      patientId: d['patientId'] as String? ?? '',
      doctorId: d['doctorId'] as String? ?? '',
      roomId: d['roomId'] as String?,
      appointmentDate: dateTs?.toDate() ?? DateTime.now(),
      startTime: d['startTime'] as String? ?? '',
      endTime: d['endTime'] as String? ?? '',
      status: AppointmentStatusExt.fromString(d['status'] as String?),
      services: servicesList,
      costAmount: (d['costAmount'] as num?)?.toDouble(),
      discountPercent: (d['discountPercent'] as num?)?.toDouble(),
      notes: d['notes'] as String?,
      isExtraSlot: d['isExtraSlot'] as bool? ?? false,
      packageId: d['packageId'] as String?,
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
      'services': services,
      'costAmount': costAmount,
      'discountPercent': discountPercent,
      'notes': notes,
      'isExtraSlot': isExtraSlot,
      'packageId': packageId,
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
      services: services,
      costAmount: costAmount,
      discountPercent: discountPercent,
      notes: notes,
      isExtraSlot: isExtraSlot,
      packageId: packageId,
      createdByUserId: createdByUserId,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
    );
  }
}
