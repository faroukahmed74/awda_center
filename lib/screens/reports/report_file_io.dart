import 'dart:io' show File;

import 'package:path_provider/path_provider.dart';

/// Writes report bytes to a temp file and returns the file path. Used for PDF/Excel share on mobile/desktop.
Future<String?> writeReportBytes(String filename, List<int> bytes) async {
  final dir = await getTemporaryDirectory();
  final path = '${dir.path}/$filename';
  await File(path).writeAsBytes(bytes);
  return path;
}
