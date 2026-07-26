import 'package:cloud_firestore/cloud_firestore.dart';

/// Global chat settings at `app_settings/chat`.
class ChatSettingsModel {
  /// 0 = unlimited. Otherwise messages older than this many days are hidden/cleaned.
  final int retentionDays;
  /// Quiet hours for chat push (local hour 0–23). Inclusive start, exclusive end wrapping midnight.
  final int quietHoursStart;
  final int quietHoursEnd;
  final bool quietHoursEnabled;
  final DateTime? updatedAt;
  final String? updatedBy;

  const ChatSettingsModel({
    this.retentionDays = 0,
    this.quietHoursStart = 22,
    this.quietHoursEnd = 8,
    this.quietHoursEnabled = true,
    this.updatedAt,
    this.updatedBy,
  });

  static const ChatSettingsModel defaults = ChatSettingsModel();

  factory ChatSettingsModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final d = doc.data() ?? {};
    return ChatSettingsModel(
      retentionDays: (d['retentionDays'] as num?)?.toInt() ?? 0,
      quietHoursStart: (d['quietHoursStart'] as num?)?.toInt() ?? 22,
      quietHoursEnd: (d['quietHoursEnd'] as num?)?.toInt() ?? 8,
      quietHoursEnabled: d['quietHoursEnabled'] as bool? ?? true,
      updatedAt: (d['updatedAt'] as Timestamp?)?.toDate(),
      updatedBy: d['updatedBy'] as String?,
    );
  }

  Map<String, dynamic> toFirestore({required String updatedBy}) {
    return {
      'retentionDays': retentionDays,
      'quietHoursStart': quietHoursStart,
      'quietHoursEnd': quietHoursEnd,
      'quietHoursEnabled': quietHoursEnabled,
      'updatedBy': updatedBy,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  DateTime? retentionCutoff([DateTime? now]) {
    if (retentionDays <= 0) return null;
    final n = now ?? DateTime.now();
    return n.subtract(Duration(days: retentionDays));
  }

  /// True if [localNow] falls inside quiet hours (no chat push).
  bool isInQuietHours([DateTime? localNow]) {
    if (!quietHoursEnabled) return false;
    final n = localNow ?? DateTime.now();
    final h = n.hour;
    if (quietHoursStart == quietHoursEnd) return false;
    if (quietHoursStart < quietHoursEnd) {
      return h >= quietHoursStart && h < quietHoursEnd;
    }
    // Wraps midnight, e.g. 22 → 8
    return h >= quietHoursStart || h < quietHoursEnd;
  }
}
