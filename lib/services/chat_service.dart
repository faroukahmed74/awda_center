import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';

import '../models/chat_conversation_model.dart';
import '../models/chat_message_model.dart';
import '../models/chat_settings_model.dart';
import 'chat_media_cache.dart';
import 'chat_media_picker.dart';

/// Chat data layer. Uses Firestore collections `conversations` / `messages`
/// and Storage path `chat/{conversationId}/…`.
///
/// Does not change Firebase project config. Security rules must allow these
/// paths (see docs/CHAT_FIREBASE_RULES_SNIPPET.md) before production use.
class ChatService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  FirebaseStorage get _storage {
    try {
      return FirebaseStorage.instanceFor(
        app: Firebase.app(),
        bucket: 'awdacenter-eb0a8.firebasestorage.app',
      );
    } catch (_) {
      return FirebaseStorage.instance;
    }
  }

  CollectionReference<Map<String, dynamic>> get _conversations =>
      _firestore.collection('conversations');

  DocumentReference<Map<String, dynamic>> get _settingsDoc =>
      _firestore.collection('app_settings').doc('chat');

  Future<ChatSettingsModel> getChatSettings() async {
    try {
      final doc = await _settingsDoc.get();
      if (!doc.exists) return ChatSettingsModel.defaults;
      return ChatSettingsModel.fromFirestore(doc);
    } catch (_) {
      return ChatSettingsModel.defaults;
    }
  }

  Future<void> saveChatSettings({
    required int retentionDays,
    required String updatedBy,
    int quietHoursStart = 22,
    int quietHoursEnd = 8,
    bool quietHoursEnabled = true,
  }) async {
    await _settingsDoc.set(
      ChatSettingsModel(
        retentionDays: retentionDays,
        quietHoursStart: quietHoursStart,
        quietHoursEnd: quietHoursEnd,
        quietHoursEnabled: quietHoursEnabled,
      ).toFirestore(updatedBy: updatedBy),
      SetOptions(merge: true),
    );
  }

  Stream<List<ChatConversationModel>> myConversationsStream(String uid) {
    return _conversations
        .where('participantIds', arrayContains: uid)
        .orderBy('lastMessageAt', descending: true)
        .limit(200)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => ChatConversationModel.fromFirestore(d))
            .toList());
  }

  /// Oversight: recent conversations (requires chat_view_all + rules).
  Stream<List<ChatConversationModel>> allConversationsStream() {
    return _conversations
        .orderBy('lastMessageAt', descending: true)
        .limit(300)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => ChatConversationModel.fromFirestore(d))
            .toList());
  }

  Stream<ChatConversationModel?> conversationStream(String id) {
    return _conversations.doc(id).snapshots().map((doc) {
      if (!doc.exists) return null;
      return ChatConversationModel.fromFirestore(doc);
    });
  }

  Stream<List<ChatMessageModel>> messagesStream(
    String conversationId, {
    DateTime? retentionCutoff,
    int limit = 100,
  }) {
    return _conversations
        .doc(conversationId)
        .collection('messages')
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((snap) {
      var list = snap.docs
          .map((d) => ChatMessageModel.fromFirestore(d, conversationId: conversationId))
          .toList();
      if (retentionCutoff != null) {
        list = list
            .where((m) =>
                m.createdAt == null || !m.createdAt!.isBefore(retentionCutoff))
            .toList();
      }
      return list;
    });
  }

  Future<ChatConversationModel> getOrCreateDirect({
    required String myUid,
    required String otherUid,
  }) async {
    final id = ChatConversationModel.directIdFor(myUid, otherUid);
    final ref = _conversations.doc(id);
    final existing = await ref.get();
    if (existing.exists) {
      return ChatConversationModel.fromFirestore(existing);
    }
    final participants = [myUid, otherUid]..sort();
    await ref.set({
      'type': 'direct',
      'participantIds': participants,
      'lastMessageText': '',
      'lastMessageType': 'text',
      'lastMessageBy': null,
      'lastMessageAt': FieldValue.serverTimestamp(),
      'createdAt': FieldValue.serverTimestamp(),
      'unreadCountByUser': {myUid: 0, otherUid: 0},
    });
    final created = await ref.get();
    return ChatConversationModel.fromFirestore(created);
  }

  /// Opens an existing direct chat or creates one, then returns its id.
  Future<String> openDirectChatId({
    required String myUid,
    required String otherUid,
  }) async {
    final c = await getOrCreateDirect(myUid: myUid, otherUid: otherUid);
    return c.id;
  }

  Future<String> createBroadcast({
    required String senderId,
    required List<String> recipientIds,
    required String title,
    required String text,
  }) async {
    final recipients = recipientIds.where((id) => id != senderId).toSet().toList();
    if (recipients.isEmpty) throw ArgumentError('no recipients');
    final participants = [senderId, ...recipients];
    final ref = _conversations.doc();
    final unread = <String, dynamic>{
      for (final u in participants) u: u == senderId ? 0 : 1,
    };
    // Create conversation first, then the message. A single batch fails security
    // rules because message create uses get() on the conversation, which does
    // not see the pending conversation write in the same batch.
    await ref.set({
      'type': 'broadcast',
      'title': title.trim().isEmpty ? 'Broadcast' : title.trim(),
      'participantIds': participants,
      'createdBy': senderId,
      'lastMessageText': text.trim(),
      'lastMessageType': 'text',
      'lastMessageBy': senderId,
      'lastMessageAt': FieldValue.serverTimestamp(),
      'createdAt': FieldValue.serverTimestamp(),
      'unreadCountByUser': unread,
    });
    await ref.collection('messages').add({
      'senderId': senderId,
      'type': 'text',
      'text': text.trim(),
      'reactions': <String, dynamic>{},
      'readBy': [senderId],
      'createdAt': FieldValue.serverTimestamp(),
    });
    return ref.id;
  }

  /// Multi-user group chat (ongoing). Requires at least one other member.
  Future<String> createGroup({
    required String creatorId,
    required List<String> memberIds,
    required String title,
  }) async {
    final members = memberIds.where((id) => id != creatorId).toSet().toList();
    if (members.isEmpty) throw ArgumentError('no members');
    final participants = [creatorId, ...members];
    final ref = _conversations.doc();
    final unread = <String, int>{for (final u in participants) u: 0};
    await ref.set({
      'type': 'group',
      'title': title.trim().isEmpty ? 'Group' : title.trim(),
      'participantIds': participants,
      'createdBy': creatorId,
      'lastMessageText': '',
      'lastMessageType': 'system',
      'lastMessageBy': creatorId,
      'lastMessageAt': FieldValue.serverTimestamp(),
      'createdAt': FieldValue.serverTimestamp(),
      'unreadCountByUser': unread,
    });
    await ref.collection('messages').add({
      'senderId': creatorId,
      'type': 'system',
      'text': 'group_created',
      'readBy': [creatorId],
      'createdAt': FieldValue.serverTimestamp(),
    });
    return ref.id;
  }

  Future<ChatConversationModel?> getConversation(String id) async {
    final doc = await _conversations.doc(id).get();
    if (!doc.exists) return null;
    return ChatConversationModel.fromFirestore(doc);
  }

  Future<void> updateGroupTitle({
    required String conversationId,
    required String title,
    required String actorId,
  }) async {
    final trimmed = title.trim();
    if (trimmed.isEmpty) throw ArgumentError('empty title');
    await _conversations.doc(conversationId).set({
      'title': trimmed,
      'updatedAt': FieldValue.serverTimestamp(),
      'updatedBy': actorId,
    }, SetOptions(merge: true));
    await _conversations.doc(conversationId).collection('messages').add({
      'senderId': actorId,
      'type': 'system',
      'text': 'group_renamed',
      'readBy': [actorId],
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> addGroupMembers({
    required String conversationId,
    required List<String> memberIds,
    required String actorId,
  }) async {
    final toAdd = memberIds.where((id) => id.isNotEmpty).toSet().toList();
    if (toAdd.isEmpty) return;
    await _conversations.doc(conversationId).update({
      'participantIds': FieldValue.arrayUnion(toAdd),
      'updatedAt': FieldValue.serverTimestamp(),
      'updatedBy': actorId,
    });
    final unreadPatch = <String, dynamic>{
      for (final id in toAdd) 'unreadCountByUser.$id': 0,
    };
    await _conversations.doc(conversationId).update(unreadPatch);
    await _conversations.doc(conversationId).collection('messages').add({
      'senderId': actorId,
      'type': 'system',
      'text': 'group_members_added',
      'readBy': [actorId],
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> removeGroupMember({
    required String conversationId,
    required String memberId,
    required String actorId,
  }) async {
    if (memberId.isEmpty) return;
    await _conversations.doc(conversationId).update({
      'participantIds': FieldValue.arrayRemove([memberId]),
      'updatedAt': FieldValue.serverTimestamp(),
      'updatedBy': actorId,
    });
    await _conversations.doc(conversationId).collection('messages').add({
      'senderId': actorId,
      'type': 'system',
      'text': 'group_member_removed',
      'readBy': [actorId],
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  /// Deletes the conversation and its messages (best-effort; Storage files cleaned by retention job).
  Future<void> deleteConversation(String conversationId) async {
    final msgs = await _conversations
        .doc(conversationId)
        .collection('messages')
        .limit(400)
        .get();
    final batch = _firestore.batch();
    for (final d in msgs.docs) {
      batch.delete(d.reference);
    }
    batch.delete(_conversations.doc(conversationId));
    await batch.commit();
    // Second pass if more messages remain
    final more = await _conversations
        .doc(conversationId)
        .collection('messages')
        .limit(400)
        .get();
    if (more.docs.isNotEmpty) {
      final b2 = _firestore.batch();
      for (final d in more.docs) {
        b2.delete(d.reference);
      }
      await b2.commit();
      await _conversations.doc(conversationId).delete();
    }
  }

  Future<String> sendText({
    required String conversationId,
    required String senderId,
    required List<String> participantIds,
    required String text,
    ChatMessageModel? replyTo,
  }) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) throw ArgumentError('empty');
    return _sendMessage(
      conversationId: conversationId,
      senderId: senderId,
      participantIds: participantIds,
      type: ChatMessageType.text,
      text: trimmed,
      preview: trimmed,
      replyTo: replyTo,
    );
  }

  Future<String> sendMedia({
    required String conversationId,
    required String senderId,
    required List<String> participantIds,
    required ChatPickedMedia media,
    String? caption,
    ChatMessageModel? replyTo,
  }) async {
    final maxBytes = switch (media.type) {
      ChatMessageType.image => 10 * 1024 * 1024,
      ChatMessageType.video => 50 * 1024 * 1024,
      ChatMessageType.voice => 8 * 1024 * 1024,
      ChatMessageType.audio => 20 * 1024 * 1024,
      ChatMessageType.document => 20 * 1024 * 1024,
      _ => 10 * 1024 * 1024,
    };
    if (media.bytes.length > maxBytes) {
      throw StateError('file_too_large');
    }
    final url = await _uploadBytes(
      conversationId: conversationId,
      fileName: media.fileName,
      bytes: media.bytes,
      mimeType: media.mimeType,
    );
    String? thumbnailUrl;
    final isPdf = media.mimeType.toLowerCase().contains('pdf') ||
        media.fileName.toLowerCase().endsWith('.pdf');
    if (media.type == ChatMessageType.document && isPdf) {
      try {
        final thumb =
            await ChatMediaCache.instance.pdfFirstPageThumbnail(media.bytes);
        if (thumb != null && thumb.isNotEmpty) {
          thumbnailUrl = await _uploadBytes(
            conversationId: conversationId,
            fileName: '${media.fileName}_thumb.png',
            bytes: thumb,
            mimeType: 'image/png',
          );
        }
      } catch (_) {}
    }
    final preview = switch (media.type) {
      ChatMessageType.image => '📷',
      ChatMessageType.video => '🎬',
      ChatMessageType.audio => '🎵',
      ChatMessageType.voice => '🎤',
      ChatMessageType.document => '📄 ${media.fileName}',
      _ => media.fileName,
    };
    return _sendMessage(
      conversationId: conversationId,
      senderId: senderId,
      participantIds: participantIds,
      type: media.type,
      text: caption?.trim().isEmpty == true ? null : caption?.trim(),
      mediaUrl: url,
      thumbnailUrl: thumbnailUrl,
      fileName: media.fileName,
      mimeType: media.mimeType,
      fileSize: media.bytes.length,
      durationMs: media.durationMs,
      preview: caption?.trim().isNotEmpty == true ? caption!.trim() : preview,
      replyTo: replyTo,
    );
  }

  Future<String> _uploadBytes({
    required String conversationId,
    required String fileName,
    required Uint8List bytes,
    required String mimeType,
  }) async {
    final safeName = fileName.replaceAll(RegExp(r'[^\w.\-]+'), '_');
    final path =
        'chat/$conversationId/${DateTime.now().millisecondsSinceEpoch}_$safeName';
    final ref = _storage.ref().child(path);
    await ref.putData(bytes, SettableMetadata(contentType: mimeType));
    return ref.getDownloadURL();
  }

  Future<String> _sendMessage({
    required String conversationId,
    required String senderId,
    required List<String> participantIds,
    required ChatMessageType type,
    String? text,
    String? mediaUrl,
    String? thumbnailUrl,
    String? fileName,
    String? mimeType,
    int? fileSize,
    int? durationMs,
    required String preview,
    ChatMessageModel? replyTo,
  }) async {
    final msgRef = _conversations.doc(conversationId).collection('messages').doc();
    final unread = <String, dynamic>{};
    for (final uid in participantIds) {
      if (uid == senderId) {
        unread[uid] = 0;
      } else {
        unread[uid] = FieldValue.increment(1);
      }
    }
    String? replyPreview;
    if (replyTo != null) {
      replyPreview = (replyTo.text?.trim().isNotEmpty == true)
          ? replyTo.text!.trim()
          : (replyTo.fileName ?? replyTo.type.value);
      if (replyPreview.length > 120) {
        replyPreview = '${replyPreview.substring(0, 120)}…';
      }
    }
    final batch = _firestore.batch();
    batch.set(msgRef, {
      'senderId': senderId,
      'type': type.value,
      if (text != null) 'text': text,
      if (mediaUrl != null) 'mediaUrl': mediaUrl,
      if (thumbnailUrl != null) 'thumbnailUrl': thumbnailUrl,
      if (fileName != null) 'fileName': fileName,
      if (mimeType != null) 'mimeType': mimeType,
      if (fileSize != null) 'fileSize': fileSize,
      if (durationMs != null) 'durationMs': durationMs,
      if (replyTo != null) ...{
        'replyToId': replyTo.id,
        'replyToText': replyPreview,
        'replyToType': replyTo.type.value,
        'replyToSenderId': replyTo.senderId,
      },
      'reactions': <String, dynamic>{},
      'readBy': [senderId],
      'createdAt': FieldValue.serverTimestamp(),
    });
    batch.set(
      _conversations.doc(conversationId),
      {
        'lastMessageText': preview.length > 200 ? preview.substring(0, 200) : preview,
        'lastMessageType': type.value,
        'lastMessageBy': senderId,
        'lastMessageAt': FieldValue.serverTimestamp(),
        'unreadCountByUser': unread,
      },
      SetOptions(merge: true),
    );
    await batch.commit();
    return msgRef.id;
  }

  /// WhatsApp-style: one reaction per user; same emoji toggles off.
  Future<void> toggleReaction({
    required String conversationId,
    required String messageId,
    required String uid,
    required String emoji,
  }) async {
    final ref = _conversations
        .doc(conversationId)
        .collection('messages')
        .doc(messageId);
    await _firestore.runTransaction((tx) async {
      final snap = await tx.get(ref);
      if (!snap.exists) return;
      final raw = snap.data()?['reactions'];
      final map = <String, List<String>>{};
      if (raw is Map) {
        for (final e in raw.entries) {
          final list = e.value;
          if (list is List) {
            map[e.key.toString()] =
                list.map((x) => x.toString()).toList();
          }
        }
      }
      // Remove this user from every emoji first.
      for (final key in map.keys.toList()) {
        map[key] = map[key]!.where((id) => id != uid).toList();
        if (map[key]!.isEmpty) map.remove(key);
      }
      final already = (raw is Map) &&
          (raw[emoji] is List) &&
          (raw[emoji] as List).map((e) => e.toString()).contains(uid);
      if (!already) {
        map.putIfAbsent(emoji, () => <String>[]).add(uid);
      }
      tx.update(ref, {'reactions': map});
    });
  }

  Future<void> markConversationRead({
    required String conversationId,
    required String uid,
  }) async {
    await _conversations.doc(conversationId).set({
      'unreadCountByUser': {uid: 0},
    }, SetOptions(merge: true));
  }

  Future<void> deleteMessage({
    required String conversationId,
    required String messageId,
  }) async {
    await _conversations
        .doc(conversationId)
        .collection('messages')
        .doc(messageId)
        .delete();
  }

  Future<int> totalUnread(String uid) async {
    try {
      final snap = await _conversations
          .where('participantIds', arrayContains: uid)
          .limit(200)
          .get();
      var total = 0;
      for (final d in snap.docs) {
        final c = ChatConversationModel.fromFirestore(d);
        total += c.unreadFor(uid);
      }
      return total;
    } catch (_) {
      return 0;
    }
  }
}
