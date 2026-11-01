import '../../../bookings/domain/entities/booking.dart';
import '../../../bookings/domain/services/saldo_calculator.dart';
import 'account_history.dart';
import 'net_worth_calculator.dart';

DateTime _day(DateTime date) => DateTime(date.year, date.month, date.day);

/// Findet Termine von Serienbuchungen (Daueraufträgen), die vermutlich nie auf den Kontostand gebucht wurden.
///
/// Hintergrund (Fehler der ursprünglichen App): Beim Anlegen einer Serie bekamen alle Termine den
/// "gebucht"-Status des ersten Termins. Lag der erste Termin heute oder in der Vergangenheit (z.B. "am
/// Monatsanfang"), galten auch alle späteren Termine als gebucht und wurden zu ihrem Datum nie auf das
/// Konto angerechnet.
///
/// Verdächtig ist deshalb ein Termin, der
/// - zu einer betroffenen Serie gehört ([affectedSerieIds]: hatte zukünftige Termine mit Status "gebucht"),
///   aber nicht ihr erster Termin ist,
/// - fällig ist und als gebucht markiert ist,
/// - nicht nachweislich angerechnet wurde ([checkedBookingIds]: beim Anlegen, beim automatischen Buchen
///   oder in einer früheren Prüfung bestätigt),
/// - nur existierende Konten betrifft.
List<Booking> findMissedSerieBookings({
  required Iterable<Booking> bookings,
  required Set<int> checkedBookingIds,
  required Set<int> affectedSerieIds,
  required Set<String> existingAccounts,
  required DateTime now,
}) {
  final Map<int, DateTime> firstDateOfSerie = {};
  for (final Booking booking in bookings) {
    if (booking.serieId == -1) {
      continue;
    }
    final DateTime day = _day(booking.date);
    final DateTime? first = firstDateOfSerie[booking.serieId];
    if (first == null || day.isBefore(first)) {
      firstDateOfSerie[booking.serieId] = day;
    }
  }
  final List<Booking> candidates = bookings.where((booking) {
    if (booking.serieId == -1 || !affectedSerieIds.contains(booking.serieId) || !booking.isBooked || !isBookingDue(booking, now) || checkedBookingIds.contains(booking.id)) {
      return false;
    }
    if (!_day(booking.date).isAfter(firstDateOfSerie[booking.serieId]!)) {
      return false;
    }
    final Map<String, double> changes = accountBalanceChanges(booking);
    return changes.isNotEmpty && changes.keys.every(existingAccounts.contains);
  }).toList();
  candidates.sort((first, second) {
    final int byDate = first.date.compareTo(second.date);
    return byDate != 0 ? byDate : first.id.compareTo(second.id);
  });
  return candidates;
}

/// Kontostände nach dem Nachbuchen der ausgewählten Buchungen.
Map<String, double> balancesAfterRepair(Map<String, double> currentBalances, Iterable<Booking> selected) {
  final Map<String, double> balances = Map<String, double>.from(currentBalances);
  for (final Booking booking in selected) {
    accountBalanceChanges(booking).forEach((account, change) {
      balances[account] = (balances[account] ?? 0.0) + change;
    });
  }
  return balances;
}

/// Kontostand nach jeder Buchung für alle beteiligten Konten: bookingId -> {Konto: Stand danach}.
/// Bei Überträgen gibt es zwei Einträge (Abbuchungs- und Zielkonto). Grundlage ist dieselbe Rechnung wie
/// in der Kontoansicht ([calculateAccountHistory]); Konten, die es nicht mehr gibt, werden ausgelassen.
Map<int, Map<String, double>> calculateBookingBalances({
  required Iterable<Booking> bookings,
  required Map<String, double> accountBalances,
  required DateTime now,
}) {
  final Map<String, List<Booking>> bookingsPerAccount = {};
  for (final Booking booking in bookings) {
    for (final String account in accountBalanceChanges(booking).keys) {
      if (accountBalances.containsKey(account)) {
        bookingsPerAccount.putIfAbsent(account, () => []).add(booking);
      }
    }
  }
  final Map<int, Map<String, double>> result = {};
  bookingsPerAccount.forEach((account, accountBookings) {
    final AccountHistory history = calculateAccountHistory(
      bookings: accountBookings,
      accountName: account,
      currentBalance: accountBalances[account]!,
      now: now,
    );
    for (final AccountHistoryEntry entry in history.entries) {
      result.putIfAbsent(entry.booking.id, () => {})[account] = entry.balanceAfter;
    }
  });
  return result;
}
