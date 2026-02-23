import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../l10n/app_localizations.dart';
import '../../models/patient_profile_model.dart';

/// Opens document in-app: image in a dialog with zoom; PDF in an in-app WebView (with fallback to external app on older platforms).
void showDocumentViewer(BuildContext context, PatientDocumentModel doc) {
  final url = doc.filePathOrUrl.trim();
  if (url.isEmpty) return;
  final l10n = AppLocalizations.of(context);
  if (doc.documentType == DocumentType.image) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        content: SingleChildScrollView(
          child: InteractiveViewer(
            minScale: 0.5,
            maxScale: 4.0,
            child: Image.network(
              url,
              fit: BoxFit.contain,
              loadingBuilder: (_, child, loadingProgress) {
                if (loadingProgress == null) return child;
                return SizedBox(
                  height: 200,
                  child: Center(
                    child: CircularProgressIndicator(
                      value: loadingProgress.expectedTotalBytes != null
                          ? loadingProgress.cumulativeBytesLoaded / (loadingProgress.expectedTotalBytes ?? 1)
                          : null,
                    ),
                  ),
                );
              },
              errorBuilder: (_, __, ___) => Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.broken_image, size: 48),
                  const SizedBox(height: 8),
                  Text(l10n.viewImage),
                  TextButton(
                    onPressed: () => _openUrl(context, url),
                    child: Text(l10n.openLink),
                  ),
                ],
              ),
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(l10n.cancel)),
        ],
      ),
    );
  } else if (doc.documentType == DocumentType.pdf) {
    _openPdfInApp(context, url, l10n);
  }
}

/// Tries in-app WebView first for PDF (Android/iOS), then falls back to external app for older versions.
Future<void> _openPdfInApp(BuildContext context, String url, AppLocalizations l10n) async {
  final uri = Uri.parse(url);
  try {
    final launched = await launchUrl(uri, mode: LaunchMode.inAppWebView);
    if (!launched && context.mounted) {
      final fallback = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!fallback && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.openLink)));
      }
    }
  } catch (_) {
    try {
      final external = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!external && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.openLink)));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${l10n.openLink}: $e')));
      }
    }
  }
}

Future<void> _openUrl(BuildContext context, String url) async {
  final uri = Uri.parse(url);
  try {
    await launchUrl(uri, mode: LaunchMode.inAppWebView);
  } catch (_) {
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}
