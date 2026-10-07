import 'package:flutter_test/flutter_test.dart';
import 'package:moneybook/shared/domain/value_objects/period_mode.dart';

void main() {
  group('month navigation', () {
    test('switching month, across year boundaries', () {
      expect(shiftPeriod(DateTime(2026, 10, 7), PeriodMode.month, 1), DateTime(2026, 11, 1));
      expect(shiftPeriod(DateTime(2026, 12, 15), PeriodMode.month, 1), DateTime(2027, 1, 1));
      expect(shiftPeriod(DateTime(2026, 1, 31), PeriodMode.month, -1), DateTime(2025, 12, 1));
      expect(shiftPeriod(DateTime(2026, 3, 31), PeriodMode.month, -1), DateTime(2026, 2, 1));
    });

    test('distance in months is the inverse of shifting', () {
      final DateTime anchor = DateTime(2026, 10, 1);
      for (int steps = -30; steps <= 30; steps++) {
        final DateTime shifted = shiftPeriod(anchor, PeriodMode.month, steps);
        expect(periodDistance(anchor, shifted, PeriodMode.month), steps);
      }
    });
  });

  group('year navigation', () {
    test('switching year keeps the month so switching back lands in the same month', () {
      final DateTime next = shiftPeriod(DateTime(2026, 10, 7), PeriodMode.year, 1);
      expect(next, DateTime(2027, 10, 1));
      expect(isSamePeriod(next, DateTime(2027, 1, 1), PeriodMode.year), isTrue);
      expect(isSamePeriod(next, DateTime(2027, 1, 1), PeriodMode.month), isFalse);
      expect(periodDistance(DateTime(2026, 10, 1), DateTime(2029, 2, 1), PeriodMode.year), 3);
    });
  });

  group('preserving the selection', () {
    tearDown(PeriodMemory.reset);

    test('remembers date and mode between page rebuilds', () {
      expect(PeriodMemory.selectedDate, isNull);
      expect(PeriodMemory.mode, PeriodMode.month);
      PeriodMemory.selectedDate = DateTime(2025, 3, 1);
      PeriodMemory.mode = PeriodMode.year;
      expect(PeriodMemory.selectedDate, DateTime(2025, 3, 1));
      expect(PeriodMemory.mode, PeriodMode.year);
    });
  });
}
