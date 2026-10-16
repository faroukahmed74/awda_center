import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../core/app_logo.dart';
import '../../core/arabic_pdf_reshaper.dart';
import '../../core/date_format.dart';
import '../../l10n/app_localizations.dart';
import '../../models/package_model.dart';
import '../../models/patient_profile_model.dart';
import '../../models/user_model.dart';
import '../../widgets/medical/medical_rich_text_html.dart';

/// One package cycle line under the sessions table.
class PatientReportPackageProgress {
  final String name;
  final int completed;
  final int total;

  const PatientReportPackageProgress({
    required this.name,
    required this.completed,
    required this.total,
  });

  factory PatientReportPackageProgress.fromPackage({
    required PackageModel pkg,
    required int completed,
    required int total,
  }) {
    return PatientReportPackageProgress(
      name: pkg.displayName,
      completed: completed,
      total: total,
    );
  }
}

/// One row for the sessions table (sessions collection or appointment).
class PatientReportSessionRow {
  final DateTime date;
  final String startTime;
  final String endTime;
  final String? service;
  final String? statusLabel;
  /// Raw payment status: paid / partial_paid / prepaid / not_paid.
  final String? paymentStatusKey;
  /// Income amount linked to this session (null when unknown).
  final double? paymentAmount;

  PatientReportSessionRow({
    required this.date,
    required this.startTime,
    required this.endTime,
    this.service,
    this.statusLabel,
    this.paymentStatusKey,
    this.paymentAmount,
  });
}

bool _hasPdfText(String? value) =>
    value != null && value.trim().isNotEmpty;

/// Keep session tables small enough for MultiPage.
const int _pdfTableChunkSize = 22;

const _patientReportArabicRegularFontPaths = [
  'assets/fonts/Cairo-Regular.ttf',
  'assets/fonts/Amiri-Regular.ttf',
];

const _patientReportArabicBoldFontPaths = [
  'assets/fonts/Cairo-Bold.ttf',
  'assets/fonts/Cairo-Regular.ttf',
  'assets/fonts/Amiri-Regular.ttf',
];

class _PdfFontBundle {
  final pw.Font? regular;
  final pw.Font? bold;
  /// Extra fonts covering Arabic presentation forms Cairo may miss (e.g. U+FEF1 ي).
  final List<pw.Font> fallback;
  final pw.ThemeData? theme;

  const _PdfFontBundle({
    required this.regular,
    required this.bold,
    required this.fallback,
    required this.theme,
  });
}

Future<pw.Font?> _tryLoadPdfFont(List<String> paths) async {
  for (final path in paths) {
    try {
      final raw = await rootBundle.load(path);
      final byteData = raw.buffer.asByteData(
        raw.offsetInBytes,
        raw.lengthInBytes,
      );
      final font = pw.Font.ttf(byteData);
      debugPrint('PDF font loaded successfully: $path');
      return font;
    } catch (e, s) {
      debugPrint('Failed to load PDF font: $path');
      debugPrint('$e');
      debugPrint('$s');
    }
  }
  return null;
}

/// Fonts that include Arabic Presentation Forms-A (isolated ي U+FEF1, etc.).
/// Do not use NotoSansArabic here — pdf's TtfParser throws
/// `FormatException: Unfinished UTF-8 octet sequence` on that file.
const _patientReportPresentationFallbackPaths = [
  'assets/fonts/Amiri-Regular.ttf',
];

Future<_PdfFontBundle> _loadPdfFonts() async {
  final regular = await _tryLoadPdfFont(_patientReportArabicRegularFontPaths);
  final bold = await _tryLoadPdfFont(_patientReportArabicBoldFontPaths);

  if (regular == null) {
    debugPrint(
      'No Arabic PDF font could be loaded. Arabic text may appear as squares.',
    );
    return const _PdfFontBundle(
      regular: null,
      bold: null,
      fallback: [],
      theme: null,
    );
  }

  final fallback = <pw.Font>[];
  for (final path in _patientReportPresentationFallbackPaths) {
    final font = await _tryLoadPdfFont([path]);
    if (font != null) fallback.add(font);
  }

  final theme = pw.ThemeData.withFont(
    base: regular,
    bold: bold ?? regular,
    italic: regular,
    boldItalic: bold ?? regular,
    fontFallback: fallback.isEmpty ? [regular] : fallback,
  );

  return _PdfFontBundle(
    regular: regular,
    bold: bold ?? regular,
    fallback: fallback,
    theme: theme,
  );
}

