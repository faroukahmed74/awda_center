import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import 'report_file_io.dart' as report_io;

/// Saves bytes to a temp file and opens the platform share sheet (Android, iOS, macOS).
/// For web, use report_pdf_share_web.
Future<void> savePdfAndShare(
  String filename,
  List<int> bytes, [
  Rect? sharePositionOrigin,
  String mimeType = 'application/pdf',
]) async {
  final path = await report_io.writeReportBytes(filename, bytes);
  if (path == null) return;

  final origin = sharePositionOrigin ?? const Rect.fromLTWH(0, 0, 100, 100);

  await Share.shareXFiles(
    [XFile(path, mimeType: mimeType)],
    sharePositionOrigin: origin,
  );
}
