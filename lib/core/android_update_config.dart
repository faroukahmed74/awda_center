/// URL of a JSON manifest hosted on Dropbox (or any HTTPS server).
/// Dropbox links may use `?dl=0`; the app forces `dl=1` for direct download when fetching this URL and the APK.
///
/// Configure in **one** of these ways (first non-empty wins):
/// 1. Build: `flutter build apk --dart-define=ANDROID_UPDATE_MANIFEST_URL=https://.../version.json`
/// 2. Paste the same JSON file’s Dropbox link below in [kAndroidUpdateManifestUrlEmbedded].
///
/// Use the share link to your **`version.json`** (not the `.apk` link). Upload the JSON next to your APK if you like.
///
/// JSON shape:
/// ```json
/// {
///   "versionName": "1.0.23",
///   "versionCode": 1,
///   "apkUrl": "https://www.dropbox.com/s/xxxx/app-release.apk?dl=1",
///   "releaseNotes": "Optional notes",
///   "minSupportedVersionCode": 1
/// }
/// ```
const String kAndroidUpdateManifestUrl = String.fromEnvironment(
  'ANDROID_UPDATE_MANIFEST_URL',
  defaultValue: '',
);

/// Optional default when [kAndroidUpdateManifestUrl] from `--dart-define` is empty.
/// Paste your Dropbox **JSON** manifest URL here (e.g. `.../version.json?...&dl=1`).
const String kAndroidUpdateManifestUrlEmbedded =
    'https://www.dropbox.com/scl/fi/phoxhhbqsq26o46a7j0vz/update_manifest.example.json?rlkey=a1yhue5rfa30t5mkutv740gwo&st=5nx4ms7k&dl=1';

/// Effective manifest URL for update checks.
String get kAndroidUpdateManifestUrlResolved {
  final env = kAndroidUpdateManifestUrl.trim();
  if (env.isNotEmpty) return env;
  return kAndroidUpdateManifestUrlEmbedded.trim();
}
