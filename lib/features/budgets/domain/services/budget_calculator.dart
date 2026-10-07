import '../../../bookings/domain/entities/booking.dart';
import '../../../bookings/domain/value_objects/booking_type.dart';
import '../entities/budget.dart';

/// Berechnet verbraucht / verbleibend / Prozent für die Budgets eines Monats.
/// Das ist exakt die bisherige Logik der Monatsansicht (BudgetListPage): Jede Ausgabe zählt
/// für das Budget ihrer Kategorie, unabhängig davon, ob sie schon gebucht oder noch ausstehend ist.
void applyBudgetUsage(List<Budget> budgets, List<Booking> bookings) {
  for (int i = 0; i < budgets.length; i++) {
    budgets[i].used = 0.0;
    budgets[i].remaining = 0.0;
    budgets[i].percentage = 0.0;
  }
  for (int i = 0; i < bookings.length; i++) {
    for (int j = 0; j < budgets.length; j++) {
      if (bookings[i].categorie == budgets[j].categorie && bookings[i].type == BookingType.expense) {
        budgets[j].used += bookings[i].amount;
        break;
      }
    }
  }
  for (int i = 0; i < budgets.length; i++) {
    budgets[i].remaining = budgets[i].amount - budgets[i].used;
    if (budgets[i].amount != 0) {
      budgets[i].percentage = (budgets[i].used / budgets[i].amount) * 100;
    } else {
      budgets[i].percentage = 0;
    }
  }
}

/// Budget und Verbrauch eines Monats (alle Kategorien zusammen).
class MonthBudgetTotal {
  final int month;
  final double budget;
  final double used;

  const MonthBudgetTotal({required this.month, required this.budget, required this.used});

  bool get hasBudget => budget != 0.0;
}

/// Budget und Verbrauch einer Kategorie über das ganze Jahr.
class CategorieBudgetTotal {
  final String categorie;
  final double budget;
  final double used;
  final int numberOfMonths;

  const CategorieBudgetTotal({required this.categorie, required this.budget, required this.used, required this.numberOfMonths});

  double get remaining => budget - used;

  double get percentage => budget != 0.0 ? used / budget * 100.0 : 0.0;
}

class YearlyBudgetSummary {
  final List<MonthBudgetTotal> months;
  final List<CategorieBudgetTotal> categories;

  const YearlyBudgetSummary({required this.months, required this.categories});

  double get budget => months.fold(0.0, (sum, month) => sum + month.budget);

  double get used => months.fold(0.0, (sum, month) => sum + month.used);

  double get remaining => budget - used;

  double get percentage => budget != 0.0 ? used / budget * 100.0 : 0.0;

  Iterable<MonthBudgetTotal> get _monthsWithBudget => months.where((month) => month.hasBudget);

  /// Kleinster / durchschnittlicher / größter monatlicher Verbrauch (nur Monate mit Budget).
  double get minUsed => _monthsWithBudget.isEmpty ? 0.0 : _monthsWithBudget.map((month) => month.used).reduce((a, b) => a < b ? a : b);

  double get maxUsed => _monthsWithBudget.isEmpty ? 0.0 : _monthsWithBudget.map((month) => month.used).reduce((a, b) => a > b ? a : b);

  double get averageUsed => _monthsWithBudget.isEmpty ? 0.0 : _monthsWithBudget.fold(0.0, (sum, month) => sum + month.used) / _monthsWithBudget.length;
}

/// Jahresbudget = Summe der Monatsbudgets (in Moneybook gibt es pro Kategorie und Monat einen Budget-Eintrag).
/// Der Verbrauch wird für jeden Monat mit [applyBudgetUsage] berechnet, also genau wie in der Monatsansicht,
/// und dann aufsummiert. Die Kategorien bleiben erhalten, damit sichtbar ist, welches Budget überzogen wurde.
YearlyBudgetSummary calculateYearlyBudget({
  required List<Budget> budgets,
  required List<Booking> bookings,
  required int year,
}) {
  final List<MonthBudgetTotal> months = [];
  final Map<String, CategorieBudgetTotal> categories = {};
  for (int month = 1; month <= 12; month++) {
    // Kopien, damit die geladenen Budgets nicht verändert werden.
    final List<Budget> monthBudgets = budgets
        .where((budget) => budget.date.year == year && budget.date.month == month)
        .map((budget) => budget.copyWith(used: 0.0, remaining: 0.0, percentage: 0.0))
        .toList();
    final List<Booking> monthBookings = bookings.where((booking) => booking.date.year == year && booking.date.month == month).toList();
    applyBudgetUsage(monthBudgets, monthBookings);
    double budgetSum = 0.0;
    double usedSum = 0.0;
    for (final Budget budget in monthBudgets) {
      budgetSum += budget.amount;
      usedSum += budget.used;
      final CategorieBudgetTotal? previous = categories[budget.categorie];
      categories[budget.categorie] = CategorieBudgetTotal(
        categorie: budget.categorie,
        budget: (previous?.budget ?? 0.0) + budget.amount,
        used: (previous?.used ?? 0.0) + budget.used,
        numberOfMonths: (previous?.numberOfMonths ?? 0) + 1,
      );
    }
    months.add(MonthBudgetTotal(month: month, budget: budgetSum, used: usedSum));
  }
  final List<CategorieBudgetTotal> categorieList = categories.values.toList()..sort((first, second) => second.percentage.compareTo(first.percentage));
  return YearlyBudgetSummary(months: months, categories: categorieList);
}
