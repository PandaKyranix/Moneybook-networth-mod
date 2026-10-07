import '../../../bookings/domain/entities/booking.dart';
import '../../../bookings/domain/value_objects/booking_type.dart';
import '../entities/account.dart';
import '../value_objects/account_type.dart';

/// Ergebnis der Vermögensberechnung über alle Konten.
class NetWorthSummary {
  /// Vermögen aller einbezogenen Konten (positive Kontostände, keine Kredite).
  final double assets;

  /// Schulden aller einbezogenen Konten (Kredite und negative Kontostände, als positiver Betrag).
  final double debts;

  /// Summe der Kontostände aller ausgeschlossenen ("zurückgelegten") Konten.
  final double excludedTotal;

  /// Anzahl ausgeschlossener Konten.
  final int excludedCount;

  const NetWorthSummary({
    required this.assets,
    required this.debts,
    required this.excludedTotal,
    required this.excludedCount,
  });

  /// Saldo = Vermögen - Schulden (nur einbezogene Konten).
  double get netWorth => assets - debts;
}

/// Berechnet Vermögen, Schulden und Saldo. Ausgeschlossene Konten werden nicht mitgezählt,
/// sondern separat in [NetWorthSummary.excludedTotal] ausgewiesen. Jedes Konto wird genau
/// einmal gezählt: entweder im Vermögen/Schulden oder in excludedTotal.
/// Die Klassifizierung Vermögen/Schulden entspricht exakt der bisherigen Logik.
NetWorthSummary calculateNetWorth(List<Account> accounts) {
  double assets = 0.0;
  double debts = 0.0;
  double excludedTotal = 0.0;
  int excludedCount = 0;
  for (final account in accounts) {
    if (!account.includeInNetWorth || account.isGoalAccount || account.archived) {
      // Ziel-Konten sind immer zurückgelegtes Geld. Archivierte Konten (abgeschlossene / gelöschte Ziele)
      // haben Kontostand 0 und werden nicht mehr mitgezählt, bleiben aber für die Historie bestehen.
      excludedTotal += account.amount;
      if (!account.archived) {
        excludedCount++;
      }
    } else if (account.type == AccountType.credit || account.amount < 0.0) {
      debts += account.amount.abs();
    } else {
      assets += account.amount;
    }
  }
  return NetWorthSummary(assets: assets, debts: debts, excludedTotal: excludedTotal, excludedCount: excludedCount);
}

/// Kontostandsänderungen einer gebuchten Buchung, genau wie in AccountLocalDataSource:
/// Ausgabe = withdraw(fromAccount), Einnahme = deposit(fromAccount), Übertrag / Investition = transfer(from -> to).
Map<String, double> accountBalanceChanges(Booking booking) {
  return switch (booking.type) {
    BookingType.expense => <String, double>{booking.fromAccount: -booking.amount},
    BookingType.income => <String, double>{booking.fromAccount: booking.amount},
    BookingType.transfer || BookingType.investment => booking.fromAccount == booking.toAccount
        ? <String, double>{}
        : <String, double>{booking.fromAccount: -booking.amount, booking.toAccount: booking.amount},
    BookingType.none => <String, double>{},
  };
}

/// Wirkung eines Übertrags auf das verfügbare (einbezogene) Vermögen.
enum TransferFlow {
  /// Keine Übertragsbuchung.
  notATransfer,

  /// Einbezogen -> Einbezogen oder Ausgeschlossen -> Ausgeschlossen: normaler Übertrag, keine Wirkung.
  internal,

  /// Einbezogen -> Ausgeschlossen: Geld wird zurückgelegt, verfügbares Vermögen sinkt.
  setAside,

  /// Ausgeschlossen -> Einbezogen: Geld wird freigegeben, verfügbares Vermögen steigt.
  released,
}

