/// Remote update manifest (JSON from Dropbox or similar).
class RemoteUpdateManifest {
  const RemoteUpdateManifest({
    required this.versionName,
    required this.versionCode,
    required this.apkUrl,
    this.releaseNotes,
    this.minSupportedVersionCode,
  });

  final String versionName;
  final int versionCode;
  final String apkUrl;
  final String? releaseNotes;
  final int? minSupportedVersionCode;

  static RemoteUpdateManifest? fromJson(Map<String, dynamic>? json) {
    if (json == null) return null;
    final name = json['versionName'] as String?;
    final code = json['versionCode'];
    final url = json['apkUrl'] as String?;
    if (name == null || name.isEmpty || url == null || url.isEmpty) return null;
    final vc = code is int ? code : int.tryParse('$code');
    if (vc == null || vc < 1) return null;
    final minRaw = json['minSupportedVersionCode'];
    final min = minRaw == null ? null : (minRaw is int ? minRaw : int.tryParse('$minRaw'));
    final notesRaw = json['releaseNotes'] as String?;
    final notes = notesRaw != null && notesRaw.trim().isNotEmpty ? notesRaw.trim() : null;
    return RemoteUpdateManifest(
      versionName: name,
      versionCode: vc,
      apkUrl: url,
      releaseNotes: notes,
      minSupportedVersionCode: min,
    );
  }
}

/// Result of comparing [PackageInfo] with [RemoteUpdateManifest].
class AndroidUpdateCheckResult {
  const AndroidUpdateCheckResult({
    required this.currentVersionName,
    required this.currentVersionCode,
    this.remote,
  });

  final String currentVersionName;
  final int currentVersionCode;
  final RemoteUpdateManifest? remote;

  bool get isConfigured => remote != null;

  /// Newer build on server than this install.
  bool get hasUpdate =>
      remote != null && remote!.versionCode > currentVersionCode;

  /// This build is below server [RemoteUpdateManifest.minSupportedVersionCode].
  bool get isBelowMinimum {
    final r = remote;
    if (r == null || r.minSupportedVersionCode == null) return false;
    return currentVersionCode < r.minSupportedVersionCode!;
  }

  /// Show download when a newer APK exists or this install is below [RemoteUpdateManifest.minSupportedVersionCode].
  bool get needsInstallPrompt {
    final r = remote;
    if (r == null) return false;
    if (r.versionCode > currentVersionCode) return true;
    if (r.minSupportedVersionCode != null &&
        currentVersionCode < r.minSupportedVersionCode!) {
      return true;
    }
    return false;
  }
}
