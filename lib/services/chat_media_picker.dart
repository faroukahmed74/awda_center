import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import '../models/chat_message_model.dart';
import '../models/user_model.dart';

class ChatPickedMedia {
  final Uint8List bytes;
  final String fileName;
  final String mimeType;
  final ChatMessageType type;
  final int? durationMs;

  const ChatPickedMedia({
    required this.bytes,
    required this.fileName,
    required this.mimeType,
    required this.type,
    this.durationMs,
  });
}

class ChatMediaPicker {
  final ImagePicker _picker = ImagePicker();
  final AudioRecorder _recorder = AudioRecorder();

  Future<ChatPickedMedia?> pickCameraPhoto(UserModel user) async {
    if (!user.canSendChatImage) return null;
    if (kIsWeb) {
      // Web: prefer capture via image_picker; fall back to file chooser.
      try {
        final x = await _picker.pickImage(
          source: ImageSource.camera,
          imageQuality: 85,
        );
        if (x != null) {
          return _fromXFile(x, ChatMessageType.image, 'image/jpeg');
        }
      } catch (_) {}
      return _pickImageViaFilePicker();
    }
    final x = await _picker.pickImage(source: ImageSource.camera, imageQuality: 85);
    return _fromXFile(x, ChatMessageType.image, 'image/jpeg');
  }

  Future<ChatPickedMedia?> pickCameraVideo(UserModel user) async {
    if (!user.canSendChatVideo) return null;
    if (kIsWeb) {
      try {
        final x = await _picker.pickVideo(
          source: ImageSource.camera,
          maxDuration: const Duration(minutes: 2),
        );
        if (x != null) {
          return _fromXFile(x, ChatMessageType.video, 'video/mp4');
        }
      } catch (_) {}
      return _pickVideoViaFilePicker();
    }
    final x = await _picker.pickVideo(
      source: ImageSource.camera,
      maxDuration: const Duration(minutes: 2),
    );
    return _fromXFile(x, ChatMessageType.video, 'video/mp4');
  }

  Future<ChatPickedMedia?> pickGallery(UserModel user) async {
    if (kIsWeb) {
      // Web gallery = file picker (image_picker pickMedia is unreliable on web).
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: [
          'jpg',
          'jpeg',
          'png',
          'gif',
          'webp',
          'heic',
          'mp4',
          'mov',
          'webm',
          'm4v',
        ],
        withData: true,
      );
      if (result == null || result.files.isEmpty) return null;
      final f = result.files.single;
      final bytes = f.bytes;
      if (bytes == null || bytes.isEmpty) return null;
      final name = f.name.toLowerCase();
      final isVideo = name.endsWith('.mp4') ||
          name.endsWith('.mov') ||
          name.endsWith('.webm') ||
          name.endsWith('.m4v');
      if (isVideo) {
        if (!user.canSendChatVideo) return null;
        return ChatPickedMedia(
          bytes: bytes,
          fileName: f.name,
          mimeType: 'video/mp4',
          type: ChatMessageType.video,
        );
      }
      if (!user.canSendChatImage) return null;
      return ChatPickedMedia(
        bytes: bytes,
        fileName: f.name,
        mimeType: 'image/jpeg',
        type: ChatMessageType.image,
      );
    }

