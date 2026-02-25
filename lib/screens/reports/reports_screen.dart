import 'package:excel/excel.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:go_router/go_router.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';
import '../../core/responsive.dart';
import '../../l10n/app_localizations.dart';
import '../../models/appointment_model.dart';
import '../../models/income_expense_models.dart';
import '../../models/user_model.dart';
import '../../services/firestore_service.dart';
import 'package:intl/intl.dart' hide TextDirection;

import 'report_file_io_stub.dart' if (dart.library.io) 'report_file_io.dart' as report_io;

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

  (DateTime, DateTime) _range() {
    if (_period == 'day') {
      final s = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day);
      return (s, s.add(const Duration(days: 1)));
    }
    if (_period == 'month') {
      final s = DateTime(_selectedDate.year, _selectedDate.month, 1);
      final e = DateTime(_selectedDate.year, _selectedDate.month + 1, 0).add(const Duration(days: 1));
      return (s, e);
    }
    final s = DateTime(_selectedDate.year, 1, 1);
    final e = DateTime(_selectedDate.year, 12, 31).add(const Duration(days: 1));
    return (s, e);
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final (from, to) = _range();
    try {
      final appointments = await _firestore.getAppointments(from: from, to: to);
      final patientIds = appointments.map((a) => a.patientId).toSet().toList();
      final names = <String, String>{};
      for (final id in patientIds) {
        final u = await _firestore.getUser(id);
        if (u != null) names[id] = u.displayName;
      }
      final income = await _firestore.getIncomeRecords(from: from, to: to);
      final expenses = await _firestore.getExpenseRecords(from: from, to: to);
      final incomeTotal = income.fold<double>(0, (s, r) => s + r.amount);
      final expenseTotal = expenses.fold<double>(0, (s, r) => s + r.amount);

      final byStatus = <String, int>{};
      for (final a in appointments) {
        byStatus[a.status.value] = (byStatus[a.status.value] ?? 0) + 1;
      }

      final users = await _firestore.getUsers();
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
      sb.writeln('${DateFormat.yMd().format(r.incomeDate)},Income,${r.amount},${r.source},${r.notes ?? ''}');
    }
    for (final r in expense) {
      sb.writeln('${DateFormat.yMd().format(r.expenseDate)},Expense,${r.amount},${r.category},${r.description ?? ''}');
    }
    await Share.share(sb.toString(), subject: '${l10n.exportIncomeExpense} ${DateFormat.yMd().format(from)} - ${DateFormat.yMd().format(to)}', sharePositionOrigin: sharePositionOrigin);
  }

  Future<void> _exportAppointments(AppLocalizations l10n, [Rect? sharePositionOrigin]) async {
    final (from, to) = _range();
    final appointments = await _firestore.getAppointments(from: from, to: to);
    final sb = StringBuffer();
    sb.writeln('Date,Start,End,PatientId,DoctorId,Status,Service');
    for (final a in appointments) {
      sb.writeln('${DateFormat.yMd().format(a.appointmentDate)},${a.startTime},${a.endTime},${a.patientId},${a.doctorId},${a.status.value},${a.service ?? ''}');
    }
    await Share.share(sb.toString(), subject: '${l10n.exportAppointments} ${DateFormat.yMd().format(from)} - ${DateFormat.yMd().format(to)}', sharePositionOrigin: sharePositionOrigin);
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
    await Share.share(sb.toString(), subject: '${l10n.exportPatients} ${DateFormat.yMd().format(from)} - ${DateFormat.yMd().format(to)}', sharePositionOrigin: sharePositionOrigin);
  }

  Future<void> _exportUsers(AppLocalizations l10n, [Rect? sharePositionOrigin]) async {
    final users = await _firestore.getUsers();
    final sb = StringBuffer();
    sb.writeln('Id,Email,FullNameAr,FullNameEn,Phone,Roles,Active');
    for (final u in users) {
      sb.writeln('${u.id},${u.email},${u.fullNameAr ?? ''},${u.fullNameEn ?? ''},${u.phone ?? ''},${u.roles.join(";")},${u.isActive}');
    }
    await Share.share(sb.toString(), subject: l10n.exportUsers, sharePositionOrigin: sharePositionOrigin);
  }

  Future<void> _exportAuditLog(AppLocalizations l10n, [Rect? sharePositionOrigin]) async {
    final logs = await _firestore.getAuditLogs(limit: 500);
    final sb = StringBuffer();
    sb.writeln('CreatedAt,Action,EntityType,EntityId,UserId,UserEmail,Details');
    for (final e in logs) {
      final details = e.details != null ? e.details!.toString().replaceAll(',', ';') : '';
      sb.writeln('${e.createdAt != null ? DateFormat.yMd().add_Hms().format(e.createdAt!) : ''},${e.action},${e.entityType},${e.entityId ?? ''},${e.userId},${e.userEmail ?? ''},$details');
    }
    await Share.share(sb.toString(), subject: l10n.exportAuditLog, sharePositionOrigin: sharePositionOrigin);
  }

  String _statusLabel(String value, AppLocalizations l10n) {
    switch (value) {
      case 'pending': return l10n.pending;
      case 'confirmed': return l10n.confirmed;
      case 'completed': return l10n.completed;
      case 'cancelled': return l10n.cancelled;
      case 'no_show': return l10n.noShow;
      default: return value;
    }
  }

  Future<void> _exportCurrentAsPdf(AppLocalizations l10n, Rect? shareOrigin) async {
    final (from, to) = _range();
    final periodLabel = '${DateFormat.yMd().format(from)} - ${DateFormat.yMd().format(to)}';
    // Use a static TTF (Amiri) for Arabic; dart_pdf does not support variable fonts.
    pw.ThemeData? pdfTheme;
    try {
      final fontData = await rootBundle.load('assets/fonts/Amiri-Regular.ttf');
      final baseFont = pw.Font.ttf(fontData);
      pdfTheme = pw.ThemeData.withFont(base: baseFont, fontFallback: [baseFont]);
    } catch (_) {
      // Fallback: no custom theme (Arabic may render as replacement glyphs)
    }
    final doc = pw.Document(theme: pdfTheme);
    final int tabIndex = _tabController.index;

    if (tabIndex == 0) {
      final names = _patientNames.toSet().toList()..sort();
      doc.addPage(pw.MultiPage(
        build: (context) => [
          pw.Text('${l10n.patientsReport} ($periodLabel)', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 8),
          pw.Text('${l10n.total}: ${names.length} ${l10n.patient}', style: pw.TextStyle(fontSize: 12)),
          pw.SizedBox(height: 8),
          pw.Table(border: pw.TableBorder.all(), columnWidths: {0: const pw.FlexColumnWidth(2)}, children: [
            pw.TableRow(children: [pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text(l10n.patient, style: pw.TextStyle(fontWeight: pw.FontWeight.bold)))]),
            ...names.map((n) => pw.TableRow(children: [pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text(n, textDirection: pw.TextDirection.rtl, textAlign: pw.TextAlign.right))])),
          ]),
        ],
      ));
    } else if (tabIndex == 1) {
      final net = _incomeTotal - _expenseTotal;
      doc.addPage(pw.MultiPage(
        build: (context) => [
          pw.Text('${l10n.incomeExpensesReport} ($periodLabel)', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 8),
          pw.Text('${l10n.totalIncome}: ${NumberFormat.currency(symbol: '').format(_incomeTotal)}'),
          pw.Text('${l10n.totalExpenses}: ${NumberFormat.currency(symbol: '').format(_expenseTotal)}'),
          pw.Text('${l10n.net}: ${NumberFormat.currency(symbol: '').format(net)}', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 12),
          pw.Text(l10n.income, style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
          pw.Table(border: pw.TableBorder.all(), columnWidths: {0: const pw.FlexColumnWidth(2), 1: const pw.FlexColumnWidth(1), 2: const pw.FlexColumnWidth(1)}, children: [
            pw.TableRow(children: [pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text(l10n.source)), pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text(l10n.date)), pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text(l10n.amount))]),
            ..._income.map((r) => pw.TableRow(children: [pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text(r.source)), pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text(DateFormat.yMd().format(r.incomeDate))), pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text(NumberFormat.currency(symbol: '').format(r.amount)))])),
          ]),
          pw.SizedBox(height: 12),
          pw.Text(l10n.expenses, style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
          pw.Table(border: pw.TableBorder.all(), columnWidths: {0: const pw.FlexColumnWidth(2), 1: const pw.FlexColumnWidth(1), 2: const pw.FlexColumnWidth(1)}, children: [
            pw.TableRow(children: [pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text(l10n.category)), pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text(l10n.date)), pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text(l10n.amount))]),
            ..._expenses.map((r) => pw.TableRow(children: [pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text(r.category)), pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text(DateFormat.yMd().format(r.expenseDate))), pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text(NumberFormat.currency(symbol: '').format(r.amount)))])),
          ]),
        ],
      ));
    } else if (tabIndex == 2) {
      doc.addPage(pw.MultiPage(
        build: (context) => [
          pw.Text('${l10n.appointmentsReport} ($periodLabel)', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 8),
          pw.Text('${l10n.total}: ${_appointments.length} ${l10n.appointments}'),
          pw.SizedBox(height: 8),
          pw.Table(border: pw.TableBorder.all(), columnWidths: {0: const pw.FlexColumnWidth(1), 1: const pw.FlexColumnWidth(1), 2: const pw.FlexColumnWidth(1), 3: const pw.FlexColumnWidth(1)}, children: [
            pw.TableRow(children: [pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text(l10n.date)), pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text(l10n.time)), pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text(l10n.status)), pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text(l10n.service))]),
            ..._appointments.take(100).map((a) => pw.TableRow(children: [pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text(DateFormat.yMd().format(a.appointmentDate))), pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text('${a.startTime}-${a.endTime}')), pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text(_statusLabel(a.status.value, l10n))), pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text(a.service ?? ''))])),
          ]),
        ],
      ));
    } else {
      doc.addPage(pw.MultiPage(
        build: (context) => [
          pw.Text(l10n.usersReport, style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 8),
          pw.Text('${l10n.total}: ${_users.length} ${l10n.users}'),
          pw.SizedBox(height: 8),
          pw.Table(border: pw.TableBorder.all(), columnWidths: {0: const pw.FlexColumnWidth(3), 1: const pw.FlexColumnWidth(2), 2: const pw.FlexColumnWidth(1)}, children: [
            pw.TableRow(children: [pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text(l10n.fullNameEn)), pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text(l10n.email)), pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text(l10n.role))]),
            ..._users.map((u) => pw.TableRow(children: [pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text(u.displayName, textDirection: pw.TextDirection.rtl, textAlign: pw.TextAlign.right)), pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text(u.email)), pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text(u.roles.join(', ')))])),
          ]),
        ],
      ));
    }

    final bytes = await doc.save();
    final path = await report_io.writeReportBytes('report_${tabIndex}_$from.pdf', bytes);
    if (path == null || !mounted) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('PDF export is available on mobile and desktop. Use CSV on web.')));
      return;
    }
    await Share.shareXFiles([XFile(path)], sharePositionOrigin: shareOrigin);
  }

  Future<void> _exportCurrentAsExcel(AppLocalizations l10n, Rect? shareOrigin) async {
    final (from, to) = _range();
    final periodLabel = '${DateFormat.yMd().format(from)} - ${DateFormat.yMd().format(to)}';
    final excel = Excel.createExcel();
    final sheet = excel['Sheet1'] ?? excel[excel.sheets.keys.first];
    if (sheet == null) return;
    final int tabIndex = _tabController.index;

    if (tabIndex == 0) {
      final names = _patientNames.toSet().toList()..sort();
      sheet.appendRow([TextCellValue(l10n.patientsReport), TextCellValue(periodLabel)]);
      sheet.appendRow([TextCellValue('${l10n.total}: ${names.length}')]);
      sheet.appendRow([TextCellValue(l10n.patient)]);
      for (final n in names) sheet.appendRow([TextCellValue(n)]);
    } else if (tabIndex == 1) {
      sheet.appendRow([TextCellValue(l10n.incomeExpensesReport), TextCellValue(periodLabel)]);
      sheet.appendRow([TextCellValue(l10n.totalIncome), TextCellValue(NumberFormat.currency(symbol: '').format(_incomeTotal))]);
      sheet.appendRow([TextCellValue(l10n.totalExpenses), TextCellValue(NumberFormat.currency(symbol: '').format(_expenseTotal))]);
      sheet.appendRow([TextCellValue(l10n.net), TextCellValue(NumberFormat.currency(symbol: '').format(_incomeTotal - _expenseTotal))]);
      sheet.appendRow([]);
      sheet.appendRow([TextCellValue(l10n.income)]);
      sheet.appendRow([TextCellValue(l10n.source), TextCellValue(l10n.date), TextCellValue(l10n.amount)]);
      for (final r in _income) sheet.appendRow([TextCellValue(r.source), TextCellValue(DateFormat.yMd().format(r.incomeDate)), TextCellValue(r.amount.toString())]);
      sheet.appendRow([]);
      sheet.appendRow([TextCellValue(l10n.expenses)]);
      sheet.appendRow([TextCellValue(l10n.category), TextCellValue(l10n.date), TextCellValue(l10n.amount)]);
      for (final r in _expenses) sheet.appendRow([TextCellValue(r.category), TextCellValue(DateFormat.yMd().format(r.expenseDate)), TextCellValue(r.amount.toString())]);
    } else if (tabIndex == 2) {
      sheet.appendRow([TextCellValue(l10n.appointmentsReport), TextCellValue(periodLabel)]);
      sheet.appendRow([TextCellValue(l10n.date), TextCellValue(l10n.time), TextCellValue(l10n.status), TextCellValue(l10n.service)]);
      for (final a in _appointments) {
        sheet.appendRow([
          TextCellValue(DateFormat.yMd().format(a.appointmentDate)),
          TextCellValue('${a.startTime} - ${a.endTime}'),
          TextCellValue(_statusLabel(a.status.value, l10n)),
          TextCellValue(a.service ?? ''),
        ]);
      }
    } else {
      sheet.appendRow([TextCellValue(l10n.usersReport)]);
      sheet.appendRow([TextCellValue(l10n.fullNameEn), TextCellValue(l10n.email), TextCellValue(l10n.role)]);
      for (final u in _users) sheet.appendRow([TextCellValue(u.displayName), TextCellValue(u.email), TextCellValue(u.roles.join(', '))]);
    }

    final bytes = excel.encode();
    if (bytes == null) return;
    final path = await report_io.writeReportBytes('report_${tabIndex}_$from.xlsx', bytes);
    if (path == null || !mounted) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Excel export is available on mobile and desktop. Use CSV on web.')));
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
          leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => context.pop()),
          actions: [
            PopupMenuButton<String>(
              icon: const Icon(Icons.upload),
              tooltip: l10n.export,
              onSelected: (v) async {
                final shareOrigin = _sharePositionOriginFrom(context);
                try {
                  if (v == 'income') await _exportIncome(l10n, shareOrigin);
                  if (v == 'appointments') await _exportAppointments(l10n, shareOrigin);
                  if (v == 'patients') await _exportPatients(l10n, shareOrigin);
                  if (v == 'users') await _exportUsers(l10n, shareOrigin);
                  if (v == 'audit') await _exportAuditLog(l10n, shareOrigin);
                  if (v == 'pdf') await _exportCurrentAsPdf(l10n, shareOrigin);
                  if (v == 'excel') await _exportCurrentAsExcel(l10n, shareOrigin);
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
                  debugPrint('Export error: $e\n$st');
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('${l10n.export}: $e'),
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
              child: Row(
                children: [
                  DropdownButton<String>(
                    value: _period,
                    items: [
                      DropdownMenuItem(value: 'day', child: Text(l10n.day)),
                      DropdownMenuItem(value: 'month', child: Text(l10n.month)),
                      DropdownMenuItem(value: 'year', child: Text(l10n.year)),
                    ],
                    onChanged: (v) {
                      if (v != null) setState(() { _period = v; _load(); });
                    },
                  ),
                  const SizedBox(width: 16),
                  TextButton.icon(
                    icon: const Icon(Icons.calendar_today),
                    label: Text(DateFormat.yMd().format(_selectedDate)),
                    onPressed: () async {
                      final d = await showDatePicker(
                        context: context,
                        initialDate: _selectedDate,
                        firstDate: DateTime(2020),
                        lastDate: DateTime.now().add(const Duration(days: 365)),
                      );
                      if (d != null) setState(() { _selectedDate = d; _load(); });
                    },
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
            ...uniqueNames.map((name) => Card(
                  child: ListTile(title: Text(name)),
                )),
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
                    Text('${l10n.totalIncome}: ${NumberFormat.currency(symbol: '').format(_incomeTotal)}', style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 4),
                    Text('${l10n.totalExpenses}: ${NumberFormat.currency(symbol: '').format(_expenseTotal)}', style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 4),
                    Text('${l10n.net}: ${NumberFormat.currency(symbol: '').format(net)}', style: Theme.of(context).textTheme.titleLarge),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(l10n.income, style: Theme.of(context).textTheme.titleSmall),
            if (_income.isEmpty)
              Card(child: Padding(padding: const EdgeInsets.all(16), child: Text(l10n.noData)))
            else
              ..._income.map((r) => Card(
                    child: ListTile(
                      title: Text(r.source),
                      subtitle: Text(DateFormat.yMd().format(r.incomeDate)),
                      trailing: Text(NumberFormat.currency(symbol: '').format(r.amount)),
                    ),
                  )),
            const SizedBox(height: 16),
            Text(l10n.expenses, style: Theme.of(context).textTheme.titleSmall),
            if (_expenses.isEmpty)
              Card(child: Padding(padding: const EdgeInsets.all(16), child: Text(l10n.noData)))
            else
              ..._expenses.map((r) => Card(
                    child: ListTile(
                      title: Text(r.category == 'Salary' && r.recipientName != null && r.recipientName!.isNotEmpty ? 'Salary – ${r.recipientName}' : r.category),
                      subtitle: Text(DateFormat.yMd().format(r.expenseDate)),
                      trailing: Text(NumberFormat.currency(symbol: '').format(r.amount)),
                    ),
                  )),
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
                    Text('${l10n.total}: ${_appointments.length} ${l10n.appointments.toLowerCase()}', style: Theme.of(context).textTheme.titleLarge),
                    if (_appointmentsByStatus.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(l10n.byStatus, style: Theme.of(context).textTheme.titleSmall),
                      ..._appointmentsByStatus.entries.map((e) => Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(_statusLabel(e.key, l10n)),
                                Text('${e.value}'),
                              ],
                            ),
                          )),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            if (_appointments.isEmpty)
              Card(child: Padding(padding: const EdgeInsets.all(16), child: Text(l10n.noData)))
            else
              ..._appointments.take(50).map((a) => Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      title: Text(DateFormat.yMd().format(a.appointmentDate)),
                      subtitle: Text('${a.startTime} - ${a.endTime} • ${_statusLabel(a.status.value, l10n)} ${a.service != null && a.service!.isNotEmpty ? '• ${a.service}' : ''}'),
                      trailing: Text(a.status.value),
                    ),
                  )),
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
                    Text('${l10n.total}: ${_users.length} ${l10n.users.toLowerCase()}', style: Theme.of(context).textTheme.titleLarge),
                    if (_usersByRole.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(l10n.role, style: Theme.of(context).textTheme.titleSmall),
                      ..._usersByRole.entries.map((e) => Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(e.key),
                                Text('${e.value}'),
                              ],
                            ),
                          )),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            if (_users.isEmpty)
              Card(child: Padding(padding: const EdgeInsets.all(16), child: Text(l10n.noData)))
            else
              ..._users.map((u) => Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      title: Text(u.displayName),
                      subtitle: Text('${u.email} • ${u.roles.map((r) => l10n.roleDisplay(r)).join(", ")}'),
                      trailing: u.isActive ? null : Chip(label: Text(l10n.inactive, style: const TextStyle(fontSize: 12))),
                    ),
                  )),
          ],
        ),
      ),
    );
  }
}
