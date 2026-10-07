import 'package:flutter_test/flutter_test.dart';
import 'package:moneybook/features/accounts/domain/entities/account.dart';
import 'package:moneybook/features/accounts/domain/services/net_worth_calculator.dart';
import 'package:moneybook/features/accounts/domain/value_objects/account_type.dart';
import 'package:moneybook/features/bookings/domain/entities/booking.dart';
import 'package:moneybook/features/bookings/domain/value_objects/amount_type.dart';
import 'package:moneybook/features/bookings/domain/value_objects/booking_type.dart';
import 'package:moneybook/features/bookings/domain/value_objects/repetition_type.dart';

Account _account(String name, double amount, {bool included = true, AccountType type = AccountType.account}) =>
    Account(id: name.hashCode, type: type, name: name, amount: amount, currency: '€', includeInNetWorth: included);

Booking _transfer(String from, String to, double amount, {BookingType type = BookingType.transfer}) => Booking(
      id: 0,
      serieId: -1,
      type: type,
      title: 'Übertrag',
      date: DateTime(2026, 10, 1),
      repetition: RepetitionType.noRepetition,
      amount: amount,
      amountType: AmountType.undefined,
      currency: '€',
      fromAccount: from,
      toAccount: to,
      categorie: 'übertrag',
      isBooked: true,
    );

/// Bildet die bestehende Übertragslogik (AccountLocalDataSource.transfer) nach.
List<Account> _applyTransfer(List<Account> accounts, Booking booking) => accounts.map((a) {
      if (a.name == booking.fromAccount) return a.copyWith(amount: a.amount - booking.amount);
      if (a.name == booking.toAccount) return a.copyWith(amount: a.amount + booking.amount);
      return a;
    }).toList();

void main() {
  group('calculateNetWorth', () {
    test('excluded account does not count towards net worth', () {
      final summary = calculateNetWorth([_account('Girokonto', 2000), _account('Sparkonto', 5000, included: false)]);
      expect(summary.netWorth, 2000);
      expect(summary.excludedTotal, 5000);
      expect(summary.excludedCount, 1);
    });

    test('all included behaves exactly like before', () {
      final summary = calculateNetWorth([
        _account('Giro', 2000),
        _account('Kredit', 1000, type: AccountType.credit),
        _account('Karte', -300, type: AccountType.card),
      ]);
      expect(summary.assets, 2000);
      expect(summary.debts, 1300);
      expect(summary.netWorth, 700);
      expect(summary.excludedCount, 0);
    });

    test('excluded debts are not counted either', () {
      final summary = calculateNetWorth([_account('Giro', 100), _account('Kredit', 1000, type: AccountType.credit, included: false)]);
      expect(summary.debts, 0);
      expect(summary.netWorth, 100);
    });

    test('every euro counted exactly once', () {
      final accounts = [_account('A', 100), _account('B', 250, included: false), _account('C', 40, included: false)];
      final summary = calculateNetWorth(accounts);
      expect(summary.netWorth + summary.excludedTotal, 390);
    });
  });

  group('transfers', () {
    test('set aside 500 then release 200', () {
      var accounts = [_account('Girokonto', 2000), _account('Sparkonto', 5000, included: false)];
      accounts = _applyTransfer(accounts, _transfer('Girokonto', 'Sparkonto', 500));
      expect(accounts.first.amount, 1500);
      expect(calculateNetWorth(accounts).netWorth, 1500);
      accounts = _applyTransfer(accounts, _transfer('Sparkonto', 'Girokonto', 200));
      expect(accounts.first.amount, 1700);
      expect(calculateNetWorth(accounts).netWorth, 1700);
      expect(calculateNetWorth(accounts).excludedTotal, 5300);
    });

    test('included -> included and excluded -> excluded do not change net worth', () {
      var accounts = [_account('A', 1000), _account('B', 0), _account('S1', 100, included: false), _account('S2', 0, included: false)];
      final before = calculateNetWorth(accounts).netWorth;
      accounts = _applyTransfer(accounts, _transfer('A', 'B', 300));
      accounts = _applyTransfer(accounts, _transfer('S1', 'S2', 50));
      expect(calculateNetWorth(accounts).netWorth, before);
    });

    test('classification', () {
      final excluded = {'S1', 'S2'};
      expect(classifyTransfer(_transfer('A', 'B', 1), excluded), TransferFlow.internal);
      expect(classifyTransfer(_transfer('S1', 'S2', 1), excluded), TransferFlow.internal);
      expect(classifyTransfer(_transfer('A', 'S1', 1), excluded), TransferFlow.setAside);
      expect(classifyTransfer(_transfer('S2', 'A', 1), excluded), TransferFlow.released);
      expect(classifyTransfer(_transfer('A', 'S1', 1, type: BookingType.expense), excluded), TransferFlow.notATransfer);
    });

    test('monthly net set aside', () {
      final excluded = {'Spar'};
      final bookings = [
        _transfer('Giro', 'Spar', 500),
        _transfer('Spar', 'Giro', 200),
        _transfer('Giro', 'Bar', 100),
        _transfer('Giro', 'Spar', 50, type: BookingType.expense),
      ];
      expect(calculateNetSetAside(bookings, excluded), 300);
    });

    test('monthly balance: set aside reduces it, released money increases it', () {
      final excluded = {'Spar'};
      // Einnahmen 3000, Ausgaben 1000, 500 zurückgelegt, 200 zurückgeholt -> Saldo 1700.
      final netSetAside = calculateNetSetAside([_transfer('Giro', 'Spar', 500), _transfer('Spar', 'Giro', 200)], excluded);
      expect(calculateMonthlyBalance(income: 3000, expense: 1000, netSetAside: netSetAside), 1700);
      // Normale Überträge ändern den Saldo nicht.
      final internal = calculateNetSetAside([_transfer('Giro', 'Bar', 400), _transfer('Spar', 'Spar2', 100)], {'Spar', 'Spar2'});
      expect(calculateMonthlyBalance(income: 3000, expense: 1000, netSetAside: internal), 2000);
    });

    test('changing the setting re-evaluates history without rewriting it', () {
      final bookings = [_transfer('Giro', 'Spar', 500)];
      expect(calculateNetSetAside(bookings, {'Spar'}), 500);
      expect(calculateNetSetAside(bookings, {}), 0);
    });
  });
}
