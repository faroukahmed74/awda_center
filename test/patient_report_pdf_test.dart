import 'package:flutter/material.dart' show Locale;
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:awda_center/l10n/app_localizations.dart';
import 'package:awda_center/models/income_expense_models.dart';
import 'package:awda_center/models/patient_profile_model.dart';
import 'package:awda_center/models/user_model.dart';
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
      medicalHistory: 'تاريخ طبي مختصر للاختبار',
      progressNotes: '<p>ملاحظات تقدم طويلة نسبياً للتأكد من التحويل للنص العادي</p>',
      chiefComplaint: 'ألم مزمن',
      treatmentGoals: 'تحسين الحركة',
    );

    final sessionRows = List<PatientReportSessionRow>.generate(120, (i) {
      final date = DateTime(2025, 1, 1).add(Duration(days: i));
      return PatientReportSessionRow(
        date: date,
        startTime: '10:00',
        endTime: '11:00',
        service: i.isEven ? 'جلسة علاج طبيعي' : 'Therapy session',
        statusLabel: l10n.attended,
        paymentStatusLabel: l10n.paid,
      );
    });

    final income = List<IncomeRecordModel>.generate(40, (i) {
      return IncomeRecordModel(
        id: 'inc-$i',
        amount: 200 + i.toDouble(),
        source: i.isEven ? 'جلسة' : 'Session',
        incomeDate: DateTime(2025, 1, 1).add(Duration(days: i)),
        sessionPaymentStatus: 'paid',
      );
    });

    final bytes = await buildPatientReportPdf(
      user: user,
      profile: profile,
      sessionRows: sessionRows,
      incomeForPatient: income,
      packageProgress: const [],
      l10n: l10n,
      centerName: l10n.appTitle,
    );

    expect(bytes.length, greaterThan(2000));
    expect(String.fromCharCodes(bytes.take(4)), '%PDF');
  });

  test('buildPatientReportPdf succeeds with empty sessions', () async {
    final l10n = AppLocalizations(const Locale('en'));
    const user = UserModel(id: 'p2', email: 'p2@test.com', fullNameEn: 'Test Patient');
    final bytes = await buildPatientReportPdf(
      user: user,
      profile: null,
      sessionRows: const [],
      incomeForPatient: const [],
      packageProgress: const [],
      l10n: l10n,
      centerName: l10n.appTitle,
    );
    expect(String.fromCharCodes(bytes.take(4)), '%PDF');
  });
}
