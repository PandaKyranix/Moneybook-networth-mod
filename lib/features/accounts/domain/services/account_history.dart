import '../../../bookings/domain/entities/booking.dart';
import '../../../bookings/domain/services/saldo_calculator.dart';
import 'net_worth_calculator.dart';

/// Eine Buchung in der Kontoansicht mit dem Kontostand direkt danach.
class AccountHistoryEntry {
  final Booking booking;

  /// Wie sich der Kontostand durch diese Buchung verändert (+ / -).
  final double change;

  /// Kontostand nach dieser Buchung.
  final double balanceAfter;

  /// Noch nicht gebucht (Datum in der Zukunft); der Kontostand ist dann eine Vorschau.
  final bool isPending;

  const AccountHistoryEntry({required this.booking, required this.change, required this.balanceAfter, required this.isPending});
}

class AccountHistory {
  /// Neueste Buchung zuerst; ausstehende Buchungen stehen oben.
  final List<AccountHistoryEntry> entries;

  /// Kontostand vor der ältesten gebuchten Buchung (Anfangsbestand bzw. Änderungen ohne Buchung).
  final double openingBalance;

  const AccountHistory({required this.entries, required this.openingBalance});
}

int _compareOldestFirst(Booking first, Booking second) {
  final int byDate = first.date.compareTo(second.date);
  return byDate != 0 ? byDate : first.id.compareTo(second.id);
}

/// Berechnet für jede Buchung eines Kontos den Kontostand danach.
///
/// Ausgangspunkt ist der aktuelle Kontostand: Er entspricht dem Stand nach der letzten gebuchten Buchung.
/// Von dort wird rückwärts gerechnet, dadurch stimmt der neueste Wert immer mit dem Konto überein.
/// Die Veränderung je Buchung kommt aus [accountBalanceChanges], also genau der Logik, mit der die App
/// Kontostände bucht (Ausgabe, Einnahme, Übertrag, Investition). Ausstehende Buchungen werden ab dem
/// aktuellen Kontostand vorwärts als Vorschau gerechnet.
AccountHistory calculateAccountHistory({
  required Iterable<Booking> bookings,
  required String accountName,
  required double currentBalance,
  required DateTime now,
}) {
  final List<Booking> due = [];
  final List<Booking> pending = [];
  for (final Booking booking in bookings) {
    if ((accountBalanceChanges(booking)[accountName] ?? 0.0) == 0.0) {
      continue;
    }
    (isBookingDue(booking, now) ? due : pending).add(booking);
  }
  due.sort(_compareOldestFirst);
  pending.sort(_compareOldestFirst);

  double dueTotal = 0.0;
  for (final Booking booking in due) {
    dueTotal += accountBalanceChanges(booking)[accountName]!;
  }
  final double openingBalance = currentBalance - dueTotal;

  final List<AccountHistoryEntry> entries = [];
  double balance = openingBalance;
  for (final Booking booking in due) {
    final double change = accountBalanceChanges(booking)[accountName]!;
    balance += change;
    entries.add(AccountHistoryEntry(booking: booking, change: change, balanceAfter: balance, isPending: false));
  }
  balance = currentBalance;
  for (final Booking booking in pending) {
    final double change = accountBalanceChanges(booking)[accountName]!;
    balance += change;
    entries.add(AccountHistoryEntry(booking: booking, change: change, balanceAfter: balance, isPending: true));
  }
  return AccountHistory(entries: entries.reversed.toList(), openingBalance: openingBalance);
}
