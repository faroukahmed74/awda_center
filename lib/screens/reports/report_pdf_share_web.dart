import 'dart:typed_data';

// ignore: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:html' as html;

import 'package:flutter/material.dart';

/// Triggers a PDF download in the browser (web). [sharePositionOrigin] is ignored on web.
Future<void> savePdfAndShare(String filename, List<int> bytes, [Rect? sharePositionOrigin]) async {
  final blob = html.Blob([Uint8List.fromList(bytes)]);
  final url = html.Url.createObjectUrlFromBlob(blob);
  final anchor = html.AnchorElement()
    ..href = url
    ..download = filename
    ..style.display = 'none';
  html.document.body?.append(anchor);
  anchor.click();
  anchor.remove();
  html.Url.revokeObjectUrl(url);
}
