/// Dropbox share links use `dl=0` for an HTML preview and `dl=1` for the raw file.
/// Normalizes [www.dropbox.com] / [dropbox.com] URLs so downloads hit the file directly.
String normalizeDropboxDirectDownload(String url) {
  final trimmed = url.trim();
  final uri = Uri.tryParse(trimmed);
  if (uri == null) return trimmed;
  final host = uri.host.toLowerCase();
  if (host != 'www.dropbox.com' && host != 'dropbox.com') {
    return trimmed;
  }
  final q = Map<String, String>.from(uri.queryParameters);
  q['dl'] = '1';
  return uri.replace(queryParameters: q).toString();
}
