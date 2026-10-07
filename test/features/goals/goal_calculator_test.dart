import 'package:flutter_test/flutter_test.dart';
import 'package:moneybook/features/accounts/domain/entities/account.dart';
import 'package:moneybook/features/accounts/domain/services/net_worth_calculator.dart';
import 'package:moneybook/features/bookings/domain/entities/booking.dart';
import 'package:moneybook/features/bookings/domain/services/saldo_calculator.dart';
import 'package:moneybook/features/bookings/domain/value_objects/booking_type.dart';
import 'package:moneybook/features/goals/domain/services/goal_calculator.dart';

import '../../helpers/booking_helpers.dart';

/// Ausgangslage: Girokonto 3.000 €, Sparkonto (zurückgelegt) 1.000 €, Ziel "Urlaub" mit leerem Ziel-Konto.
List<Account> _startAccounts({double urlaub = 0.0}) => [
      account('Giro', 3000),
      account('Spar', 1000, included: false),
      account('Urlaub', urlaub, included: false, goalId: 1),
    ];

double _balance(List<Account> accounts, String name) => accounts.firstWhere((a) => a.name == name).amount;

void main() {
  final DateTime today = DateTime(2026, 10, 7);

  group('metrics', () {
    test('partial progress, deadline in the future, required per month', () {
      final m = calculateGoalMetrics(saved: 500, target: 2000, deadline: DateTime(2027, 4, 7), now: today);
      expect(m.progress, 0.25);
      expect(m.remaining, 1500);
      expect(m.isReached, isFalse);
      expect(m.daysLeft, 182);
      expect(m.requiredPerMonth, closeTo(1500 / 6, 0.01));
      expect(m.isOverdue, isFalse);
    });

    test('goal reached exactly', () {
      final m = calculateGoalMetrics(saved: 2000, target: 2000, deadline: DateTime(2027, 1, 1), now: today);
      expect(m.isReached, isTrue);
      expect(m.remaining, 0);
      expect(m.requiredPerMonth, isNull);
      expect(m.progress, 1.0);
    });

    test('saving more than the target is allowed and the target is not changed', () {
      final m = calculateGoalMetrics(saved: 2500, target: 2000, deadline: DateTime(2027, 1, 1), now: today);
      expect(m.isReached, isTrue);
      expect(m.progress, 1.25);
      expect(m.target, 2000);
      expect(m.remaining, 0);
    });

    test('deadline in the past', () {
      final m = calculateGoalMetrics(saved: 100, target: 2000, deadline: DateTime(2026, 9, 1), now: today);
      expect(m.daysLeft, lessThan(0));
      expect(m.isOverdue, isTrue);
      expect(m.requiredPerMonth, isNull);
    });

    test('deadline today still needs at least one month of saving', () {
      final m = calculateGoalMetrics(saved: 0, target: 300, deadline: today, now: today);
      expect(m.daysLeft, 0);
      expect(m.requiredPerMonth, 300);
    });
  });

  group('history', () {
    test('progress follows transfers into and out of the goal account, multiple per day combined', () {
      final List<Booking> bookings = [
        transfer('Giro', 'Urlaub', 200, date: DateTime(2026, 8, 1)),
        transfer('Giro', 'Urlaub', 300, date: DateTime(2026, 9, 1)),
        transfer('Spar', 'Urlaub', 100, date: DateTime(2026, 9, 1)),
        transfer('Urlaub', 'Giro', 50, date: DateTime(2026, 9, 15)),
        transfer('Giro', 'Urlaub', 100, date: DateTime(2026, 11, 1)),
        transfer('Giro', 'Bar', 999, date: DateTime(2026, 9, 2)),
      ];
      final history = calculateGoalHistory(bookings: bookings, goalAccountName: 'Urlaub', now: today);
      expect(history.length, 4);
      expect(history[0].amount, 200);
      expect(history[1].amount, 600);
      expect(history[2].amount, 550);
      expect(history[2].isPlanned, isFalse);
      expect(history[3].amount, 650);
      expect(history[3].isPlanned, isTrue);
    });

    test('history is event based: later bookings do not change earlier points', () {
      final List<Booking> first = [transfer('Giro', 'Urlaub', 200, date: DateTime(2026, 8, 1))];
      final before = calculateGoalHistory(bookings: first, goalAccountName: 'Urlaub', now: today);
      final after = calculateGoalHistory(
        bookings: [...first, expense(200, from: 'Urlaub', date: DateTime(2026, 10, 1))],
        goalAccountName: 'Urlaub',
        now: today,
      );
      expect(after.first.amount, before.first.amount);
      expect(after.last.amount, 0);
    });
  });

  group('accounting', () {
    test('included account -> goal: available money down, goal up, total unchanged, not income/expense', () {
      var accounts = _startAccounts();
      final Booking deposit = buildGoalDepositBooking(
        goalAccountName: 'Urlaub',
        fromAccount: 'Giro',
        amount: 500,
        title: 'Urlaub',
        date: today,
        currency: '€',
        now: today,
      );
      expect(deposit.type, BookingType.transfer);
      expect(deposit.isBooked, isTrue);
      final double totalBefore = totalMoney(accounts);
      final double netWorthBefore = calculateNetWorth(accounts).netWorth;
      accounts = applyBookings(accounts, [deposit]);
      expect(_balance(accounts, 'Urlaub'), 500);
      expect(calculateNetWorth(accounts).netWorth, netWorthBefore - 500);
      expect(totalMoney(accounts), totalBefore);
      final SaldoSummary summary = summarizeBookings([deposit], excludedNames(accounts));
      expect(summary.income, 0);
      expect(summary.expense, 0);
      expect(summary.setAside, 500);
      expect(summary.balance, -500);
    });

    test('future deposit is planned and not booked yet', () {
      final Booking deposit = buildGoalDepositBooking(
          goalAccountName: 'Urlaub', fromAccount: 'Giro', amount: 100, title: 'Urlaub', date: DateTime(2026, 11, 1), currency: '€', now: today);
      expect(deposit.isBooked, isFalse);
    });

    test('goal -> included account: goal down, available up, treated as transfer', () {
      var accounts = _startAccounts(urlaub: 800);
      final Booking back = transfer('Urlaub', 'Giro', 300);
      accounts = applyBookings(accounts, [back]);
      expect(_balance(accounts, 'Urlaub'), 500);
      expect(calculateNetWorth(accounts).netWorth, 3300);
      final summary = summarizeBookings([back], excludedNames(accounts));
      expect(summary.income, 0);
      expect(summary.setAside, -300);
      expect(summary.balance, 300);
    });

    test('included -> included stays unchanged', () {
      final summary = summarizeBookings([transfer('Giro', 'Bar', 300)], {'Spar', 'Urlaub'});
      expect(summary.isEmpty, isTrue);
    });

    test('goal -> goal and goal -> excluded account do not change net worth or saldo', () {
      var accounts = [..._startAccounts(urlaub: 500), account('Laptop', 0, included: false, goalId: 2)];
      final double netWorthBefore = calculateNetWorth(accounts).netWorth;
      final List<Booking> moves = [transfer('Urlaub', 'Laptop', 200), transfer('Urlaub', 'Spar', 100)];
      accounts = applyBookings(accounts, moves);
      expect(calculateNetWorth(accounts).netWorth, netWorthBefore);
      expect(summarizeBookings(moves, excludedNames(accounts)).balance, 0);
      expect(_balance(accounts, 'Laptop'), 200);
    });

    test('complete "Gekauft": expense from goal, counts as expense, saldo not reduced twice', () {
      var accounts = _startAccounts();
      final Set<String> ex = excludedNames(accounts);
      // Oktober: 2.000 € zurücklegen.
      final List<Booking> october = [transfer('Giro', 'Urlaub', 2000, date: DateTime(2026, 10, 1))];
      accounts = applyBookings(accounts, october);
      // November: Ziel als gekauft abschließen.
      final List<Booking> closing = buildGoalClosingBookings(
        action: GoalCloseAction.spend,
        goalAccountName: 'Urlaub',
        balance: _balance(accounts, 'Urlaub'),
        title: 'Urlaub',
        date: DateTime(2026, 11, 3),
        currency: '€',
        categorie: 'freizeit',
      );
      expect(closing.length, 1);
      expect(closing.first.type, BookingType.expense);
      expect(closing.first.categorie, 'freizeit');
      final double netWorthBefore = calculateNetWorth(accounts).netWorth;
      accounts = applyBookings(accounts, closing);
      expect(_balance(accounts, 'Urlaub'), 0);
      // Das verfügbare Vermögen ändert sich beim Kauf nicht mehr ...
      expect(calculateNetWorth(accounts).netWorth, netWorthBefore);
      // ... und das Geld ist nicht mehr als Vermögen vorhanden.
      expect(calculateNetWorth(accounts).excludedTotal, 1000);
      final SaldoSummary nov = summarizeBookings(closing, ex);
      expect(nov.expense, 2000);
      expect(nov.setAside, -2000);
      expect(nov.balance, 0);
      // Über beide Monate: genau einmal -2.000 €.
      expect(summarizeBookings([...october, ...closing], ex).balance, -2000);
      // Oktober bleibt unverändert.
      expect(summarizeBookings(october, ex).balance, -2000);
    });

    test('complete "Erreicht – behalten": transfer to an account, goal empty', () {
      var accounts = _startAccounts(urlaub: 2100);
      final closing = buildGoalClosingBookings(
        action: GoalCloseAction.keep,
        goalAccountName: 'Urlaub',
        balance: 2100,
        title: 'Urlaub',
        date: today,
        currency: '€',
        targetAccountName: 'Spar',
      );
      final double totalBefore = totalMoney(accounts);
      accounts = applyBookings(accounts, closing);
      expect(_balance(accounts, 'Urlaub'), 0);
      expect(_balance(accounts, 'Spar'), 3100);
      expect(totalMoney(accounts), totalBefore);
      expect(closing.single.type, BookingType.transfer);
    });

    test('delete empty goal: no booking needed', () {
      final closing = buildGoalClosingBookings(
          action: GoalCloseAction.delete, goalAccountName: 'Urlaub', balance: 0, title: 'Urlaub', date: today, currency: '€');
      expect(closing, isEmpty);
    });

    test('delete goal containing money: remaining money moves to the chosen account, nothing lost', () {
      var accounts = _startAccounts(urlaub: 750);
      final double totalBefore = totalMoney(accounts);
      final closing = buildGoalClosingBookings(
        action: GoalCloseAction.delete,
        goalAccountName: 'Urlaub',
        balance: 750,
        title: 'Urlaub',
        date: today,
        currency: '€',
        targetAccountName: 'Giro',
      );
      accounts = applyBookings(accounts, closing);
      expect(_balance(accounts, 'Urlaub'), 0);
      expect(_balance(accounts, 'Giro'), 3750);
      expect(totalMoney(accounts), totalBefore);
      final summary = summarizeBookings(closing, excludedNames(accounts));
      expect(summary.income, 0);
      expect(summary.balance, 750);
    });

    test('delete goal with negative balance: the chosen account balances it out', () {
      var accounts = _startAccounts(urlaub: -50);
      final closing = buildGoalClosingBookings(
        action: GoalCloseAction.delete,
        goalAccountName: 'Urlaub',
        balance: -50,
        title: 'Urlaub',
        date: today,
        currency: '€',
        targetAccountName: 'Giro',
      );
      accounts = applyBookings(accounts, closing);
      expect(_balance(accounts, 'Urlaub'), 0);
      expect(_balance(accounts, 'Giro'), 2950);
    });

    test('closing with money but without target account is rejected (money cannot disappear)', () {
      expect(
        () => buildGoalClosingBookings(action: GoalCloseAction.delete, goalAccountName: 'Urlaub', balance: 10, title: 'U', date: today, currency: '€'),
        throwsArgumentError,
      );
      expect(
        () => buildGoalClosingBookings(action: GoalCloseAction.spend, goalAccountName: 'Urlaub', balance: -10, title: 'U', date: today, currency: '€'),
        throwsArgumentError,
      );
    });

    test('multiple goals are independent', () {
      var accounts = [..._startAccounts(), account('Laptop', 0, included: false, goalId: 2)];
      accounts = applyBookings(accounts, [transfer('Giro', 'Urlaub', 300), transfer('Giro', 'Laptop', 700)]);
      expect(_balance(accounts, 'Urlaub'), 300);
      expect(_balance(accounts, 'Laptop'), 700);
      expect(calculateNetWorth(accounts).netWorth, 2000);
      expect(calculateNetWorth(accounts).excludedTotal, 2000);
    });

    test('archived goal accounts keep old transfers classified as set aside', () {
      final List<Account> accounts = [account('Giro', 0), account('Urlaub', 0, included: false, goalId: 1, archived: true)];
      final Booking old = transfer('Giro', 'Urlaub', 500, date: DateTime(2026, 3, 1));
      expect(summarizeBookings([old], excludedNames(accounts)).setAside, 500);
    });
  });
}
