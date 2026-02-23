import 'package:cloud_firestore/cloud_firestore.dart';

class AuditLogModel {
  final String id;
  final String action; // e.g. 'user_roles_updated', 'user_deactivated', 'document_deleted'
  final String entityType; // e.g. 'user', 'appointment', 'patient_document'
  final String? entityId;
  final String userId; // who performed the action
  final String? userEmail;
  final Map<String, dynamic>? details;
  final DateTime? createdAt;

  const AuditLogModel({
    required this.id,
    required this.action,
    required this.entityType,
    this.entityId,
    required this.userId,
    this.userEmail,
    this.details,
    this.createdAt,
  });

  factory AuditLogModel.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? {};
    return AuditLogModel(
      id: doc.id,
      action: d['action'] as String? ?? '',
      entityType: d['entityType'] as String? ?? '',
      entityId: d['entityId'] as String?,
      userId: d['userId'] as String? ?? '',
      userEmail: d['userEmail'] as String?,
      details: d['details'] as Map<String, dynamic>?,
      createdAt: (d['createdAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'action': action,
      'entityType': entityType,
      'entityId': entityId,
      'userId': userId,
      'userEmail': userEmail,
      'details': details,
      'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : FieldValue.serverTimestamp(),
    };
  }
}
