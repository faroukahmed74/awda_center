import '../models/doctor_model.dart';
import '../models/income_expense_models.dart';

/// Same NET / BASKET math as [FinanceSummaryScreen] `_loadConfigAndData` (lines 146–261),
/// so other screens can show the same basket without duplicating UI.
class FinanceSummaryMetricsResult {
  const FinanceSummaryMetricsResult({
    required this.net,
    required this.basket,
    required this.basketSupport,
    required this.basketRate,
  });

  final double net;
  final double basket;
  final double basketSupport;
  final double basketRate;
}

const String kBasketSupportIncomeSource = 'Basket Support';
const String kBasketSupportExpenseCategory = 'Basket Support';

/// Commission rate for a given income (matches Finance Summary `_commissionRateForIncome`).
double commissionRateForIncome(
  double income,
  List<({double min, double? max, double percent, double rate})> slices,
) {
  for (final s in slices) {
    if (income < s.min) continue;
    if (s.max == null || income <= s.max!) return s.rate;
  }
  return slices.isNotEmpty ? slices.last.rate : 0.25;
}

/// [config] is the map from `getFinanceSummaryConfig(year, configMonth)`.
/// [monthsInRange] scales per-month target / rent / receptionist (1 = one month, 12 = year).
FinanceSummaryMetricsResult computeFinanceSummaryMetrics({
  required List<DoctorModel> doctors,
  required Map<String, dynamic> config,
  required List<IncomeRecordModel> incomeList,
  required List<ExpenseRecordModel> expenseList,
  required int monthsInRange,
}) {
  final configTarget = (config['target'] as num?)?.toDouble() ?? 20000;
  var configRent = (config['rentGuard'] as num?)?.toDouble() ?? 0;
  var configReceptionist = (config['receptionist'] as num?)?.toDouble() ?? 0;
  if (configRent == 10500) configRent = 0;
  if (configReceptionist == 4700 || configReceptionist == 4500) {
    configReceptionist = 0;
  }
  final target = configTarget * monthsInRange;
  var rentGuard = configRent * monthsInRange;
  var receptionist = configReceptionist * monthsInRange;
  final basketRate = (config['basketRate'] as num?)?.toDouble() ?? 0.30;
  final percent30 = (config['percent30'] as num?)?.toDouble() ?? 0.30;

  var slices = <({double min, double? max, double percent, double rate})>[
    (min: 10000, max: 19000, percent: 25, rate: 0.25),
    (min: 21000, max: 29000, percent: 35, rate: 0.05),
    (min: 30000, max: 39000, percent: 45, rate: 0.15),
    (min: 40000, max: 49000, percent: 55, rate: 0.25),
    (min: 50000, max: null, percent: 60, rate: 0.35),
  ];
  final sl = config['commissionSlices'];
  if (sl is List && sl.isNotEmpty) {
    slices = sl.map<({double min, double? max, double percent, double rate})>((s) {
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
  double basketSupportIncome = 0;
  for (final r in incomeList) {
    if (r.source.trim().toLowerCase() == kBasketSupportIncomeSource.toLowerCase()) {
      basketSupportIncome += r.amount;
      continue;
    }
    final id = r.doctorId ?? '';
    incomeByDoctor[id] = (incomeByDoctor[id] ?? 0) + r.amount;
  }

  final consumablesByDoctor = <String, double>{};
  final mediaByDoctor = <String, double>{};
  double rentTotal = 0;
  double salaryTotal = 0;
  double basketSupportExpense = 0;
  for (final r in expenseList) {
    final cat = (r.category).toLowerCase().trim();
    if (cat == kBasketSupportExpenseCategory.toLowerCase()) {
      basketSupportExpense += r.amount;
      continue;
    }
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
  if (rentTotal > 0 && rentGuard == 0) rentGuard = rentTotal;
  if (salaryTotal > 0 && receptionist == 0) receptionist = salaryTotal;

  final overridesConsumables = config['consumablesByDoctor'] is Map
      ? Map<String, double>.from(
          (config['consumablesByDoctor'] as Map).map(
            (k, v) => MapEntry(k.toString(), (v as num).toDouble()),
          ),
        )
      : <String, double>{};
  final overridesMedia = config['mediaByDoctor'] is Map
      ? Map<String, double>.from(
          (config['mediaByDoctor'] as Map).map(
            (k, v) => MapEntry(k.toString(), (v as num).toDouble()),
          ),
        )
      : <String, double>{};

  double totalIncome = 0;
  double totalC30 = 0;
  double totalPercent = 0;
  double totalConsumables = 0;
  double totalMedia = 0;

  for (final d in doctors) {
    final income = incomeByDoctor[d.id] ?? 0;
    if (income <= 0) continue;
    final c30 = income * percent30;
    final bonus = (income - target) > 0 ? (income - target) : 0.0;
    final rate = commissionRateForIncome(income, slices);
    final percentVal = bonus * rate;
    final consumables = overridesConsumables[d.id] ?? consumablesByDoctor[d.id] ?? 0;
    final media = overridesMedia[d.id] ?? mediaByDoctor[d.id] ?? 0;
    totalIncome += income;
    totalC30 += c30;
    totalPercent += percentVal;
    totalConsumables += consumables;
    totalMedia += media;
  }

  final net = totalIncome -
      totalC30 -
      rentGuard -
      receptionist -
      totalConsumables -
      totalMedia -
      totalPercent;
  final basketSupport = basketSupportIncome + basketSupportExpense;
  final basket = (net * basketRate) + basketSupport;

  return FinanceSummaryMetricsResult(
    net: net,
    basket: basket,
    basketSupport: basketSupport,
    basketRate: basketRate,
  );
}