String _plainDiagnosis(String? value) {
  if (!_hasPdfText(value)) return '—';
  final raw = value!.trim();
  if (MedicalRichTextHtml.isLikelyHtml(raw) ||
      MedicalRichTextHtml.isDeltaJson(raw)) {
    final plain = MedicalRichTextHtml.htmlToPlainText(raw).trim();
    return plain.isEmpty ? '—' : plain;
  }
  return raw;
}

/// Display text for the Session payment column.
String patientReportSessionPaymentLabel(
  PatientReportSessionRow row,
  AppLocalizations l10n,
  NumberFormat amountFormat,
) {
  final key = row.paymentStatusKey?.trim();
  if (key == 'prepaid') return l10n.prepaid;
  if (row.paymentAmount != null && row.paymentAmount!.isFinite) {
    return amountFormat.format(row.paymentAmount).trim();
  }
  if (key == 'not_paid') return l10n.notPaid;
  if (key == 'partial_paid') return l10n.partialPaid;
  if (key == 'paid') return l10n.paid;
  return '—';
}

/// Sum amounts that count toward Total (excludes prepaid).
double patientReportPaymentTotal(List<PatientReportSessionRow> rows) {
  var sum = 0.0;
  for (final r in rows) {
    if (r.paymentStatusKey == 'prepaid') continue;
    final a = r.paymentAmount;
    if (a != null && a.isFinite) sum += a;
  }
  return sum;
}

Future<pw.ImageProvider?> _loadReportLogo() async {
  const candidates = [
    'assets/CenterLogo.png',
    kAppLogoLightAsset,
    'assets/AppLogo.png',
  ];
  for (final path in candidates) {
    try {
      final data = await rootBundle.load(path);
      return pw.MemoryImage(data.buffer.asUint8List());
    } catch (_) {
      // try next
    }
  }
  return null;
}

