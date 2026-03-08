import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../core/date_format.dart';
import '../../core/responsive.dart';
import '../../l10n/app_localizations.dart';
import '../../providers/data_cache_provider.dart';
import '../../models/income_expense_models.dart';
import '../../services/firestore_service.dart';
import '../../widgets/notifications_button.dart';
import 'package:intl/intl.dart' hide TextDirection;

/// Monthly finance summary: income per doctor, target, bonus %, consumables/media/rent/receptionist expenses, NET, MANG, BASKET, profit. All editable; config saved per month.
class FinanceSummaryScreen extends StatefulWidget {
  const FinanceSummaryScreen({super.key});

  @override
  State<FinanceSummaryScreen> createState() => _FinanceSummaryScreenState();
}

enum _SummaryPeriod { month, quarter, sixMonths, year }

class _FinanceSummaryScreenState extends State<FinanceSummaryScreen> {
  final FirestoreService _firestore = FirestoreService();
  int _year = DateTime.now().year;
  int _month = DateTime.now().month;
  _SummaryPeriod _period = _SummaryPeriod.month;
  double _target = 20000;
  double _rentGuard = 10500;
  double _receptionist = 4700;
  Map<String, double> _doctorPercent = {}; // legacy; % column now uses slice rate
  /// Commission slices: income range (min, max) → display percent and rate (right column). % = BONUS * rate.
  /// Commission slices: rate used for % = BONUS * rate. Spreadsheet: 21–29k uses 0.5 so Tarek % = 2500, total % = 4750, NET = 18850.
  List<({double min, double? max, double percent, double rate})> _slices = [
    (min: 10000, max: 19000, percent: 25, rate: 0.25),
    (min: 21000, max: 29000, percent: 35, rate: 0.5),
    (min: 30000, max: 39000, percent: 45, rate: 0.15),
    (min: 40000, max: 49000, percent: 55, rate: 0.25),
    (min: 50000, max: null, percent: 60, rate: 0.35),
  ];
  List<_DoctorRow> _doctorRows = [];
  double _totalIncome = 0;
  double _totalC30 = 0;
  double _totalBonus = 0;
  double _totalPercent = 0;
  double _totalConsumables = 0;
  double _totalMedia = 0;
  double _net = 0;
  double _mang = 0;
  double _basket = 0;
  double _profitForEach = 0;
  bool _loading = true;
  bool _saving = false;
  String? _loadError;
  Map<String, double> _overridesConsumables = {};
  Map<String, double> _overridesMedia = {};
  List<IncomeRecordModel> _lastIncomeList = [];
  List<ExpenseRecordModel> _lastExpenseList = [];
  StreamSubscription? _incomeSub;
  StreamSubscription? _expenseSub;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadConfigAndData());
  }

  @override
  void dispose() {
    _incomeSub?.cancel();
    _expenseSub?.cancel();
    super.dispose();
  }

  Future<void> _loadConfigAndData() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _loadError = null;
    });
    final cache = context.read<DataCacheProvider>();
    final doctors = cache.doctors;

    // Date range and config month from period
    int rangeStartMonth;
    int rangeEndMonth;
    int configMonth;
    switch (_period) {
      case _SummaryPeriod.month:
        rangeStartMonth = _month;
        rangeEndMonth = _month;
        configMonth = _month;
        break;
      case _SummaryPeriod.quarter:
        rangeStartMonth = ((_month - 1) ~/ 3) * 3 + 1;
        rangeEndMonth = rangeStartMonth + 2;
        configMonth = rangeStartMonth;
        break;
      case _SummaryPeriod.sixMonths:
        rangeStartMonth = _month <= 6 ? 1 : 7;
        rangeEndMonth = _month <= 6 ? 6 : 12;
        configMonth = rangeStartMonth;
        break;
      case _SummaryPeriod.year:
        rangeStartMonth = 1;
        rangeEndMonth = 12;
        configMonth = 1;
        break;
    }
    final monthStart = DateTime(_year, rangeStartMonth, 1);
    final monthEnd = DateTime(_year, rangeEndMonth + 1, 0, 23, 59, 59);
    final monthsInRange = rangeEndMonth - rangeStartMonth + 1;

    try {
      final config = await _firestore.getFinanceSummaryConfig(_year, configMonth).timeout(
        const Duration(seconds: 25),
        onTimeout: () => throw TimeoutException('Finance summary config'),
      );
      final incomeList = await _firestore.getIncomeRecords(from: monthStart, to: monthEnd).timeout(
        const Duration(seconds: 25),
        onTimeout: () => throw TimeoutException('Income records'),
      );
      final expenseList = await _firestore.getExpenseRecords(from: monthStart, to: monthEnd).timeout(
        const Duration(seconds: 25),
        onTimeout: () => throw TimeoutException('Expense records'),
      );

      final configTarget = (config['target'] as num?)?.toDouble() ?? 20000;
      final configRent = (config['rentGuard'] as num?)?.toDouble() ?? 10500;
      final configReceptionist = (config['receptionist'] as num?)?.toDouble() ?? 4700;
      _target = configTarget * monthsInRange;
      _rentGuard = configRent * monthsInRange;
      _receptionist = configReceptionist * monthsInRange;
      final dp = config['doctorPercent'];
      if (dp is Map) {
        _doctorPercent = Map.fromEntries(
          dp.entries.map((e) => MapEntry(e.key.toString(), (e.value as num).toDouble())),
        );
      }
      final sl = config['commissionSlices'];
      if (sl is List && sl.isNotEmpty) {
        _slices = sl.map<({double min, double? max, double percent, double rate})>((s) {
          final m = s is Map ? s : {};
          final pct = (m['percent'] as num?)?.toDouble() ?? 0;
          return (
            min: (m['min'] as num?)?.toDouble() ?? 0,
            max: (m['max'] as num?)?.toDouble(),
            percent: pct,
            rate: (m['rate'] as num?)?.toDouble() ?? (pct / 100),
          );
        }).toList();
      }

      final incomeByDoctor = <String, double>{};
      for (final r in incomeList) {
        final id = r.doctorId ?? '';
        incomeByDoctor[id] = (incomeByDoctor[id] ?? 0) + r.amount;
      }
      final consumablesByDoctor = <String, double>{};
      final mediaByDoctor = <String, double>{};
      double rentTotal = 0;
      double salaryTotal = 0;
      // Map expense category to summary cells: Supplies + Other → Consumables (per doctor);
      // Salary → Receptionist; Media → Media (per doctor); Rent → Rent+Guard
      for (final r in expenseList) {
        final cat = (r.category).toLowerCase().trim();
        final id = r.paidByDoctorId ?? '';
        if (cat == 'rent') {
          rentTotal += r.amount;
        } else if (cat == 'salary') {
          salaryTotal += r.amount;
        } else if (cat == 'media') {
          mediaByDoctor[id] = (mediaByDoctor[id] ?? 0) + r.amount;
        } else if (cat == 'supplies' || cat == 'other' || cat == 'consumables') {
          consumablesByDoctor[id] = (consumablesByDoctor[id] ?? 0) + r.amount;
        }
      }
      if (rentTotal > 0 && _rentGuard == 10500) _rentGuard = rentTotal;
      if (salaryTotal > 0 && _receptionist == 4700) _receptionist = salaryTotal;

      _overridesConsumables = config['consumablesByDoctor'] is Map
          ? Map<String, double>.from(
              (config['consumablesByDoctor'] as Map).map((k, v) => MapEntry(k.toString(), (v as num).toDouble())))
          : <String, double>{};
      _overridesMedia = config['mediaByDoctor'] is Map
          ? Map<String, double>.from(
              (config['mediaByDoctor'] as Map).map((k, v) => MapEntry(k.toString(), (v as num).toDouble())))
          : <String, double>{};

      // Spreadsheet equations: C = B*0.3 (30% target), D = B-target (BONUS), E = D*commission% (%)
      final rows = <_DoctorRow>[];
      for (final d in doctors) {
        final income = incomeByDoctor[d.id] ?? 0;
        if (income <= 0) continue; // Exclude doctors with no income in this period
        final c30 = income * 0.3; // %30 target (20) = income * 0.3
        final bonus = (income - _target) > 0 ? (income - _target) : 0.0; // BONUS = max(0, income - target)
        final rate = _commissionRateForIncome(income); // % = BONUS * rate from slice table
        final percentVal = bonus * rate;
        final consumables = _overridesConsumables[d.id] ?? consumablesByDoctor[d.id] ?? 0;
        final media = _overridesMedia[d.id] ?? mediaByDoctor[d.id] ?? 0;
        rows.add(_DoctorRow(
          doctorId: d.id,
          doctorName: cache.doctorDisplayName(d.id) ?? d.displayName ?? d.id,
          income: income,
          c30: c30,
          bonus: bonus,
          percentVal: percentVal,
          commissionPercent: rate,
          consumables: consumables,
          media: media,
        ));
      }

      _totalIncome = rows.fold<double>(0, (s, r) => s + r.income);
      _totalC30 = rows.fold<double>(0, (s, r) => s + r.c30);
      _totalBonus = rows.fold<double>(0, (s, r) => s + r.bonus);
      _totalPercent = rows.fold<double>(0, (s, r) => s + r.percentVal);
      _totalConsumables = rows.fold<double>(0, (s, r) => s + r.consumables);
      _totalMedia = rows.fold<double>(0, (s, r) => s + r.media);
      // NET = Total income - Total 30% - Rent - Receptionist - Total consumables - Total media - Total %
      _net = _totalIncome - _totalC30 - _rentGuard - _receptionist - _totalConsumables - _totalMedia - _totalPercent;
      _mang = _net * 0.15; // MANG (.15) = NET * 0.15
      _basket = _net * 0.30; // BASKET (.3) = NET * 0.30
      _profitForEach = rows.isEmpty ? 0 : (_net - _mang - _basket) / rows.length; // PROFIT FOR EACH = (NET - MANG - BASKET) / n

      if (mounted) {
        _lastIncomeList = incomeList;
        _lastExpenseList = expenseList;
        setState(() {
          _doctorRows = rows;
          _loading = false;
        });
        _setupStreams();
      }
    } catch (e, st) {
      debugPrint('FinanceSummary load error: $e\n$st');
      if (mounted) {
        setState(() {
          _loading = false;
          _loadError = e.toString();
        });
        if (context.mounted) {
          final msg = AppLocalizations.of(context).financeSummaryLoadError;
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
        }
      }
    }
  }

  (DateTime, DateTime) _getMonthRange() {
    int rangeStartMonth;
    int rangeEndMonth;
    switch (_period) {
      case _SummaryPeriod.month:
        rangeStartMonth = _month;
        rangeEndMonth = _month;
        break;
      case _SummaryPeriod.quarter:
        rangeStartMonth = ((_month - 1) ~/ 3) * 3 + 1;
        rangeEndMonth = rangeStartMonth + 2;
        break;
      case _SummaryPeriod.sixMonths:
        rangeStartMonth = _month <= 6 ? 1 : 7;
        rangeEndMonth = _month <= 6 ? 6 : 12;
        break;
      case _SummaryPeriod.year:
        rangeStartMonth = 1;
        rangeEndMonth = 12;
        break;
    }
    final monthStart = DateTime(_year, rangeStartMonth, 1);
    final monthEnd = DateTime(_year, rangeEndMonth + 1, 0, 23, 59, 59);
    return (monthStart, monthEnd);
  }

  void _setupStreams() {
    if (_incomeSub != null && _expenseSub != null) return;
    _incomeSub?.cancel();
    _expenseSub?.cancel();
    _incomeSub = _firestore.incomeRecordsStream().listen((snapshot) {
      final list = snapshot.docs
          .map((d) => IncomeRecordModel.fromFirestore(d as DocumentSnapshot<Map<String, dynamic>>))
          .toList();
      if (!mounted) return;
      _lastIncomeList = list;
      _applyIncomeAndExpense();
    });
    _expenseSub = _firestore.expenseRecordsStream().listen((snapshot) {
      final list = snapshot.docs
          .map((d) => ExpenseRecordModel.fromFirestore(d as DocumentSnapshot<Map<String, dynamic>>))
          .toList();
      if (!mounted) return;
      _lastExpenseList = list;
      _applyIncomeAndExpense();
    });
  }

  void _applyIncomeAndExpense() {
    if (!mounted) return;
    final cache = context.read<DataCacheProvider>();
    final doctors = cache.doctors;
    final (monthStart, monthEnd) = _getMonthRange();
    final incomeList = _lastIncomeList
        .where((r) => !r.incomeDate.isBefore(monthStart) && !r.incomeDate.isAfter(monthEnd))
        .toList();
    final expenseList = _lastExpenseList
        .where((r) => !r.expenseDate.isBefore(monthStart) && !r.expenseDate.isAfter(monthEnd))
        .toList();
    final incomeByDoctor = <String, double>{};
    for (final r in incomeList) {
      final id = r.doctorId ?? '';
      incomeByDoctor[id] = (incomeByDoctor[id] ?? 0) + r.amount;
    }
    final consumablesByDoctor = <String, double>{};
    final mediaByDoctor = <String, double>{};
    for (final r in expenseList) {
      final cat = (r.category).toLowerCase().trim();
      final id = r.paidByDoctorId ?? '';
      if (cat == 'media') {
        mediaByDoctor[id] = (mediaByDoctor[id] ?? 0) + r.amount;
      } else if (cat == 'supplies' || cat == 'other' || cat == 'consumables') {
        consumablesByDoctor[id] = (consumablesByDoctor[id] ?? 0) + r.amount;
      }
    }
    final rows = <_DoctorRow>[];
    for (final d in doctors) {
      final income = incomeByDoctor[d.id] ?? 0;
      if (income <= 0) continue;
      final c30 = income * 0.3;
      final bonus = (income - _target) > 0 ? (income - _target) : 0.0;
      final rate = _commissionRateForIncome(income);
      final percentVal = bonus * rate;
      final consumables = _overridesConsumables[d.id] ?? consumablesByDoctor[d.id] ?? 0;
      final media = _overridesMedia[d.id] ?? mediaByDoctor[d.id] ?? 0;
      rows.add(_DoctorRow(
        doctorId: d.id,
        doctorName: cache.doctorDisplayName(d.id) ?? d.displayName ?? d.id,
        income: income,
        c30: c30,
        bonus: bonus,
        percentVal: percentVal,
        commissionPercent: rate,
        consumables: consumables,
        media: media,
      ));
    }
    _totalIncome = rows.fold<double>(0, (s, r) => s + r.income);
    _totalC30 = rows.fold<double>(0, (s, r) => s + r.c30);
    _totalBonus = rows.fold<double>(0, (s, r) => s + r.bonus);
    _totalPercent = rows.fold<double>(0, (s, r) => s + r.percentVal);
    _totalConsumables = rows.fold<double>(0, (s, r) => s + r.consumables);
    _totalMedia = rows.fold<double>(0, (s, r) => s + r.media);
    _net = _totalIncome - _totalC30 - _rentGuard - _receptionist - _totalConsumables - _totalMedia - _totalPercent;
    _mang = _net * 0.15;
    _basket = _net * 0.30;
    _profitForEach = rows.isEmpty ? 0 : (_net - _mang - _basket) / rows.length;
    if (mounted) setState(() => _doctorRows = rows);
  }

  int _getConfigMonth() {
    switch (_period) {
      case _SummaryPeriod.month:
        return _month;
      case _SummaryPeriod.quarter:
        return ((_month - 1) ~/ 3) * 3 + 1;
      case _SummaryPeriod.sixMonths:
        return _month <= 6 ? 1 : 7;
      case _SummaryPeriod.year:
        return 1;
    }
  }

  int _getMonthsInRange() {
    switch (_period) {
      case _SummaryPeriod.month:
        return 1;
      case _SummaryPeriod.quarter:
        return 3;
      case _SummaryPeriod.sixMonths:
        return 6;
      case _SummaryPeriod.year:
        return 12;
    }
  }

  /// Commission rate (right column of commission table) for a given income. Used for % = BONUS * rate.
  double _commissionRateForIncome(double income) {
    for (final s in _slices) {
      if (income < s.min) continue;
      if (s.max == null || income <= s.max!) return s.rate;
    }
    return _slices.isNotEmpty ? _slices.last.rate : 0.25;
  }

  Future<void> _saveConfig() async {
    setState(() => _saving = true);
    final configMonth = _getConfigMonth();
    final monthsInRange = _getMonthsInRange();
    final doctorPercent = _doctorPercent;
    final commissionSlices = _slices.map((s) => {'min': s.min, 'max': s.max, 'percent': s.percent, 'rate': s.rate}).toList();
    final data = <String, dynamic>{
      'target': _target / monthsInRange,
      'rentGuard': _rentGuard / monthsInRange,
      'receptionist': _receptionist / monthsInRange,
      'doctorPercent': doctorPercent,
      'commissionSlices': commissionSlices,
    };
    if (_period == _SummaryPeriod.month) {
      data['consumablesByDoctor'] = {for (final r in _doctorRows) r.doctorId: r.consumables};
      data['mediaByDoctor'] = {for (final r in _doctorRows) r.doctorId: r.media};
    }
    await _firestore.setFinanceSummaryConfig(_year, configMonth, data);
    if (mounted) setState(() => _saving = false);
  }

  void _recalcFromRows() {
    _totalIncome = _doctorRows.fold<double>(0, (s, r) => s + r.income);
    _totalC30 = _doctorRows.fold<double>(0, (s, r) => s + r.c30);
    _totalBonus = _doctorRows.fold<double>(0, (s, r) => s + r.bonus);
    _totalPercent = _doctorRows.fold<double>(0, (s, r) => s + r.percentVal);
    _totalConsumables = _doctorRows.fold<double>(0, (s, r) => s + r.consumables);
    _totalMedia = _doctorRows.fold<double>(0, (s, r) => s + r.media);
    // NET = Total income - Total 30% - Rent - Receptionist - Total consumables - Total media - Total %
    _net = _totalIncome - _totalC30 - _rentGuard - _receptionist - _totalConsumables - _totalMedia - _totalPercent;
    _mang = _net * 0.15;
    _basket = _net * 0.30;
    _profitForEach = _doctorRows.isEmpty ? 0 : (_net - _mang - _basket) / _doctorRows.length;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final cache = context.watch<DataCacheProvider>();
    final isRtl = l10n.isArabic;

    return Directionality(
      textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        appBar: AppBar(
          title: Text(l10n.financeSummary),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () {
              if (context.canPop()) context.pop();
              else context.go('/income-expenses');
            },
          ),
          actions: const [NotificationsButton()],
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : _loadError != null
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(l10n.financeSummaryLoadError, textAlign: TextAlign.center),
                          if (_loadError != null && _loadError!.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Text(_loadError!, style: Theme.of(context).textTheme.bodySmall, textAlign: TextAlign.center),
                          ],
                          const SizedBox(height: 16),
                          FilledButton.icon(
                            onPressed: () => _loadConfigAndData(),
                            icon: const Icon(Icons.refresh),
                            label: Text(l10n.retry),
                          ),
                        ],
                      ),
                    ),
                  )
                : RefreshIndicator(
                onRefresh: _loadConfigAndData,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: ResponsivePadding.all(context),
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            DropdownButton<int>(
                              value: _month,
                              items: List.generate(12, (i) => i + 1)
                                  .map((m) => DropdownMenuItem(
                                      value: m,
                                      child: Text(AppDateFormat.monthYear().format(DateTime(_year, m)))),
                                  )
                                  .toList(),
                              onChanged: (v) {
                                if (v != null) setState(() => _month = v);
                                _loadConfigAndData();
                              },
                            ),
                            const SizedBox(width: 8),
                            DropdownButton<int>(
                              value: _year,
                              items: List.generate(5, (i) => DateTime.now().year - 2 + i)
                                  .map((y) => DropdownMenuItem(value: y, child: Text('$y')))
                                  .toList(),
                              onChanged: (v) {
                                if (v != null) setState(() => _year = v);
                                _loadConfigAndData();
                              },
                            ),
                            const SizedBox(width: 12),
                            DropdownButton<_SummaryPeriod>(
                              value: _period,
                              items: [
                                DropdownMenuItem(value: _SummaryPeriod.month, child: Text(l10n.month)),
                                DropdownMenuItem(value: _SummaryPeriod.quarter, child: Text(l10n.periodQuarter)),
                                DropdownMenuItem(value: _SummaryPeriod.sixMonths, child: Text(l10n.periodSixMonths)),
                                DropdownMenuItem(value: _SummaryPeriod.year, child: Text(l10n.year)),
                              ],
                              onChanged: (v) {
                                if (v != null) setState(() => _period = v);
                                _loadConfigAndData();
                              },
                            ),
                            const SizedBox(width: 16),
                            SizedBox(
                              width: 120,
                              child: TextFormField(
                                initialValue: _target.toStringAsFixed(0),
                                keyboardType: TextInputType.number,
                                decoration: InputDecoration(
                                  labelText: l10n.target,
                                  isDense: true,
                                ),
                                onChanged: (v) {
                                  final t = double.tryParse(v);
                                  if (t != null && t >= 0) {
                                    setState(() {
                                      _target = t;
                                      for (var i = 0; i < _doctorRows.length; i++) {
                                        final r = _doctorRows[i];
                                        final rate = _commissionRateForIncome(r.income);
                                        final bonusVal = (r.income - t) > 0 ? (r.income - t) : 0.0;
                                        _doctorRows[i] = r.copyWith(
                                          c30: r.income * 0.3,
                                          bonus: bonusVal,
                                          percentVal: bonusVal * rate,
                                          commissionPercent: rate,
                                        );
                                      }
                                      _recalcFromRows();
                                    });
                                  }
                                },
                              ),
                            ),
                            const SizedBox(width: 16),
                            if (_saving) const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2)),
                            if (!_saving)
                              FilledButton.icon(
                                icon: const Icon(Icons.save),
                                label: Text(l10n.save),
                                onPressed: _saveConfig,
                              ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: SingleChildScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: EdgeInsets.only(
                          left: ResponsivePadding.all(context).left,
                          right: ResponsivePadding.all(context).right,
                          bottom: ResponsivePadding.all(context).bottom,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _buildMainTable(context, l10n, cache),
                            const SizedBox(height: 24),
                            Text(l10n.commission, style: Theme.of(context).textTheme.titleMedium),
                            const SizedBox(height: 8),
                            _buildCommissionTable(context, l10n),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildMainTable(BuildContext context, AppLocalizations l10n, DataCacheProvider cache) {
    final nf = NumberFormat.currency(symbol: '', decimalDigits: 0);
    final padding = ResponsivePadding.all(context);
    final minWidth = MediaQuery.sizeOf(context).width - padding.left - padding.right;
    return LayoutBuilder(
      builder: (_, constraints) {
        final tableMinWidth = constraints.maxWidth > 0 ? constraints.maxWidth : minWidth;
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: ConstrainedBox(
            constraints: BoxConstraints(minWidth: tableMinWidth),
            child: DataTable(
              columnSpacing: Breakpoint.isMobile(context) ? 12 : 24,
              horizontalMargin: Breakpoint.isMobile(context) ? 8 : 16,
              headingRowColor: WidgetStateProperty.all(Theme.of(context).colorScheme.surfaceContainerHighest),
              headingTextStyle: TextStyle(
                color: Theme.of(context).colorScheme.onSurface,
                fontWeight: FontWeight.w600,
              ),
              columns: [
                DataColumn(label: Text(l10n.doctor)),
                DataColumn(label: Text(l10n.income)),
                DataColumn(label: Text(l10n.percent30Target)),
                DataColumn(label: Text(l10n.bonus)),
                DataColumn(label: const Text('%')),
                DataColumn(label: Text('Consumables')),
                DataColumn(label: Text('Media')),
              ],
              rows: [
          ..._doctorRows.map((r) => DataRow(
                cells: [
                  DataCell(Text(r.doctorName)),
                  DataCell(_editableCell(nf.format(r.income), (v) {
                    final x = double.tryParse(v);
                    if (x == null) return;
                    _updateDoctorRow(r.doctorId, income: x);
                  })),
                  DataCell(Text(nf.format(r.c30))),
                  DataCell(Text(nf.format(r.bonus))),
                  DataCell(Text('${r.commissionPercent} (${nf.format(r.percentVal)})')), // rate from slice table, % = BONUS * rate
                  DataCell(_editableCell(nf.format(r.consumables), (v) {
                    final x = double.tryParse(v.replaceAll(',', ''));
                    if (x == null) return;
                    _updateDoctorRow(r.doctorId, consumables: x);
                  })),
                  DataCell(_editableCell(nf.format(r.media), (v) {
                    final x = double.tryParse(v.replaceAll(',', ''));
                    if (x == null) return;
                    _updateDoctorRow(r.doctorId, media: x);
                  })),
                ],
              )),
          // Total row (exactly like spreadsheet row 30): Total | income | 30% | Total | % | consumables | media
          DataRow(
            cells: [
              const DataCell(Text('Total')),
              DataCell(Text(nf.format(_totalIncome))),
              DataCell(Text(nf.format(_totalC30))),
              DataCell(Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('Total'), Text(nf.format(_totalBonus), style: const TextStyle(fontSize: 11))])),
              DataCell(Text(nf.format(_totalPercent))),
              DataCell(Text(nf.format(_totalConsumables))),
              DataCell(Text(nf.format(_totalMedia))),
            ],
          ),
          // Summary rows exactly like spreadsheet (rows 31–33): Label1 | Value1 | Label2 | Value2 | Doctor | C+E
          DataRow(
            cells: [
              const DataCell(Text('NET')),
              DataCell(Text(nf.format(_net), style: const TextStyle(fontWeight: FontWeight.bold))),
              DataCell(Text(l10n.rentGuard)),
              DataCell(_editableCell(nf.format(_rentGuard), (v) {
                final x = double.tryParse(v.replaceAll(',', ''));
                if (x != null) setState(() { _rentGuard = x; _recalcFromRows(); });
              })),
              DataCell(Text(_doctorRows.isNotEmpty ? _doctorRows[0].doctorName : '')),
              DataCell(Text(_doctorRows.isNotEmpty ? nf.format(_doctorRows[0].c30 + _doctorRows[0].percentVal) : '')),
              const DataCell(Text('')),
            ],
          ),
          DataRow(
            cells: [
              const DataCell(Text('MANG (.15)')),
              DataCell(Text(nf.format(_mang))),
              DataCell(Text(l10n.receptionist)),
              DataCell(_editableCell(nf.format(_receptionist), (v) {
                final x = double.tryParse(v.replaceAll(',', ''));
                if (x != null) setState(() { _receptionist = x; _recalcFromRows(); });
              })),
              DataCell(Text(_doctorRows.length > 1 ? _doctorRows[1].doctorName : '')),
              DataCell(Text(_doctorRows.length > 1 ? nf.format(_doctorRows[1].c30 + _doctorRows[1].percentVal) : '')),
              const DataCell(Text('')),
            ],
          ),
          DataRow(
            cells: [
              const DataCell(Text('BASKET (.3)')),
              DataCell(Text(nf.format(_basket))),
              DataCell(Text(l10n.profitForEach)),
              DataCell(Text(nf.format(_profitForEach), style: const TextStyle(fontWeight: FontWeight.bold))),
              DataCell(Text(_doctorRows.length > 2 ? _doctorRows[2].doctorName : '')),
              DataCell(Text(_doctorRows.length > 2 ? nf.format(_doctorRows[2].c30 + _doctorRows[2].percentVal) : '')),
              const DataCell(Text('')),
            ],
          ),
        ],
      ),
            ),
          );
      },
    );
  }

  Widget _editableCell(String value, void Function(String) onChanged) {
    return SizedBox(
      width: 90,
      child: TextFormField(
        initialValue: value,
        keyboardType: TextInputType.number,
        decoration: const InputDecoration(isDense: true, border: OutlineInputBorder()),
        onChanged: onChanged,
      ),
    );
  }

  void _updateDoctorRow(String doctorId, {double? income, double? consumables, double? media}) {
    final i = _doctorRows.indexWhere((r) => r.doctorId == doctorId);
    if (i < 0) return;
    final r = _doctorRows[i];
    final newIncome = income ?? r.income;
    final rate = _commissionRateForIncome(newIncome);
    final newC30 = newIncome * 0.3;
    final newBonus = (newIncome - _target) > 0 ? (newIncome - _target) : 0.0;
    final newPercentVal = newBonus * rate;
    _doctorRows[i] = r.copyWith(
      income: newIncome,
      c30: newC30,
      bonus: newBonus,
      commissionPercent: rate,
      percentVal: newPercentVal,
      consumables: consumables ?? r.consumables,
      media: media ?? r.media,
    );
    _recalcFromRows();
    setState(() {});
  }

  void _recalcPercentFromSlices() {
    for (var i = 0; i < _doctorRows.length; i++) {
      final r = _doctorRows[i];
      final rate = _commissionRateForIncome(r.income);
      final percentVal = r.bonus * rate;
      _doctorRows[i] = r.copyWith(commissionPercent: rate, percentVal: percentVal);
    }
    _recalcFromRows();
  }

  Widget _buildCommissionTable(BuildContext context, AppLocalizations l10n) {
    final theme = Theme.of(context).colorScheme;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        headingRowColor: WidgetStateProperty.all(theme.surfaceContainerHighest),
        headingTextStyle: TextStyle(color: theme.onSurface, fontWeight: FontWeight.w600),
        columns: [
          DataColumn(label: Text(l10n.slice)),
          DataColumn(label: Text(l10n.incomeRange)),
          DataColumn(label: Text(l10n.commission)),
          const DataColumn(label: Text('Rate')),
        ],
        rows: _slices.asMap().entries.map((e) {
          final idx = e.key;
          final s = e.value;
          final range = s.max == null ? 'above ${(s.min / 1000).toStringAsFixed(0)} k' : '${(s.min / 1000).toStringAsFixed(0)} k - ${(s.max! / 1000).toStringAsFixed(0)} k';
          return DataRow(
            cells: [
              DataCell(Text('${idx + 1}')),
              DataCell(Text(range)),
              DataCell(Text('${s.percent.toStringAsFixed(0)}%')),
              DataCell(SizedBox(
                width: 56,
                child: TextFormField(
                  initialValue: s.rate.toString(),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(isDense: true, border: OutlineInputBorder()),
                  onChanged: (v) {
                    final x = double.tryParse(v);
                    if (x == null || x < 0 || x > 1) return;
                    setState(() {
                      final prev = _slices[idx];
                      _slices = [
                        for (var i = 0; i < _slices.length; i++)
                          i == idx ? (min: prev.min, max: prev.max, percent: prev.percent, rate: x) : _slices[i],
                      ];
                      _recalcPercentFromSlices();
                    });
                  },
                ),
              )),
            ],
          );
        }).toList(),
      ),
    );
  }
}

class _DoctorRow {
  final String doctorId;
  final String doctorName;
  final double income;
  final double c30;
  final double bonus;
  final double percentVal;
  final double commissionPercent;
  final double consumables;
  final double media;

  _DoctorRow({
    required this.doctorId,
    required this.doctorName,
    required this.income,
    required this.c30,
    required this.bonus,
    required this.percentVal,
    required this.commissionPercent,
    required this.consumables,
    required this.media,
  });

  _DoctorRow copyWith({
    double? income,
    double? c30,
    double? bonus,
    double? percentVal,
    double? commissionPercent,
    double? consumables,
    double? media,
  }) {
    return _DoctorRow(
      doctorId: doctorId,
      doctorName: doctorName,
      income: income ?? this.income,
      c30: c30 ?? this.c30,
      bonus: bonus ?? this.bonus,
      percentVal: percentVal ?? this.percentVal,
      commissionPercent: commissionPercent ?? this.commissionPercent,
      consumables: consumables ?? this.consumables,
      media: media ?? this.media,
    );
  }
}
