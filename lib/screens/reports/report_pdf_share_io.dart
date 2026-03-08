import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import 'report_file_io.dart' as report_io;

/// Saves PDF bytes to a temp file and opens the platform share sheet (Android, iOS, macOS). For web, use report_pdf_share_web.
Future<void> savePdfAndShare(String filename, List<int> bytes, [Rect? sharePositionOrigin]) async {
  final path = await report_io.writeReportBytes(filename, bytes);
  if (path != null) {
    await Share.shareXFiles([XFile(path)], sharePositionOrigin: sharePositionOrigin);
  }
}
