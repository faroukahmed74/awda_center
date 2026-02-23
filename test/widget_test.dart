import 'package:flutter/material.dart' show Locale;
import 'package:flutter_test/flutter_test.dart';
import 'package:awda_center/l10n/app_localizations.dart';

void main() {
  testWidgets('App localizations support AR and EN', (WidgetTester tester) async {
    expect(AppLocalizations.supportedLocales.length, 2);
    final en = AppLocalizations(const Locale('en'));
    final ar = AppLocalizations(const Locale('ar'));
    expect(en.appTitle, 'Awda Physical Therapy');
    expect(ar.appTitle, 'عودة للعلاج الطبيعي');
    expect(en.isArabic, false);
    expect(ar.isArabic, true);
  });
}
