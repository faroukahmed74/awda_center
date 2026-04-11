import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:http/http.dart' as http;
import 'package:open_filex/open_filex.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';

import '../core/android_update_config.dart';
import '../core/direct_download_url.dart';
import 'app_update_models.dart';

/// Avoids stale manifest JSON from intermediaries after you edit the file on Dropbox.
Uri _manifestRequestUri(String url) {
  final u = Uri.parse(url);
  final q = Map<String, String>.from(u.queryParameters);
  q['_nc'] = DateTime.now().millisecondsSinceEpoch.toString();
  return u.replace(queryParameters: q);
}

Future<AndroidUpdateCheckResult?> checkAndroidAppUpdate() async {
  if (!Platform.isAndroid) return null;
  final url = normalizeDropboxDirectDownload(kAndroidUpdateManifestUrlResolved);
  if (url.isEmpty) return null;

  final info = await PackageInfo.fromPlatform();
  final currentCode = int.tryParse(info.buildNumber) ?? 0;
  final currentName = info.version;

  try {
    final uri = _manifestRequestUri(url);
    final res = await http
        .get(
          uri,
          headers: const {
            'Cache-Control': 'no-cache',
            'Pragma': 'no-cache',
          },
        )
        .timeout(const Duration(seconds: 25));
    if (res.statusCode < 200 || res.statusCode >= 300) {
      return AndroidUpdateCheckResult(
        currentVersionName: currentName,
        currentVersionCode: currentCode,
        remote: null,
      );
    }
    final map = jsonDecode(res.body) as Map<String, dynamic>?;
    final remote = RemoteUpdateManifest.fromJson(map);
    return AndroidUpdateCheckResult(
      currentVersionName: currentName,
      currentVersionCode: currentCode,
      remote: remote,
    );
  } catch (_) {
    return AndroidUpdateCheckResult(
      currentVersionName: currentName,
      currentVersionCode: currentCode,
      remote: null,
    );
  }
}

/// Downloads APK to app cache; returns file path or null on failure.
Future<String?> downloadAndroidApk(
  String url, {
  void Function(double progress)? onProgress,
}) async {
  if (!Platform.isAndroid) return null;
  final resolved = normalizeDropboxDirectDownload(url);
  final uri = Uri.tryParse(resolved);
  if (uri == null || (uri.scheme != 'https' && uri.scheme != 'http')) {
    return null;
  }

  final dir = await getTemporaryDirectory();
  final file = File('${dir.path}/awda_center_update.apk');
  if (await file.exists()) {
    try {
      await file.delete();
    } catch (_) {}
  }

  final dio = Dio();
  try {
    await dio.download(
      resolved,
      file.path,
      options: Options(
        receiveTimeout: const Duration(minutes: 30),
        sendTimeout: const Duration(seconds: 60),
      ),
      onReceiveProgress: (received, total) {
        if (total <= 0) return;
        onProgress?.call(received / total);
      },
    );
    if (!await file.exists() || await file.length() == 0) return null;
    return file.path;
  } catch (_) {
    try {
      if (await file.exists()) await file.delete();
    } catch (_) {}
    return null;
  }
}

Future<void> openAndroidApk(String filePath) async {
  if (!Platform.isAndroid) return;
  final f = File(filePath);
  if (!await f.exists()) return;
  await OpenFilex.open(filePath);
}
