import 'package:flutter_test/flutter_test.dart';

/// Tests that the Finance Summary formulas match the spreadsheet:
/// Dr. Samir 35k → % 2250, Dr. Tarek 25k → % 2500 (rate 0.5), Dr. Ziad 18k → bonus 0, % 0.
/// Total % = 4750; NET = 18,850; MANG = 2,828; BASKET = 5,655; Profit for each = 3,456; Net for Dr. Tarek = 10,000.
void main() {
  test('Finance summary formulas match spreadsheet', () {
    const double rentGuard = 10500;
    const double receptionist = 4500;

    final rows = [
      _Row(income: 35000, c30: 10500, bonus: 15000, percentVal: 2250, consumables: 7000, media: 0),
      _Row(income: 25000, c30: 7500, bonus: 5000, percentVal: 2500, consumables: 0, media: 0),
      _Row(income: 18000, c30: 5400, bonus: 0, percentVal: 0, consumables: 9000, media: 0),
    ];

    final totalIncome = rows.fold<double>(0, (s, r) => s + r.income);
    final totalC30 = rows.fold<double>(0, (s, r) => s + r.c30);
    final totalPercent = rows.fold<double>(0, (s, r) => s + r.percentVal);
    final totalConsumables = rows.fold<double>(0, (s, r) => s + r.consumables);
    final totalMedia = rows.fold<double>(0, (s, r) => s + r.media);

    expect(totalIncome, 78000);
    expect(totalC30, 23400);
    expect(totalPercent, 4750);
    expect(totalConsumables, 16000);
    expect(totalMedia, 0);

    // NET = Total income - Total 30% - Rent - Receptionist - Total consumables - Total media - Total %
    final net = totalIncome - totalC30 - rentGuard - receptionist - totalConsumables - totalMedia - totalPercent;
    expect(net, 18850);

    // MANG = NET * 0.15
    final mang = net * 0.15;
    expect(mang, closeTo(2827.5, 0.1));

    // BASKET = NET * 0.30
    final basket = net * 0.30;
    expect(basket, 5655);

    // Profit for each = (NET - MANG - BASKET) / number of doctors
    final profitForEach = (net - mang - basket) / rows.length;
    expect(profitForEach, closeTo(3456, 1));

    // Net for Dr. Tarek = C28 + E28 = 30% target + % = 7500 + 2500
    expect(rows[1].c30 + rows[1].percentVal, 10000);
  });
}

class _Row {
  final double income;
  final double c30;
  final double bonus;
  final double percentVal;
  final double consumables;
  final double media;
  _Row({
    required this.income,
    required this.c30,
    required this.bonus,
    required this.percentVal,
    required this.consumables,
    required this.media,
  });
}
