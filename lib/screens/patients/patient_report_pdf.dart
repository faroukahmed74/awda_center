import 'dart:typed_data';

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

/// One row for sessions section (from sessions collection or appointment).
class PatientReportSessionRow {
  final DateTime date;
  final String startTime;
  final String endTime;
  final String? service;
  final String? statusLabel;
  final String? paymentStatusLabel;

  PatientReportSessionRow({
    required this.date,
    required this.startTime,
    required this.endTime,
    this.service,
    this.statusLabel,
    this.paymentStatusLabel,
  });
}

/// Use a modern Arabic font first.
/// Make sure these files really exist in assets and are declared in pubspec.yaml.
const _patientReportArabicRegularFontPaths = [
  'assets/fonts/Cairo-Regular.ttf',
  'assets/fonts/Tajawal-Regular.ttf',
  'assets/fonts/Amiri-Regular.ttf',
  'assets/fonts/Fonts/KacstFarsi.ttf',
  'assets/fonts/Fonts/DTNASKH2.TTF',
  'assets/fonts/Fonts/Candarab.ttf',
  'assets/fonts/Fonts/ARIALUNI.TTF',
];

const _patientReportArabicBoldFontPaths = [
  'assets/fonts/Cairo-Bold.ttf',
  'assets/fonts/Tajawal-Bold.ttf',
  'assets/fonts/Amiri-Bold.ttf',
  'assets/fonts/Amiri-Regular.ttf',
  'assets/fonts/Fonts/KacstFarsi.ttf',
  'assets/fonts/Fonts/DTNASKH2.TTF',
  'assets/fonts/Fonts/Candarab.ttf',
  'assets/fonts/Fonts/ARIALUNI.TTF',
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
        textDirection:
            isArabic ? pw.TextDirection.rtl : pw.TextDirection.ltr,
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

  pw.Widget bulletItem(String label, String value) {
    final labelText = shape(label);
    final valueText = shape(value);

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
                  hasArabic('$label $value')
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

  final medicalLines = <pw.Widget>[];

  if (profile != null) {
    if ((profile.diagnosis ?? '').isNotEmpty) {
      medicalLines.add(bulletItem(l10n.diagnosis, profile.diagnosis!));
    }
    if ((profile.medicalHistory ?? '').isNotEmpty) {
      medicalLines.add(
        bulletItem(l10n.medicalHistory, profile.medicalHistory!),
      );
    }
    if ((profile.chiefComplaint ?? '').isNotEmpty) {
      medicalLines.add(
        bulletItem(l10n.chiefComplaint, profile.chiefComplaint!),
      );
    }
    if ((profile.treatmentProgress ?? '').isNotEmpty) {
      medicalLines.add(
        bulletItem(l10n.treatmentProgress, profile.treatmentProgress!),
      );
    }
  }

  doc.addPage(
    pw.MultiPage(
      margin: const pw.EdgeInsets.all(24),
      build:
          (context) => [
            pw.Directionality(
              textDirection:
                  isArabic ? pw.TextDirection.rtl : pw.TextDirection.ltr,
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
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
                          textDirection:
                              isArabic
                                  ? pw.TextDirection.rtl
                                  : pw.TextDirection.ltr,
                          textAlign: pw.TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                  pw.SizedBox(height: 16),

                  /// Personal data
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
                      if (user.phone != null && user.phone!.isNotEmpty)
                        plainText(
                          user.phone!,
                          fontSize: 10,
                          textDirection: pw.TextDirection.ltr,
                        ),
                    ],
                  ),

                  if (profile != null) ...[
                    pw.SizedBox(height: 6),
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        if (profile.dateOfBirth != null &&
                            profile.dateOfBirth!.isNotEmpty)
                          bulletItem(l10n.date, profile.dateOfBirth!),
                        if (profile.gender != null &&
                            profile.gender!.isNotEmpty)
                          bulletItem(l10n.gender, profile.gender!),
                        if (profile.address != null &&
                            profile.address!.isNotEmpty)
                          bulletItem(l10n.address, profile.address!),
                        if (profile.occupation != null &&
                            profile.occupation!.isNotEmpty)
                          bulletItem(l10n.occupation, profile.occupation!),
                      ],
                    ),
                  ],

                  pw.SizedBox(height: 14),

                  /// Medical details
                  sectionTitle(l10n.medicalDetails),
                  pw.SizedBox(height: 6),
                  if (medicalLines.isEmpty)
                    plainText(
                      l10n.noData,
                      fontSize: 10,
                      textDirection:
                          isArabic
                              ? pw.TextDirection.rtl
                              : pw.TextDirection.ltr,
                    )
                  else
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: medicalLines,
                    ),

                  pw.SizedBox(height: 14),

                  /// Sessions
                  sectionTitle(l10n.sessions),
                  pw.SizedBox(height: 6),
                  sessionRows.isEmpty
                      ? plainText(
                        l10n.noData,
                        fontSize: 10,
                        textDirection:
                            isArabic
                                ? pw.TextDirection.rtl
                                : pw.TextDirection.ltr,
                      )
                      : pw.Table(
                        border: pw.TableBorder.all(color: PdfColors.grey400),
                        columnWidths: {
                          0: const pw.FlexColumnWidth(1.2),
                          1: const pw.FlexColumnWidth(1),
                          2: const pw.FlexColumnWidth(2),
                          3: const pw.FlexColumnWidth(1),
                          4: const pw.FlexColumnWidth(1),
                        },
                        children: [
                          pw.TableRow(
                            children: [
                              headerCell(l10n.date),
                              headerCell(l10n.time),
                              headerCell(l10n.services),
                              headerCell(l10n.status),
                              headerCell(l10n.sessionPayment),
                            ],
                          ),
                          ...sessionRows.asMap().entries.map((entry) {
                            final i = entry.key;
                            final r = entry.value;
                            final serviceStr = r.service?.trim().isNotEmpty == true
                                ? r.service!.trim()
                                : '—';
                            final statusStr = r.statusLabel?.trim().isNotEmpty == true
                                ? r.statusLabel!.trim()
                                : '—';
                            final paymentStr = r.paymentStatusLabel?.trim().isNotEmpty == true
                                ? r.paymentStatusLabel!.trim()
                                : '—';

                            return pw.TableRow(
                              children: [
                                cell(
                                  AppDateFormat.shortDate.format(r.date),
                                  alternate: i.isOdd,
                                  textDirection: pw.TextDirection.ltr,
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

                  pw.SizedBox(height: 14),

                  /// Payments
                  sectionTitle(l10n.amountPaid),
                  pw.SizedBox(height: 6),
                  incomeForPatient.isEmpty
                      ? plainText(
                        l10n.noData,
                        fontSize: 10,
                        textDirection:
                            isArabic
                                ? pw.TextDirection.rtl
                                : pw.TextDirection.ltr,
                      )
                      : pw.Table(
                        border: pw.TableBorder.all(color: PdfColors.grey400),
                        columnWidths: {
                          0: const pw.FlexColumnWidth(1.5),
                          1: const pw.FlexColumnWidth(1),
                          2: const pw.FlexColumnWidth(1),
                          3: const pw.FlexColumnWidth(1.2),
                        },
                        children: [
                          pw.TableRow(
                            children: [
                              headerCell(l10n.source),
                              headerCell(l10n.date),
                              headerCell(l10n.amount),
                              headerCell(l10n.status),
                            ],
                          ),
                          ...incomeForPatient.asMap().entries.map((entry) {
                            final i = entry.key;
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

                  pw.SizedBox(height: 14),

                  /// Packages
                  sectionTitle(l10n.packages),
                  pw.SizedBox(height: 6),
                  packageProgress.isEmpty
                      ? plainText(
                        l10n.noData,
                        fontSize: 10,
                        textDirection:
                            isArabic
                                ? pw.TextDirection.rtl
                                : pw.TextDirection.ltr,
                      )
                      : pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children:
                            packageProgress.map((e) {
                              return pw.Padding(
                                padding: const pw.EdgeInsets.only(bottom: 4),
                                child: pw.Row(
                                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                                  children: [
                                    pw.Expanded(
                                      child: plainText(
                                        e.pkg.displayName,
                                        fontSize: 10,
                                        textDirection: dirForText(
                                          e.pkg.displayName,
                                        ),
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
                                      textDirection:
                                          isArabic
                                              ? pw.TextDirection.rtl
                                              : pw.TextDirection.ltr,
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                      ),

                  pw.SizedBox(height: 20),

                  pw.Center(
                    child: plainText(
                      '${l10n.date}: ${AppDateFormat.mediumDate().format(DateTime.now())}',
                      fontSize: 9,
                      color: PdfColors.grey700,
                      textDirection:
                          isArabic
                              ? pw.TextDirection.rtl
                              : pw.TextDirection.ltr,
                      textAlign: pw.TextAlign.center,
                    ),
                  ),
                ],
              ),
            ),
          ],
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