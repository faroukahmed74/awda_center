import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdf/widgets.dart' as pw;

import 'package:awda_center/core/arabic_pdf_reshaper.dart';
import 'package:awda_center/l10n/app_localizations.dart';
import 'package:awda_center/models/patient_profile_model.dart';
import 'package:awda_center/models/user_model.dart';
import 'package:awda_center/screens/patients/patient_report_pdf.dart';
import 'package:flutter/material.dart' show Locale;
import 'package:intl/date_symbol_data_local.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await initializeDateFormatting('ar');
    await initializeDateFormatting('en');
  });

  test('Amiri can draw isolated Arabic yeh presentation form', () async {
    final amiri =
        pw.Font.ttf(await rootBundle.load('assets/fonts/Amiri-Regular.ttf'));
    final shaped = ArabicPdfReshaper.reshape('هويدا محمود');
    expect(shaped.runes.contains(0xFEF1), isTrue);

    final doc = pw.Document();
    doc.addPage(
      pw.Page(
        build: (_) => pw.Text(
          shaped,
          style: pw.TextStyle(font: amiri, fontSize: 14),
          textDirection: pw.TextDirection.rtl,
        ),
      ),
    );
    final bytes = await doc.save();
    expect(String.fromCharCodes(bytes.take(4)), '%PDF');
  });

  test('patient report PDF with هويدا does not throw UTF-8 FormatException', () async {
    final l10n = AppLocalizations(const Locale('ar'));
    final bytes = await buildPatientReportPdf(
      user: const UserModel(
        id: 'p-yeh',
        email: 'yeh@test.com',
        fullNameAr: 'هويدا محمود',
      ),
      profile: const PatientProfileModel(
        id: 'p-yeh',
        userId: 'p-yeh',
        diagnosis: 'Test',
      ),
      sessionRows: const [],
      l10n: l10n,
      centerName: l10n.appTitle,
    );
    expect(String.fromCharCodes(bytes.take(4)), '%PDF');
  });
}
