import 'package:cloud_firestore/cloud_firestore.dart';

enum ChatConversationType { direct, broadcast, group }

class ChatConversationModel {
  final String id;
  final ChatConversationType type;
  final List<String> participantIds;
  final String? lastMessageText;
  final String? lastMessageType;
  final String? lastMessageBy;
  final DateTime? lastMessageAt;
  final DateTime? createdAt;
  final Map<String, int> unreadCountByUser;
  final String? title;
  final String? createdBy;

  const ChatConversationModel({
    required this.id,
    this.type = ChatConversationType.direct,
    this.participantIds = const [],
    this.lastMessageText,
    this.lastMessageType,
    this.lastMessageBy,
    this.lastMessageAt,
    this.createdAt,
    this.unreadCountByUser = const {},
    this.title,
    this.createdBy,
  });

  bool get isMultiParty =>
      type == ChatConversationType.group || type == ChatConversationType.broadcast;

  int unreadFor(String uid) => unreadCountByUser[uid] ?? 0;

  String otherParticipantId(String myUid) {
    for (final id in participantIds) {
      if (id != myUid) return id;
    }
    return '';
  }

  factory ChatConversationModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final d = doc.data() ?? {};
    final unreadRaw = d['unreadCountByUser'];
    final unread = <String, int>{};
    if (unreadRaw is Map) {
      for (final e in unreadRaw.entries) {
        unread[e.key.toString()] = (e.value as num?)?.toInt() ?? 0;
      }
    }
    final typeStr = d['type'] as String? ?? 'direct';
    final type = switch (typeStr) {
      'broadcast' => ChatConversationType.broadcast,
      'group' => ChatConversationType.group,
      _ => ChatConversationType.direct,
    };
    return ChatConversationModel(
      id: doc.id,
      type: type,
      participantIds:
          (d['participantIds'] as List?)?.map((e) => e.toString()).toList() ??
              const [],
      lastMessageText: d['lastMessageText'] as String?,
      lastMessageType: d['lastMessageType'] as String?,
      lastMessageBy: d['lastMessageBy'] as String?,
      lastMessageAt: (d['lastMessageAt'] as Timestamp?)?.toDate(),
      createdAt: (d['createdAt'] as Timestamp?)?.toDate(),
      unreadCountByUser: unread,
      title: d['title'] as String?,
      createdBy: d['createdBy'] as String?,
    );
  }

  static String directIdFor(String uidA, String uidB) {
    final sorted = [uidA, uidB]..sort();
    return 'direct_${sorted[0]}_${sorted[1]}';
  }
}
