import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart' show TargetPlatform, defaultTargetPlatform, kIsWeb;
import '../models/audit_log_model.dart';

/// Logs sensitive actions to Firestore for audit. Call after successful mutation.
class AuditService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static String _platformLabel() {
    if (kIsWeb) return 'web';
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return 'android';
      case TargetPlatform.iOS:
        return 'ios';
      case TargetPlatform.macOS:
        return 'macos';
      case TargetPlatform.windows:
        return 'windows';
      case TargetPlatform.linux:
        return 'linux';
      case TargetPlatform.fuchsia:
        return 'fuchsia';
    }
  }

  static String _deviceTypeLabel() {
    if (kIsWeb) return 'browser';
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
      case TargetPlatform.iOS:
        return 'mobile';
      case TargetPlatform.macOS:
      case TargetPlatform.windows:
      case TargetPlatform.linux:
        return 'desktop';
      case TargetPlatform.fuchsia:
        return 'unknown';
    }
  }

  static Future<void> log({
    required String action,
    required String entityType,
    String? entityId,
    required String userId,
    String? userEmail,
    Map<String, dynamic>? details,
  }) async {
    try {
      final mergedDetails = <String, dynamic>{...?details};
      mergedDetails.putIfAbsent('platform', _platformLabel);
      mergedDetails.putIfAbsent('deviceType', _deviceTypeLabel);

      await _firestore.collection('audit_log').add(AuditLogModel(
        id: '',
        action: action,
        entityType: entityType,
        entityId: entityId,
        userId: userId,
        userEmail: userEmail,
        details: mergedDetails,
        createdAt: DateTime.now(),
      ).toFirestore());
    } catch (_) {}
  }
}
