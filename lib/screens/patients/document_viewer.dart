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
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 200, maxWidth: 400),
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
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircularProgressIndicator(
                            value: loadingProgress.expectedTotalBytes != null
                                ? loadingProgress.cumulativeBytesLoaded / (loadingProgress.expectedTotalBytes ?? 1)
                                : null,
                          ),
                          const SizedBox(height: 12),
                          const Text('Loading…'),
                        ],
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
                    const SizedBox(height: 8),
                    FilledButton.icon(
                      icon: const Icon(Icons.open_in_browser, size: 20),
                      label: Text(l10n.openLink),
                      onPressed: () {
                        Navigator.pop(ctx);
                        _openUrl(context, url);
                      },
                    ),
                  ],
                ),
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

/// Opens PDF in external browser/app so it actually displays (in-app WebView often shows blank for PDFs).
Future<void> _openPdfInApp(BuildContext context, String url, AppLocalizations l10n) async {
  final uri = Uri.parse(url);
  try {
    // In-app WebView often shows a blank screen for PDFs (e.g. Firebase Storage). Open externally so the system viewer/browser shows the PDF.
    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched && context.mounted) {
      final inApp = await launchUrl(uri, mode: LaunchMode.inAppWebView);
      if (!inApp && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.openLink)));
      }
    }
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${l10n.openLink}: $e')));
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
