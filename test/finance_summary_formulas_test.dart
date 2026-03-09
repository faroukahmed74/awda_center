import 'package:flutter_test/flutter_test.dart';

/// Tests that the Finance Summary formulas match the spreadsheet:
/// Second slice (21k–29k) uses rate 0.05. Dr. Samir 35k → % 2250; Dr. Tarek 25k → % 250 (5000*0.05); Dr. Ziad 18k → bonus 0, % 0.
/// Total % = 2500; NET = 21,100; MANG = 3,165; BASKET = 6,330; Profit for each = 3,835; Net for Dr. Tarek = 7,750.
void main() {
  test('Finance summary formulas match spreadsheet', () {
    const double rentGuard = 10500;
    const double receptionist = 4500;

    final rows = [
      _Row(income: 35000, c30: 10500, bonus: 15000, percentVal: 2250, consumables: 7000, media: 0),
      _Row(income: 25000, c30: 7500, bonus: 5000, percentVal: 250, consumables: 0, media: 0),
      _Row(income: 18000, c30: 5400, bonus: 0, percentVal: 0, consumables: 9000, media: 0),
    ];

    final totalIncome = rows.fold<double>(0, (s, r) => s + r.income);
    final totalC30 = rows.fold<double>(0, (s, r) => s + r.c30);
    final totalPercent = rows.fold<double>(0, (s, r) => s + r.percentVal);
    final totalConsumables = rows.fold<double>(0, (s, r) => s + r.consumables);
    final totalMedia = rows.fold<double>(0, (s, r) => s + r.media);

    expect(totalIncome, 78000);
    expect(totalC30, 23400);
    expect(totalPercent, 2500);
    expect(totalConsumables, 16000);
    expect(totalMedia, 0);

    // NET = Total income - Total 30% - Rent - Receptionist - Total consumables - Total media - Total %
    final net = totalIncome - totalC30 - rentGuard - receptionist - totalConsumables - totalMedia - totalPercent;
    expect(net, 21100);

    // MANG = NET * 0.15
    final mang = net * 0.15;
    expect(mang, closeTo(3165, 0.1));

    // BASKET = NET * 0.30
    final basket = net * 0.30;
    expect(basket, 6330);

    // Profit for each = (NET - MANG - BASKET) / number of doctors
    final profitForEach = (net - mang - basket) / rows.length;
    expect(profitForEach, closeTo(3835, 1));

    // Net for Dr. Tarek = 30% target + % = 7500 + 250
    expect(rows[1].c30 + rows[1].percentVal, 7750);
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
