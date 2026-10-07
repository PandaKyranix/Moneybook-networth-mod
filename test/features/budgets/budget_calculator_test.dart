import 'package:flutter_test/flutter_test.dart';
import 'package:moneybook/features/budgets/domain/entities/budget.dart';
import 'package:moneybook/features/budgets/domain/services/budget_calculator.dart';

import '../../helpers/booking_helpers.dart';

Budget _budget(String categorie, int month, double amount) => Budget(
      id: month * 100 + categorie.length,
      categorie: categorie,
      date: DateTime(2026, month, 1),
      amount: amount,
      used: 0.0,
      remaining: 0.0,
      percentage: 0.0,
      currency: '€',
    );

void main() {
  test('monthly usage: only expenses of the budget category count', () {
    final budgets = [_budget('lebensmittel', 3, 400), _budget('freizeit', 3, 100)];
    applyBudgetUsage(budgets, [
      expense(150, categorie: 'lebensmittel', date: DateTime(2026, 3, 2)),
      expense(80, categorie: 'lebensmittel', date: DateTime(2026, 3, 20)),
      expense(120, categorie: 'freizeit', date: DateTime(2026, 3, 5)),
      income(1000, date: DateTime(2026, 3, 1)),
      transfer('Giro', 'Spar', 500, date: DateTime(2026, 3, 1)),
    ]);
    expect(budgets[0].used, 230);
    expect(budgets[0].remaining, 170);
    expect(budgets[1].used, 120);
    expect(budgets[1].remaining, -20);
    expect(budgets[1].percentage, closeTo(120, 0.001));
  });

  test('yearly budget = sum of monthly budgets, usage per month like the monthly view', () {
    final budgets = [
      for (int m = 1; m <= 12; m++) _budget('lebensmittel', m, 400),
      for (int m = 6; m <= 12; m++) _budget('freizeit', m, 100),
    ];
    final bookings = [
      expense(350, categorie: 'lebensmittel', date: DateTime(2026, 1, 10)),
      expense(450, categorie: 'lebensmittel', date: DateTime(2026, 2, 10)),
      // Ausgabe ohne Budget in diesem Monat zählt nicht.
      expense(60, categorie: 'freizeit', date: DateTime(2026, 3, 10)),
      expense(90, categorie: 'freizeit', date: DateTime(2026, 7, 10)),
      // Anderes Jahr zählt nicht.
      expense(999, categorie: 'lebensmittel', date: DateTime(2025, 12, 31)),
    ];
    final summary = calculateYearlyBudget(budgets: budgets, bookings: bookings, year: 2026);
    expect(summary.budget, 12 * 400 + 7 * 100);
    expect(summary.used, 350 + 450 + 90);
    expect(summary.months[0].used, 350);
    expect(summary.months[2].used, 0);
    expect(summary.months[6].used, 90);
    expect(summary.months[6].budget, 500);
    final lebensmittel = summary.categories.firstWhere((c) => c.categorie == 'lebensmittel');
    expect(lebensmittel.budget, 4800);
    expect(lebensmittel.used, 800);
    expect(lebensmittel.numberOfMonths, 12);
    final freizeit = summary.categories.firstWhere((c) => c.categorie == 'freizeit');
    expect(freizeit.numberOfMonths, 7);
    expect(freizeit.used, 90);
    expect(summary.maxUsed, 450);
    expect(summary.minUsed, 0);
    // Die geladenen Budgets werden nicht verändert.
    expect(budgets.every((b) => b.used == 0.0), isTrue);
  });

  test('year without budgets', () {
    final summary = calculateYearlyBudget(budgets: [], bookings: [expense(10)], year: 2026);
    expect(summary.budget, 0);
    expect(summary.percentage, 0);
    expect(summary.categories, isEmpty);
    expect(summary.averageUsed, 0);
  });
}
