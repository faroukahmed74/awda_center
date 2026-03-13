import 'package:excel/excel.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:go_router/go_router.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';
import '../../core/arabic_pdf_reshaper.dart';
import '../../core/general_error_helper.dart';
import '../../core/responsive.dart';
import '../../l10n/app_localizations.dart';
import '../../models/appointment_model.dart';
import '../../models/income_expense_models.dart';
import '../../models/user_model.dart';
import '../../services/firestore_service.dart';
import '../../widgets/notifications_button.dart';
import 'package:intl/intl.dart' hide TextDirection;
import '../../core/date_format.dart';

import 'report_file_io_stub.dart' if (dart.library.io) 'report_file_io.dart' as report_io;
import 'report_pdf_share.dart';

/// Reports: patients, income & expenses, appointments, users summary. All reports use period (day/month/year) where applicable; exports available from menu.
class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> with SingleTickerProviderStateMixin {
  final FirestoreService _firestore = FirestoreService();
  late TabController _tabController;
  String _period = 'month';
  DateTime _selectedDate = DateTime.now();
  List<String> _patientNames = [];
  List<IncomeRecordModel> _income = [];
  List<ExpenseRecordModel> _expenses = [];
  double _incomeTotal = 0;
  double _expenseTotal = 0;
  List<AppointmentModel> _appointments = [];
  Map<String, int> _appointmentsByStatus = {};
  List<UserModel> _users = [];
  Map<String, int> _usersByRole = {};
  bool _loading = false;
  int _previousTabIndex = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(_onTabChanged);
    _load();
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    super.dispose();
  }

  void _onTabChanged() {
    if (!_tabController.indexIsChanging && mounted) {
      final index = _tabController.index;
      if (index != _previousTabIndex) {
        _previousTabIndex = index;
        _load();
      }
    }
  }

  /// Returns (fromInclusive, toExclusive) for Firestore queries.
  (DateTime, DateTime) _range() {
    if (_period == 'day') {
      final s = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day);
      return (s, s.add(const Duration(days: 1)));
    }
    if (_period == 'month') {
      final s = DateTime(_selectedDate.year, _selectedDate.month, 1);
      final e = DateTime(_selectedDate.year, _selectedDate.month + 1, 1);
      return (s, e);
    }
    final s = DateTime(_selectedDate.year, 1, 1);
    final e = DateTime(_selectedDate.year + 1, 1, 1);
    return (s, e);
  }

  String _periodLabel() {
    if (_period == 'day') return AppDateFormat.shortDate.format(_selectedDate);
    if (_period == 'month') return AppDateFormat.monthYear().format(DateTime(_selectedDate.year, _selectedDate.month, 1));
    return AppDateFormat.yearOnly.format(DateTime(_selectedDate.year, 1, 1));
  }

  Future<void> _pickPeriod(BuildContext context) async {
    final l10n = AppLocalizations.of(context);
    final now = DateTime.now();
    if (_period == 'day') {
      final d = await showDatePicker(
        context: context,
        initialDate: _selectedDate,
        firstDate: DateTime(2020),
        lastDate: DateTime(now.year + 1, 12, 31),
      );
      if (d != null && mounted) {
        setState(() {
          _selectedDate = d;
          _load();
        });
      }
      return;
    }
    if (_period == 'month') {
      final picked = await showDialog<DateTime>(
        context: context,
        builder: (ctx) => _MonthYearPickerDialog(
          initial: _selectedDate,
          l10n: l10n,
          now: now,
        ),
      );
      if (picked != null && mounted) {
        setState(() {
          _selectedDate = picked;
          _load();
        });
      }
      return;
    }
    final pickedYear = await showDialog<int>(
      context: context,
      builder: (ctx) => _YearPickerDialog(initial: _selectedDate.year, l10n: l10n, now: now),
    );
    if (pickedYear != null && mounted) {
      setState(() {
        _selectedDate = DateTime(pickedYear, 1, 1);
        _load();
      });
    }
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final (from, to) = _range();
    try {
      // Load all data in parallel to avoid sequential round-trips (was N+1 getUser calls).
      final results = await Future.wait<dynamic>([
        _firestore.getAppointments(from: from, to: to),
        _firestore.getIncomeRecords(from: from, to: to),
        _firestore.getExpenseRecords(from: from, to: to),
        _firestore.getUsers(),
      ]);
      final appointments = results[0] as List<AppointmentModel>;
      final income = results[1] as List<IncomeRecordModel>;
      final expenses = results[2] as List<ExpenseRecordModel>;
      final users = results[3] as List<UserModel>;

      final names = <String, String>{};
      for (final u in users) {
        names[u.id] = u.displayName;
      }
      final patientIds = appointments.map((a) => a.patientId).toSet().toList();

      final incomeTotal = income.fold<double>(0, (s, r) => s + r.amount);
      final expenseTotal = expenses.fold<double>(0, (s, r) => s + r.amount);

      final byStatus = <String, int>{};
      for (final a in appointments) {
        byStatus[a.status.value] = (byStatus[a.status.value] ?? 0) + 1;
      }

      final byRole = <String, int>{};
      for (final u in users) {
        for (final r in u.roles) {
          byRole[r] = (byRole[r] ?? 0) + 1;
        }
      }

      if (!mounted) return;
      setState(() {
        _patientNames = patientIds.map((id) => names[id] ?? id).toList();
        _appointments = appointments;
        _appointmentsByStatus = byStatus;
        _income = income;
        _expenses = expenses;
        _incomeTotal = incomeTotal;
        _expenseTotal = expenseTotal;
        _users = users;
        _usersByRole = byRole;
        _loading = false;
      });
    } catch (e, st) {
      debugPrint('ReportsScreen _load error: $e\n$st');
      if (mounted) setState(() => _loading = false);
    }
  }

  /// Origin rect for the share sheet (required on iPad / some iOS). Pass from build context.
  static Rect? _sharePositionOriginFrom(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    if (size.width <= 0 || size.height <= 0) return null;
    return Rect.fromLTWH(0, 0, size.width, size.height * 0.5);
  }

  Future<void> _exportIncome(AppLocalizations l10n, [Rect? sharePositionOrigin]) async {
    final (from, to) = _range();
    final income = await _firestore.getIncomeRecords(from: from, to: to);
    final expense = await _firestore.getExpenseRecords(from: from, to: to);
    final sb = StringBuffer();
    sb.writeln('Date,Type,Amount,Source/Category,Notes');
    for (final r in income) {
      sb.writeln('${AppDateFormat.shortDate.format(r.incomeDate)},Income,${r.amount},${r.source},${r.notes ?? ''}');
    }
    for (final r in expense) {
      sb.writeln('${AppDateFormat.shortDate.format(r.expenseDate)},Expense,${r.amount},${r.category},${r.description ?? ''}');
    }
    await Share.share(
      sb.toString(),
      subject: '${l10n.exportIncomeExpense} ${AppDateFormat.shortDate.format(from)} - ${AppDateFormat.shortDate.format(to)}',
      sharePositionOrigin: sharePositionOrigin,
    );
  }

  Future<void> _exportAppointments(AppLocalizations l10n, [Rect? sharePositionOrigin]) async {
    final (from, to) = _range();
    final appointments = await _firestore.getAppointments(from: from, to: to);
    final sb = StringBuffer();
    sb.writeln('Date,Start,End,PatientId,DoctorId,Status,Service');
    for (final a in appointments) {
      sb.writeln(
        '${AppDateFormat.shortDate.format(a.appointmentDate)},${a.startTime},${a.endTime},${a.patientId},${a.doctorId},${a.status.value},${a.servicesDisplay}',
      );
    }
    await Share.share(
      sb.toString(),
      subject: '${l10n.exportAppointments} ${AppDateFormat.shortDate.format(from)} - ${AppDateFormat.shortDate.format(to)}',
      sharePositionOrigin: sharePositionOrigin,
    );
  }

  Future<void> _exportPatients(AppLocalizations l10n, [Rect? sharePositionOrigin]) async {
    final (from, to) = _range();
    final appointments = await _firestore.getAppointments(from: from, to: to);
    final patientIds = appointments.map((a) => a.patientId).toSet().toList();
    final sb = StringBuffer();
    sb.writeln('PatientId,DisplayName');
    for (final id in patientIds) {
      final u = await _firestore.getUser(id);
      sb.writeln('$id,${u?.displayName ?? id}');
    }
    await Share.share(
      sb.toString(),
      subject: '${l10n.exportPatients} ${AppDateFormat.shortDate.format(from)} - ${AppDateFormat.shortDate.format(to)}',
      sharePositionOrigin: sharePositionOrigin,
    );
  }

  Future<void> _exportUsers(AppLocalizations l10n, [Rect? sharePositionOrigin]) async {
    final users = await _firestore.getUsers();
    final sb = StringBuffer();
    sb.writeln('Id,Email,FullNameAr,FullNameEn,Phone,Roles,Active');
    for (final u in users) {
      sb.writeln(
        '${u.id},${u.email},${u.fullNameAr ?? ''},${u.fullNameEn ?? ''},${u.phone ?? ''},${u.roles.join(";")},${u.isActive}',
      );
    }
    await Share.share(sb.toString(), subject: l10n.exportUsers, sharePositionOrigin: sharePositionOrigin);
  }

  Future<void> _exportAuditLog(AppLocalizations l10n, [Rect? sharePositionOrigin]) async {
    final logs = await _firestore.getAuditLogs(limit: 500);
    final sb = StringBuffer();
    sb.writeln('CreatedAt,Action,EntityType,EntityId,UserId,UserEmail,Details');
    for (final e in logs) {
      final details = e.details != null ? e.details!.toString().replaceAll(',', ';') : '';
      sb.writeln(
        '${e.createdAt != null ? AppDateFormat.shortDateTimeSec.format(e.createdAt!) : ''},${e.action},${e.entityType},${e.entityId ?? ''},${e.userId},${e.userEmail ?? ''},$details',
      );
    }
    await Share.share(sb.toString(), subject: l10n.exportAuditLog, sharePositionOrigin: sharePositionOrigin);
  }

  String _statusLabel(String value, AppLocalizations l10n) {
    switch (value) {
      case 'pending':
        return l10n.pending;
      case 'confirmed':
        return l10n.confirmed;
      case 'completed':
        return l10n.attended;
      case 'cancelled':
        return l10n.cancelled;
      case 'no_show':
        return l10n.absent;
      case 'absent_with_cause':
        return l10n.apologized;
      case 'absent_without_cause':
        return l10n.absent;
      default:
        return value;
    }
  }

  String _sessionPaymentStatusLabel(String? value, AppLocalizations l10n) {
    switch (value) {
      case 'paid':
        return l10n.paid;
      case 'partial_paid':
        return l10n.partialPaid;
      case 'prepaid':
        return l10n.prepaid;
      case 'not_paid':
        return l10n.notPaid;
      default:
        return value ?? '';
    }
  }

  /// Cairo only for web (Income & expenses, Appointments); full list for other platforms.
  static const _pdfCairoRegularPaths = ['assets/fonts/Cairo-Regular.ttf'];
  static const _pdfCairoBoldPaths = ['assets/fonts/Cairo-Bold.ttf'];
  static const _pdfArabicRegularPaths = [
    'assets/fonts/Cairo-Regular.ttf',
    'assets/fonts/Tajawal-Regular.ttf',
    'assets/fonts/Amiri-Regular.ttf',
    'assets/fonts/Fonts/KacstFarsi.ttf',
    'assets/fonts/Fonts/DTNASKH2.TTF',
    'assets/fonts/Fonts/Candarab.ttf',
    'assets/fonts/Fonts/ARIALUNI.TTF',
  ];
  static const _pdfArabicBoldPaths = [
    'assets/fonts/Cairo-Bold.ttf',
    'assets/fonts/Tajawal-Bold.ttf',
    'assets/fonts/Amiri-Bold.ttf',
    'assets/fonts/Amiri-Regular.ttf',
    'assets/fonts/Fonts/KacstFarsi.ttf',
    'assets/fonts/Fonts/DTNASKH2.TTF',
    'assets/fonts/Fonts/Candarab.ttf',
    'assets/fonts/Fonts/ARIALUNI.TTF',
  ];

  Future<pw.Font?> _tryLoadPdfFont(List<String> paths) async {
    for (final path in paths) {
      try {
        final raw = await rootBundle.load(path);
        final byteData = raw.buffer.asByteData(raw.offsetInBytes, raw.lengthInBytes);
        final font = pw.Font.ttf(byteData);
        debugPrint('Reports PDF font loaded: $path');
        return font;
      } catch (e, st) {
        debugPrint('Reports PDF font failed: $path');
        debugPrint('$e');
        debugPrint('$st');
      }
    }
    return null;
  }

  Future<void> _exportCurrentAsPdf(AppLocalizations l10n, Rect? shareOrigin) async {
    final (from, to) = _range();
    final periodLabel = '${AppDateFormat.shortDate.format(from)} - ${AppDateFormat.shortDate.format(to)}';

    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => PopScope(
        canPop: false,
        child: AlertDialog(
          content: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2)),
              const SizedBox(width: 24),
              Expanded(child: Text(l10n.generatingReport)),
            ],
          ),
        ),
      ),
    );
    await Future.delayed(const Duration(milliseconds: 250));

    try {
    pw.Font? arabicFont;
    pw.Font? arabicBoldFont;
    try {
      if (kIsWeb) {
        arabicFont = await _tryLoadPdfFont(_pdfCairoRegularPaths);
        arabicBoldFont = await _tryLoadPdfFont(_pdfCairoBoldPaths) ?? arabicFont;
      } else {
        arabicFont = await _tryLoadPdfFont(_pdfArabicRegularPaths);
        arabicBoldFont = await _tryLoadPdfFont(_pdfArabicBoldPaths) ?? arabicFont;
      }
    } catch (e, st) {
      debugPrint('Reports PDF font load error: $e\n$st');
      arabicFont = null;
      arabicBoldFont = null;
    }
    if (arabicFont == null) {
      debugPrint('Reports PDF: no Arabic font; using default.');
    }

    final pdfTheme = arabicFont == null
        ? null
        : pw.ThemeData.withFont(
            base: arabicFont,
            bold: arabicBoldFont ?? arabicFont,
            italic: arabicFont,
            boldItalic: arabicBoldFont ?? arabicFont,
            fontFallback: [arabicFont],
          );

    final doc = pw.Document(theme: pdfTheme);
    final int tabIndex = _tabController.index;
    final isArabic = l10n.isArabic;

    final headerBg = PdfColor.fromInt(0xFFE3F2FD);
    final headerText = PdfColors.blue900;
    final sectionGreen = PdfColor.fromInt(0xFFE8F5E9);

    bool hasArabic(String text) {
      try {
        return ArabicPdfReshaper.hasArabic(text);
      } catch (_) {
        return false;
      }
    }

    String shape(String text) {
      if (text.isEmpty) return text;
      if (arabicFont == null) return text;
      try {
        return hasArabic(text) ? ArabicPdfReshaper.reshape(text) : text;
      } catch (_) {
        return text;
      }
    }

    pw.TextDirection dirForText(String text) {
      return hasArabic(text) ? pw.TextDirection.rtl : pw.TextDirection.ltr;
    }

    pw.TextStyle pdfTextStyle({
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

    pw.Widget pdfText(
      String? text, {
      double fontSize = 10,
      bool bold = false,
      PdfColor? color,
      pw.TextDirection? textDirection,
      pw.TextAlign? textAlign,
    }) {
      final s = text ?? '';
      return pw.Text(
        shape(s),
        textDirection: textDirection ?? dirForText(s),
        textAlign: textAlign,
        style: pdfTextStyle(
          fontSize: fontSize,
          bold: bold,
          color: color,
        ),
      );
    }

    pw.Widget pdfHeaderCell(String text, {PdfColor? bg, PdfColor? textColor}) {
      return pw.Container(
        padding: const pw.EdgeInsets.all(6),
        color: bg ?? PdfColors.blue50,
        child: pdfText(
          text,
          fontSize: 10,
          bold: true,
          color: textColor ?? PdfColors.blue900,
          textDirection: dirForText(text),
          textAlign: hasArabic(text) ? pw.TextAlign.right : pw.TextAlign.left,
        ),
      );
    }

    pw.Widget pdfCell(
      String? text, {
      bool alternate = false,
      pw.TextDirection? textDirection,
      pw.TextAlign? textAlign,
    }) {
      final t = text ?? '';
      return pw.Container(
        padding: const pw.EdgeInsets.all(4),
        color: alternate ? PdfColor.fromInt(0xFFF5F5F5) : null,
        child: pdfText(
          t,
          fontSize: 9,
          textDirection: textDirection ?? dirForText(t),
          textAlign: textAlign ?? (hasArabic(t) ? pw.TextAlign.right : pw.TextAlign.left),
        ),
      );
    }

    String safeFormatDate(DateTime d) {
      try {
        return AppDateFormat.shortDate.format(d);
      } catch (_) {
        return '${d.year}-${d.month}-${d.day}';
      }
    }

    final usersById = <String, UserModel>{
      for (final u in _users) u.id: u,
    };
    final appointmentsById = <String, AppointmentModel>{
      for (final a in _appointments) a.id: a,
    };

    String displayName(String? userId) {
      if (userId == null || userId.isEmpty) return '';
      return usersById[userId]?.displayName ?? userId;
    }

    String incomeDetails(IncomeRecordModel r) {
      final lines = <String>[];
      final appointment = r.appointmentId == null
          ? null
          : appointmentsById[r.appointmentId!];

      if (r.patientId != null && r.patientId!.isNotEmpty) {
        lines.add('${l10n.patient}: ${displayName(r.patientId)}');
      }
      if (r.doctorId != null && r.doctorId!.isNotEmpty) {
        lines.add('${l10n.doctor}: ${displayName(r.doctorId)}');
      }
      if (appointment != null) {
        lines.add('${l10n.time}: ${appointment.startTime} - ${appointment.endTime}');
        if (appointment.servicesDisplay.trim().isNotEmpty) {
          lines.add('${l10n.services}: ${appointment.servicesDisplay}');
        }
        lines.add('${l10n.status}: ${_statusLabel(appointment.status.value, l10n)}');
      }
      if (r.sessionPaymentStatus != null && r.sessionPaymentStatus!.isNotEmpty) {
        lines.add('${l10n.sessionPayment}: ${_sessionPaymentStatusLabel(r.sessionPaymentStatus, l10n)}');
      }
      if (r.notes != null && r.notes!.trim().isNotEmpty) {
        lines.add('${l10n.notes}: ${r.notes!.trim()}');
      }
      return lines.join('\n');
    }

    String expenseDetails(ExpenseRecordModel r) {
      final lines = <String>[];
      if (r.paidByDoctorId != null && r.paidByDoctorId!.isNotEmpty) {
        lines.add('${l10n.paidByDoctor}: ${displayName(r.paidByDoctorId)}');
      }
      if (r.recipientName != null && r.recipientName!.trim().isNotEmpty) {
        lines.add('${l10n.patient}: ${r.recipientName!.trim()}');
      }
      if (r.description != null && r.description!.trim().isNotEmpty) {
        lines.add('${l10n.notes}: ${r.description!.trim()}');
      }
      return lines.join('\n');
    }

    // On web, cap data to avoid "Array buffer allocation failed" (browser memory limit).
    const int webPdfCap = 50;
    if (tabIndex == 0) {
      final allNames = _patientNames.toSet().toList()..sort();
      final names = kIsWeb && allNames.length > webPdfCap ? allNames.sublist(0, webPdfCap) : allNames;
      const int chunkSize = 25;
      if (names.isEmpty) {
        if (kIsWeb) await Future.delayed(Duration.zero);
        doc.addPage(
          pw.Page(
            pageFormat: PdfPageFormat.a4,
            margin: const pw.EdgeInsets.all(24),
            build: (context) => pw.Directionality(
              textDirection: isArabic ? pw.TextDirection.rtl : pw.TextDirection.ltr,
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pdfText(
                    '${l10n.patientsReport} ($periodLabel)',
                    fontSize: 16,
                    bold: true,
                    textDirection: isArabic ? pw.TextDirection.rtl : pw.TextDirection.ltr,
                  ),
                  pw.SizedBox(height: 8),
                  pw.Container(
                    padding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                    color: sectionGreen,
                    child: pdfText(
                      '${l10n.total}: 0 ${l10n.patient}',
                      fontSize: 12,
                      bold: true,
                      textDirection: isArabic ? pw.TextDirection.rtl : pw.TextDirection.ltr,
                    ),
                  ),
                  pw.SizedBox(height: 8),
                  pdfText(l10n.noData, fontSize: 10, textDirection: isArabic ? pw.TextDirection.rtl : pw.TextDirection.ltr),
                ],
              ),
            ),
          ),
        );
      }
      for (int start = 0; start < names.length; start += chunkSize) {
        final end = start + chunkSize > names.length ? names.length : start + chunkSize;
        final chunk = names.sublist(start, end);
        doc.addPage(
          pw.Page(
            pageFormat: PdfPageFormat.a4,
            margin: const pw.EdgeInsets.all(24),
            build: (context) => pw.Directionality(
              textDirection: isArabic ? pw.TextDirection.rtl : pw.TextDirection.ltr,
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  if (start == 0) ...[
                    pdfText(
                      '${l10n.patientsReport} ($periodLabel)',
                      fontSize: 16,
                      bold: true,
                      textDirection: isArabic ? pw.TextDirection.rtl : pw.TextDirection.ltr,
                    ),
                    pw.SizedBox(height: 8),
                    pw.Container(
                      padding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                      color: sectionGreen,
                      child: pdfText(
                        '${l10n.total}: ${names.length} ${l10n.patient}',
                        fontSize: 12,
                        bold: true,
                        textDirection: isArabic ? pw.TextDirection.rtl : pw.TextDirection.ltr,
                      ),
                    ),
                    pw.SizedBox(height: 8),
                  ],
                  pw.Table(
                    border: pw.TableBorder.all(color: PdfColors.grey400),
                    columnWidths: {0: const pw.FlexColumnWidth(2)},
                    children: [
                      if (start == 0)
                        pw.TableRow(
                          decoration: pw.BoxDecoration(color: headerBg),
                          children: [
                            pdfHeaderCell(l10n.patient, bg: headerBg, textColor: headerText),
                          ],
                        ),
                      ...chunk.asMap().entries.map(
                            (e) => pw.TableRow(
                              children: [pdfCell(e.value, alternate: (start + e.key).isOdd)],
                            ),
                          ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
        if (kIsWeb) await Future.delayed(Duration.zero);
      }
    } else if (tabIndex == 1) {
      final incomeTotal = _incomeTotal.isFinite ? _incomeTotal : 0.0;
      final expenseTotal = _expenseTotal.isFinite ? _expenseTotal : 0.0;
      final net = incomeTotal - expenseTotal;
      final nf = NumberFormat.currency(symbol: '', decimalDigits: 0);
      final incomeForPdf = kIsWeb && _income.length > webPdfCap ? _income.sublist(0, webPdfCap) : _income;
      final expensesForPdf = kIsWeb && _expenses.length > webPdfCap ? _expenses.sublist(0, webPdfCap) : _expenses;
      const int chunkSize = 25;
      if (kIsWeb) await Future.delayed(Duration.zero);
      doc.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(24),
          build: (context) => pw.Directionality(
            textDirection: isArabic ? pw.TextDirection.rtl : pw.TextDirection.ltr,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pdfText(
                  '${l10n.incomeExpensesReport} ($periodLabel)',
                  fontSize: 16,
                  bold: true,
                  textDirection: isArabic ? pw.TextDirection.rtl : pw.TextDirection.ltr,
                ),
                pw.SizedBox(height: 8),
                pw.Container(
                  padding: const pw.EdgeInsets.all(8),
                  color: sectionGreen,
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pdfText(
                        '${l10n.totalIncome}: ${nf.format(incomeTotal)}',
                        fontSize: 11,
                        textDirection: isArabic ? pw.TextDirection.rtl : pw.TextDirection.ltr,
                      ),
                      pdfText(
                        '${l10n.totalExpenses}: ${nf.format(expenseTotal)}',
                        fontSize: 11,
                        textDirection: isArabic ? pw.TextDirection.rtl : pw.TextDirection.ltr,
                      ),
                      pdfText(
                        '${l10n.net}: ${nf.format(net)}',
                        fontSize: 12,
                        bold: true,
                        textDirection: isArabic ? pw.TextDirection.rtl : pw.TextDirection.ltr,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
      for (int start = 0; start < incomeForPdf.length; start += chunkSize) {
        if (kIsWeb) await Future.delayed(Duration.zero);
        final end = start + chunkSize > incomeForPdf.length ? incomeForPdf.length : start + chunkSize;
        final chunk = incomeForPdf.sublist(start, end);
        doc.addPage(
          pw.Page(
            pageFormat: PdfPageFormat.a4,
            margin: const pw.EdgeInsets.all(24),
            build: (context) => pw.Directionality(
              textDirection: isArabic ? pw.TextDirection.rtl : pw.TextDirection.ltr,
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pdfText(
                    l10n.income,
                    fontSize: 12,
                    bold: true,
                    textDirection: isArabic ? pw.TextDirection.rtl : pw.TextDirection.ltr,
                  ),
                  pw.SizedBox(height: 6),
                  pw.Table(
                    border: pw.TableBorder.all(color: PdfColors.grey400),
                    columnWidths: {
                      0: const pw.FlexColumnWidth(1.2),
                      1: const pw.FlexColumnWidth(1.1),
                      2: const pw.FlexColumnWidth(3),
                      3: const pw.FlexColumnWidth(1),
                    },
                    children: [
                      pw.TableRow(
                        decoration: pw.BoxDecoration(color: headerBg),
                        children: [
                          pdfHeaderCell(l10n.date, bg: headerBg, textColor: headerText),
                          pdfHeaderCell(l10n.source, bg: headerBg, textColor: headerText),
                          pdfHeaderCell(l10n.notes, bg: headerBg, textColor: headerText),
                          pdfHeaderCell(l10n.amount, bg: headerBg, textColor: headerText),
                        ],
                      ),
                      ...chunk.asMap().entries.map(
                            (e) => pw.TableRow(
                              children: [
                                pdfCell(
                                  safeFormatDate(e.value.incomeDate),
                                  alternate: (start + e.key).isOdd,
                                  textDirection: pw.TextDirection.ltr,
                                ),
                                pdfCell(
                                  e.value.source,
                                  alternate: (start + e.key).isOdd,
                                ),
                                pdfCell(
                                  incomeDetails(e.value),
                                  alternate: (start + e.key).isOdd,
                                ),
                                pdfCell(
                                  nf.format(e.value.amount.isFinite ? e.value.amount : 0),
                                  alternate: (start + e.key).isOdd,
                                  textDirection: pw.TextDirection.ltr,
                                ),
                              ],
                            ),
                          ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      }
      for (int start = 0; start < expensesForPdf.length; start += chunkSize) {
        if (kIsWeb) await Future.delayed(Duration.zero);
        final end = start + chunkSize > expensesForPdf.length ? expensesForPdf.length : start + chunkSize;
        final chunk = expensesForPdf.sublist(start, end);
        doc.addPage(
          pw.Page(
            pageFormat: PdfPageFormat.a4,
            margin: const pw.EdgeInsets.all(24),
            build: (context) => pw.Directionality(
              textDirection: isArabic ? pw.TextDirection.rtl : pw.TextDirection.ltr,
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pdfText(
                    l10n.expenses,
                    fontSize: 12,
                    bold: true,
                    textDirection: isArabic ? pw.TextDirection.rtl : pw.TextDirection.ltr,
                  ),
                  pw.SizedBox(height: 6),
                  pw.Table(
                    border: pw.TableBorder.all(color: PdfColors.grey400),
                    columnWidths: {
                      0: const pw.FlexColumnWidth(1.2),
                      1: const pw.FlexColumnWidth(1.3),
                      2: const pw.FlexColumnWidth(2.7),
                      3: const pw.FlexColumnWidth(1),
                    },
                    children: [
                      pw.TableRow(
                        decoration: pw.BoxDecoration(color: headerBg),
                        children: [
                          pdfHeaderCell(l10n.date, bg: headerBg, textColor: headerText),
                          pdfHeaderCell(l10n.category, bg: headerBg, textColor: headerText),
                          pdfHeaderCell(l10n.notes, bg: headerBg, textColor: headerText),
                          pdfHeaderCell(l10n.amount, bg: headerBg, textColor: headerText),
                        ],
                      ),
                      ...chunk.asMap().entries.map(
                            (e) => pw.TableRow(
                              children: [
                                pdfCell(
                                  safeFormatDate(e.value.expenseDate),
                                  alternate: (start + e.key).isOdd,
                                  textDirection: pw.TextDirection.ltr,
                                ),
                                pdfCell(
                                  e.value.category,
                                  alternate: (start + e.key).isOdd,
                                ),
                                pdfCell(
                                  expenseDetails(e.value),
                                  alternate: (start + e.key).isOdd,
                                ),
                                pdfCell(
                                  nf.format(e.value.amount.isFinite ? e.value.amount : 0),
                                  alternate: (start + e.key).isOdd,
                                  textDirection: pw.TextDirection.ltr,
                                ),
                              ],
                            ),
                          ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      }
    } else if (tabIndex == 2) {
      final appointmentsForPdf = kIsWeb && _appointments.length > webPdfCap ? _appointments.sublist(0, webPdfCap) : _appointments;
      const int chunkSize = 25;
      if (appointmentsForPdf.isEmpty) {
        if (kIsWeb) await Future.delayed(Duration.zero);
        doc.addPage(
          pw.Page(
            pageFormat: PdfPageFormat.a4,
            margin: const pw.EdgeInsets.all(24),
            build: (context) => pw.Directionality(
              textDirection: isArabic ? pw.TextDirection.rtl : pw.TextDirection.ltr,
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pdfText(
                    '${l10n.appointmentsReport} ($periodLabel)',
                    fontSize: 16,
                    bold: true,
                    textDirection: isArabic ? pw.TextDirection.rtl : pw.TextDirection.ltr,
                  ),
                  pw.SizedBox(height: 8),
                  pw.Container(
                    padding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                    color: sectionGreen,
                    child: pdfText(
                      '${l10n.total}: 0 ${l10n.appointments}',
                      fontSize: 12,
                      bold: true,
                      textDirection: isArabic ? pw.TextDirection.rtl : pw.TextDirection.ltr,
                    ),
                  ),
                  pw.SizedBox(height: 8),
                  pdfText(l10n.noData, fontSize: 10, textDirection: isArabic ? pw.TextDirection.rtl : pw.TextDirection.ltr),
                ],
              ),
            ),
          ),
        );
      }
      for (int start = 0; start < appointmentsForPdf.length; start += chunkSize) {
        if (kIsWeb) await Future.delayed(Duration.zero);
        final end = start + chunkSize > appointmentsForPdf.length ? appointmentsForPdf.length : start + chunkSize;
        final chunk = appointmentsForPdf.sublist(start, end);
        doc.addPage(
          pw.Page(
            pageFormat: PdfPageFormat.a4,
            margin: const pw.EdgeInsets.all(24),
            build: (context) => pw.Directionality(
              textDirection: isArabic ? pw.TextDirection.rtl : pw.TextDirection.ltr,
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  if (start == 0) ...[
                    pdfText(
                      '${l10n.appointmentsReport} ($periodLabel)',
                      fontSize: 16,
                      bold: true,
                      textDirection: isArabic ? pw.TextDirection.rtl : pw.TextDirection.ltr,
                    ),
                    pw.SizedBox(height: 8),
                    pw.Container(
                      padding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                      color: sectionGreen,
                      child: pdfText(
                        '${l10n.total}: ${appointmentsForPdf.length} ${l10n.appointments}',
                        fontSize: 12,
                        bold: true,
                        textDirection: isArabic ? pw.TextDirection.rtl : pw.TextDirection.ltr,
                      ),
                    ),
                    pw.SizedBox(height: 8),
                  ],
                  pw.Table(
                    border: pw.TableBorder.all(color: PdfColors.grey400),
                    columnWidths: {
                      0: const pw.FlexColumnWidth(1),
                      1: const pw.FlexColumnWidth(1),
                      2: const pw.FlexColumnWidth(1),
                      3: const pw.FlexColumnWidth(1),
                    },
                    children: [
                      if (start == 0)
                        pw.TableRow(
                          decoration: pw.BoxDecoration(color: headerBg),
                          children: [
                            pdfHeaderCell(l10n.date, bg: headerBg, textColor: headerText),
                            pdfHeaderCell(l10n.time, bg: headerBg, textColor: headerText),
                            pdfHeaderCell(l10n.status, bg: headerBg, textColor: headerText),
                            pdfHeaderCell(l10n.service, bg: headerBg, textColor: headerText),
                          ],
                        ),
                      ...chunk.asMap().entries.map(
                            (e) => pw.TableRow(
                              children: [
                                pdfCell(
                                  safeFormatDate(e.value.appointmentDate),
                                  alternate: (start + e.key).isOdd,
                                  textDirection: pw.TextDirection.ltr,
                                ),
                                pdfCell(
                                  '${e.value.startTime}-${e.value.endTime}',
                                  alternate: (start + e.key).isOdd,
                                  textDirection: pw.TextDirection.ltr,
                                ),
                                pdfCell(
                                  _statusLabel(e.value.status.value, l10n),
                                  alternate: (start + e.key).isOdd,
                                ),
                                pdfCell(
                                  e.value.servicesDisplay,
                                  alternate: (start + e.key).isOdd,
                                ),
                              ],
                            ),
                          ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      }
    } else {
      final usersForPdf = kIsWeb && _users.length > webPdfCap ? _users.sublist(0, webPdfCap) : _users;
      const int chunkSize = 25;
      if (usersForPdf.isEmpty) {
        if (kIsWeb) await Future.delayed(Duration.zero);
        doc.addPage(
          pw.Page(
            pageFormat: PdfPageFormat.a4,
            margin: const pw.EdgeInsets.all(24),
            build: (context) => pw.Directionality(
              textDirection: isArabic ? pw.TextDirection.rtl : pw.TextDirection.ltr,
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pdfText(
                    l10n.usersReport,
                    fontSize: 16,
                    bold: true,
                    textDirection: isArabic ? pw.TextDirection.rtl : pw.TextDirection.ltr,
                  ),
                  pw.SizedBox(height: 8),
                  pw.Container(
                    padding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                    color: sectionGreen,
                    child: pdfText(
                      '${l10n.total}: 0 ${l10n.users}',
                      fontSize: 12,
                      bold: true,
                      textDirection: isArabic ? pw.TextDirection.rtl : pw.TextDirection.ltr,
                    ),
                  ),
                  pw.SizedBox(height: 8),
                  pdfText(l10n.noData, fontSize: 10, textDirection: isArabic ? pw.TextDirection.rtl : pw.TextDirection.ltr),
                ],
              ),
            ),
          ),
        );
      }
      for (int start = 0; start < usersForPdf.length; start += chunkSize) {
        if (kIsWeb) await Future.delayed(Duration.zero);
        final end = start + chunkSize > usersForPdf.length ? usersForPdf.length : start + chunkSize;
        final chunk = usersForPdf.sublist(start, end);
        doc.addPage(
          pw.Page(
            pageFormat: PdfPageFormat.a4,
            margin: const pw.EdgeInsets.all(24),
            build: (context) => pw.Directionality(
              textDirection: isArabic ? pw.TextDirection.rtl : pw.TextDirection.ltr,
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  if (start == 0) ...[
                    pdfText(
                      l10n.usersReport,
                      fontSize: 16,
                      bold: true,
                      textDirection: isArabic ? pw.TextDirection.rtl : pw.TextDirection.ltr,
                    ),
                    pw.SizedBox(height: 8),
                    pw.Container(
                      padding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                      color: sectionGreen,
                      child: pdfText(
                        '${l10n.total}: ${usersForPdf.length} ${l10n.users}',
                        fontSize: 12,
                        bold: true,
                        textDirection: isArabic ? pw.TextDirection.rtl : pw.TextDirection.ltr,
                      ),
                    ),
                    pw.SizedBox(height: 8),
                  ],
                  pw.Table(
                    border: pw.TableBorder.all(color: PdfColors.grey400),
                    columnWidths: {
                      0: const pw.FlexColumnWidth(2),
                      1: const pw.FlexColumnWidth(2),
                      2: const pw.FlexColumnWidth(2),
                      3: const pw.FlexColumnWidth(1),
                    },
                    children: [
                      if (start == 0)
                        pw.TableRow(
                          decoration: pw.BoxDecoration(color: headerBg),
                          children: [
                            pdfHeaderCell(l10n.fullNameAr, bg: headerBg, textColor: headerText),
                            pdfHeaderCell(l10n.fullNameEn, bg: headerBg, textColor: headerText),
                            pdfHeaderCell(l10n.email, bg: headerBg, textColor: headerText),
                            pdfHeaderCell(l10n.role, bg: headerBg, textColor: headerText),
                          ],
                        ),
                      ...chunk.asMap().entries.map((e) {
                        final alt = (start + e.key).isOdd;
                        final u = e.value;
                        return pw.TableRow(
                          children: [
                            pdfCell(u.fullNameAr ?? '', alternate: alt),
                            pdfCell(u.fullNameEn ?? '', alternate: alt, textDirection: pw.TextDirection.ltr),
                            pdfCell(u.email, alternate: alt, textDirection: pw.TextDirection.ltr),
                            pdfCell(u.roles.join(', '), alternate: alt, textDirection: pw.TextDirection.ltr),
                          ],
                        );
                      }),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      }
    }

    if (kIsWeb) await Future.delayed(Duration.zero);
    final bytes = await doc.save();
    if (mounted) Navigator.of(context).pop();
    final filename = 'report_${tabIndex}_${from.millisecondsSinceEpoch}.pdf';
    await savePdfAndShare(filename, bytes, shareOrigin);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('PDF ready — download or share')),
      );
    }
  } catch (e) {
    if (mounted) Navigator.of(context).pop();
    rethrow;
  }
  }

  Future<void> _exportCurrentAsExcel(AppLocalizations l10n, Rect? shareOrigin) async {
    if (kIsWeb) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Excel export is available on mobile and desktop. Use PDF or CSV export on web.')),
        );
      }
      return;
    }
    final (from, to) = _range();
    final periodLabel = '${AppDateFormat.shortDate.format(from)} - ${AppDateFormat.shortDate.format(to)}';
    final excel = Excel.createExcel();
    final sheet = excel['Sheet1'];
    final int tabIndex = _tabController.index;

    if (tabIndex == 0) {
      final names = _patientNames.toSet().toList()..sort();
      sheet.appendRow([TextCellValue(l10n.patientsReport), TextCellValue(periodLabel)]);
      sheet.appendRow([TextCellValue('${l10n.total}: ${names.length}')]);
      sheet.appendRow([TextCellValue(l10n.patient)]);
      for (final n in names) {
        sheet.appendRow([TextCellValue(n)]);
      }
    } else if (tabIndex == 1) {
      sheet.appendRow([TextCellValue(l10n.incomeExpensesReport), TextCellValue(periodLabel)]);
      sheet.appendRow([TextCellValue(l10n.totalIncome), TextCellValue(NumberFormat.currency(symbol: '').format(_incomeTotal))]);
      sheet.appendRow([TextCellValue(l10n.totalExpenses), TextCellValue(NumberFormat.currency(symbol: '').format(_expenseTotal))]);
      sheet.appendRow([TextCellValue(l10n.net), TextCellValue(NumberFormat.currency(symbol: '').format(_incomeTotal - _expenseTotal))]);
      sheet.appendRow([]);
      sheet.appendRow([TextCellValue(l10n.income)]);
      sheet.appendRow([TextCellValue(l10n.source), TextCellValue(l10n.date), TextCellValue(l10n.amount)]);
      for (final r in _income) {
        sheet.appendRow([
          TextCellValue(r.source),
          TextCellValue(AppDateFormat.shortDate.format(r.incomeDate)),
          TextCellValue(r.amount.toString()),
        ]);
      }
      sheet.appendRow([]);
      sheet.appendRow([TextCellValue(l10n.expenses)]);
      sheet.appendRow([TextCellValue(l10n.category), TextCellValue(l10n.date), TextCellValue(l10n.amount)]);
      for (final r in _expenses) {
        sheet.appendRow([
          TextCellValue(r.category),
          TextCellValue(AppDateFormat.shortDate.format(r.expenseDate)),
          TextCellValue(r.amount.toString()),
        ]);
      }
    } else if (tabIndex == 2) {
      sheet.appendRow([TextCellValue(l10n.appointmentsReport), TextCellValue(periodLabel)]);
      sheet.appendRow([TextCellValue(l10n.date), TextCellValue(l10n.time), TextCellValue(l10n.status), TextCellValue(l10n.service)]);
      for (final a in _appointments) {
        sheet.appendRow([
          TextCellValue(AppDateFormat.shortDate.format(a.appointmentDate)),
          TextCellValue('${a.startTime} - ${a.endTime}'),
          TextCellValue(_statusLabel(a.status.value, l10n)),
          TextCellValue(a.servicesDisplay),
        ]);
      }
    } else {
      sheet.appendRow([TextCellValue(l10n.usersReport)]);
      sheet.appendRow([TextCellValue(l10n.fullNameAr), TextCellValue(l10n.fullNameEn), TextCellValue(l10n.email), TextCellValue(l10n.role)]);
      for (final u in _users) {
        sheet.appendRow([
          TextCellValue(u.fullNameAr ?? ''),
          TextCellValue(u.fullNameEn ?? ''),
          TextCellValue(u.email),
          TextCellValue(u.roles.join(', ')),
        ]);
      }
    }

    final bytes = excel.encode();
    if (bytes == null) return;
    final path = await report_io.writeReportBytes('report_${tabIndex}_$from.xlsx', bytes);
    if (path == null || !mounted) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Excel export is available on mobile and desktop. Use CSV on web.')),
        );
      }
      return;
    }
    await Share.shareXFiles([XFile(path)], sharePositionOrigin: shareOrigin);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isRtl = l10n.isArabic;

    return Directionality(
      textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        appBar: AppBar(
          title: Text(l10n.reports),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () {
              if (context.canPop()) {
                context.pop();
              } else {
                context.go('/dashboard');
              }
            },
          ),
          actions: [
            const NotificationsButton(),
            PopupMenuButton<String>(
              icon: const Icon(Icons.upload),
              tooltip: l10n.export,
              onSelected: (v) async {
                final shareOrigin = _sharePositionOriginFrom(context);
                final showOverlay = v != 'pdf' && v != 'excel';
                if (showOverlay && mounted) {
                  showDialog(
                    context: context,
                    barrierDismissible: false,
                    builder: (ctx) => PopScope(
                      canPop: false,
                      child: AlertDialog(
                        content: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2)),
                            const SizedBox(width: 24),
                            Expanded(child: Text(l10n.export)),
                          ],
                        ),
                      ),
                    ),
                  );
                  await Future.delayed(const Duration(milliseconds: 150));
                }
                try {
                  if (v == 'income') await _exportIncome(l10n, shareOrigin);
                  if (v == 'appointments') await _exportAppointments(l10n, shareOrigin);
                  if (v == 'patients') await _exportPatients(l10n, shareOrigin);
                  if (v == 'users') await _exportUsers(l10n, shareOrigin);
                  if (v == 'audit') await _exportAuditLog(l10n, shareOrigin);
                  if (v == 'pdf') await _exportCurrentAsPdf(l10n, shareOrigin);
                  if (v == 'excel') await _exportCurrentAsExcel(l10n, shareOrigin);

                  if (showOverlay && mounted) Navigator.of(context).pop();
                  if (context.mounted && v != 'pdf' && v != 'excel') {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Export ready — use share sheet to save or send')),
                    );
                  }
                  if (context.mounted && (v == 'pdf' || v == 'excel')) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(v == 'pdf' ? 'PDF export ready' : 'Excel export ready')),
                    );
                  }
                } catch (e, st) {
                  if (showOverlay && mounted) Navigator.of(context).pop();
                  debugPrint('Export error: $e\n$st');
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(AppLocalizations.of(context).generalErrorMessage(generalErrorToMessageKey(e))),
                        duration: const Duration(seconds: 5),
                      ),
                    );
                  }
                }
              },
              itemBuilder: (context) => [
                PopupMenuItem(value: 'income', child: Text(l10n.exportIncomeExpense)),
                PopupMenuItem(value: 'appointments', child: Text(l10n.exportAppointments)),
                PopupMenuItem(value: 'patients', child: Text(l10n.exportPatients)),
                PopupMenuItem(value: 'users', child: Text(l10n.exportUsers)),
                PopupMenuItem(value: 'audit', child: Text(l10n.exportAuditLog)),
                const PopupMenuDivider(),
                const PopupMenuItem(value: 'pdf', child: Text('Export current tab as PDF')),
                const PopupMenuItem(value: 'excel', child: Text('Export current tab as Excel')),
              ],
            ),
          ],
          bottom: TabBar(
            controller: _tabController,
            isScrollable: true,
            tabs: [
              Tab(text: l10n.patientsReport),
              Tab(text: l10n.incomeExpensesReport),
              Tab(text: l10n.appointmentsReport),
              Tab(text: l10n.usersReport),
            ],
          ),
        ),
        body: Column(
          children: [
            Padding(
              padding: ResponsivePadding.all(context),
              child: Wrap(
                spacing: 12,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  DropdownButton<String>(
                    value: _period,
                    items: [
                      DropdownMenuItem(value: 'day', child: Text(l10n.day)),
                      DropdownMenuItem(value: 'month', child: Text(l10n.month)),
                      DropdownMenuItem(value: 'year', child: Text(l10n.year)),
                    ],
                    onChanged: (v) {
                      if (v != null) {
                        setState(() {
                          _period = v;
                          _load();
                        });
                      }
                    },
                  ),
                  TextButton.icon(
                    icon: const Icon(Icons.calendar_today),
                    label: Text(_periodLabel()),
                    onPressed: () => _pickPeriod(context),
                  ),
                ],
              ),
            ),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : TabBarView(
                      controller: _tabController,
                      children: [
                        _patientsTab(l10n),
                        _incomeExpensesTab(l10n),
                        _appointmentsTab(l10n),
                        _usersTab(l10n),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _patientsTab(AppLocalizations l10n) {
    final uniqueNames = _patientNames.toSet().toList()..sort();
    return RefreshIndicator(
      onRefresh: _load,
      child: SingleChildScrollView(
        padding: ResponsivePadding.all(context),
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  '${l10n.total}: ${uniqueNames.length} ${l10n.patient.toLowerCase()}',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
            ),
            const SizedBox(height: 8),
            ...uniqueNames.map(
              (name) => Card(
                  child: ListTile(title: Text(name)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _incomeExpensesTab(AppLocalizations l10n) {
    final net = _incomeTotal - _expenseTotal;
    return RefreshIndicator(
      onRefresh: _load,
      child: SingleChildScrollView(
        padding: ResponsivePadding.all(context),
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${l10n.totalIncome}: ${NumberFormat.currency(symbol: '').format(_incomeTotal)}',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${l10n.totalExpenses}: ${NumberFormat.currency(symbol: '').format(_expenseTotal)}',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${l10n.net}: ${NumberFormat.currency(symbol: '').format(net)}',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(l10n.income, style: Theme.of(context).textTheme.titleSmall),
            if (_income.isEmpty)
              Card(child: Padding(padding: const EdgeInsets.all(16), child: Text(l10n.noData)))
            else
              ..._income.map(
                (r) => Card(
                    child: ListTile(
                      title: Text(r.source),
                    subtitle: Text(AppDateFormat.shortDate.format(r.incomeDate)),
                      trailing: Text(NumberFormat.currency(symbol: '').format(r.amount)),
                    ),
                ),
              ),
            const SizedBox(height: 16),
            Text(l10n.expenses, style: Theme.of(context).textTheme.titleSmall),
            if (_expenses.isEmpty)
              Card(child: Padding(padding: const EdgeInsets.all(16), child: Text(l10n.noData)))
            else
              ..._expenses.map(
                (r) => Card(
                    child: ListTile(
                    title: Text(
                      r.category == 'Salary' && r.recipientName != null && r.recipientName!.isNotEmpty
                          ? 'Salary – ${r.recipientName}'
                          : r.category,
                    ),
                    subtitle: Text(AppDateFormat.shortDate.format(r.expenseDate)),
                      trailing: Text(NumberFormat.currency(symbol: '').format(r.amount)),
                    ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _appointmentsTab(AppLocalizations l10n) {
    return RefreshIndicator(
      onRefresh: _load,
      child: SingleChildScrollView(
        padding: ResponsivePadding.all(context),
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${l10n.total}: ${_appointments.length} ${l10n.appointments.toLowerCase()}',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    if (_appointmentsByStatus.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(l10n.byStatus, style: Theme.of(context).textTheme.titleSmall),
                      ..._appointmentsByStatus.entries.map(
                        (e) => Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(_statusLabel(e.key, l10n)),
                                Text('${e.value}'),
                              ],
                            ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            if (_appointments.isEmpty)
              Card(child: Padding(padding: const EdgeInsets.all(16), child: Text(l10n.noData)))
            else
              ..._appointments.take(50).map(
                (a) => Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                    title: Text(AppDateFormat.shortDate.format(a.appointmentDate)),
                    subtitle: Text(
                      '${a.startTime} - ${a.endTime} • ${_statusLabel(a.status.value, l10n)} ${a.hasServices ? '• ${a.servicesDisplay}' : ''}',
                    ),
                      trailing: Text(a.status.value),
                    ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _usersTab(AppLocalizations l10n) {
    return RefreshIndicator(
      onRefresh: _load,
      child: SingleChildScrollView(
        padding: ResponsivePadding.all(context),
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${l10n.total}: ${_users.length} ${l10n.users.toLowerCase()}',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    if (_usersByRole.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(l10n.role, style: Theme.of(context).textTheme.titleSmall),
                      ..._usersByRole.entries.map(
                        (e) => Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(e.key),
                                Text('${e.value}'),
                              ],
                            ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            if (_users.isEmpty)
              Card(child: Padding(padding: const EdgeInsets.all(16), child: Text(l10n.noData)))
            else
              ..._users.map(
                (u) => Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      title: Text(u.displayName),
                      subtitle: Text('${u.email} • ${u.roles.map((r) => l10n.roleDisplay(r)).join(", ")}'),
                      trailing: u.isActive ? null : Chip(label: Text(l10n.inactive, style: const TextStyle(fontSize: 12))),
                    ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _MonthYearPickerDialog extends StatefulWidget {
  const _MonthYearPickerDialog({required this.initial, required this.l10n, required this.now});

  final DateTime initial;
  final AppLocalizations l10n;
  final DateTime now;

  @override
  State<_MonthYearPickerDialog> createState() => _MonthYearPickerDialogState();
}

class _MonthYearPickerDialogState extends State<_MonthYearPickerDialog> {
  late int _year;
  late int _month;

  @override
  void initState() {
    super.initState();
    _year = widget.initial.year;
    _month = widget.initial.month;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.l10n.month),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DropdownButton<int>(
            value: _month,
            isExpanded: true,
            items: List.generate(12, (i) => i + 1)
                .map((m) => DropdownMenuItem(value: m, child: Text(AppDateFormat.monthName().format(DateTime(2000, m)))))
                .toList(),
            onChanged: (v) => setState(() => _month = v ?? _month),
          ),
          const SizedBox(height: 8),
          DropdownButton<int>(
            value: _year,
            isExpanded: true,
            items: List.generate(widget.now.year - 2020 + 2, (i) => 2020 + i)
                .map((y) => DropdownMenuItem(value: y, child: Text('$y')))
                .toList(),
            onChanged: (v) => setState(() => _year = v ?? _year),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(widget.l10n.cancel)),
        FilledButton(
          onPressed: () => Navigator.pop(context, DateTime(_year, _month, 1)),
          child: Text(widget.l10n.confirm),
        ),
      ],
    );
  }
}

class _YearPickerDialog extends StatefulWidget {
  const _YearPickerDialog({required this.initial, required this.l10n, required this.now});

  final int initial;
  final AppLocalizations l10n;
  final DateTime now;

  @override
  State<_YearPickerDialog> createState() => _YearPickerDialogState();
}

class _YearPickerDialogState extends State<_YearPickerDialog> {
  late int _year;

  @override
  void initState() {
    super.initState();
    _year = widget.initial;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.l10n.year),
      content: DropdownButton<int>(
        value: _year,
        isExpanded: true,
        items: List.generate(widget.now.year - 2020 + 2, (i) => 2020 + i)
            .map((y) => DropdownMenuItem(value: y, child: Text('$y')))
            .toList(),
        onChanged: (v) => setState(() => _year = v ?? _year),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(widget.l10n.cancel)),
        FilledButton(onPressed: () => Navigator.pop(context, _year), child: Text(widget.l10n.confirm)),
      ],
    );
  }
}