/// Bestimmt anhand der *aktuellen* Einstellung der Konten, wie ein Übertrag wirkt.
/// Die Buchung selbst bleibt unverändert ein Übertrag. Konten, die nicht (mehr) existieren,
/// gelten als einbezogen. Investitionen bewegen Geld genauso von Konto zu Konto
/// (AccountLocalDataSource.transfer) und werden deshalb gleich behandelt.
TransferFlow classifyTransfer(Booking booking, Set<String> excludedAccountNames) {
  if (booking.type != BookingType.transfer && booking.type != BookingType.investment) {
    return TransferFlow.notATransfer;
  }
  final bool fromExcluded = excludedAccountNames.contains(booking.fromAccount);
  final bool toExcluded = excludedAccountNames.contains(booking.toAccount);
  if (!fromExcluded && toExcluded) {
    return TransferFlow.setAside;
  } else if (fromExcluded && !toExcluded) {
    return TransferFlow.released;
  }
  return TransferFlow.internal;
}

/// Veränderung des zurückgelegten Geldes (Summe aller ausgeschlossenen Konten inkl. Ziel-Konten),
/// die eine einzelne Buchung bewirkt. Positiv = es wurde Geld zurückgelegt.
///
/// - Übertrag / Investition einbezogen -> ausgeschlossen: +Betrag (zurückgelegt)
/// - Übertrag / Investition ausgeschlossen -> einbezogen: -Betrag (freigegeben)
/// - Einnahme direkt auf ein ausgeschlossenes Konto: +Betrag
/// - Ausgabe direkt von einem ausgeschlossenen Konto (z.B. "Gekauft" bei einem Ziel): -Betrag
///
/// Dadurch gilt immer: Saldo = Einnahmen - Ausgaben - Zurückgelegt = Veränderung des verfügbaren Geldes.
/// Eine Ausgabe, die mit bereits zurückgelegtem Geld bezahlt wird, zählt so als Ausgabe (und im Budget),
/// verringert den Saldo aber nicht ein zweites Mal.
double reservedChange(Booking booking, Set<String> excludedAccountNames) {
  return switch (booking.type) {
    BookingType.transfer || BookingType.investment => switch (classifyTransfer(booking, excludedAccountNames)) {
        TransferFlow.setAside => booking.amount,
        TransferFlow.released => -booking.amount,
        TransferFlow.internal || TransferFlow.notATransfer => 0.0,
      },
    BookingType.income => excludedAccountNames.contains(booking.fromAccount) ? booking.amount : 0.0,
    BookingType.expense => excludedAccountNames.contains(booking.fromAccount) ? -booking.amount : 0.0,
    BookingType.none => 0.0,
  };
}

/// Veränderung des verfügbaren Geldes (Summe aller einbezogenen Konten) durch eine Buchung.
/// Grundlage für den Saldo, die Saldo-Linie und die Jahresübersicht.
double availableChange(Booking booking, Set<String> excludedAccountNames) {
  final double income = booking.type == BookingType.income ? booking.amount : 0.0;
  final double expense = booking.type == BookingType.expense ? booking.amount : 0.0;
  return income - expense - reservedChange(booking, excludedAccountNames);
}

/// Netto zurückgelegter Betrag einer Buchungsliste: zurückgelegt minus freigegeben
/// minus von zurückgelegtem Geld bezahlt (siehe [reservedChange]).
double calculateNetSetAside(Iterable<Booking> bookings, Set<String> excludedAccountNames) {
  double net = 0.0;
  for (final booking in bookings) {
    net += reservedChange(booking, excludedAccountNames);
  }
  return net;
}

/// Monatlicher Saldo auf der Buchungsseite: Einnahmen - Ausgaben - netto Zurückgelegtes.
/// Geld, das auf ein zurückgelegtes Konto übertragen wird, steht nicht mehr zum Ausgeben zur
/// Verfügung und verringert daher den Saldo; Überträge zurück erhöhen ihn wieder.
/// Die Überträge selbst bleiben Überträge und zählen weder als Ausgabe noch als Einnahme.
double calculateMonthlyBalance({required double income, required double expense, required double netSetAside}) {
  return income - expense - netSetAside;
}
