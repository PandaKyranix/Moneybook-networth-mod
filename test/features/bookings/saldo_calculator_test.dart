import 'package:flutter_test/flutter_test.dart';
import 'package:moneybook/features/accounts/domain/services/net_worth_calculator.dart';
import 'package:moneybook/features/bookings/domain/entities/booking.dart';
import 'package:moneybook/features/bookings/domain/services/saldo_calculator.dart';
import 'package:moneybook/features/bookings/domain/value_objects/booking_type.dart';

import '../../helpers/booking_helpers.dart';

void main() {
  final Set<String> excluded = {'Spar', 'Urlaub'};

  group('Zurückgelegt (generalized)', () {
    test('transfer into / out of excluded accounts', () {
      expect(reservedChange(transfer('Giro', 'Spar', 500), excluded), 500);
      expect(reservedChange(transfer('Spar', 'Giro', 200), excluded), -200);
      expect(reservedChange(transfer('Giro', 'Bar', 100), excluded), 0);
      expect(reservedChange(transfer('Spar', 'Urlaub', 100), excluded), 0);
    });

    test('expense paid from an excluded account reduces Zurückgelegt, not the saldo', () {
      final Booking bought = expense(2000, from: 'Urlaub');
      expect(reservedChange(bought, excluded), -2000);
      expect(availableChange(bought, excluded), 0);
    });

    test('income onto an excluded account does not change available money', () {
      final Booking interest = income(10, to: 'Spar');
      expect(reservedChange(interest, excluded), 10);
      expect(availableChange(interest, excluded), 0);
    });

    test('investments between accounts behave like transfers', () {
      expect(reservedChange(transfer('Giro', 'Spar', 300, type: BookingType.investment), excluded), 300);
      expect(availableChange(transfer('Giro', 'Depot', 300, type: BookingType.investment), excluded), 0);
    });

    test('transfers are never income or expense', () {
      final SaldoSummary summary = summarizeBookings([transfer('Giro', 'Spar', 500), transfer('Giro', 'Bar', 50)], excluded);
      expect(summary.income, 0);
      expect(summary.expense, 0);
      expect(summary.setAside, 500);
      expect(summary.balance, -500);
    });

    test('saldo = income - expense - zurückgelegt = change of available money', () {
      final List<Booking> bookings = [
        income(3000),
        expense(1000),
        transfer('Giro', 'Spar', 500),
        transfer('Spar', 'Giro', 200),
        expense(2000, from: 'Urlaub'),
        income(10, to: 'Spar'),
      ];
      final SaldoSummary summary = summarizeBookings(bookings, excluded);
      final double available = bookings.fold(0.0, (sum, b) => sum + availableChange(b, excluded));
      expect(summary.balance, closeTo(available, 0.001));
      // Verfügbar: +3000 -1000 -500 +200 = 1700; Kauf aus Urlaub und Zinsen auf Spar ändern das nicht.
      expect(summary.balance, closeTo(1700, 0.001));
      expect(summary.expense, 3000);
      expect(summary.setAside, closeTo(500 - 200 - 2000 + 10, 0.001));
    });

    test('available money matches the change of included account balances', () {
      var accounts = [account('Giro', 1000), account('Bar', 50), account('Spar', 5000, included: false), account('Urlaub', 2000, goalId: 1)];
      final Set<String> ex = excludedNames(accounts);
      final List<Booking> bookings = [
        income(3000),
        expense(400, from: 'Bar'),
        transfer('Giro', 'Spar', 500),
        transfer('Giro', 'Urlaub', 250),
        expense(2250, from: 'Urlaub'),
      ];
      final double before = calculateNetWorth(accounts).netWorth;
      final double totalBefore = totalMoney(accounts);
      accounts = applyBookings(accounts, bookings);
      final double after = calculateNetWorth(accounts).netWorth;
      expect(after - before, closeTo(summarizeBookings(bookings, ex).balance, 0.001));
      // Gesamtgeld ändert sich nur durch Einnahmen und Ausgaben, nie durch Überträge.
      expect(totalMoney(accounts) - totalBefore, closeTo(3000 - 400 - 2250, 0.001));
    });
  });

  group('monthly saldo line', () {
    final DateTime pastNow = DateTime(2026, 12, 15);

    test('month without bookings is flat at 0', () {
      final series = calculateMonthlySaldoSeries(bookings: [], excludedAccountNames: excluded, year: 2026, month: 10, now: pastNow);
      expect(series.daysInMonth, 31);
      expect(series.values.every((v) => v == 0.0), isTrue);
      expect(series.hasPendingChanges, isFalse);
    });

    test('only income goes up, only expenses go down', () {
      final up = calculateMonthlySaldoSeries(
          bookings: [income(100, date: DateTime(2026, 10, 3))], excludedAccountNames: excluded, year: 2026, month: 10, now: pastNow);
      expect(up.values[2], 0);
      expect(up.values[3], 100);
      expect(up.values.last, 100);
      final down = calculateMonthlySaldoSeries(
          bookings: [expense(40, date: DateTime(2026, 10, 3))], excludedAccountNames: excluded, year: 2026, month: 10, now: pastNow);
      expect(down.values.last, -40);
    });

    test('multiple bookings on the same day are combined; negative saldo possible', () {
      final DateTime day = DateTime(2026, 10, 5);
      final series = calculateMonthlySaldoSeries(
        bookings: [income(500, date: day), expense(1200, date: day), transfer('Giro', 'Spar', 300, date: day)],
        excludedAccountNames: excluded,
        year: 2026,
        month: 10,
        now: pastNow,
      );
      expect(series.values[4], 0);
      expect(series.values[5], -1000);
      expect(series.values.last, -1000);
    });

    test('ends exactly at the monthly saldo card value', () {
      final List<Booking> bookings = [
        income(2000, date: DateTime(2026, 10, 1)),
        expense(800, date: DateTime(2026, 10, 10)),
        transfer('Giro', 'Spar', 300, date: DateTime(2026, 10, 20)),
        transfer('Spar', 'Giro', 50, date: DateTime(2026, 10, 25)),
      ];
      final series = calculateMonthlySaldoSeries(bookings: bookings, excludedAccountNames: excluded, year: 2026, month: 10, now: pastNow);
      expect(series.dueBalance, closeTo(summarizeBookings(bookings, excluded).balance, 0.001));
    });

    test('current month: pending bookings only in the forecast', () {
      final DateTime now = DateTime(2026, 10, 15, 12);
      final List<Booking> bookings = [income(1000, date: DateTime(2026, 10, 1)), expense(300, date: DateTime(2026, 10, 15)), expense(200, date: DateTime(2026, 10, 20))];
      final series = calculateMonthlySaldoSeries(bookings: bookings, excludedAccountNames: excluded, year: 2026, month: 10, now: now);
      expect(series.lastDueDay, 15);
      expect(series.dueBalance, 700);
      expect(series.projectedBalance, 500);
      expect(series.hasPendingChanges, isTrue);
      final dueOnly = bookings.where((b) => isBookingDue(b, now));
      expect(series.dueBalance, summarizeBookings(dueOnly, excluded).balance);
    });

    test('bookings of other months are ignored (month boundaries)', () {
      final series = calculateMonthlySaldoSeries(
        bookings: [income(100, date: DateTime(2026, 9, 30)), income(50, date: DateTime(2026, 10, 31)), income(70, date: DateTime(2026, 11, 1))],
        excludedAccountNames: excluded,
        year: 2026,
        month: 10,
        now: pastNow,
      );
      expect(series.values.last, 50);
      expect(series.values[30], 0);
    });

    test('future month is completely pending', () {
      final series = calculateMonthlySaldoSeries(
          bookings: [income(100, date: DateTime(2027, 1, 5))], excludedAccountNames: excluded, year: 2027, month: 1, now: pastNow);
      expect(series.lastDueDay, 0);
      expect(series.dueBalance, 0);
      expect(series.projectedBalance, 100);
    });
  });

  group('yearly overview', () {
    test('months with no bookings, only income, only expenses and both', () {
      final DateTime now = DateTime(2027, 1, 10);
      final List<Booking> bookings = [
        income(1000, date: DateTime(2026, 2, 1)),
        expense(300, date: DateTime(2026, 3, 5)),
        income(2000, date: DateTime(2026, 4, 1)),
        expense(500, date: DateTime(2026, 4, 2)),
        transfer('Giro', 'Spar', 1000, date: DateTime(2026, 4, 3)),
      ];
      final months = calculateYearlySaldo(bookings: bookings, excludedAccountNames: excluded, year: 2026, now: now);
      expect(months.length, 12);
      expect(months[0].due.isEmpty, isTrue);
      expect(months[1].due.balance, 1000);
      expect(months[2].due.balance, -300);
      expect(months[3].due.income, 2000);
      expect(months[3].due.expense, 500);
      expect(months[3].due.setAside, 1000);
      expect(months[3].due.balance, 500);
      // Jahressaldo läuft über die Monate weiter.
      expect(months[3].yearToDateBefore, 700);
      expect(months[3].yearToDateAfter, 1200);
      expect(months[11].yearToDateAfter, 1200);
    });

    test('yearly values are the sum of the monthly values', () {
      final DateTime now = DateTime(2026, 6, 15);
      final List<Booking> bookings = [
        for (int m = 1; m <= 12; m++) ...[
          income(2500, date: DateTime(2026, m, 1)),
          expense(1700, date: DateTime(2026, m, 10)),
          transfer('Giro', 'Urlaub', 200, date: DateTime(2026, m, 28)),
        ],
      ];
      final months = calculateYearlySaldo(bookings: bookings, excludedAccountNames: excluded, year: 2026, now: now);
      for (final month in months) {
        final monthBookings = bookings.where((b) => b.date.month == month.month && isBookingDue(b, now));
        expect(month.due.balance, closeTo(summarizeBookings(monthBookings, excluded).balance, 0.001));
      }
      // Juni: 1. und 10. gebucht, 28. ausstehend.
      expect(months[5].due.balance, 800);
      expect(months[5].pending.setAside, 200);
      expect(months[6].isFuture, isTrue);
      expect(months[6].chartValues.income, 2500);
    });
  });
}
