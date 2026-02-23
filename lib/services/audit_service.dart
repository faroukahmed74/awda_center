import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/audit_log_model.dart';

/// Logs sensitive actions to Firestore for audit. Call after successful mutation.
class AuditService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static Future<void> log({
    required String action,
    required String entityType,
    String? entityId,
    required String userId,
    String? userEmail,
    Map<String, dynamic>? details,
  }) async {
    try {
      await _firestore.collection('audit_log').add(AuditLogModel(
        id: '',
        action: action,
        entityType: entityType,
        entityId: entityId,
        userId: userId,
        userEmail: userEmail,
        details: details,
        createdAt: DateTime.now(),
      ).toFirestore());
    } catch (_) {}
  }
}
