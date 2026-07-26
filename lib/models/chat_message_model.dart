import 'package:cloud_firestore/cloud_firestore.dart';

enum ChatMessageType {
  text,
  image,
  video,
  audio,
  voice,
  document,
  system,
}

extension ChatMessageTypeExt on ChatMessageType {
  String get value => name;

  static ChatMessageType fromString(String? v) {
    switch (v) {
      case 'image':
        return ChatMessageType.image;
      case 'video':
        return ChatMessageType.video;
      case 'audio':
        return ChatMessageType.audio;
      case 'voice':
        return ChatMessageType.voice;
      case 'document':
        return ChatMessageType.document;
      case 'system':
        return ChatMessageType.system;
      default:
        return ChatMessageType.text;
    }
  }
}

class ChatMessageModel {
  final String id;
  final String conversationId;
  final String senderId;
  final ChatMessageType type;
  final String? text;
  final String? mediaUrl;
  final String? thumbnailUrl;
  final String? fileName;
  final String? mimeType;
  final int? fileSize;
  final int? durationMs;
  final DateTime? createdAt;
  final List<String> readBy;
  /// emoji → list of user ids
  final Map<String, List<String>> reactions;
  final String? replyToId;
  final String? replyToText;
  final String? replyToType;
  final String? replyToSenderId;

  const ChatMessageModel({
    required this.id,
    required this.conversationId,
    required this.senderId,
    this.type = ChatMessageType.text,
    this.text,
    this.mediaUrl,
    this.thumbnailUrl,
    this.fileName,
    this.mimeType,
    this.fileSize,
    this.durationMs,
    this.createdAt,
    this.readBy = const [],
    this.reactions = const {},
    this.replyToId,
    this.replyToText,
    this.replyToType,
    this.replyToSenderId,
  });

  bool get hasMedia =>
      mediaUrl != null &&
      mediaUrl!.isNotEmpty &&
      type != ChatMessageType.text &&
      type != ChatMessageType.system;

  bool get isPdf =>
      (mimeType ?? '').toLowerCase().contains('pdf') ||
      (fileName ?? '').toLowerCase().endsWith('.pdf');

  factory ChatMessageModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc, {
    required String conversationId,
  }) {
    final d = doc.data() ?? {};
    final reactionsRaw = d['reactions'];
    final reactions = <String, List<String>>{};
    if (reactionsRaw is Map) {
      for (final e in reactionsRaw.entries) {
        final list = e.value;
        if (list is List) {
          reactions[e.key.toString()] =
              list.map((x) => x.toString()).toList();
        }
      }
    }
    return ChatMessageModel(
      id: doc.id,
      conversationId: conversationId,
      senderId: d['senderId'] as String? ?? '',
      type: ChatMessageTypeExt.fromString(d['type'] as String?),
      text: d['text'] as String?,
      mediaUrl: d['mediaUrl'] as String?,
      thumbnailUrl: d['thumbnailUrl'] as String?,
      fileName: d['fileName'] as String?,
      mimeType: d['mimeType'] as String?,
      fileSize: (d['fileSize'] as num?)?.toInt(),
      durationMs: (d['durationMs'] as num?)?.toInt(),
      createdAt: (d['createdAt'] as Timestamp?)?.toDate(),
      readBy: (d['readBy'] as List?)?.map((e) => e.toString()).toList() ?? const [],
      reactions: reactions,
      replyToId: d['replyToId'] as String?,
      replyToText: d['replyToText'] as String?,
      replyToType: d['replyToType'] as String?,
      replyToSenderId: d['replyToSenderId'] as String?,
    );
  }

  ChatMessageModel copyWith({
    String? text,
    Map<String, List<String>>? reactions,
  }) {
    return ChatMessageModel(
      id: id,
      conversationId: conversationId,
      senderId: senderId,
      type: type,
      text: text ?? this.text,
      mediaUrl: mediaUrl,
      thumbnailUrl: thumbnailUrl,
      fileName: fileName,
      mimeType: mimeType,
      fileSize: fileSize,
      durationMs: durationMs,
      createdAt: createdAt,
      readBy: readBy,
      reactions: reactions ?? this.reactions,
      replyToId: replyToId,
      replyToText: replyToText,
      replyToType: replyToType,
      replyToSenderId: replyToSenderId,
    );
  }
}
