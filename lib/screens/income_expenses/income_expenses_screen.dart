import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../core/responsive.dart';
import '../../l10n/app_localizations.dart';
import '../../models/income_expense_models.dart';
import '../../models/user_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/data_cache_provider.dart';
import '../../services/audit_service.dart';
import '../../services/firestore_service.dart';
import '../../widgets/notifications_button.dart';
import 'package:intl/intl.dart' hide TextDirection;
import '../../core/date_format.dart';

class IncomeExpensesScreen extends StatefulWidget {
  const IncomeExpensesScreen({super.key});

  @override
  State<IncomeExpensesScreen> createState() => _IncomeExpensesScreenState();
}

class _IncomeExpensesScreenState extends State<IncomeExpensesScreen> {
  final FirestoreService _firestore = FirestoreService();
  List<IncomeRecordModel> _income = [];
  List<ExpenseRecordModel> _expense = [];
  final Map<String, String> _sessionNotesByAppointmentId = {};
  bool _loading = true;
  DateTime? _filterDay;
  int? _filterYear;
  int? _filterMonth;
  String? _filterDoctorId;
  String? _filterPatientId;
  String _searchQuery = '';
  String _typeFilter = 'both';
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _incomeSub;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _expenseSub;

  List<IncomeRecordModel> get _filteredIncome {
    final cache = context.read<DataCacheProvider>();
    var out = _income;
    if (_filterDay != null) {
      final d = _filterDay!;
      out = out.where((r) => r.incomeDate.year == d.year && r.incomeDate.month == d.month && r.incomeDate.day == d.day).toList();
    } else if (_filterYear != null && _filterMonth != null) {
      out = out.where((r) => r.incomeDate.year == _filterYear && r.incomeDate.month == _filterMonth).toList();
    } else if (_filterYear != null) {
      out = out.where((r) => r.incomeDate.year == _filterYear).toList();
    }
    if (_filterDoctorId != null && _filterDoctorId!.isNotEmpty) {
      out = out.where((r) => r.doctorId == _filterDoctorId).toList();
    }
    if (_filterPatientId != null && _filterPatientId!.isNotEmpty) {
      out = out.where((r) => r.patientId == _filterPatientId).toList();
    }
    final q = _searchQuery.trim().toLowerCase();
    if (q.isNotEmpty) {
      out = out.where((r) {
        final source = (r.source).toLowerCase();
        final notes = (r.notes ?? '').toLowerCase();
        final amountStr = r.amount.toString().toLowerCase();
        final doctor = (cache.doctorDisplayName(r.doctorId) ?? cache.userName(r.doctorId) ?? '').toLowerCase();
        final patient = (cache.userName(r.patientId) ?? '').toLowerCase();
        return source.contains(q) ||
            notes.contains(q) ||
            amountStr.contains(q) ||
            doctor.contains(q) ||
            patient.contains(q);
      }).toList();
    }
    out.sort((a, b) {
      final byDate = b.incomeDate.compareTo(a.incomeDate);
      if (byDate != 0) return byDate;
      final at = a.createdAt ?? a.incomeDate;
      final bt = b.createdAt ?? b.incomeDate;
      return bt.compareTo(at);
    });
    return out;
  }

  List<ExpenseRecordModel> get _filteredExpense {
    final cache = context.read<DataCacheProvider>();
    var out = _expense;
    if (_filterDay != null) {
      final d = _filterDay!;
      out = out.where((r) => r.expenseDate.year == d.year && r.expenseDate.month == d.month && r.expenseDate.day == d.day).toList();
    } else if (_filterYear != null && _filterMonth != null) {
      out = out.where((r) => r.expenseDate.year == _filterYear && r.expenseDate.month == _filterMonth).toList();
    } else if (_filterYear != null) {
      out = out.where((r) => r.expenseDate.year == _filterYear).toList();
    }
    if (_filterDoctorId != null && _filterDoctorId!.isNotEmpty) {
      out = out.where((r) => r.paidByDoctorId == _filterDoctorId).toList();
    }
    final q = _searchQuery.trim().toLowerCase();
    if (q.isNotEmpty) {
      out = out.where((r) {
        final category = (r.category).toLowerCase();
        final desc = (r.description ?? '').toLowerCase();
        final amountStr = r.amount.toString().toLowerCase();
        final recipient = (r.recipientName ?? '').toLowerCase();
        final doctor = (cache.doctorDisplayName(r.paidByDoctorId) ?? cache.userName(r.paidByDoctorId) ?? '').toLowerCase();
        return category.contains(q) ||
            desc.contains(q) ||
            amountStr.contains(q) ||
            recipient.contains(q) ||
            doctor.contains(q);
      }).toList();
    }
    out.sort((a, b) {
      final byDate = b.expenseDate.compareTo(a.expenseDate);
      if (byDate != 0) return byDate;
      final at = a.createdAt ?? a.expenseDate;
      final bt = b.createdAt ?? b.expenseDate;
      return bt.compareTo(at);
    });
    return out;
  }

