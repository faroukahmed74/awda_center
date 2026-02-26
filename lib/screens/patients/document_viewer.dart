import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../l10n/app_localizations.dart';
import '../../models/patient_profile_model.dart';

/// Opens document in-app: image in full-screen with zoom; PDF in external app.
void showDocumentViewer(BuildContext context, PatientDocumentModel doc) {
  final url = doc.filePathOrUrl.trim();
  if (url.isEmpty) return;
  final l10n = AppLocalizations.of(context);
  if (doc.documentType == DocumentType.image) {
    Navigator.of(context).push(
      PageRouteBuilder(
        opaque: true,
        pageBuilder: (_, __, ___) => _FullScreenImageView(
          url: url,
          l10n: l10n,
          onClose: () => Navigator.of(context).pop(),
          onOpenInBrowser: () {
            Navigator.of(context).pop();
            _openUrl(context, url);
          },
        ),
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

class _FullScreenImageView extends StatelessWidget {
  const _FullScreenImageView({
    required this.url,
    required this.l10n,
    required this.onClose,
    required this.onOpenInBrowser,
  });

  final String url;
  final AppLocalizations l10n;
  final VoidCallback onClose;
  final VoidCallback onOpenInBrowser;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          InteractiveViewer(
            minScale: 0.5,
            maxScale: 5.0,
            child: Center(
              child: Image.network(
                url,
                fit: BoxFit.contain,
                loadingBuilder: (_, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(
                          value: loadingProgress.expectedTotalBytes != null
                              ? loadingProgress.cumulativeBytesLoaded /
                                  (loadingProgress.expectedTotalBytes ?? 1)
                              : null,
                        ),
                        const SizedBox(height: 12),
                        const Text('Loading…', style: TextStyle(color: Colors.white70)),
                      ],
                    ),
                  );
                },
                errorBuilder: (_, __, ___) => Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.broken_image, size: 64, color: Colors.white70),
                      const SizedBox(height: 16),
                      Text(l10n.viewImage, style: const TextStyle(color: Colors.white70)),
                      const SizedBox(height: 16),
                      FilledButton.icon(
                        icon: const Icon(Icons.open_in_browser, size: 20),
                        label: Text(l10n.openLink),
                        onPressed: onOpenInBrowser,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          SafeArea(
            child: Align(
              alignment: AlignmentDirectional.topEnd,
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: IconButton.filled(
                  icon: const Icon(Icons.close),
                  onPressed: onClose,
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.black54,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
