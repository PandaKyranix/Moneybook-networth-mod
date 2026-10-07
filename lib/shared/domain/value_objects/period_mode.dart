/// Ob Buchungen / Budgets für einen Monat oder ein ganzes Jahr angezeigt werden.
enum PeriodMode {
  month,
  year;
}

/// Merkt sich den zuletzt gewählten Zeitraum, solange die App läuft. Nach dem Speichern einer
/// Buchung wird die Hauptseite neu aufgebaut; so bleibt der gewählte Monat / das Jahr erhalten.
class PeriodMemory {
  static DateTime? selectedDate;
  static PeriodMode mode = PeriodMode.month;

  static void reset() {
    selectedDate = null;
    mode = PeriodMode.month;
  }
}

/// Verschiebt einen Zeitraum um [steps] Monate bzw. Jahre. Ergebnis ist immer der 1. des Monats;
/// im Jahresmodus bleibt der Monat erhalten, damit man beim Zurückwechseln im selben Monat landet.
DateTime shiftPeriod(DateTime date, PeriodMode mode, int steps) {
  if (mode == PeriodMode.month) {
    return DateTime(date.year, date.month + steps, 1);
  }
  return DateTime(date.year + steps, date.month, 1);
}

/// Anzahl Monate bzw. Jahre von [from] bis [to].
int periodDistance(DateTime from, DateTime to, PeriodMode mode) {
  if (mode == PeriodMode.month) {
    return (to.year - from.year) * 12 + (to.month - from.month);
  }
  return to.year - from.year;
}

/// Ob zwei Daten im selben Monat (bzw. Jahr) liegen.
bool isSamePeriod(DateTime a, DateTime b, PeriodMode mode) {
  if (mode == PeriodMode.month) {
    return a.year == b.year && a.month == b.month;
  }
  return a.year == b.year;
}
