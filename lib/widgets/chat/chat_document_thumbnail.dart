import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import '../../models/chat_message_model.dart';
import '../../services/chat_media_cache.dart';
import 'chat_network_image.dart';

/// Shows uploaded PDF thumbnail, or lazily renders page 1 from the cached PDF.
class ChatDocumentThumbnail extends StatefulWidget {
  const ChatDocumentThumbnail({
    super.key,
    required this.message,
    this.width = 56,
    this.height = 72,
  });

  final ChatMessageModel message;
  final double width;
  final double height;

  @override
  State<ChatDocumentThumbnail> createState() => _ChatDocumentThumbnailState();
}

class _ChatDocumentThumbnailState extends State<ChatDocumentThumbnail> {
  Uint8List? _localBytes;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _maybeLoadLocal();
  }

  @override
  void didUpdateWidget(covariant ChatDocumentThumbnail oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.message.id != widget.message.id ||
        oldWidget.message.thumbnailUrl != widget.message.thumbnailUrl ||
        oldWidget.message.mediaUrl != widget.message.mediaUrl) {
      _localBytes = null;
      _maybeLoadLocal();
    }
  }

  Future<void> _maybeLoadLocal() async {
    final msg = widget.message;
    if (!msg.isPdf) return;
    if ((msg.thumbnailUrl ?? '').isNotEmpty) return;
    final url = msg.mediaUrl;
    if (url == null || url.isEmpty || kIsWeb) return;
    if (_loading) return;
    setState(() => _loading = true);
    try {
      final info = await ChatMediaCache.instance.getFile(url);
      if (info == null) return;
      final bytes = await info.file.readAsBytes();
      final thumb =
          await ChatMediaCache.instance.pdfFirstPageThumbnail(bytes);
      if (mounted && thumb != null) {
        setState(() => _localBytes = thumb);
      }
    } catch (_) {
      // Keep icon fallback.
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final remote = widget.message.thumbnailUrl;
    Widget child;
    if (remote != null && remote.isNotEmpty) {
      child = ChatNetworkImage(
        url: remote,
        fit: BoxFit.cover,
        width: widget.width,
        height: widget.height,
      );
    } else if (_localBytes != null) {
      child = Image.memory(
        _localBytes!,
        fit: BoxFit.cover,
        width: widget.width,
        height: widget.height,
      );
    } else {
      child = _placeholder(theme);
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: SizedBox(
        width: widget.width,
        height: widget.height,
        child: child,
      ),
    );
  }

  Widget _placeholder(ThemeData theme) {
    return ColoredBox(
      color: theme.colorScheme.surfaceContainerHigh,
      child: Center(
        child: _loading
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Icon(
                widget.message.isPdf
                    ? Icons.picture_as_pdf
                    : Icons.description,
              ),
      ),
    );
  }
}
