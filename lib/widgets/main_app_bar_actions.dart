import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:provider/provider.dart';

import '../l10n/app_localizations.dart';
import '../providers/locale_provider.dart';
import '../providers/theme_provider.dart';
import '../web/reload_page.dart';
import 'android_app_update_button.dart';
import 'notifications_button.dart';

/// Notifications, language, and theme toggles — same behavior as [DashboardScreen] app bar.
class MainAppBarActions {
  MainAppBarActions._();

  static List<Widget> _refreshLangTheme(BuildContext context) => [
        if (kIsWeb) const _WebRefreshButton(),
        const _LanguageToggleButton(),
        const _ThemeToggleButton(),
      ];

  /// Language + theme only (use when notifications is already placed separately).
  static List<Widget> languageAndTheme(BuildContext context) => [
        if (AndroidAppUpdateButton.isSupported) const AndroidAppUpdateButton(),
        ..._refreshLangTheme(context),
      ];

  /// Notifications, language, and theme — use on most authenticated screens.
  static List<Widget> notificationsLanguageTheme(BuildContext context) => [
        if (AndroidAppUpdateButton.isSupported) const AndroidAppUpdateButton(),
        const NotificationsButton(),
        ..._refreshLangTheme(context),
      ];
}

class _LanguageToggleButton extends StatelessWidget {
  const _LanguageToggleButton();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return IconButton(
      icon: const Icon(Icons.language),
      tooltip: l10n.isArabic ? 'English' : 'العربية',
      onPressed: () => context.read<LocaleProvider>().toggleLocale(),
    );
  }
}

class _ThemeToggleButton extends StatelessWidget {
  const _ThemeToggleButton();

  @override
  Widget build(BuildContext context) {
    final isDark = context.watch<ThemeProvider>().isDark;
    return IconButton(
      icon: Icon(isDark ? Icons.light_mode : Icons.dark_mode),
      tooltip: 'Theme',
      onPressed: () => context.read<ThemeProvider>().toggleDarkLight(),
    );
  }
}

class _WebRefreshButton extends StatelessWidget {
  const _WebRefreshButton();

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.refresh),
      tooltip: 'Refresh (get latest update)',
      onPressed: () {
        reloadCurrentPage();
      },
    );
  }
}
