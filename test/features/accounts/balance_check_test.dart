import 'package:flutter_test/flutter_test.dart';
import 'package:moneybook/features/accounts/domain/services/balance_check.dart';
import 'package:moneybook/features/bookings/domain/entities/booking.dart';

import '../../helpers/booking_helpers.dart';

void main() {
  final DateTime now = DateTime(2026, 11, 1, 1, 30);
  final Set<String> accounts = {'Giro', 'Spar', 'Bar'};

  // Dauerauftrag "am Monatsanfang", angelegt im September: alle Termine als gebucht gespeichert.
  Booking serie(int id, DateTime date, {bool isBooked = true, double amount = 100, String from = 'Giro', String to = 'Spar'}) =>
      transfer(from, to, amount, date: date).copyWith(id: id, serieId: 7, isBooked: isBooked);

  test('later past dates of a series that are marked booked are suspicious, the first one is not', () {
    final List<Booking> bookings = [
      serie(1, DateTime(2026, 9, 1)),
      serie(2, DateTime(2026, 10, 1)),
      serie(3, DateTime(2026, 11, 1)),
      serie(4, DateTime(2026, 12, 1)),
      income(2000, date: DateTime(2026, 10, 1)).copyWith(id: 5),
    ];
    final missed = findMissedSerieBookings(bookings: bookings, checkedBookingIds: {}, affectedSerieIds: {7}, existingAccounts: accounts, now: now);
    expect(missed.map((b) => b.id).toList(), [2, 3]);
  });

  test('bookings recorded as applied, unbooked ones and unknown accounts are not suspicious', () {
    final List<Booking> bookings = [
      serie(1, DateTime(2026, 8, 1)),
      serie(2, DateTime(2026, 9, 1)),
      serie(3, DateTime(2026, 10, 1), isBooked: false),
      serie(4, DateTime(2026, 10, 15), to: 'Gelöscht'),
    ];
    final missed = findMissedSerieBookings(bookings: bookings, checkedBookingIds: {2}, affectedSerieIds: {7}, existingAccounts: accounts, now: now);
    expect(missed, isEmpty);
  });

  test('series that were never affected by the bug are not suspicious', () {
    final List<Booking> bookings = [serie(1, DateTime(2026, 9, 1)), serie(2, DateTime(2026, 10, 1))];
    final missed = findMissedSerieBookings(bookings: bookings, checkedBookingIds: {}, affectedSerieIds: {}, existingAccounts: accounts, now: now);
    expect(missed, isEmpty);
  });

  test('preview: applying missed transfers moves money between both accounts', () {
    final after = balancesAfterRepair({'Giro': 1000, 'Spar': 50}, [serie(2, DateTime(2026, 10, 1)), serie(3, DateTime(2026, 11, 1))]);
    expect(after['Giro'], 800);
    expect(after['Spar'], 250);
  });

  test('balance after each booking for both accounts of a transfer', () {
    final List<Booking> bookings = [
      income(1000, date: DateTime(2026, 10, 1)).copyWith(id: 1),
      transfer('Giro', 'Spar', 300, date: DateTime(2026, 10, 5)).copyWith(id: 2),
      expense(50, date: DateTime(2026, 10, 7)).copyWith(id: 3),
      expense(20, from: 'Gelöscht', date: DateTime(2026, 10, 8)).copyWith(id: 4),
    ];
    final balances = calculateBookingBalances(bookings: bookings, accountBalances: {'Giro': 650, 'Spar': 300}, now: now);
    expect(balances[1], {'Giro': 1000.0});
    expect(balances[2], {'Giro': 700.0, 'Spar': 300.0});
    expect(balances[3], {'Giro': 650.0});
    expect(balances.containsKey(4), isFalse);
  });
}
