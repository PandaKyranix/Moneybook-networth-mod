import 'dart:math';

import '../../../bookings/domain/entities/booking.dart';
import '../../../bookings/domain/value_objects/amount_type.dart';
import '../../../bookings/domain/value_objects/booking_type.dart';
import '../../../bookings/domain/value_objects/repetition_type.dart';

/// Kennzahlen eines Sparziels.
class GoalMetrics {
  final double saved;
  final double target;

  /// Tage bis zur Deadline (negativ = Deadline überschritten).
  final int daysLeft;

  /// Benötigter Betrag pro Monat bis zur Deadline; null, wenn das Ziel erreicht oder die Deadline vorbei ist.
  final double? requiredPerMonth;

  const GoalMetrics({required this.saved, required this.target, required this.daysLeft, required this.requiredPerMonth});

  double get remaining => max(target - saved, 0.0);

  /// Fortschritt als Anteil (1.0 = 100 %). Kann über 1.0 liegen, wenn mehr gespart wurde als nötig.
  double get progress => target > 0.0 ? saved / target : (saved > 0.0 ? 1.0 : 0.0);

  /// Erreicht, sobald der gesparte Betrag den Zielbetrag erreicht (Rundung auf Cent).
  bool get isReached => target > 0.0 && saved >= target - 0.005;

  bool get isOverdue => daysLeft < 0 && !isReached;
}

DateTime _dateOnly(DateTime date) => DateTime.utc(date.year, date.month, date.day);

/// Berechnet gesparten Betrag, Fortschritt, verbleibende Tage und benötigte Sparrate pro Monat.
/// Der Zielbetrag wird dabei nie verändert.
GoalMetrics calculateGoalMetrics({required double saved, required double target, required DateTime deadline, required DateTime now}) {
  final int daysLeft = _dateOnly(deadline).difference(_dateOnly(now)).inDays;
  final double remaining = max(target - saved, 0.0);
  double? requiredPerMonth;
  if (remaining > 0.005 && daysLeft >= 0) {
    // Angefangene Monate zählen als ganzer Monat; mindestens ein Monat.
    final int monthsLeft = max(1, (daysLeft / 30.4375).ceil());
    requiredPerMonth = remaining / monthsLeft;
  }
  return GoalMetrics(saved: saved, target: target, daysLeft: daysLeft, requiredPerMonth: requiredPerMonth);
}

/// Wie eine Buchung den Kontostand des Ziel-Kontos verändert. Spiegelt die Kontologik
/// (AccountLocalDataSource): Ausgabe/Einnahme betreffen fromAccount, Übertrag/Investition fromAccount -> toAccount.
double goalAccountChange(Booking booking, String goalAccountName) {
  return switch (booking.type) {
    BookingType.transfer || BookingType.investment =>
      (booking.toAccount == goalAccountName ? booking.amount : 0.0) - (booking.fromAccount == goalAccountName ? booking.amount : 0.0),
    BookingType.income => booking.fromAccount == goalAccountName ? booking.amount : 0.0,
    BookingType.expense => booking.fromAccount == goalAccountName ? -booking.amount : 0.0,
    BookingType.none => 0.0,
  };
}

/// Ein Punkt im Verlauf eines Ziels: gesparter Betrag nach allen Buchungen dieses Tages.
class GoalHistoryPoint {
  final DateTime date;
  final double amount;

  /// true für zukünftige (geplante) Buchungen, z.B. ein Sparplan.
  final bool isPlanned;

  const GoalHistoryPoint({required this.date, required this.amount, required this.isPlanned});
}

/// Verlauf des Ziel-Kontos aus den Buchungen (ereignisbasiert, es wird nichts zusätzlich gespeichert).
/// Mehrere Buchungen an einem Tag ergeben einen Punkt.
List<GoalHistoryPoint> calculateGoalHistory({
  required Iterable<Booking> bookings,
  required String goalAccountName,
  required DateTime now,
}) {
  final Map<DateTime, double> changesPerDay = {};
  for (final Booking booking in bookings) {
    final double change = goalAccountChange(booking, goalAccountName);
    if (change == 0.0) {
      continue;
    }
    final DateTime day = DateTime(booking.date.year, booking.date.month, booking.date.day);
    changesPerDay[day] = (changesPerDay[day] ?? 0.0) + change;
  }
  final List<DateTime> days = changesPerDay.keys.toList()..sort();
  final List<GoalHistoryPoint> points = [];
  double amount = 0.0;
  for (final DateTime day in days) {
    amount += changesPerDay[day]!;
    points.add(GoalHistoryPoint(date: day, amount: amount, isPlanned: day.isAfter(now)));
  }
  return points;
}

