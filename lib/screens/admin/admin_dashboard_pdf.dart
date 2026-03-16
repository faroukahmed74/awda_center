import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../../l10n/app_localizations.dart';
import '../reports/report_pdf_share.dart';
import 'package:intl/intl.dart' hide TextDirection;

/// Exports a single admin dashboard chart as PDF using Cairo fonts from assets.
class AdminDashboardPdf {
  static const _cairoRegular = 'assets/fonts/Cairo-Regular.ttf';
  static const _cairoBold = 'assets/fonts/Cairo-Bold.ttf';

  static Future<pw.Font?> _loadFont(String path) async {
    try {
      final data = await rootBundle.load(path);
      final bytes = data.buffer.asByteData(data.offsetInBytes, data.lengthInBytes);
      return pw.Font.ttf(bytes);
    } catch (_) {
      return null;
    }
  }

  static Future<void> exportChartPdf({
    required BuildContext context,
    required AppLocalizations l10n,
    required String chartTitle,
    required String rangeLabel,
    required List<int> imageBytes,
  }) async {
    pw.Font? font = await _loadFont(_cairoRegular);
    pw.Font? fontBold = await _loadFont(_cairoBold);
    font ??= pw.Font.helvetica();
    fontBold ??= font;

    final theme = pw.ThemeData.withFont(
      base: font,
      bold: fontBold,
      italic: font,
      boldItalic: fontBold,
    );

    final doc = pw.Document(theme: theme);
    final now = DateFormat.yMd().add_Hm().format(DateTime.now());

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(24),
        build: (ctx) => [
          pw.Header(
            level: 0,
            child: pw.Text(
              chartTitle,
              style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
            ),
          ),
          pw.SizedBox(height: 8),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text('${l10n.filterByPeriod}: $rangeLabel', style: const pw.TextStyle(fontSize: 10)),
              pw.Text('${l10n.date}: $now', style: const pw.TextStyle(fontSize: 10)),
            ],
          ),
          pw.SizedBox(height: 16),
          pw.Center(
            child: pw.Image(
              pw.MemoryImage(Uint8List.fromList(imageBytes)),
              fit: pw.BoxFit.contain,
              width: 500,
              height: 320,
            ),
          ),
        ],
      ),
    );

    final bytes = await doc.save();
    final filename = 'admin_chart_${DateTime.now().millisecondsSinceEpoch}.pdf';
    await savePdfAndShare(filename, bytes, null);
  }
}
