import '../../../accounts/domain/services/net_worth_calculator.dart';
import '../entities/booking.dart';
import '../value_objects/booking_type.dart';

/// Gemeinsame Berechnungen für Saldo-Karten, Saldo-Linie und Jahresübersicht.
/// Alle Werte werden aus denselben Funktionen abgeleitet ([availableChange], [reservedChange]),
/// damit Monats- und Jahresansicht immer zusammenpassen.

/// Eine Buchung gilt als gebucht, sobald ihr Datum erreicht ist (wie bisher auf der Buchungsseite).
bool isBookingDue(Booking booking, DateTime now) => !booking.date.isAfter(now);

/// Einnahmen, Ausgaben und Zurückgelegtes eines Zeitraums.
class SaldoSummary {
  final double income;
  final double expense;

  /// Netto zurückgelegt (siehe [reservedChange]); negativ, wenn mehr freigegeben / ausgegeben als zurückgelegt wurde.
  final double setAside;

  const SaldoSummary({this.income = 0.0, this.expense = 0.0, this.setAside = 0.0});

  static const SaldoSummary zero = SaldoSummary();

  /// Saldo = Einnahmen - Ausgaben - Zurückgelegt.
  double get balance => calculateMonthlyBalance(income: income, expense: expense, netSetAside: setAside);

  bool get isEmpty => income == 0.0 && expense == 0.0 && setAside == 0.0;

  SaldoSummary operator +(SaldoSummary other) => SaldoSummary(
        income: income + other.income,
        expense: expense + other.expense,
        setAside: setAside + other.setAside,
      );
}

/// Fasst Buchungen zu Einnahmen / Ausgaben / Zurückgelegt zusammen.
SaldoSummary summarizeBookings(Iterable<Booking> bookings, Set<String> excludedAccountNames) {
  double income = 0.0;
  double expense = 0.0;
  for (final booking in bookings) {
    if (booking.type == BookingType.income) {
      income += booking.amount;
    } else if (booking.type == BookingType.expense) {
      expense += booking.amount;
    }
  }
  return SaldoSummary(
    income: income,
    expense: expense,
    setAside: calculateNetSetAside(bookings, excludedAccountNames),
  );
}

/// Tagesgenauer Verlauf des Monatssaldos.
class MonthlySaldoSeries {
  /// values[0] = 0 (Monatsanfang), values[d] = Saldo nach allen Buchungen bis einschließlich Tag d.
  /// Enthält gebuchte und ausstehende Buchungen; ab [lastDueDay] sind die Werte eine Vorschau.
  final List<double> values;

  /// Letzter Tag, dessen Buchungen bereits gebucht sind (0 = Monat liegt komplett in der Zukunft).
  final int lastDueDay;

  /// Ob nach [lastDueDay] noch ausstehende Buchungen den Saldo verändern.
  final bool hasPendingChanges;

  const MonthlySaldoSeries({required this.values, required this.lastDueDay, required this.hasPendingChanges});

  int get daysInMonth => values.length - 1;

  /// Aktueller Saldo (entspricht der Saldo-Karte).
  double get dueBalance => values[lastDueDay];

  /// Saldo am Monatsende inklusive ausstehender Buchungen.
  double get projectedBalance => values.last;
}

/// Berechnet den Saldo-Verlauf eines Monats. Mehrere Buchungen an einem Tag werden zusammengefasst.
/// Buchungen außerhalb des Monats werden ignoriert, damit nichts doppelt gezählt wird.
MonthlySaldoSeries calculateMonthlySaldoSeries({
  required Iterable<Booking> bookings,
  required Set<String> excludedAccountNames,
  required int year,
  required int month,
  required DateTime now,
}) {
  final int daysInMonth = DateTime(year, month + 1, 0).day;
  final List<double> dailyChanges = List<double>.filled(daysInMonth + 1, 0.0);
  for (final booking in bookings) {
    if (booking.date.year != year || booking.date.month != month) {
      continue;
    }
    dailyChanges[booking.date.day] += availableChange(booking, excludedAccountNames);
  }
  final List<double> values = List<double>.filled(daysInMonth + 1, 0.0);
  for (int day = 1; day <= daysInMonth; day++) {
    values[day] = values[day - 1] + dailyChanges[day];
  }
  final int lastDueDay = lastDueDayOfMonth(year: year, month: month, now: now);
  bool hasPendingChanges = false;
  for (int day = lastDueDay + 1; day <= daysInMonth; day++) {
    if (dailyChanges[day] != 0.0) {
      hasPendingChanges = true;
      break;
    }
  }
  return MonthlySaldoSeries(values: values, lastDueDay: lastDueDay, hasPendingChanges: hasPendingChanges);
}

/// Letzter bereits gebuchter Tag eines Monats bezogen auf [now].
int lastDueDayOfMonth({required int year, required int month, required DateTime now}) {
  final int daysInMonth = DateTime(year, month + 1, 0).day;
  if (now.isBefore(DateTime(year, month, 1))) {
    return 0;
  }
  if (now.year == year && now.month == month) {
    return now.day;
  }
  return daysInMonth;
}

/// Saldo eines Monats in der Jahresübersicht.
class MonthSaldo {
  final int month;

  /// Bereits gebuchte Buchungen des Monats (wie die Saldo-Karte der Monatsansicht).
  final SaldoSummary due;

  /// Noch ausstehende Buchungen des Monats.
  final SaldoSummary pending;

  /// Summe der Monatssalden aller vorherigen Monate des Jahres (nur gebuchte Buchungen).
  final double yearToDateBefore;

  /// Ob der Monat komplett in der Zukunft liegt.
  final bool isFuture;

  const MonthSaldo({
    required this.month,
    required this.due,
    required this.pending,
    required this.yearToDateBefore,
    required this.isFuture,
  });

  double get yearToDateAfter => yearToDateBefore + due.balance;

  /// Werte für das Balkendiagramm: Zukünftige Monate zeigen die geplanten Buchungen.
  SaldoSummary get chartValues => isFuture ? pending : due;
}

/// Jahresübersicht: Für jeden Monat Einnahmen, Ausgaben, Zurückgelegt und Saldo
/// aus genau denselben Funktionen wie die Monatsansicht.
List<MonthSaldo> calculateYearlySaldo({
  required Iterable<Booking> bookings,
  required Set<String> excludedAccountNames,
  required int year,
  required DateTime now,
}) {
  final List<List<Booking>> dueByMonth = List.generate(12, (_) => <Booking>[]);
  final List<List<Booking>> pendingByMonth = List.generate(12, (_) => <Booking>[]);
  for (final booking in bookings) {
    if (booking.date.year != year) {
      continue;
    }
    if (isBookingDue(booking, now)) {
      dueByMonth[booking.date.month - 1].add(booking);
    } else {
      pendingByMonth[booking.date.month - 1].add(booking);
    }
  }
  final List<MonthSaldo> months = [];
  double yearToDate = 0.0;
  for (int i = 0; i < 12; i++) {
    final SaldoSummary due = summarizeBookings(dueByMonth[i], excludedAccountNames);
    final SaldoSummary pending = summarizeBookings(pendingByMonth[i], excludedAccountNames);
    months.add(MonthSaldo(
      month: i + 1,
      due: due,
      pending: pending,
      yearToDateBefore: yearToDate,
      isFuture: now.isBefore(DateTime(year, i + 1, 1)),
    ));
    yearToDate += due.balance;
  }
  return months;
}
