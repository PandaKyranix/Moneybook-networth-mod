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
    if (!account.includeInNetWorth) {
      excludedTotal += account.amount;
      excludedCount++;
    } else if (account.type == AccountType.credit || account.amount < 0.0) {
      debts += account.amount.abs();
    } else {
      assets += account.amount;
    }
  }
  return NetWorthSummary(assets: assets, debts: debts, excludedTotal: excludedTotal, excludedCount: excludedCount);
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
/// gelten als einbezogen.
TransferFlow classifyTransfer(Booking booking, Set<String> excludedAccountNames) {
  if (booking.type != BookingType.transfer) {
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

/// Netto zurückgelegter Betrag einer Buchungsliste: zurückgelegt minus freigegeben.
double calculateNetSetAside(Iterable<Booking> bookings, Set<String> excludedAccountNames) {
  double net = 0.0;
  for (final booking in bookings) {
    switch (classifyTransfer(booking, excludedAccountNames)) {
      case TransferFlow.setAside:
        net += booking.amount;
        break;
      case TransferFlow.released:
        net -= booking.amount;
        break;
      case TransferFlow.internal:
      case TransferFlow.notATransfer:
        break;
    }
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
