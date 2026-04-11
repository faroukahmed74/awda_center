import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb, defaultTargetPlatform;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../l10n/app_localizations.dart';
import '../services/app_update_export.dart';

bool _autoUpdateDialogShownThisSession = false;

/// Clears the “already shown this session” flag (e.g. after tests). Normal apps don’t need this.
void debugResetAndroidAutoUpdateSession() {
  _autoUpdateDialogShownThisSession = false;
}

/// Fetches the manifest and shows the update dialog only when a newer (or required) build exists.
///
/// [userInitiated]: `true` = user tapped the app-bar icon (shows loading; snackbars only for
/// misconfiguration or network failure). `false` = automatic check (fully silent unless an update exists).
Future<void> runAndroidUpdateCheck(
  BuildContext context, {
  required bool userInitiated,
}) async {
  if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;

  if (!userInitiated) {
    if (_autoUpdateDialogShownThisSession) return;
  }

  final messenger = ScaffoldMessenger.maybeOf(context);

  Future<void> closeLoading() async {
    if (userInitiated && context.mounted) {
      Navigator.of(context, rootNavigator: true).pop();
    }
  }

  if (userInitiated) {
    final l10n = AppLocalizations.of(context);
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => PopScope(
        canPop: false,
        child: AlertDialog(
          content: Row(
            children: [
              const CircularProgressIndicator(),
              const SizedBox(width: 20),
              Expanded(child: Text(l10n.checkForUpdate)),
            ],
          ),
        ),
      ),
    );
  }

  AndroidUpdateCheckResult? check;
  try {
    check = await checkAndroidAppUpdate();
  } finally {
    await closeLoading();
  }

  if (!context.mounted) return;

  if (check == null) {
    if (userInitiated) {
      messenger?.showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context).updateNotConfigured)),
      );
    }
    return;
  }

  if (check.remote == null) {
    if (userInitiated) {
      messenger?.showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context).updateCheckFailed)),
      );
    }
    return;
  }

  if (!check.needsInstallPrompt) {
    // Same build (or newer already installed): no modal, no snackbar.
    return;
  }

  final pending = check;

  if (!userInitiated) {
    _autoUpdateDialogShownThisSession = true;
  }

  final force = pending.isBelowMinimum;
  await showDialog<void>(
    context: context,
    barrierDismissible: !force,
    builder: (ctx) => AndroidUpdateDialogContent(check: pending, force: force),
  );
}

/// Dialog body shared by app-bar check and auto dashboard prompt.
class AndroidUpdateDialogContent extends StatefulWidget {
  const AndroidUpdateDialogContent({
    super.key,
    required this.check,
    required this.force,
  });

  final AndroidUpdateCheckResult check;
  final bool force;

  @override
  State<AndroidUpdateDialogContent> createState() => _AndroidUpdateDialogContentState();
}

class _AndroidUpdateDialogContentState extends State<AndroidUpdateDialogContent> {
  bool _downloading = false;
  double _progress = 0;
  String? _error;

  Future<void> _download() async {
    final url = widget.check.remote?.apkUrl;
    if (url == null || url.isEmpty) return;

    setState(() {
      _downloading = true;
      _error = null;
      _progress = 0;
    });

    final path = await downloadAndroidApk(
      url,
      onProgress: (p) {
        if (mounted) setState(() => _progress = p);
      },
    );

    if (!mounted) return;

    if (path == null) {
      setState(() {
        _downloading = false;
        _error = AppLocalizations.of(context).updateDownloadFailed;
      });
      return;
    }

    Navigator.of(context, rootNavigator: true).pop();

    // After the route is gone, open the package installer (system UI).
    SchedulerBinding.instance.addPostFrameCallback((_) {
      unawaited(openAndroidApk(path));
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final r = widget.check.remote!;
    final scrollable = MediaQuery.sizeOf(context).height < 520;

    final body = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.force) ...[
          Text(l10n.updateRequiredBody, style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 12),
        ],
        Text(
          l10n.updateVersionCurrent(
            widget.check.currentVersionName,
            widget.check.currentVersionCode,
          ),
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 4),
        Text(
          l10n.updateVersionNew(r.versionName, r.versionCode),
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: Theme.of(context).colorScheme.primary,
              ),
        ),
        if (r.releaseNotes != null) ...[
          const SizedBox(height: 12),
          Text(l10n.updateReleaseNotes, style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 4),
          Text(r.releaseNotes!, style: Theme.of(context).textTheme.bodySmall),
        ],
        if (_downloading) ...[
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(value: _progress > 0 ? _progress : null),
          ),
          const SizedBox(height: 8),
          Text(
            l10n.updateDownloadingPercent(
              (_progress * 100).clamp(0, 100).round(),
            ),
            style: Theme.of(context).textTheme.bodySmall,
            textAlign: TextAlign.center,
          ),
        ],
        if (_error != null) ...[
          const SizedBox(height: 8),
          Text(
            _error!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ],
      ],
    );

    return AlertDialog(
      title: Text(widget.force ? l10n.updateRequiredTitle : l10n.updateAvailable),
      content: scrollable
          ? SizedBox(
              width: double.maxFinite,
              child: SingleChildScrollView(child: body),
            )
          : body,
      actions: [
        if (!widget.force && !_downloading)
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(l10n.cancel),
          ),
        FilledButton(
          onPressed: _downloading ? null : _download,
          child: Text(l10n.updateDownload),
        ),
      ],
    );
  }
}
