import 'package:flutter_test/flutter_test.dart';
import 'package:moneybook/features/accounts/domain/services/account_history.dart';
import 'package:moneybook/features/bookings/domain/entities/booking.dart';
import 'package:moneybook/features/bookings/domain/value_objects/booking_type.dart';

import '../../helpers/booking_helpers.dart';

void main() {
  final DateTime now = DateTime(2026, 10, 22, 12);

  Booking withId(Booking booking, int id) => booking.copyWith(id: id);

  test('balance after each booking, newest first, ending at the current balance', () {
    final history = calculateAccountHistory(
      bookings: [
        withId(income(2000, date: DateTime(2026, 10, 1)), 1),
        withId(expense(300, date: DateTime(2026, 10, 5)), 2),
        withId(transfer('Giro', 'Spar', 500, date: DateTime(2026, 10, 10)), 3),
        withId(transfer('Spar', 'Giro', 100, date: DateTime(2026, 10, 15)), 4),
        // Betrifft das Konto nicht.
        withId(expense(50, from: 'Bar', date: DateTime(2026, 10, 12)), 5),
      ],
      accountName: 'Giro',
      currentBalance: 1500,
      now: now,
    );
    expect(history.entries.length, 4);
    expect(history.entries.map((e) => e.change).toList(), [100, -500, -300, 2000]);
    expect(history.entries.map((e) => e.balanceAfter).toList(), [1500, 1400, 1900, 2200]);
    expect(history.openingBalance, 200);
  });

  test('several bookings on the same day keep their creation order', () {
    final history = calculateAccountHistory(
      bookings: [
        withId(expense(20, date: DateTime(2026, 10, 3)), 8),
        withId(income(100, date: DateTime(2026, 10, 3)), 7),
      ],
      accountName: 'Giro',
      currentBalance: 80,
      now: now,
    );
    expect(history.entries.first.booking.id, 8);
    expect(history.entries.first.balanceAfter, 80);
    expect(history.entries.last.balanceAfter, 100);
  });

  test('pending bookings are a preview starting at the current balance', () {
    final history = calculateAccountHistory(
      bookings: [
        withId(income(1000, date: DateTime(2026, 10, 1)), 1),
        withId(expense(200, date: DateTime(2026, 11, 1)), 2),
        withId(transfer('Giro', 'Urlaub', 100, date: DateTime(2026, 12, 1)), 3),
      ],
      accountName: 'Giro',
      currentBalance: 1000,
      now: now,
    );
    expect(history.entries[0].isPending, isTrue);
    expect(history.entries[0].balanceAfter, 700);
    expect(history.entries[1].balanceAfter, 800);
    expect(history.entries[2].isPending, isFalse);
    expect(history.entries[2].balanceAfter, 1000);
    expect(history.openingBalance, 0);
  });

  test('incoming transfer and investment count for the target account', () {
    final history = calculateAccountHistory(
      bookings: [
        withId(transfer('Giro', 'Depot', 300, type: BookingType.investment, date: DateTime(2026, 10, 2)), 1),
      ],
      accountName: 'Depot',
      currentBalance: 300,
      now: now,
    );
    expect(history.entries.single.change, 300);
    expect(history.openingBalance, 0);
  });
}