/// Compact patient report: centered logo + name, NAME/DATE/DIAGNOSIS header,
/// sessions table with Session payment + Total. Sessions should be oldest→newest.
Future<List<int>> buildPatientReportPdf({
  required UserModel user,
  required PatientProfileModel? profile,
  required List<PatientReportSessionRow> sessionRows,
  required AppLocalizations l10n,
  required String centerName,
  String currency = 'EGP',
  List<PatientReportPackageProgress> packageProgress = const [],
}) async {
  final fonts = await _loadPdfFonts();
  final arabicFont = fonts.regular;
  final arabicBoldFont = fonts.bold;
  final fontFallback = fonts.fallback;
  final isArabic = l10n.isArabic;
  final logo = await _loadReportLogo();

  final doc = pw.Document(theme: fonts.theme);
  final nf = NumberFormat.currency(symbol: '', decimalDigits: 2);
  final headerBg = PdfColor.fromInt(0xFFE3F2FD);
  final headerText = PdfColors.blue900;
  final totalBlue = PdfColors.blue800;

  bool hasArabic(String text) => ArabicPdfReshaper.hasArabic(text);

  String shape(String text) {
    if (text.isEmpty) return text;
    if (hasArabic(text)) return ArabicPdfReshaper.reshape(text);
    return text;
  }

  pw.TextDirection dirForText(String text) {
    return hasArabic(text) ? pw.TextDirection.rtl : pw.TextDirection.ltr;
  }

  final pageDir = isArabic ? pw.TextDirection.rtl : pw.TextDirection.ltr;

  pw.TextStyle textStyle({
    double fontSize = 10,
    bool bold = false,
    PdfColor? color,
  }) {
    return pw.TextStyle(
      fontSize: fontSize,
      fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
      color: color,
      font: bold ? (arabicBoldFont ?? arabicFont) : arabicFont,
      // Cairo lacks some presentation glyphs (isolated ي U+FEF1 in "هويدا").
      fontFallback: fontFallback,
    );
  }

  pw.Widget plainText(
    String text, {
    double fontSize = 10,
    bool bold = false,
    PdfColor? color,
    pw.TextDirection? textDirection,
    pw.TextAlign? textAlign,
  }) {
    return pw.Text(
      shape(text),
      textDirection: textDirection ?? dirForText(text),
      textAlign: textAlign,
      style: textStyle(fontSize: fontSize, bold: bold, color: color),
    );
  }

  pw.Widget headerCell(String text) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(6),
      color: headerBg,
      child: plainText(
        text,
        fontSize: 10,
        bold: true,
        color: headerText,
        textDirection: dirForText(text),
      ),
    );
  }

  pw.Widget cell(
    String text, {
    bool bold = false,
    bool alternate = false,
    PdfColor? color,
    pw.TextDirection? textDirection,
    pw.TextAlign? textAlign,
  }) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      color: alternate ? PdfColor.fromInt(0xFFF5F5F5) : null,
      child: plainText(
        text,
        fontSize: 9,
        bold: bold,
        color: color,
        textDirection: textDirection ?? dirForText(text),
        textAlign: textAlign,
      ),
    );
  }

  pw.Widget infoLabel(String text) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 8),
      alignment: pw.Alignment.centerLeft,
      child: plainText(
        text.toUpperCase(),
        fontSize: 10,
        bold: true,
        textDirection: dirForText(text),
      ),
    );
  }

  pw.Widget infoValue(String text) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 8),
      alignment: pw.Alignment.centerLeft,
      child: plainText(
        text,
        fontSize: 10,
        textDirection: dirForText(text),
      ),
    );
  }

  final patientName = user.displayName.trim().isEmpty ? '—' : user.displayName.trim();
  final reportDate = AppDateFormat.shortDate.format(DateTime.now());
  final diagnosis = _plainDiagnosis(profile?.diagnosis);
  final paymentTotal = patientReportPaymentTotal(sessionRows);
  final totalLabel =
      '${nf.format(paymentTotal).trim()} ${currency.trim().isEmpty ? 'EGP' : currency.trim()}';
  final sessionsTitle = '${l10n.sessions} & ${l10n.amountPaid}';

  final content = <pw.Widget>[
    pw.Center(
      child: pw.Column(
        mainAxisSize: pw.MainAxisSize.min,
        children: [
          if (logo != null) ...[
            pw.Image(logo, width: 120, height: 120, fit: pw.BoxFit.contain),
            pw.SizedBox(height: 8),
          ],
          plainText(
            centerName,
            fontSize: 18,
            bold: true,
            textDirection: dirForText(centerName),
            textAlign: pw.TextAlign.center,
          ),
        ],
      ),
    ),
    pw.SizedBox(height: 16),
    pw.Table(
      border: pw.TableBorder.all(color: PdfColors.black, width: 0.8),
      columnWidths: const {
        0: pw.FlexColumnWidth(1.2),
        1: pw.FlexColumnWidth(2.6),
        2: pw.FlexColumnWidth(1.0),
        3: pw.FlexColumnWidth(1.8),
      },
      children: [
        pw.TableRow(
          children: [
            infoLabel(l10n.name),
            infoValue(patientName),
            infoLabel(l10n.date),
            infoValue(reportDate),
          ],
        ),
      ],
    ),
    pw.Table(
      border: pw.TableBorder.all(color: PdfColors.black, width: 0.8),
      columnWidths: const {
        0: pw.FlexColumnWidth(1.2),
        1: pw.FlexColumnWidth(5.4),
      },
      children: [
        pw.TableRow(
          children: [
            infoLabel(l10n.diagnosis),
            infoValue(diagnosis),
          ],
        ),
      ],
    ),
    pw.SizedBox(height: 16),
    plainText(
      sessionsTitle,
      fontSize: 12,
      bold: true,
      textDirection: pageDir,
    ),
    pw.SizedBox(height: 8),
  ];

  if (sessionRows.isEmpty) {
    content.add(
      plainText(l10n.noData, fontSize: 10, textDirection: pageDir),
    );
  } else {
    for (var start = 0;
        start < sessionRows.length;
        start += _pdfTableChunkSize) {
      final end = (start + _pdfTableChunkSize > sessionRows.length)
          ? sessionRows.length
          : start + _pdfTableChunkSize;
      final chunk = sessionRows.sublist(start, end);
      final isLastChunk = end >= sessionRows.length;

      content.add(
        pw.Table(
          border: pw.TableBorder.all(color: PdfColors.grey400),
          columnWidths: const {
            0: pw.FlexColumnWidth(1.5),
            1: pw.FlexColumnWidth(1.1),
            2: pw.FlexColumnWidth(2.0),
            3: pw.FlexColumnWidth(1.0),
            4: pw.FlexColumnWidth(1.2),
          },
          children: [
            if (start == 0)
              pw.TableRow(
                children: [
                  headerCell(l10n.date),
                  headerCell(l10n.time),
                  headerCell(l10n.services),
                  headerCell(l10n.status),
                  headerCell(l10n.sessionPayment),
                ],
              ),
            ...chunk.asMap().entries.map((entry) {
              final i = start + entry.key;
              final r = entry.value;
              final serviceStr =
                  _hasPdfText(r.service) ? r.service!.trim() : '—';
              final statusStr =
                  _hasPdfText(r.statusLabel) ? r.statusLabel!.trim() : '—';
              final paymentStr =
                  patientReportSessionPaymentLabel(r, l10n, nf);

              return pw.TableRow(
                children: [
                  cell(
                    AppDateFormat.shortDateWithWeekday(
                      r.date,
                      locale: isArabic ? 'ar' : 'en',
                    ),
                    alternate: i.isOdd,
                    textDirection: isArabic
                        ? pw.TextDirection.rtl
                        : pw.TextDirection.ltr,
                  ),
                  cell(
                    '${r.startTime}–${r.endTime}',
                    alternate: i.isOdd,
                    textDirection: pw.TextDirection.ltr,
                  ),
                  cell(
                    serviceStr,
                    alternate: i.isOdd,
                    textDirection: dirForText(serviceStr),
                  ),
                  cell(
                    statusStr,
                    alternate: i.isOdd,
                    textDirection: dirForText(statusStr),
                  ),
                  cell(
                    paymentStr,
                    alternate: i.isOdd,
                    textDirection: dirForText(paymentStr),
                  ),
                ],
              );
            }),
          ],
        ),
      );
      if (!isLastChunk) {
        content.add(pw.SizedBox(height: 6));
      } else {
        content.add(
          pw.Table(
            border: pw.TableBorder.all(color: PdfColors.grey400),
            columnWidths: const {
              0: pw.FlexColumnWidth(5.6),
              1: pw.FlexColumnWidth(1.2),
            },
            children: [
              pw.TableRow(
                children: [
                  pw.Container(
                    padding: const pw.EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 6,
                    ),
                    alignment: pw.Alignment.center,
                    child: plainText(
                      l10n.total,
                      fontSize: 10,
                      bold: true,
                      color: totalBlue,
                      textAlign: pw.TextAlign.center,
                      textDirection: pageDir,
                    ),
                  ),
                  cell(
                    totalLabel,
                    bold: true,
                    textDirection: pw.TextDirection.ltr,
                    textAlign: pw.TextAlign.right,
                  ),
                ],
              ),
            ],
          ),
        );
      }
    }
  }

  if (packageProgress.isNotEmpty) {
    content.add(pw.SizedBox(height: 14));
    content.add(
      plainText(
        l10n.packages,
        fontSize: 12,
        bold: true,
        textDirection: pageDir,
      ),
    );
    content.add(pw.SizedBox(height: 6));
    for (final p in packageProgress) {
      final name = p.name.trim().isEmpty ? '—' : p.name.trim();
      final progress = '${p.completed} / ${p.total}';
      content.add(
        pw.Padding(
          padding: const pw.EdgeInsets.only(bottom: 4),
          child: pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Expanded(
                child: plainText(
                  name,
                  fontSize: 10,
                  textDirection: dirForText(name),
                ),
              ),
              pw.SizedBox(width: 8),
              plainText(
                progress,
                fontSize: 10,
                bold: true,
                textDirection: pw.TextDirection.ltr,
              ),
              pw.SizedBox(width: 6),
              plainText(
                l10n.sessions,
                fontSize: 10,
                textDirection: pageDir,
              ),
            ],
          ),
        ),
      );
    }
  }

  doc.addPage(
    pw.MultiPage(
      maxPages: 200,
      pageTheme: pw.PageTheme(
        margin: const pw.EdgeInsets.all(24),
        textDirection: pageDir,
      ),
      build: (context) => content,
    ),
  );

  return doc.save();
}
