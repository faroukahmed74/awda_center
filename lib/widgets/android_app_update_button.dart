import 'package:flutter/foundation.dart' show kIsWeb, defaultTargetPlatform;
import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import 'android_update_flow.dart';

/// Android-only app bar action: check for updates from a remote JSON manifest, download APK with progress, open installer.
class AndroidAppUpdateButton extends StatelessWidget {
  const AndroidAppUpdateButton({super.key});

  static bool get isSupported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  @override
  Widget build(BuildContext context) {
    if (!isSupported) return const SizedBox.shrink();

    final l10n = AppLocalizations.of(context);
    final width = MediaQuery.sizeOf(context).width;
    final shortest = MediaQuery.sizeOf(context).shortestSide;
    final compact = shortest < 360 || width < 340;
    final iconSize = compact ? 22.0 : 24.0;

    return IconButton(
      icon: Icon(Icons.system_update, size: iconSize),
      tooltip: l10n.checkForUpdate,
      visualDensity: compact ? VisualDensity.compact : VisualDensity.standard,
      padding: EdgeInsets.symmetric(horizontal: compact ? 4 : 8),
      constraints: BoxConstraints(
        minWidth: compact ? 36 : 40,
        minHeight: compact ? 36 : 40,
      ),
      onPressed: () => runAndroidUpdateCheck(context, userInitiated: true),
    );
  }
}
