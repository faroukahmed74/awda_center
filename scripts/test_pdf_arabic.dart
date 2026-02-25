// Run from project root: dart run scripts/test_pdf_arabic.dart
// Tests that PDF export renders Arabic using Amiri font (no Flutter required).

import 'dart:io';
import 'dart:typed_data';

import 'package:pdf/widgets.dart' as pw;

void main() async {
  final fontPath = 'assets/fonts/Amiri-Regular.ttf';
  final fontFile = File(fontPath);
  if (!fontFile.existsSync()) {
    print('ERROR: Font not found at $fontPath (run from project root)');
    exit(1);
  }

  final bytes = await fontFile.readAsBytes();
  final fontData = ByteData.sublistView(bytes);
  final baseFont = pw.Font.ttf(fontData);
  final theme = pw.ThemeData.withFont(base: baseFont, fontFallback: [baseFont]);
  final doc = pw.Document(theme: theme);

  // Sample Arabic text (e.g. "Ahmed Mohamed" in Arabic, and a short phrase)
  const arabicSample = 'أحمد محمد سامير'; // Example names
  const arabicPhrase = 'تقرير المستخدمين';

  doc.addPage(
    pw.MultiPage(
      build: (context) => [
        pw.Text('Users summary (test)', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 8),
        pw.Text('Total: 5 Users'),
        pw.SizedBox(height: 8),
        pw.Table(
          border: pw.TableBorder.all(),
          columnWidths: {0: const pw.FlexColumnWidth(3), 1: const pw.FlexColumnWidth(2), 2: const pw.FlexColumnWidth(1)},
          children: [
            pw.TableRow(
              children: [
                pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text('Full name (English)', style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
                pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text('Email')),
                pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text('Role')),
              ],
            ),
            pw.TableRow(
              children: [
                pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text(arabicSample, textDirection: pw.TextDirection.rtl, textAlign: pw.TextAlign.right)),
                pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text('secretary@awda.com')),
                pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text('secretary')),
              ],
            ),
            pw.TableRow(
              children: [
                pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text(arabicPhrase, textDirection: pw.TextDirection.rtl, textAlign: pw.TextAlign.right)),
                pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text('test@awda.com')),
                pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text('patient')),
              ],
            ),
          ],
        ),
      ],
    ),
  );

  final outPath = 'test_arabic.pdf';
  final outFile = File(outPath);
  final pdfBytes = await doc.save();
  await outFile.writeAsBytes(pdfBytes);
  print('OK: Wrote $outPath (${pdfBytes.length} bytes). Open it to verify Arabic renders (not boxes).');
}
