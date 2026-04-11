import 'dart:html' as html;

Future<void> _clearServiceWorkersAndCaches() async {
  try {
    final sw = html.window.navigator.serviceWorker;
    if (sw != null) {
      final regs = await sw.getRegistrations();
      for (final reg in regs) {
        await reg.unregister();
      }
    }
  } catch (_) {}

  try {
    final cacheStorage = html.window.caches;
    if (cacheStorage != null) {
      final keys = await cacheStorage.keys();
      for (final key in keys) {
        await cacheStorage.delete(key);
      }
    }
  } catch (_) {}
}

Future<void> reloadCurrentPage() async {
  // Best-effort hard refresh for Flutter web:
  // 1) unregister service workers, 2) clear CacheStorage, 3) reload with cache-busting query.
  await _clearServiceWorkersAndCaches();

  final uri = Uri.parse(html.window.location.href);
  final qp = Map<String, String>.from(uri.queryParameters)
    ..['_v'] = DateTime.now().millisecondsSinceEpoch.toString();
  final busted = uri.replace(queryParameters: qp);
  html.window.location.assign(busted.toString());
}

Future<void> ensureFreshWebLoad() async {
  final uri = Uri.parse(html.window.location.href);
  // Do not loop: if this request already came from the auto-reload step, continue app startup.
  if (uri.queryParameters['_autoRefreshed'] == '1') return;

  // Only once per browser tab/session.
  const storageKey = 'awda_auto_refresh_done';
  if (html.window.sessionStorage[storageKey] == '1') return;
  html.window.sessionStorage[storageKey] = '1';

  await _clearServiceWorkersAndCaches();
  final qp = Map<String, String>.from(uri.queryParameters)
    ..['_autoRefreshed'] = '1'
    ..['_v'] = DateTime.now().millisecondsSinceEpoch.toString();
  final refreshed = uri.replace(queryParameters: qp);
  html.window.location.assign(refreshed.toString());
}