  void _clearAllFilters() {
    setState(() {
      _filterDay = null;
      _filterYear = null;
      _filterMonth = null;
      _filterDoctorId = null;
      _filterPatientId = null;
      _typeFilter = 'both';
    });
  }

  /// Per-doctor totals from [income] for the "Income by doctor" breakdown.
  List<({String doctorId, String doctorName, double total})> _incomeByDoctorEntries(List<IncomeRecordModel> income, DataCacheProvider cache, AppLocalizations l10n) {
    final byDoctor = <String, double>{};
    for (final r in income) {
      final id = r.doctorId ?? '';
      byDoctor[id] = (byDoctor[id] ?? 0) + r.amount;
    }
    return byDoctor.entries.map((e) {
      final name = e.key.isEmpty
          ? l10n.filterAll
          : (cache.doctorDisplayName(e.key) ?? cache.userName(e.key) ?? e.key);
      return (doctorId: e.key, doctorName: name, total: e.value);
    }).toList()..sort((a, b) => b.total.compareTo(a.total));
  }

  /// Per-doctor totals from [expense] for the "Expense by doctor" breakdown (who paid).
  List<({String doctorId, String doctorName, double total})> _expenseByDoctorEntries(List<ExpenseRecordModel> expense, DataCacheProvider cache, AppLocalizations l10n) {
    final byDoctor = <String, double>{};
    for (final r in expense) {
      final id = r.paidByDoctorId ?? '';
      byDoctor[id] = (byDoctor[id] ?? 0) + r.amount;
    }
    return byDoctor.entries.map((e) {
      final name = e.key.isEmpty
          ? l10n.filterAll
          : (cache.doctorDisplayName(e.key) ?? cache.userName(e.key) ?? e.key);
      return (doctorId: e.key, doctorName: name, total: e.value);
    }).toList()..sort((a, b) => b.total.compareTo(a.total));
  }

  @override
  @override
  void initState() {
    super.initState();
    // Default to current month so "new" months start at zero; past data remains viewable via Month/Year filter
    final now = DateTime.now();
    _filterYear = now.year;
    _filterMonth = now.month;
    _listen();
  }

  @override
  void dispose() {
    _incomeSub?.cancel();
    _expenseSub?.cancel();
    super.dispose();
  }

  void _listen() {
    setState(() => _loading = true);
    _incomeSub?.cancel();
    _expenseSub?.cancel();
    _incomeSub = _firestore.incomeRecordsStream().listen((snapshot) async {
      final list = snapshot.docs
          .map((d) => IncomeRecordModel.fromFirestore(d as DocumentSnapshot<Map<String, dynamic>>))
          .toList();
      final appointmentIds = list
          .where((r) => r.appointmentId != null && r.appointmentId!.isNotEmpty)
          .map((r) => r.appointmentId!)
          .toSet()
          .toList();
      final notesById = <String, String>{};
      if (appointmentIds.isNotEmpty) {
        final sessions = await _firestore.getSessionsByAppointmentIds(appointmentIds);
        for (final s in sessions) {
          if (s.appointmentId != null && s.notes != null && s.notes!.trim().isNotEmpty) {
            notesById[s.appointmentId!] = s.notes!.trim();
          }
        }
      }
      if (mounted) {
        setState(() {
          _income = list;
          _sessionNotesByAppointmentId
            ..clear()
            ..addAll(notesById);
          _loading = false;
        });
      }
    }, onError: (e) {
      if (mounted) setState(() => _loading = false);
    });
    _expenseSub = _firestore.expenseRecordsStream().listen((snapshot) {
      final list = snapshot.docs
          .map((d) => ExpenseRecordModel.fromFirestore(d as DocumentSnapshot<Map<String, dynamic>>))
          .toList();
      if (mounted) setState(() {
        _expense = list;
        _loading = false;
      });
    }, onError: (e) {
      if (mounted) setState(() => _loading = false);
    });
  }

  String _sessionPaymentStatusLabel(String status, AppLocalizations l10n) {
    switch (status) {
      case 'paid': return l10n.paid;
      case 'partial_paid': return l10n.partialPaid;
      case 'prepaid': return l10n.prepaid;
      case 'not_paid': return l10n.notPaid;
      default: return status;
    }
  }