/// Was mit dem Geld eines Ziels beim Abschließen / Löschen passiert.
enum GoalCloseAction {
  /// "Gekauft": Das Geld wird als Ausgabe vom Ziel-Konto gebucht.
  spend,

  /// "Erreicht – Geld behalten": Das Geld wird auf ein Konto übertragen, das Ziel ist abgeschlossen.
  keep,

  /// Ziel löschen: Restgeld wird auf ein Konto übertragen, das Ziel wird archiviert.
  delete,
}

/// Erzeugt die Buchungen, mit denen ein Ziel-Konto beim Abschließen / Löschen auf 0 gebracht wird.
/// Es werden nur neue Buchungen erzeugt; vorhandene Buchungen werden nie verändert.
///
/// - spend: Ausgabe vom Ziel-Konto in [categorie] (zählt als Ausgabe und im Budget; der Saldo sinkt
///   nicht erneut, weil das Geld bereits beim Zurücklegen abgezogen wurde).
/// - keep / delete: Übertrag des Restbetrags auf [targetAccountName]. Ein negativer Kontostand wird
///   vom Zielkonto ausgeglichen. Bei Kontostand 0 wird nichts gebucht.
List<Booking> buildGoalClosingBookings({
  required GoalCloseAction action,
  required String goalAccountName,
  required double balance,
  required String title,
  required DateTime date,
  required String currency,
  String? targetAccountName,
  String categorie = '',
}) {
  final double amount = double.parse(balance.toStringAsFixed(2));
  if (amount.abs() < 0.005) {
    return [];
  }
  if (action == GoalCloseAction.spend) {
    if (amount < 0.0) {
      throw ArgumentError('Ein Ziel ohne Guthaben kann nicht als gekauft gebucht werden.');
    }
    return [
      Booking(
        id: 0,
        serieId: -1,
        type: BookingType.expense,
        title: title,
        date: date,
        repetition: RepetitionType.noRepetition,
        amount: amount,
        amountType: AmountType.variable,
        currency: currency,
        fromAccount: goalAccountName,
        toAccount: '',
        categorie: categorie,
        isBooked: true,
      ),
    ];
  }
  if (targetAccountName == null || targetAccountName.isEmpty) {
    throw ArgumentError('Für das Restgeld muss ein Konto ausgewählt werden.');
  }
  final bool positive = amount > 0.0;
  return [
    Booking(
      id: 0,
      serieId: -1,
      type: BookingType.transfer,
      title: title,
      date: date,
      repetition: RepetitionType.noRepetition,
      amount: amount.abs(),
      amountType: AmountType.undefined,
      currency: currency,
      fromAccount: positive ? goalAccountName : targetAccountName,
      toAccount: positive ? targetAccountName : goalAccountName,
      categorie: 'übertrag',
      isBooked: true,
    ),
  ];
}

/// Übertrag vom Konto [fromAccount] auf das Ziel-Konto ("Geld hinzufügen").
Booking buildGoalDepositBooking({
  required String goalAccountName,
  required String fromAccount,
  required double amount,
  required String title,
  required DateTime date,
  required String currency,
  required DateTime now,
}) {
  return Booking(
    id: 0,
    serieId: -1,
    type: BookingType.transfer,
    title: title,
    date: date,
    repetition: RepetitionType.noRepetition,
    amount: amount,
    amountType: AmountType.undefined,
    currency: currency,
    fromAccount: fromAccount,
    toAccount: goalAccountName,
    categorie: 'übertrag',
    // Gleiche Regel wie isBookingDue: gebucht, sobald das Datum erreicht ist.
    isBooked: !date.isAfter(now),
  );
}
