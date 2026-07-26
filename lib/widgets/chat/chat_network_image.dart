import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import '../../services/chat_media_cache.dart';

/// Chat image that works on web (HTML img, no Storage CORS needed to display)
/// and on mobile (disk-cached via [ChatMediaCache]).
class ChatNetworkImage extends StatelessWidget {
  const ChatNetworkImage({
    super.key,
    required this.url,
    this.width,
    this.height,
    this.maxWidth,
    this.maxHeight,
    this.fit = BoxFit.contain,
    this.borderRadius,
  });

  final String url;
  final double? width;
  final double? height;
  final double? maxWidth;
  final double? maxHeight;
  final BoxFit fit;
  final BorderRadius? borderRadius;

  @override
  Widget build(BuildContext context) {
    Widget child = kIsWeb ? _webImage() : _cachedImage();
    if (maxWidth != null || maxHeight != null) {
      child = ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: maxWidth ?? double.infinity,
          maxHeight: maxHeight ?? double.infinity,
        ),
        child: child,
      );
    }
    if (borderRadius != null) {
      return ClipRRect(borderRadius: borderRadius!, child: child);
    }
    return child;
  }

  Widget _webImage() {
    return Image.network(
      url,
      width: width,
      height: height,
      fit: fit,
      // Prefer HTML <img> so Firebase Storage download URLs display without CORS.
      webHtmlElementStrategy: WebHtmlElementStrategy.prefer,
      loadingBuilder: (context, child, progress) {
        if (progress == null) return child;
        return SizedBox(
          width: width ?? (maxWidth != null ? maxWidth! * 0.7 : 180),
          height: height ?? 160,
          child: const Center(
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        );
      },
      errorBuilder: (_, __, ___) => SizedBox(
        width: width ?? 120,
        height: height ?? 120,
        child: const Center(child: Icon(Icons.broken_image)),
      ),
    );
  }

  Widget _cachedImage() {
    return CachedNetworkImage(
      imageUrl: url,
      cacheManager: ChatMediaCache.instance.manager,
      width: width,
      height: height,
      fit: fit,
      placeholder: (_, __) => SizedBox(
        width: width ?? (maxWidth != null ? maxWidth! * 0.7 : 180),
        height: height ?? 160,
        child: const Center(
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
      errorWidget: (_, __, ___) => SizedBox(
        width: width ?? 120,
        height: height ?? 120,
        child: const Center(child: Icon(Icons.broken_image)),
      ),
    );
  }
}