    final x = await _picker.pickMedia();
    if (x == null) return null;
    final path = x.path.toLowerCase();
    final name = x.name.toLowerCase();
    final isVideo = path.endsWith('.mp4') ||
        path.endsWith('.mov') ||
        path.endsWith('.m4v') ||
        name.endsWith('.mp4') ||
        name.endsWith('.mov');
    if (isVideo) {
      if (!user.canSendChatVideo) return null;
      return _fromXFile(x, ChatMessageType.video, 'video/mp4');
    }
    if (!user.canSendChatImage) return null;
    return _fromXFile(x, ChatMessageType.image, 'image/jpeg');
  }

  Future<ChatPickedMedia?> pickDocument(UserModel user) async {
    if (!user.canSendChatDocument) return null;
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'doc', 'docx', 'xls', 'xlsx'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return null;
    final f = result.files.single;
    final bytes = f.bytes;
    if (bytes == null || bytes.isEmpty) return null;
    final ext = (f.extension ?? '').toLowerCase();
    final mime = switch (ext) {
      'pdf' => 'application/pdf',
      'doc' => 'application/msword',
      'docx' =>
        'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
      'xls' => 'application/vnd.ms-excel',
      'xlsx' =>
        'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      _ => 'application/octet-stream',
    };
    return ChatPickedMedia(
      bytes: bytes,
      fileName: f.name,
      mimeType: mime,
      type: ChatMessageType.document,
    );
  }

  Future<ChatPickedMedia?> pickAudioFile(UserModel user) async {
    if (!user.canSendChatAudio) return null;
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['mp3', 'm4a', 'wav', 'aac', 'ogg'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return null;
    final f = result.files.single;
    final bytes = f.bytes;
    if (bytes == null || bytes.isEmpty) return null;
    final ext = (f.extension ?? 'm4a').toLowerCase();
    return ChatPickedMedia(
      bytes: bytes,
      fileName: f.name,
      mimeType: 'audio/$ext',
      type: ChatMessageType.audio,
    );
  }

  Future<bool> startVoiceRecording(UserModel user) async {
    if (!user.canSendChatVoice) return false;
    if (!await _recorder.hasPermission()) return false;
    String path;
    if (kIsWeb) {
      path = 'voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
    } else {
      final dir = await getTemporaryDirectory();
      path = '${dir.path}/voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
    }
    await _recorder.start(
      const RecordConfig(encoder: AudioEncoder.aacLc),
      path: path,
    );
    return true;
  }

  Future<ChatPickedMedia?> stopVoiceRecording() async {
    final path = await _recorder.stop();
    if (path == null || path.isEmpty) return null;
    final bytes = await XFile(path).readAsBytes();
    if (bytes.isEmpty) return null;
    return ChatPickedMedia(
      bytes: bytes,
      fileName: 'voice_${DateTime.now().millisecondsSinceEpoch}.m4a',
      mimeType: 'audio/mp4',
      type: ChatMessageType.voice,
    );
  }

  Future<void> cancelVoiceRecording() async {
    if (await _recorder.isRecording()) {
      await _recorder.stop();
    }
  }

  Future<void> dispose() async {
    await _recorder.dispose();
  }

  Future<ChatPickedMedia?> _pickImageViaFilePicker() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      withData: true,
    );
    if (result == null || result.files.isEmpty) return null;
    final f = result.files.single;
    final bytes = f.bytes;
    if (bytes == null || bytes.isEmpty) return null;
    return ChatPickedMedia(
      bytes: bytes,
      fileName: f.name,
      mimeType: 'image/jpeg',
      type: ChatMessageType.image,
    );
  }

  Future<ChatPickedMedia?> _pickVideoViaFilePicker() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.video,
      withData: true,
    );
    if (result == null || result.files.isEmpty) return null;
    final f = result.files.single;
    final bytes = f.bytes;
    if (bytes == null || bytes.isEmpty) return null;
    return ChatPickedMedia(
      bytes: bytes,
      fileName: f.name,
      mimeType: 'video/mp4',
      type: ChatMessageType.video,
    );
  }

  Future<ChatPickedMedia?> _fromXFile(
    XFile? x,
    ChatMessageType type,
    String defaultMime,
  ) async {
    if (x == null) return null;
    final bytes = await x.readAsBytes();
    if (bytes.isEmpty) return null;
    final name = x.name.isNotEmpty
        ? x.name
        : 'file_${DateTime.now().millisecondsSinceEpoch}';
    final mime = x.mimeType ?? defaultMime;
    return ChatPickedMedia(
      bytes: bytes,
      fileName: name,
      mimeType: mime,
      type: type,
    );
  }
}
