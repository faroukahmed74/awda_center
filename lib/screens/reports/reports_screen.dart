import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';
import '../../core/responsive.dart';
import '../../l10n/app_localizations.dart';
import '../../models/appointment_model.dart';
import '../../models/income_expense_models.dart';
import '../../models/user_model.dart';
import '../../services/firestore_service.dart';
import 'package:intl/intl.dart' hide TextDirection;

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

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
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

  Future<void> _exportIncome(AppLocalizations l10n) async {
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
    await Share.share(sb.toString(), subject: '${l10n.exportIncomeExpense} ${DateFormat.yMd().format(from)} - ${DateFormat.yMd().format(to)}');
  }

  Future<void> _exportAppointments(AppLocalizations l10n) async {
    final (from, to) = _range();
    final appointments = await _firestore.getAppointments(from: from, to: to);
    final sb = StringBuffer();
    sb.writeln('Date,Start,End,PatientId,DoctorId,Status,Service');
    for (final a in appointments) {
      sb.writeln('${DateFormat.yMd().format(a.appointmentDate)},${a.startTime},${a.endTime},${a.patientId},${a.doctorId},${a.status.value},${a.service ?? ''}');
    }
    await Share.share(sb.toString(), subject: '${l10n.exportAppointments} ${DateFormat.yMd().format(from)} - ${DateFormat.yMd().format(to)}');
  }

  Future<void> _exportPatients(AppLocalizations l10n) async {
    final (from, to) = _range();
    final appointments = await _firestore.getAppointments(from: from, to: to);
    final patientIds = appointments.map((a) => a.patientId).toSet().toList();
    final sb = StringBuffer();
    sb.writeln('PatientId,DisplayName');
    for (final id in patientIds) {
      final u = await _firestore.getUser(id);
      sb.writeln('$id,${u?.displayName ?? id}');
    }
    await Share.share(sb.toString(), subject: '${l10n.exportPatients} ${DateFormat.yMd().format(from)} - ${DateFormat.yMd().format(to)}');
  }

  Future<void> _exportUsers(AppLocalizations l10n) async {
    final users = await _firestore.getUsers();
    final sb = StringBuffer();
    sb.writeln('Id,Email,FullNameAr,FullNameEn,Phone,Roles,Active');
    for (final u in users) {
      sb.writeln('${u.id},${u.email},${u.fullNameAr ?? ''},${u.fullNameEn ?? ''},${u.phone ?? ''},${u.roles.join(";")},${u.isActive}');
    }
    await Share.share(sb.toString(), subject: l10n.exportUsers);
  }

  Future<void> _exportAuditLog(AppLocalizations l10n) async {
    final logs = await _firestore.getAuditLogs(limit: 500);
    final sb = StringBuffer();
    sb.writeln('CreatedAt,Action,EntityType,EntityId,UserId,UserEmail,Details');
    for (final e in logs) {
      final details = e.details != null ? e.details!.toString().replaceAll(',', ';') : '';
      sb.writeln('${e.createdAt != null ? DateFormat.yMd().add_Hms().format(e.createdAt!) : ''},${e.action},${e.entityType},${e.entityId ?? ''},${e.userId},${e.userEmail ?? ''},$details');
    }
    await Share.share(sb.toString(), subject: l10n.exportAuditLog);
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
                if (v == 'income') await _exportIncome(l10n);
                if (v == 'appointments') await _exportAppointments(l10n);
                if (v == 'patients') await _exportPatients(l10n);
                if (v == 'users') await _exportUsers(l10n);
                if (v == 'audit') await _exportAuditLog(l10n);
              },
              itemBuilder: (context) => [
                PopupMenuItem(value: 'income', child: Text(l10n.exportIncomeExpense)),
                PopupMenuItem(value: 'appointments', child: Text(l10n.exportAppointments)),
                PopupMenuItem(value: 'patients', child: Text(l10n.exportPatients)),
                PopupMenuItem(value: 'users', child: Text(l10n.exportUsers)),
                PopupMenuItem(value: 'audit', child: Text(l10n.exportAuditLog)),
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
