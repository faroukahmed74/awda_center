import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../core/arabic_pdf_reshaper.dart';
import '../../core/date_format.dart';
import '../../l10n/app_localizations.dart';
import '../../models/income_expense_models.dart';
import '../../models/package_model.dart';
import '../../models/patient_profile_model.dart';
import '../../models/user_model.dart';
import '../../widgets/medical/medical_rich_text_html.dart';

/// One row for sessions section (from sessions collection or appointment).
class PatientReportSessionRow {
  final DateTime date;
  final String startTime;
  final String endTime;
  final String? service;
  final String? statusLabel;
  final String? paymentStatusLabel;
  /// Optional "Doctor: … / Performing: …" line from the UI.
  final String? doctorLabel;

  PatientReportSessionRow({
    required this.date,
    required this.startTime,
    required this.endTime,
    this.service,
    this.statusLabel,
    this.paymentStatusLabel,
    this.doctorLabel,
  });
}

bool _hasPdfText(String? value) =>
    value != null && value.trim().isNotEmpty;

/// Keep session/payment tables small enough to fit on a page.
/// A single tall [pw.Table] inside MultiPage frequently aborts on iOS (SIGABRT)
/// for patients with many sessions.
const int _pdfTableChunkSize = 18;

/// Soft cap for long medical rich-text fields in the PDF.
const int _maxMedicalFieldChars = 8000;

/// Max characters per MultiPage child. A single [pw.Row]/[pw.RichText] taller
/// than the page throws: "Widget won't fit into the page".
const int _maxPdfBlockChars = 900;

/// Use a modern Arabic font first.
/// Make sure these files really exist in assets and are declared in pubspec.yaml.
const _patientReportArabicRegularFontPaths = [
  'assets/fonts/Cairo-Regular.ttf',
  'assets/fonts/NotoSansArabic-Regular.ttf',
  'assets/fonts/Amiri-Regular.ttf',
];

const _patientReportArabicBoldFontPaths = [
  'assets/fonts/Cairo-Bold.ttf',
  'assets/fonts/Cairo-Regular.ttf',
  'assets/fonts/NotoSansArabic-Regular.ttf',
  'assets/fonts/Amiri-Regular.ttf',
];

class _PdfFontBundle {
  final pw.Font? regular;
  final pw.Font? bold;
  final pw.ThemeData? theme;

  const _PdfFontBundle({
    required this.regular,
    required this.bold,
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
      theme: null,
    );
  }

  final theme = pw.ThemeData.withFont(
    base: regular,
    bold: bold ?? regular,
    italic: regular,
    boldItalic: bold ?? regular,
    fontFallback: [regular],
  );

  return _PdfFontBundle(
    regular: regular,
    bold: bold ?? regular,
    theme: theme,
  );
}

String _plainMedicalText(String value) {
  if (MedicalRichTextHtml.isLikelyHtml(value) ||
      MedicalRichTextHtml.isDeltaJson(value)) {
    return MedicalRichTextHtml.htmlToPlainText(value);
  }
  return value;
}

String _truncateForPdf(String value) {
  final plain = _plainMedicalText(value);
  if (plain.length <= _maxMedicalFieldChars) return plain;
  return '${plain.substring(0, _maxMedicalFieldChars)}…';
}

/// Split long plain text into page-safe blocks for [pw.MultiPage].
List<String> _chunkTextForPdfPage(String plain) {
  final normalized = plain.replaceAll('\r\n', '\n').trim();
  if (normalized.isEmpty) return const [];
  if (normalized.length <= _maxPdfBlockChars) return [normalized];

  final chunks = <String>[];
  final paragraphs = normalized.split(RegExp(r'\n+'));
  final buf = StringBuffer();

  void flush() {
    final s = buf.toString().trim();
    if (s.isNotEmpty) chunks.add(s);
    buf.clear();
  }

  for (final para in paragraphs) {
    final piece = para.trim();
    if (piece.isEmpty) continue;
    if (piece.length > _maxPdfBlockChars) {
      flush();
      for (var i = 0; i < piece.length; i += _maxPdfBlockChars) {
        final end = (i + _maxPdfBlockChars < piece.length)
            ? i + _maxPdfBlockChars
            : piece.length;
        chunks.add(piece.substring(i, end).trim());
      }
      continue;
    }
    final nextLen = buf.length + (buf.isEmpty ? 0 : 1) + piece.length;
    if (buf.isNotEmpty && nextLen > _maxPdfBlockChars) {
      flush();
    }
    if (buf.isNotEmpty) buf.writeln();
    buf.write(piece);
  }
  flush();
  return chunks.isEmpty ? [normalized.substring(0, _maxPdfBlockChars)] : chunks;
}

