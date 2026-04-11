import 'reload_page_stub.dart'
    if (dart.library.html) 'reload_page_web.dart' as reload_impl;

Future<void> reloadCurrentPage() => reload_impl.reloadCurrentPage();

Future<void> ensureFreshWebLoad() => reload_impl.ensureFreshWebLoad();