  Widget _sessionPaymentStatusChip(BuildContext context, String status, AppLocalizations l10n) {
    final label = _sessionPaymentStatusLabel(status, l10n);
    final theme = Theme.of(context);
    Color chipColor;
    switch (status) {
      case 'paid': chipColor = theme.colorScheme.primaryContainer; break;
      case 'partial_paid': chipColor = theme.colorScheme.tertiaryContainer; break;
      case 'prepaid': chipColor = theme.colorScheme.secondaryContainer; break;
      case 'not_paid': chipColor = theme.colorScheme.errorContainer; break;
      default: chipColor = theme.colorScheme.surfaceContainerHighest;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: chipColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(label, style: theme.textTheme.labelMedium),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final uid = context.read<AuthProvider>().currentUser?.id;
    final cache = context.watch<DataCacheProvider>();
    final isRtl = l10n.isArabic;

    final filteredIncome = _filteredIncome;
    final filteredExpense = _filteredExpense;
    final showIncome = _typeFilter == 'both' || _typeFilter == 'income';
    final showExpense = _typeFilter == 'both' || _typeFilter == 'expense';
    final totalIncome = showIncome
        ? filteredIncome.fold<double>(0, (s, r) => s + r.amount)
        : 0;
    final totalExpense = showExpense
        ? filteredExpense.fold<double>(0, (s, r) => s + r.amount)
        : 0;
    final net = totalIncome - totalExpense;

    return Directionality(
      textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        appBar: AppBar(
          title: Text(l10n.incomeAndExpenses),
          leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () { if (context.canPop()) context.pop(); else context.go('/dashboard'); }),
          actions: [
            const NotificationsButton(),
            IconButton(
              icon: const Icon(Icons.add),
              onPressed: () => _showAddIncome(context, uid, l10n),
            ),
            IconButton(
              icon: const Icon(Icons.remove_circle_outline),
              onPressed: () => _showAddExpense(context, uid, l10n),
            ),
          ],
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: () async {
                  _incomeSub?.cancel();
                  _expenseSub?.cancel();
                  _listen();
                  await Future.delayed(const Duration(milliseconds: 400));
                },
                child: SingleChildScrollView(
                  padding: ResponsivePadding.all(context),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          children: [
                            if (context.watch<AuthProvider>().currentUser?.canAccessFinanceSummary == true)
                              FilledButton.tonalIcon(
                                onPressed: () => context.push('/income-expenses-summary'),
                                icon: const Icon(Icons.summarize),
                                label: Text(l10n.financeSummary),
                                style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12)),
                              ),
                            if (context.watch<AuthProvider>().currentUser?.canAccessFinanceSummary == true) const SizedBox(width: 12),
                            FilterChip(
                              label: Text(l10n.filterAll),
                              selected: _filterDay == null &&
                                  _filterYear == null &&
                                  _filterMonth == null &&
                                  _filterDoctorId == null &&
                                  _filterPatientId == null &&
                                  _typeFilter == 'both',
                              onSelected: (_) => _clearAllFilters(),
                            ),
                            const SizedBox(width: 8),
                            FilterChip(
                              label: const Text('Both'),
                              selected: _typeFilter == 'both',
                              onSelected: (_) => setState(() => _typeFilter = 'both'),
                            ),
                            const SizedBox(width: 8),
                            FilterChip(
                              label: Text(l10n.income),
                              selected: _typeFilter == 'income',
                              onSelected: (_) => setState(() => _typeFilter = 'income'),
                            ),
                            const SizedBox(width: 8),
                            FilterChip(
                              label: Text(l10n.expenses),
                              selected: _typeFilter == 'expense',
                              onSelected: (_) => setState(() => _typeFilter = 'expense'),
                            ),
                            const SizedBox(width: 8),
                            FilterChip(
                              label: Text(_filterDay != null ? '${l10n.filterDay}: ${AppDateFormat.shortDate.format(_filterDay!)}' : l10n.filterDay),
                              selected: _filterDay != null,
                              onSelected: (_) async {
                                if (_filterDay != null) {
                                  setState(() => _filterDay = null);
                                  return;
                                }
                                final d = await showDatePicker(
                                  context: context,
                                  initialDate: DateTime.now(),
                                  firstDate: DateTime(2020),
                                  lastDate: DateTime.now().add(const Duration(days: 365)),
                                );
                                if (d != null) setState(() {
                                  _filterDay = d;
                                  _filterMonth = null;
                                  _filterYear = null;
                                });
                              },
                            ),
                            const SizedBox(width: 8),
                            FilterChip(
                              label: Text(_filterMonth != null && _filterYear != null ? '${l10n.filterMonth}: ${AppDateFormat.monthYear(l10n.isArabic ? 'ar' : 'en').format(DateTime(_filterYear!, _filterMonth!))}' : l10n.filterMonth),
                              selected: _filterMonth != null && _filterYear != null,
                              onSelected: (_) async {
                                if (_filterMonth != null && _filterYear != null) {
                                  setState(() { _filterMonth = null; _filterYear = null; _filterDay = null; });
                                  return;
                                }
                                final now = DateTime.now();
                                final d = await showDatePicker(
                                  context: context,
                                  initialDate: now,
                                  firstDate: DateTime(2020),
                                  lastDate: DateTime(now.year + 1),
                                );
                                if (d != null) setState(() {
                                  _filterMonth = d.month;
                                  _filterYear = d.year;
                                  _filterDay = null;
                                });
                              },
                            ),
                            const SizedBox(width: 8),
                            FilterChip(
                              label: Text(_filterYear != null && _filterMonth == null ? '${l10n.filterYear}: $_filterYear' : l10n.filterYear),
                              selected: _filterYear != null && _filterMonth == null,
                              onSelected: (_) async {
                                if (_filterYear != null && _filterMonth == null) {
                                  setState(() { _filterYear = null; _filterDay = null; });
                                  return;
                                }
                                final y = await showDialog<int>(
                                  context: context,
                                  builder: (ctx) {
                                    final years = List.generate(6, (i) => DateTime.now().year - 2 + i);
                                    return AlertDialog(
                                      title: Text(l10n.filterYear),
                                      content: SingleChildScrollView(
                                        child: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: years.map((y) => ListTile(title: Text('$y'), onTap: () => Navigator.pop(ctx, y))).toList(),
                                        ),
                                      ),
                                    );
                                  },
                                );
                                if (y != null) setState(() {
                                  _filterYear = y;
                                  _filterMonth = null;
                                  _filterDay = null;
                                });
                              },
                            ),
                            const SizedBox(width: 8),
                            SizedBox(
                              width: 180,
                              child: DropdownButtonFormField<String?>(
                                value: _filterDoctorId,
                                decoration: InputDecoration(
                                  labelText: l10n.filterByDoctor,
                                  isDense: true,
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                ),
                                items: [
                                  DropdownMenuItem<String?>(value: null, child: Text(l10n.filterAll)),
                                  ...cache.doctors.map((d) => DropdownMenuItem<String?>(
                                    value: d.id,
                                    child: Text(cache.userName(d.userId) ?? d.displayName ?? d.id, overflow: TextOverflow.ellipsis),
                                  )),
                                ],
                                onChanged: (v) => setState(() => _filterDoctorId = v),
                              ),
                            ),
                            const SizedBox(width: 8),
                            SizedBox(
                              width: 160,
                              child: DropdownButtonFormField<String?>(
                                value: _filterPatientId,
                                decoration: InputDecoration(
                                  labelText: l10n.patient,
                                  isDense: true,
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                ),
                                items: [
                                  DropdownMenuItem<String?>(value: null, child: Text(l10n.filterAll)),
                                  ...cache.patients.map((p) {
                                    final label = p.displayName;
                                    return DropdownMenuItem<String?>(
                                      value: p.id,
                                      child: Text(label, overflow: TextOverflow.ellipsis),
                                    );
                                  }),
                                ],
                                onChanged: (v) => setState(() => _filterPatientId = v),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Text(
                          '${l10n.income}: ${filteredIncome.length} · ${l10n.expenses}: ${filteredExpense.length}',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: TextField(
                          onChanged: (v) => setState(() => _searchQuery = v),
                          decoration: InputDecoration(
                            hintText: l10n.search,
                            prefixIcon: const Icon(Icons.search),
                            suffixIcon: _searchQuery.isEmpty
                                ? null
                                : IconButton(
                                    icon: const Icon(Icons.clear),
                                    onPressed: () => setState(() => _searchQuery = ''),
                                  ),
                            isDense: true,
                            border: const OutlineInputBorder(),
                          ),
                        ),
                      ),
                      Row(
                        children: [
                          Expanded(
                            child: Card(
                              color: Theme.of(context).colorScheme.primaryContainer,
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  children: [
                                    Text(l10n.totalIncome, style: Theme.of(context).textTheme.titleSmall),
                                    Text(NumberFormat.currency(symbol: '').format(totalIncome), style: Theme.of(context).textTheme.headlineSmall),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Card(
                              color: net >= 0
                                  ? const Color(0xFFC8E6C9)
                                  : const Color(0xFFFFCDD2),
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  children: [
                                    Text(l10n.netProfit, style: Theme.of(context).textTheme.titleSmall),
                                    Text(
                                      NumberFormat.currency(symbol: '').format(net),
                                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                        color: net >= 0 ? const Color(0xFF2E7D32) : const Color(0xFFC62828),
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Card(
                              color: Theme.of(context).colorScheme.tertiaryContainer,
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  children: [
                                    Text(l10n.totalExpenses, style: Theme.of(context).textTheme.titleSmall),
                                    Text(NumberFormat.currency(symbol: '').format(totalExpense), style: Theme.of(context).textTheme.headlineSmall),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (showIncome && filteredIncome.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        Text(l10n.incomeByDoctor, style: Theme.of(context).textTheme.titleSmall),
                        const SizedBox(height: 8),
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: _incomeByDoctorEntries(filteredIncome, cache, l10n).map((e) {
                              return Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: FilterChip(
                                  label: Text('${e.doctorName}: ${NumberFormat.currency(symbol: '').format(e.total)}'),
                                  selected: _filterDoctorId == e.doctorId,
                                  onSelected: (_) => setState(() => _filterDoctorId = _filterDoctorId == e.doctorId ? null : e.doctorId),
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                      ],
                      if (showExpense && filteredExpense.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Text(l10n.expenseByDoctor, style: Theme.of(context).textTheme.titleSmall),
                        const SizedBox(height: 8),
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: _expenseByDoctorEntries(filteredExpense, cache, l10n).map((e) {
                              return Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: FilterChip(
                                  label: Text('${e.doctorName}: ${NumberFormat.currency(symbol: '').format(e.total)}'),
                                  selected: _filterDoctorId == e.doctorId,
                                  onSelected: (_) => setState(() => _filterDoctorId = _filterDoctorId == e.doctorId ? null : e.doctorId),
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                      ],
                      const SizedBox(height: 24),
                      if (showIncome) ...[
                        Text(l10n.income, style: Theme.of(context).textTheme.titleMedium),
                        const SizedBox(height: 8),
                        if (filteredIncome.isEmpty)
                          Card(child: Padding(padding: const EdgeInsets.all(16), child: Text(l10n.noData)))
                        else
                          ...filteredIncome.take(50).map((r) {
                            final sessionNote = r.appointmentId == null
                                ? null
                                : _sessionNotesByAppointmentId[r.appointmentId!];
                            final visibleNotes =
                                (r.source == 'Session' && sessionNote != null && sessionNote.isNotEmpty)
                                ? sessionNote
                                : r.notes;
                            return Card(
                              margin: const EdgeInsets.only(bottom: 8),
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(r.source, style: Theme.of(context).textTheme.titleMedium),
                                        ),
                                        Text(
                                          NumberFormat.currency(symbol: r.currency).format(r.amount),
                                          style: Theme.of(context).textTheme.titleLarge,
                                        ),
                                        PopupMenuButton<String>(
                                          icon: const Icon(Icons.more_vert),
                                          onSelected: (v) async {
                                            if (v == 'edit') await _showEditIncome(context, r, uid, l10n);
                                            else if (v == 'delete') await _showDeleteIncome(context, r, l10n);
                                            if (mounted) { _incomeSub?.cancel(); _expenseSub?.cancel(); _listen(); }
                                          },
                                          itemBuilder: (context) => [
                                            PopupMenuItem(value: 'edit', child: Text(l10n.edit)),
                                            PopupMenuItem(value: 'delete', child: Text(l10n.delete)),
                                          ],
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    Text('${l10n.date}: ${AppDateFormat.shortDateTime.format(r.incomeDate)}', style: Theme.of(context).textTheme.bodySmall),
                                    if (visibleNotes != null && visibleNotes.isNotEmpty)
                                      Padding(
                                        padding: const EdgeInsets.only(top: 4),
                                        child: Text('${l10n.notes}: $visibleNotes', style: Theme.of(context).textTheme.bodySmall, maxLines: 3, overflow: TextOverflow.ellipsis),
                                      ),
                                    if (r.patientId != null && r.patientId!.isNotEmpty)
                                      Padding(
                                        padding: const EdgeInsets.only(top: 2),
                                        child: Text('${l10n.patient}: ${cache.userName(r.patientId) ?? r.patientId}', style: Theme.of(context).textTheme.bodySmall),
                                      ),
                                    if (r.doctorId != null && r.doctorId!.isNotEmpty)
                                      Padding(
                                        padding: const EdgeInsets.only(top: 2),
                                        child: Text('${l10n.doctor}: ${cache.doctorDisplayName(r.doctorId) ?? cache.userName(r.doctorId) ?? r.doctorId}', style: Theme.of(context).textTheme.bodySmall),
                                      ),
                                    if ((r.appointmentId != null || r.source == 'Session') && r.sessionPaymentStatus != null)
                                      Padding(
                                        padding: const EdgeInsets.only(top: 6),
                                        child: Row(
                                          children: [
                                            Text('${l10n.status}: ', style: Theme.of(context).textTheme.bodySmall),
                                            _sessionPaymentStatusChip(context, r.sessionPaymentStatus!, l10n),
                                          ],
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            );
                          }),
                        const SizedBox(height: 16),
                      ],
                      if (showExpense) ...[
                        Text(l10n.expenses, style: Theme.of(context).textTheme.titleMedium),
                        const SizedBox(height: 8),
                        if (filteredExpense.isEmpty)
                          Card(child: Padding(padding: const EdgeInsets.all(16), child: Text(l10n.noData)))
                        else
                          ...filteredExpense.take(50).map((r) => Card(
                              margin: const EdgeInsets.only(bottom: 8),
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(_expenseTitle(r), style: Theme.of(context).textTheme.titleMedium),
                                        ),
                                        Text(
                                          NumberFormat.currency(symbol: '').format(r.amount),
                                          style: Theme.of(context).textTheme.titleLarge,
                                        ),
                                        PopupMenuButton<String>(
                                          icon: const Icon(Icons.more_vert),
                                          onSelected: (v) async {
                                            if (v == 'edit') await _showEditExpense(context, r, uid, l10n);
                                            else if (v == 'delete') await _showDeleteExpense(context, r, l10n);
                                            if (mounted) { _incomeSub?.cancel(); _expenseSub?.cancel(); _listen(); }
                                          },
                                          itemBuilder: (context) => [
                                            PopupMenuItem(value: 'edit', child: Text(l10n.edit)),
                                            PopupMenuItem(value: 'delete', child: Text(l10n.delete)),
                                          ],
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    Text('${l10n.date}: ${AppDateFormat.shortDateTime.format(r.expenseDate)}', style: Theme.of(context).textTheme.bodySmall),
                                    if (r.paidByDoctorId != null && r.paidByDoctorId!.isNotEmpty)
                                      Padding(
                                        padding: const EdgeInsets.only(top: 2),
                                        child: Text('${l10n.paidByDoctor}: ${cache.doctorDisplayName(r.paidByDoctorId) ?? cache.userName(r.paidByDoctorId) ?? r.paidByDoctorId}', style: Theme.of(context).textTheme.bodySmall),
                                      ),
                                    Text('${l10n.category}: ${r.category}', style: Theme.of(context).textTheme.bodySmall),
                                    if (r.description != null && r.description!.isNotEmpty)
                                      Padding(
                                        padding: const EdgeInsets.only(top: 4),
                                        child: Text('${l10n.description}: ${r.description}', style: Theme.of(context).textTheme.bodySmall, maxLines: 3, overflow: TextOverflow.ellipsis),
                                      ),
                                    if (r.recipientName != null && r.recipientName!.isNotEmpty)
                                      Padding(
                                        padding: const EdgeInsets.only(top: 2),
                                        child: Text('${l10n.employeeOptional}: ${r.recipientName}', style: Theme.of(context).textTheme.bodySmall),
                                      ),
                                  ],
                                ),
                              ),
                            )),
                      ],
                    ],
                  ),
                ),
              ),
      ),
    );
  }

  /// For salary expenses with recipient, show "Salary – Name"; otherwise category.
  static String _expenseTitle(ExpenseRecordModel r) {
    if (r.category == 'Salary' && r.recipientName != null && r.recipientName!.isNotEmpty) {
      return 'Salary – ${r.recipientName}';
    }
    return r.category;
  }

  Future<void> _showAddIncome(BuildContext context, String? uid, AppLocalizations l10n) async {
    final amountController = TextEditingController();
    final sourceController = TextEditingController();
    DateTime selectedDate = DateTime.now();

    if (!context.mounted) return;
    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: Text(l10n.addIncome),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: amountController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(labelText: l10n.amount),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: sourceController,
                  decoration: InputDecoration(labelText: l10n.source),
                ),
                const SizedBox(height: 8),
                ListTile(
                  title: Text(AppDateFormat.shortDate.format(selectedDate)),
                  onTap: () async {
                    final d = await showDatePicker(context: ctx, initialDate: selectedDate, firstDate: DateTime(2020), lastDate: DateTime.now().add(const Duration(days: 365)));
                    if (d != null) setState(() => selectedDate = d);
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: Text(l10n.cancel)),
            FilledButton(
              onPressed: () async {
                final amount = double.tryParse(amountController.text);
                if (amount == null || amount <= 0 || sourceController.text.trim().isEmpty) return;
                await _firestore.addIncomeRecord(IncomeRecordModel(
                  id: '',
                  amount: amount,
                  source: sourceController.text.trim(),
                  recordedByUserId: uid,
                  incomeDate: selectedDate,
                ));
                final u = ctx.read<AuthProvider>().currentUser;
                if (u != null) AuditService.log(action: 'income_added', entityType: 'income_record', userId: u.id, userEmail: u.email, details: {'amount': amount, 'source': sourceController.text.trim()});
                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: Text(l10n.save),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showEditIncome(BuildContext context, IncomeRecordModel r, String? uid, AppLocalizations l10n) async {
    final amountController = TextEditingController(text: r.amount.toString());
    final sourceController = TextEditingController(text: r.source);
    final notesController = TextEditingController(text: r.notes ?? '');
    final currencyController = TextEditingController(text: r.currency);
    DateTime selectedDate = r.incomeDate;

    if (!context.mounted) return;
    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: Text(l10n.edit),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: amountController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(labelText: l10n.amount),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: sourceController,
                  decoration: InputDecoration(labelText: l10n.source),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: currencyController,
                  decoration: const InputDecoration(labelText: 'Currency'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: notesController,
                  decoration: InputDecoration(labelText: l10n.notes),
                  maxLines: 2,
                ),
                const SizedBox(height: 8),
                ListTile(
                  title: Text(AppDateFormat.shortDate.format(selectedDate)),
                  onTap: () async {
                    final d = await showDatePicker(context: ctx, initialDate: selectedDate, firstDate: DateTime(2020), lastDate: DateTime.now().add(const Duration(days: 365)));
                    if (d != null) setState(() => selectedDate = d);
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: Text(l10n.cancel)),
            FilledButton(
              onPressed: () async {
                final amount = double.tryParse(amountController.text);
                if (amount == null || amount < 0 || sourceController.text.trim().isEmpty) return;
                await _firestore.updateIncomeRecord(r.id, {
                  'amount': amount,
                  'currency': currencyController.text.trim().isEmpty ? 'EGP' : currencyController.text.trim(),
                  'source': sourceController.text.trim(),
                  'notes': notesController.text.trim().isEmpty ? null : notesController.text.trim(),
                  'incomeDate': Timestamp.fromDate(selectedDate),
                });
                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: Text(l10n.save),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showDeleteIncome(BuildContext context, IncomeRecordModel r, AppLocalizations l10n) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.delete),
        content: Text(l10n.deleteConfirm),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l10n.cancel)),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(l10n.confirmAction)),
        ],
      ),
    );
    if (confirmed == true) {
      await _firestore.deleteIncomeRecord(r.id);
      final u = context.read<AuthProvider>().currentUser;
      if (u != null) AuditService.log(action: 'income_deleted', entityType: 'income_record', entityId: r.id, userId: u.id, userEmail: u.email, details: {'amount': r.amount, 'source': r.source});
    }
  }

  static const List<String> _expenseCategories = ['Salary', 'Rent', 'Supplies', 'Media', 'Other'];

  Future<void> _showAddExpense(BuildContext context, String? uid, AppLocalizations l10n) async {
    final amountController = TextEditingController();
    final categoryController = TextEditingController(text: 'Salary');
    final descriptionController = TextEditingController();
    DateTime selectedDate = DateTime.now();
    UserModel? selectedEmployee;
    String? selectedPaidByDoctorId;
    final staff = await _firestore.getUsers();
    final staffList = staff.where((u) => u.hasAnyRole([UserRole.doctor, UserRole.secretary, UserRole.trainee])).toList();
    final cache = context.read<DataCacheProvider>();

    if (!context.mounted) return;
    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) {
          final isSalary = categoryController.text == 'Salary';
          return AlertDialog(
          title: Text(l10n.addExpense),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: amountController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(labelText: l10n.amount),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: _expenseCategories.contains(categoryController.text) ? categoryController.text : _expenseCategories.first,
                  decoration: InputDecoration(labelText: l10n.category),
                  items: _expenseCategories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                  onChanged: (v) {
                    categoryController.text = v ?? 'Salary';
                    if (v != 'Salary') selectedEmployee = null;
                    setState(() {});
                  },
                ),
                if (isSalary) ...[
                  const SizedBox(height: 8),
                  DropdownButtonFormField<UserModel?>(
                    value: selectedEmployee,
                    decoration: InputDecoration(labelText: l10n.employeeOptional),
                    items: [
                      const DropdownMenuItem<UserModel?>(value: null, child: Text('—')),
                      ...staffList.map((u) => DropdownMenuItem<UserModel?>(value: u, child: Text(u.displayName))),
                    ],
                    onChanged: (u) => setState(() => selectedEmployee = u),
                  ),
                ],
                const SizedBox(height: 8),
                DropdownButtonFormField<String?>(
                  value: selectedPaidByDoctorId,
                  decoration: InputDecoration(labelText: l10n.paidByDoctor),
                  items: [
                    const DropdownMenuItem<String?>(value: null, child: Text('—')),
                    ...cache.doctors.map((d) => DropdownMenuItem<String?>(
                      value: d.id,
                      child: Text(cache.userName(d.userId) ?? d.displayName ?? d.id, overflow: TextOverflow.ellipsis),
                    )),
                  ],
                  onChanged: (v) => setState(() => selectedPaidByDoctorId = v),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: descriptionController,
                  decoration: InputDecoration(labelText: l10n.description),
                  maxLines: 2,
                ),
                const SizedBox(height: 8),
                ListTile(
                  title: Text(AppDateFormat.shortDate.format(selectedDate)),
                  onTap: () async {
                    final d = await showDatePicker(context: ctx, initialDate: selectedDate, firstDate: DateTime(2020), lastDate: DateTime.now().add(const Duration(days: 365)));
                    if (d != null) setState(() => selectedDate = d);
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: Text(l10n.cancel)),
            FilledButton(
              onPressed: () async {
                final amount = double.tryParse(amountController.text);
                if (amount == null || amount <= 0 || categoryController.text.trim().isEmpty) return;
                final category = categoryController.text.trim().isEmpty ? 'Salary' : categoryController.text.trim();
                await _firestore.addExpenseRecord(ExpenseRecordModel(
                  id: '',
                  amount: amount,
                  category: category,
                  description: descriptionController.text.trim().isEmpty ? null : descriptionController.text.trim(),
                  recipientUserId: selectedEmployee?.id,
                  recipientName: selectedEmployee?.displayName,
                  paidByDoctorId: selectedPaidByDoctorId,
                  recordedByUserId: uid,
                  expenseDate: selectedDate,
                ));
                final u = ctx.read<AuthProvider>().currentUser;
                if (u != null) AuditService.log(action: 'expense_added', entityType: 'expense_record', userId: u.id, userEmail: u.email, details: {'amount': amount, 'category': category});
                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: Text(l10n.save),
            ),
          ],
        );
        },
      ),
    );
  }

  Future<void> _showEditExpense(BuildContext context, ExpenseRecordModel r, String? uid, AppLocalizations l10n) async {
    final amountController = TextEditingController(text: r.amount.toString());
    final categoryController = TextEditingController(text: r.category);
    final descriptionController = TextEditingController(text: r.description ?? '');
    DateTime selectedDate = r.expenseDate;
    String? selectedPaidByDoctorId = r.paidByDoctorId;
    final staff = await _firestore.getUsers();
    final staffList = staff.where((u) => u.hasAnyRole([UserRole.doctor, UserRole.secretary, UserRole.trainee])).toList();
    UserModel? selectedEmployee;
    if (r.recipientUserId != null) {
      try {
        selectedEmployee = staffList.firstWhere((u) => u.id == r.recipientUserId);
      } catch (_) {
        selectedEmployee = null;
      }
    }
    final cache = context.read<DataCacheProvider>();

    if (!context.mounted) return;
    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) {
          final isSalary = categoryController.text == 'Salary';
          return AlertDialog(
            title: Text(l10n.edit),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: amountController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(labelText: l10n.amount),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    value: _expenseCategories.contains(categoryController.text) ? categoryController.text : _expenseCategories.first,
                    decoration: InputDecoration(labelText: l10n.category),
                    items: _expenseCategories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                    onChanged: (v) {
                      categoryController.text = v ?? 'Salary';
                      if (v != 'Salary') selectedEmployee = null;
                      setState(() {});
                    },
                  ),
                  if (isSalary) ...[
                    const SizedBox(height: 8),
                    DropdownButtonFormField<UserModel?>(
                      value: selectedEmployee,
                      decoration: InputDecoration(labelText: l10n.employeeOptional),
                      items: [
                        const DropdownMenuItem<UserModel?>(value: null, child: Text('—')),
                        ...staffList.map((u) => DropdownMenuItem<UserModel?>(value: u, child: Text(u.displayName))),
                      ],
                      onChanged: (u) => setState(() => selectedEmployee = u),
                    ),
                  ],
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String?>(
                    value: selectedPaidByDoctorId,
                    decoration: InputDecoration(labelText: l10n.paidByDoctor),
                    items: [
                      const DropdownMenuItem<String?>(value: null, child: Text('—')),
                      ...cache.doctors.map((d) => DropdownMenuItem<String?>(
                        value: d.id,
                        child: Text(cache.userName(d.userId) ?? d.displayName ?? d.id, overflow: TextOverflow.ellipsis),
                      )),
                    ],
                    onChanged: (v) => setState(() => selectedPaidByDoctorId = v),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: descriptionController,
                    decoration: InputDecoration(labelText: l10n.description),
                    maxLines: 2,
                  ),
                  const SizedBox(height: 8),
                  ListTile(
                    title: Text(AppDateFormat.shortDate.format(selectedDate)),
                    onTap: () async {
                      final d = await showDatePicker(context: ctx, initialDate: selectedDate, firstDate: DateTime(2020), lastDate: DateTime.now().add(const Duration(days: 365)));
                      if (d != null) setState(() => selectedDate = d);
                    },
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: Text(l10n.cancel)),
              FilledButton(
                onPressed: () async {
                  final amount = double.tryParse(amountController.text);
                  if (amount == null || amount < 0 || categoryController.text.trim().isEmpty) return;
                  final category = categoryController.text.trim().isEmpty ? 'Salary' : categoryController.text.trim();
                  await _firestore.updateExpenseRecord(r.id, {
                    'amount': amount,
                    'category': category,
                    'description': descriptionController.text.trim().isEmpty ? null : descriptionController.text.trim(),
                    'recipientUserId': selectedEmployee?.id,
                    'recipientName': selectedEmployee?.displayName,
                    'paidByDoctorId': selectedPaidByDoctorId,
                    'expenseDate': Timestamp.fromDate(selectedDate),
                  });
                  if (ctx.mounted) Navigator.pop(ctx);
                },
                child: Text(l10n.save),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _showDeleteExpense(BuildContext context, ExpenseRecordModel r, AppLocalizations l10n) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.delete),
        content: Text(l10n.deleteConfirm),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l10n.cancel)),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(l10n.confirmAction)),
        ],
      ),
    );
    if (confirmed == true) {
      await _firestore.deleteExpenseRecord(r.id);
      final u = context.read<AuthProvider>().currentUser;
      if (u != null) AuditService.log(action: 'expense_deleted', entityType: 'expense_record', entityId: r.id, userId: u.id, userEmail: u.email, details: {'amount': r.amount, 'category': r.category});
    }
  }
}