/// Builds a PDF report for the patient: personal data, medical details, sessions, payments, packages.
/// [centerName] is the app/center title (e.g. from l10n.appTitle).
Future<List<int>> buildPatientReportPdf({
  required UserModel user,
  required PatientProfileModel? profile,
  required List<PatientReportSessionRow> sessionRows,
  required List<IncomeRecordModel> incomeForPatient,
  required List<({PackageModel pkg, int completed, int total})> packageProgress,
  required AppLocalizations l10n,
  required String centerName,
  /// Resolved display name for [PatientProfileModel.followedByDoctorId], if any.
  String? followedByDoctorName,
}) async {
  final fonts = await _loadPdfFonts();
  final arabicFont = fonts.regular;
  final arabicBoldFont = fonts.bold;
  final isArabic = l10n.isArabic;

  final doc = pw.Document(theme: fonts.theme);

  final nf = NumberFormat.currency(symbol: '', decimalDigits: 2);
  final headerBg = PdfColor.fromInt(0xFFE3F2FD);
  final headerText = PdfColors.blue900;
  final sectionBg = PdfColor.fromInt(0xFFE8F5E9);

  bool hasArabic(String text) => ArabicPdfReshaper.hasArabic(text);

  String shape(String text) {
    if (text.isEmpty) return text;
    if (hasArabic(text)) {
      return ArabicPdfReshaper.reshape(text);
    }
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
    final shaped = shape(text);
    return pw.Text(
      shaped,
      textDirection: textDirection ?? dirForText(text),
      textAlign: textAlign,
      style: textStyle(
        fontSize: fontSize,
        bold: bold,
        color: color,
      ),
    );
  }

  pw.Widget sectionTitle(String text) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 8),
      color: sectionBg,
      child: plainText(
        text,
        fontSize: 12,
        bold: true,
        textDirection: pageDir,
      ),
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
        textDirection: textDirection ?? dirForText(text),
        textAlign: textAlign,
      ),
    );
  }

  /// Short fields — single row when short enough for one page.
  pw.Widget bulletItem(String label, String value) {
    final plainValue = _truncateForPdf(value);
    final labelText = shape(label);
    final valueText = shape(plainValue);

    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 4),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          plainText('•', fontSize: 10),
          pw.SizedBox(width: 4),
          pw.Expanded(
            child: pw.RichText(
              textDirection:
                  hasArabic('$label $plainValue')
                      ? pw.TextDirection.rtl
                      : pw.TextDirection.ltr,
              text: pw.TextSpan(
                children: [
                  pw.TextSpan(
                    text: '$labelText: ',
                    style: textStyle(fontSize: 10, bold: true),
                  ),
                  pw.TextSpan(
                    text: valueText,
                    style: textStyle(fontSize: 10),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Long fields: multiple MultiPage-safe children (paginates for huge treatment plans).
  List<pw.Widget> labeledFieldBlocks(String label, String value) {
    final plainValue = _truncateForPdf(value);
    final chunks = _chunkTextForPdfPage(plainValue);
    if (chunks.isEmpty) return const [];

    final out = <pw.Widget>[
      pw.Padding(
        padding: const pw.EdgeInsets.only(top: 4, bottom: 2),
        child: plainText(
          '• $label:',
          fontSize: 10,
          bold: true,
          textDirection: dirForText(label),
        ),
      ),
    ];
    for (final chunk in chunks) {
      out.add(
        pw.Padding(
          padding: const pw.EdgeInsets.only(bottom: 6, left: 10, right: 4),
          child: plainText(
            chunk,
            fontSize: 10,
            textDirection: dirForText(chunk),
          ),
        ),
      );
    }
    return out;
  }

  /// Auto-pick short bullet vs paginated blocks from actual content length.
  List<pw.Widget> dynamicField(String label, String? value) {
    if (!_hasPdfText(value)) return const [];
    final plain = _truncateForPdf(value!);
    if (plain.length <= _maxPdfBlockChars) {
      return [bulletItem(label, plain)];
    }
    return labeledFieldBlocks(label, plain);
  }

  void addSection(
    List<pw.Widget> target,
    String title,
    List<pw.Widget> body, {
    bool omitIfEmpty = true,
  }) {
    if (omitIfEmpty && body.isEmpty) return;
    if (target.isNotEmpty) target.add(pw.SizedBox(height: 14));
    target.add(sectionTitle(title));
    target.add(pw.SizedBox(height: 6));
    if (body.isEmpty) {
      target.add(
        plainText(l10n.noData, fontSize: 10, textDirection: pageDir),
      );
    } else {
      target.addAll(body);
    }
  }

  /// Flat MultiPage children — only fields/sections that exist for this patient.
  final content = <pw.Widget>[
    pw.Center(
      child: pw.Column(
        children: [
          plainText(
            centerName,
            fontSize: 18,
            bold: true,
            textDirection: dirForText(centerName),
            textAlign: pw.TextAlign.center,
          ),
          pw.SizedBox(height: 4),
          plainText(
            l10n.patientDetail,
            fontSize: 14,
            textDirection: pageDir,
            textAlign: pw.TextAlign.center,
          ),
        ],
      ),
    ),
    pw.SizedBox(height: 16),
    sectionTitle(l10n.personalData),
    pw.SizedBox(height: 6),
    pw.Wrap(
      spacing: 8,
      runSpacing: 6,
      children: [
        plainText(
          user.displayName,
          fontSize: 11,
          bold: true,
          textDirection: dirForText(user.displayName),
        ),
        if (user.email.isNotEmpty)
          plainText(
            user.email,
            fontSize: 10,
            textDirection: pw.TextDirection.ltr,
          ),
        if (_hasPdfText(user.phone))
          plainText(
            user.phone!,
            fontSize: 10,
            textDirection: pw.TextDirection.ltr,
          ),
        if (_hasPdfText(user.phone2))
          plainText(
            user.phone2!,
            fontSize: 10,
            textDirection: pw.TextDirection.ltr,
          ),
      ],
    ),
  ];

  final personalFields = <pw.Widget>[];
  if (profile != null) {
    if (_hasPdfText(profile.dateOfBirth)) {
      personalFields.addAll(dynamicField(l10n.date, profile.dateOfBirth));
    } else if (profile.age != null) {
      personalFields.add(
        bulletItem(l10n.age, '${profile.age} ${l10n.yearsOld}'),
      );
    }
    personalFields.addAll(dynamicField(l10n.gender, profile.gender));
    personalFields.addAll(dynamicField(l10n.address, profile.address));
    personalFields.addAll(dynamicField(l10n.occupation, profile.occupation));
    personalFields.addAll(dynamicField(l10n.referredBy, profile.referredBy));
    personalFields.addAll(
      dynamicField(l10n.maritalStatus, profile.maritalStatus),
    );
    personalFields.addAll(
      dynamicField(l10n.areasToTreat, profile.areasToTreat),
    );
    personalFields.addAll(dynamicField(l10n.feesType, profile.feesType));
    if (_hasPdfText(followedByDoctorName)) {
      personalFields.addAll(
        dynamicField(l10n.doctor, followedByDoctorName),
      );
    }
  }
  if (personalFields.isNotEmpty) {
    content.add(pw.SizedBox(height: 6));
    content.addAll(personalFields);
  }

  final medicalFields = <pw.Widget>[];
  if (profile != null) {
    medicalFields.addAll(dynamicField(l10n.diagnosis, profile.diagnosis));
    medicalFields.addAll(
      dynamicField(l10n.chiefComplaint, profile.chiefComplaint),
    );
    medicalFields.addAll(dynamicField(l10n.painLevel, profile.painLevel));
    medicalFields.addAll(
      dynamicField(l10n.medicalHistory, profile.medicalHistory),
    );
    medicalFields.addAll(
      dynamicField(l10n.previousTreatment, profile.previousTreatment),
    );
    medicalFields.addAll(
      dynamicField(l10n.contraindications, profile.contraindications),
    );
    medicalFields.addAll(
      dynamicField(l10n.treatmentGoals, profile.treatmentGoals),
    );
    medicalFields.addAll(
      dynamicField(l10n.treatmentProgress, profile.treatmentProgress),
    );
    medicalFields.addAll(
      dynamicField(l10n.progressNotes, profile.progressNotes),
    );
  }
  addSection(content, l10n.medicalDetails, medicalFields);

  final sessionBody = <pw.Widget>[];
  final includeDoctorCol =
      sessionRows.any((r) => _hasPdfText(r.doctorLabel));
  if (sessionRows.isNotEmpty) {
    for (var start = 0;
        start < sessionRows.length;
        start += _pdfTableChunkSize) {
      final end = (start + _pdfTableChunkSize > sessionRows.length)
          ? sessionRows.length
          : start + _pdfTableChunkSize;
      final chunk = sessionRows.sublist(start, end);
      sessionBody.add(
        pw.Table(
          border: pw.TableBorder.all(color: PdfColors.grey400),
          columnWidths: includeDoctorCol
              ? {
                  0: const pw.FlexColumnWidth(1.6),
                  1: const pw.FlexColumnWidth(0.9),
                  2: const pw.FlexColumnWidth(1.4),
                  3: const pw.FlexColumnWidth(1.6),
                  4: const pw.FlexColumnWidth(0.9),
                  5: const pw.FlexColumnWidth(0.9),
                }
              : {
                  0: const pw.FlexColumnWidth(2.0),
                  1: const pw.FlexColumnWidth(1),
                  2: const pw.FlexColumnWidth(1.8),
                  3: const pw.FlexColumnWidth(1),
                  4: const pw.FlexColumnWidth(1),
                },
          children: [
            if (start == 0)
              pw.TableRow(
                children: [
                  headerCell(l10n.date),
                  headerCell(l10n.time),
                  headerCell(l10n.services),
                  if (includeDoctorCol) headerCell(l10n.doctor),
                  headerCell(l10n.status),
                  headerCell(l10n.sessionPayment),
                ],
              ),
            ...chunk.asMap().entries.map((entry) {
              final i = start + entry.key;
              final r = entry.value;
              final serviceStr = _hasPdfText(r.service) ? r.service!.trim() : '—';
              final statusStr =
                  _hasPdfText(r.statusLabel) ? r.statusLabel!.trim() : '—';
              final paymentStr = _hasPdfText(r.paymentStatusLabel)
                  ? r.paymentStatusLabel!.trim()
                  : '—';
              final doctorStr = _hasPdfText(r.doctorLabel)
                  ? r.doctorLabel!.trim()
                  : '—';

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
                    '${r.startTime} - ${r.endTime}',
                    alternate: i.isOdd,
                    textDirection: pw.TextDirection.ltr,
                  ),
                  cell(
                    serviceStr,
                    alternate: i.isOdd,
                    textDirection: dirForText(serviceStr),
                  ),
                  if (includeDoctorCol)
                    cell(
                      doctorStr,
                      alternate: i.isOdd,
                      textDirection: dirForText(doctorStr),
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
      if (end < sessionRows.length) {
        sessionBody.add(pw.SizedBox(height: 6));
      }
    }
  }
  addSection(
    content,
    sessionRows.isEmpty
        ? l10n.sessions
        : '${l10n.sessions} (${sessionRows.length})',
    sessionBody,
    omitIfEmpty: false,
  );

  final paymentBody = <pw.Widget>[];
  if (incomeForPatient.isNotEmpty) {
    for (var start = 0;
        start < incomeForPatient.length;
        start += _pdfTableChunkSize) {
      final end = (start + _pdfTableChunkSize > incomeForPatient.length)
          ? incomeForPatient.length
          : start + _pdfTableChunkSize;
      final chunk = incomeForPatient.sublist(start, end);
      final isLastChunk = end >= incomeForPatient.length;
      paymentBody.add(
        pw.Table(
          border: pw.TableBorder.all(color: PdfColors.grey400),
          columnWidths: {
            0: const pw.FlexColumnWidth(1.5),
            1: const pw.FlexColumnWidth(1),
            2: const pw.FlexColumnWidth(1),
            3: const pw.FlexColumnWidth(1.2),
          },
          children: [
            if (start == 0)
              pw.TableRow(
                children: [
                  headerCell(l10n.source),
                  headerCell(l10n.date),
                  headerCell(l10n.amount),
                  headerCell(l10n.status),
                ],
              ),
            ...chunk.asMap().entries.map((entry) {
              final i = start + entry.key;
              final r = entry.value;
              final statusStr = _paymentStatusLabel(
                r.sessionPaymentStatus,
                l10n,
                useLatin: false,
              );

              return pw.TableRow(
                children: [
                  cell(
                    r.source,
                    alternate: i.isOdd,
                    textDirection: dirForText(r.source),
                  ),
                  cell(
                    AppDateFormat.shortDate.format(r.incomeDate),
                    alternate: i.isOdd,
                    textDirection: pw.TextDirection.ltr,
                  ),
                  cell(
                    nf.format(r.amount),
                    alternate: i.isOdd,
                    textDirection: pw.TextDirection.ltr,
                  ),
                  cell(
                    statusStr,
                    alternate: i.isOdd,
                    textDirection: dirForText(statusStr),
                  ),
                ],
              );
            }),
            if (isLastChunk)
              pw.TableRow(
                decoration: pw.BoxDecoration(
                  color: PdfColor.fromInt(0xFFF5F5F5),
                ),
                children: [
                  cell(l10n.total, bold: true),
                  cell('', textDirection: pw.TextDirection.ltr),
                  cell(
                    nf.format(
                      incomeForPatient.fold<double>(
                        0,
                        (s, r) => s + r.amount,
                      ),
                    ),
                    bold: true,
                    textDirection: pw.TextDirection.ltr,
                  ),
                  cell('', textDirection: pw.TextDirection.ltr),
                ],
              ),
          ],
        ),
      );
      if (!isLastChunk) {
        paymentBody.add(pw.SizedBox(height: 6));
      }
    }
  }
  addSection(
    content,
    incomeForPatient.isEmpty
        ? l10n.amountPaid
        : '${l10n.amountPaid} (${incomeForPatient.length})',
    paymentBody,
    omitIfEmpty: false,
  );

  final packageBody = <pw.Widget>[];
  for (final e in packageProgress) {
    packageBody.add(
      pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: 4),
        child: pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Expanded(
              child: plainText(
                e.pkg.displayName,
                fontSize: 10,
                textDirection: dirForText(e.pkg.displayName),
              ),
            ),
            pw.SizedBox(width: 8),
            plainText(
              '${e.completed} / ${e.total}',
              fontSize: 10,
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
  addSection(
    content,
    packageProgress.isEmpty
        ? l10n.packages
        : '${l10n.packages} (${packageProgress.length})',
    packageBody,
    omitIfEmpty: false,
  );

  content.addAll([
    pw.SizedBox(height: 20),
    pw.Center(
      child: plainText(
        '${l10n.date}: ${AppDateFormat.mediumDate().format(DateTime.now())}',
        fontSize: 9,
        color: PdfColors.grey700,
        textDirection: pageDir,
        textAlign: pw.TextAlign.center,
      ),
    ),
  ]);

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

  final bytes = await doc.save();
  return bytes;
}

String _paymentStatusLabel(
  String? status,
  AppLocalizations l10n, {
  bool useLatin = false,
}) {
  if (status == null || status.isEmpty) return '—';

  if (useLatin) {
    switch (status) {
      case 'paid':
        return 'Paid';
      case 'partial_paid':
        return 'Partial';
      case 'prepaid':
        return 'Prepaid';
      case 'not_paid':
        return 'Not paid';
      default:
        return status;
    }
  }

  switch (status) {
    case 'paid':
      return l10n.paid;
    case 'partial_paid':
      return l10n.partialPaid;
    case 'prepaid':
      return l10n.prepaid;
    case 'not_paid':
      return l10n.notPaid;
    default:
      return status;
  }
}
