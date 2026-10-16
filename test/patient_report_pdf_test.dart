import 'package:archive/archive.dart';
import 'package:flutter/material.dart' show Locale;
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:awda_center/l10n/app_localizations.dart';
import 'package:awda_center/models/patient_profile_model.dart';
import 'package:awda_center/models/user_model.dart';
import 'package:awda_center/screens/patients/patient_report_docx.dart';
import 'package:awda_center/screens/patients/patient_report_pdf.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await initializeDateFormatting('en');
    await initializeDateFormatting('ar');
  });

  test('buildPatientReportPdf succeeds with many Arabic session rows', () async {
    final l10n = AppLocalizations(const Locale('ar'));
    const user = UserModel(
      id: 'patient-1',
      email: 'patient@test.com',
      fullNameAr: 'مريض تجريبي طويل الاسم',
      phone: '01000000000',
    );
    const profile = PatientProfileModel(
      id: 'patient-1',
      userId: 'patient-1',
      diagnosis: 'ألم أسفل الظهر',
    );

    final sessionRows = List<PatientReportSessionRow>.generate(120, (i) {
      final date = DateTime(2025, 1, 1).add(Duration(days: i));
      return PatientReportSessionRow(
        date: date,
        startTime: '10:00',
        endTime: '11:00',
        service: i.isEven ? 'جلسة علاج طبيعي' : 'Therapy session',
        statusLabel: l10n.attended,
        paymentStatusKey: i % 3 == 0 ? 'prepaid' : 'paid',
        paymentAmount: i % 3 == 0 ? null : 150.0 + i,
      );
    });

    final bytes = await buildPatientReportPdf(
      user: user,
      profile: profile,
      sessionRows: sessionRows,
      l10n: l10n,
      centerName: l10n.appTitle,
    );

    expect(bytes.length, greaterThan(2000));
    expect(String.fromCharCodes(bytes.take(4)), '%PDF');
  });

  test('buildPatientReportPdf renders Arabic yeh in names like هويدا', () async {
    final l10n = AppLocalizations(const Locale('ar'));
    const user = UserModel(
      id: 'p-yeh',
      email: 'yeh@test.com',
      fullNameAr: 'هويدا محمود',
    );
    final bytes = await buildPatientReportPdf(
      user: user,
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
    expect(bytes.length, greaterThan(1500));
  });

  test('buildPatientReportPdf succeeds with empty sessions', () async {
    final l10n = AppLocalizations(const Locale('en'));
    const user = UserModel(id: 'p2', email: 'p2@test.com', fullNameEn: 'Test Patient');
    final bytes = await buildPatientReportPdf(
      user: user,
      profile: null,
      sessionRows: const [],
      l10n: l10n,
      centerName: l10n.appTitle,
    );
    expect(String.fromCharCodes(bytes.take(4)), '%PDF');
  });

  test('buildPatientReportPdf includes diagnosis and payment total', () async {
    final l10n = AppLocalizations(const Locale('en'));
    const user = UserModel(
      id: 'p3',
      email: 'long@test.com',
      fullNameEn: 'Long Plan Patient',
    );
    final profile = PatientProfileModel(
      id: 'p3',
      userId: 'p3',
      diagnosis:
          'LF SUPRASPINATUS PARTIAL-THICKNESS TEAR\nCERVICAL AND LUMBAR SPONDYLOSIS',
      treatmentGoals: 'ignored in compact report',
    );

    final rows = [
      PatientReportSessionRow(
        date: DateTime(2026, 10, 1),
        startTime: '17:00',
        endTime: '19:00',
        service: 'Session A',
        statusLabel: l10n.attended,
        paymentStatusKey: 'paid',
        paymentAmount: 1550,
      ),
      PatientReportSessionRow(
        date: DateTime(2026, 10, 6),
        startTime: '17:00',
        endTime: '19:00',
        service: 'Session B',
        statusLabel: l10n.attended,
        paymentStatusKey: 'prepaid',
        paymentAmount: 0,
      ),
    ];

    expect(patientReportPaymentTotal(rows), 1550);

    final bytes = await buildPatientReportPdf(
      user: user,
      profile: profile,
      sessionRows: rows,
      l10n: l10n,
      centerName: l10n.appTitle,
      packageProgress: const [
        PatientReportPackageProgress(
          name: '6 sessions PT package',
          completed: 6,
          total: 6,
        ),
      ],
    );

    expect(bytes.length, greaterThan(2000));
    expect(String.fromCharCodes(bytes.take(4)), '%PDF');
  });

  test('buildPatientReportDocx embeds logo and returns a zip package', () async {
    final l10n = AppLocalizations(const Locale('en'));
    const user = UserModel(id: 'p4', email: 'd@test.com', fullNameEn: 'Docs Patient');
    final bytes = await buildPatientReportDocx(
      user: user,
      profile: const PatientProfileModel(
        id: 'p4',
        userId: 'p4',
        diagnosis: 'Test diagnosis',
      ),
      sessionRows: [
        PatientReportSessionRow(
          date: DateTime(2026, 1, 2),
          startTime: '10:00',
          endTime: '11:00',
          service: 'PT',
          statusLabel: l10n.attended,
          paymentStatusKey: 'paid',
          paymentAmount: 200,
        ),
      ],
      l10n: l10n,
      centerName: l10n.appTitle,
    );
    // ZIP / DOCX local file header
    expect(bytes[0], 0x50); // P
    expect(bytes[1], 0x4B); // K
    final zip = ZipDecoder().decodeBytes(bytes);
    expect(
      zip.findFile('word/media/logo.png'),
      isNotNull,
      reason: 'Docs report must embed the center logo',
    );
    final docXml = zip.findFile('word/document.xml');
    expect(docXml, isNotNull);
    final xml = String.fromCharCodes(docXml!.content as List<int>);
    expect(xml.contains('rIdLogo'), isTrue);
  });
}
