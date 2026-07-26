import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:http/http.dart' as http;
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdfx/pdfx.dart';
import 'package:url_launcher/url_launcher.dart';

/// Shared cache for chat media so files are not re-downloaded every open.
class ChatMediaCache {
  ChatMediaCache._();
  static final instance = ChatMediaCache._();

  static const key = 'awdaChatMediaCache';

  final CacheManager manager = CacheManager(
    Config(
      key,
      stalePeriod: const Duration(days: 30),
      maxNrOfCacheObjects: 400,
    ),
  );

  Future<FileInfo?> getFile(String url) async {
    try {
      return await manager.getFileFromCache(url) ??
          await manager.downloadFile(url);
    } catch (_) {
      return null;
    }
  }

  /// Open a PDF (or other document) in the device’s default app.
  Future<bool> openInExternalApp(String url, {String? fileName}) async {
    if (kIsWeb) {
      return launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    }
    try {
      final info = await getFile(url);
      if (info != null) {
        final result = await OpenFilex.open(info.file.path);
        return result.type == ResultType.done ||
            result.type == ResultType.noAppToOpen;
      }
      final res = await http.get(Uri.parse(url));
      if (res.statusCode < 200 || res.statusCode >= 300) return false;
      final dir = await getTemporaryDirectory();
      final name = (fileName != null && fileName.trim().isNotEmpty)
          ? fileName.trim()
          : 'awda_${DateTime.now().millisecondsSinceEpoch}.pdf';
      final file = File('${dir.path}/$name');
      await file.writeAsBytes(res.bodyBytes, flush: true);
      final result = await OpenFilex.open(file.path);
      return result.type == ResultType.done;
    } catch (_) {
      try {
        return await launchUrl(
          Uri.parse(url),
          mode: LaunchMode.externalApplication,
        );
      } catch (_) {
        return false;
      }
    }
  }

  /// Render first PDF page as PNG bytes (for document thumbnails).
  Future<Uint8List?> pdfFirstPageThumbnail(Uint8List pdfBytes) async {
    try {
      final doc = await PdfDocument.openData(pdfBytes);
      if (doc.pagesCount < 1) {
        await doc.close();
        return null;
      }
      final page = await doc.getPage(1);
      final pageImage = await page.render(
        width: 240,
        height: 320,
        format: PdfPageImageFormat.png,
      );
      await page.close();
      await doc.close();
      return pageImage?.bytes;
    } catch (_) {
      return null;
    }
  }
}
