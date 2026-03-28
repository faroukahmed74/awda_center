import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import '../../core/date_format.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../l10n/app_localizations.dart';
import '../reports/report_pdf_share.dart';

/// One chart snapshot for a combined admin statistics PDF.
class AdminDashboardReportSection {
  final String title;
  final List<int> imageBytes;

  const AdminDashboardReportSection({required this.title, required this.imageBytes});
}

/// Exports admin dashboard charts as PDF using Cairo fonts from assets.
class AdminDashboardPdf {
  static const _cairoRegular = 'assets/fonts/Cairo-Regular.ttf';
  static const _cairoBold = 'assets/fonts/Cairo-Bold.ttf';

  static const double _pageMarginPt = 24;
  static const PdfColor _metaColor = PdfColors.grey800;

  /// Share sheet anchor for iOS/iPad (was `null` and broke mobile share).
  static Rect _shareOrigin(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    if (size.width <= 0 || size.height <= 0) {
      return const Rect.fromLTWH(0, 0, 100, 100);
    }
    return Rect.fromLTWH(0, 0, size.width, size.height * 0.5);
  }

  static Future<pw.Font?> _loadFont(String path) async {
    try {
      final data = await rootBundle.load(path);
      final bytes = data.buffer.asByteData(data.offsetInBytes, data.lengthInBytes);
      return pw.Font.ttf(bytes);
    } catch (_) {
      return null;
    }
  }

  static Future<pw.ThemeData> _pdfTheme() async {
    pw.Font? font = await _loadFont(_cairoRegular);
    pw.Font? fontBold = await _loadFont(_cairoBold);
    font ??= pw.Font.helvetica();
    fontBold ??= font;
    return pw.ThemeData.withFont(
      base: font,
      bold: fontBold,
      italic: font,
      boldItalic: fontBold,
    );
  }

  static pw.Widget _fullReportHeader({
    required AppLocalizations l10n,
    required String title,
    required String rangeLabel,
    required String now,
  }) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        pw.Header(
          level: 0,
          child: pw.Text(
            title,
            style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold),
          ),
        ),
        pw.SizedBox(height: 8),
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Expanded(
              child: pw.Text(
                '${l10n.filterByPeriod}: $rangeLabel',
                style: const pw.TextStyle(fontSize: 11, color: _metaColor),
              ),
            ),
            pw.Text(
              '${l10n.date}: $now',
              style: const pw.TextStyle(fontSize: 11, color: _metaColor),
            ),
          ],
        ),
        pw.SizedBox(height: 12),
      ],
    );
  }

  /// Single chart: header + chart image fills the rest of the page.
  static Future<void> exportChartPdf({
    required BuildContext context,
    required AppLocalizations l10n,
    required String chartTitle,
    required String rangeLabel,
    required List<int> imageBytes,
  }) async {
    final shareOrigin = _shareOrigin(context);
    final theme = await _pdfTheme();
    final doc = pw.Document(theme: theme);
    final now = AppDateFormat.shortDateTime.format(DateTime.now());

    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(_pageMarginPt),
        build: (pw.Context ctx) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: [
              _fullReportHeader(l10n: l10n, title: chartTitle, rangeLabel: rangeLabel, now: now),
              pw.Expanded(
                child: pw.Center(
                  child: pw.Image(
                    pw.MemoryImage(Uint8List.fromList(imageBytes)),
                    fit: pw.BoxFit.contain,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );

    final bytes = await doc.save();
    final filename = 'admin_chart_${DateTime.now().millisecondsSinceEpoch}.pdf';
    await savePdfAndShare(filename, bytes, shareOrigin);
  }

  /// Combined report: two chart sections per page; chart area splits remaining space.
  /// A single section uses the full page under the header (same as [exportChartPdf] layout).
  static Future<void> exportCombinedReport({
    required BuildContext context,
    required AppLocalizations l10n,
    required String reportTitle,
    required String rangeLabel,
    required List<AdminDashboardReportSection> sections,
  }) async {
    if (sections.isEmpty) return;

    final shareOrigin = _shareOrigin(context);
    final theme = await _pdfTheme();
    final doc = pw.Document(theme: theme);
    final now = AppDateFormat.shortDateTime.format(DateTime.now());

    for (var pageIndex = 0; pageIndex < (sections.length + 1) ~/ 2; pageIndex++) {
      final start = pageIndex * 2;
      final chunk = sections.sublist(start, start + 2 > sections.length ? sections.length : start + 2);

      doc.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(_pageMarginPt),
          build: (pw.Context ctx) {
            final children = <pw.Widget>[];
            if (pageIndex == 0) {
              children.add(_fullReportHeader(l10n: l10n, title: reportTitle, rangeLabel: rangeLabel, now: now));
            }

            for (var i = 0; i < chunk.length; i++) {
              final s = chunk[i];
              children.add(
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                    children: [
                      pw.Text(
                        s.title,
                        style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
                      ),
                      pw.SizedBox(height: 6),
                      pw.Expanded(
                        child: pw.Center(
                          child: pw.Image(
                            pw.MemoryImage(Uint8List.fromList(s.imageBytes)),
                            fit: pw.BoxFit.contain,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
              if (i < chunk.length - 1) {
                children.add(pw.SizedBox(height: 14));
              }
            }

            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.stretch,
              children: children,
            );
          },
        ),
      );
    }

    final bytes = await doc.save();
    final filename = 'admin_statistics_report_${DateTime.now().millisecondsSinceEpoch}.pdf';
    await savePdfAndShare(filename, bytes, shareOrigin);
  }
}
