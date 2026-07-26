import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:gal/gal.dart';
import 'package:http/http.dart' as http;
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../models/chat_message_model.dart';
import '../models/user_model.dart';

/// Save / download chat media on Android, iOS, and Web.
class ChatMediaSaver {
  Future<bool> saveMessageMedia(ChatMessageModel message, UserModel user) async {
    if (!user.canSaveChatMedia) return false;
    final url = message.mediaUrl;
    if (url == null || url.isEmpty) return false;

    final bytes = await _download(url);
    if (bytes == null || bytes.isEmpty) return false;
    final name = message.fileName ??
        'awda_chat_${message.id}${_extFor(message)}';

    if (kIsWeb) {
      await Share.shareXFiles([
        XFile.fromData(
          bytes,
          name: name,
          mimeType: message.mimeType ?? 'application/octet-stream',
        ),
      ]);
      return true;
    }

    final path = await _writeTemp(name, bytes);

    switch (message.type) {
      case ChatMessageType.image:
        await Gal.putImage(path, album: 'Awda Center');
        return true;
      case ChatMessageType.video:
        await Gal.putVideo(path, album: 'Awda Center');
        return true;
      case ChatMessageType.audio:
      case ChatMessageType.voice:
      case ChatMessageType.document:
        final result = await OpenFilex.open(path);
        if (result.type == ResultType.done) return true;
        await Share.shareXFiles([XFile(path)]);
        return true;
      default:
        await Share.shareXFiles([XFile(path)]);
        return true;
    }
  }

  Future<Uint8List?> _download(String url) async {
    try {
      final res = await http.get(Uri.parse(url));
      if (res.statusCode >= 200 && res.statusCode < 300) {
        return res.bodyBytes;
      }
    } catch (_) {}
    return null;
  }

  Future<String> _writeTemp(String name, Uint8List bytes) async {
    final dir = await getTemporaryDirectory();
    final path = '${dir.path}/$name';
    final x = XFile.fromData(bytes, name: name);
    await x.saveTo(path);
    return path;
  }

  String _extFor(ChatMessageModel m) {
    final mime = m.mimeType ?? '';
    if (mime.contains('png')) return '.png';
    if (mime.contains('jpeg') || mime.contains('jpg')) return '.jpg';
    if (mime.contains('mp4')) return '.mp4';
    if (mime.contains('pdf')) return '.pdf';
    if (mime.contains('audio') || m.type == ChatMessageType.voice) return '.m4a';
    if (mime.contains('sheet') || mime.contains('excel')) return '.xlsx';
    if (mime.contains('word')) return '.docx';
    return '';
  }
}
