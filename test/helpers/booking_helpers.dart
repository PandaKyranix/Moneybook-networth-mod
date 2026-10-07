import 'package:moneybook/features/accounts/domain/entities/account.dart';
import 'package:moneybook/features/accounts/domain/services/net_worth_calculator.dart';
import 'package:moneybook/features/accounts/domain/value_objects/account_type.dart';
import 'package:moneybook/features/bookings/domain/entities/booking.dart';
import 'package:moneybook/features/bookings/domain/value_objects/amount_type.dart';
import 'package:moneybook/features/bookings/domain/value_objects/booking_type.dart';
import 'package:moneybook/features/bookings/domain/value_objects/repetition_type.dart';

Account account(String name, double amount, {bool included = true, AccountType type = AccountType.account, int goalId = 0, bool archived = false}) =>
    Account(
      id: name.hashCode,
      type: type,
      name: name,
      amount: amount,
      currency: '€',
      includeInNetWorth: included,
      goalId: goalId,
      archived: archived,
    );

Booking booking(
  BookingType type,
  double amount, {
  String from = 'Giro',
  String to = '',
  DateTime? date,
  String categorie = '',
}) =>
    Booking(
      id: 0,
      serieId: -1,
      type: type,
      title: 'Test',
      date: date ?? DateTime(2026, 10, 1),
      repetition: RepetitionType.noRepetition,
      amount: amount,
      amountType: AmountType.undefined,
      currency: '€',
      fromAccount: from,
      toAccount: to,
      categorie: categorie,
      isBooked: true,
    );

Booking income(double amount, {String to = 'Giro', DateTime? date}) => booking(BookingType.income, amount, from: to, date: date);

Booking expense(double amount, {String from = 'Giro', DateTime? date, String categorie = 'lebensmittel'}) =>
    booking(BookingType.expense, amount, from: from, date: date, categorie: categorie);

Booking transfer(String from, String to, double amount, {DateTime? date, BookingType type = BookingType.transfer}) =>
    booking(type, amount, from: from, to: to, date: date);

/// Bucht Buchungen auf Konten – mit derselben Funktion, die auch die App verwendet.
List<Account> applyBookings(List<Account> accounts, Iterable<Booking> bookings) {
  final Map<String, double> balances = {for (final Account a in accounts) a.name: a.amount};
  for (final Booking b in bookings) {
    accountBalanceChanges(b).forEach((name, change) {
      if (!balances.containsKey(name)) {
        throw StateError('Unknown account $name');
      }
      balances[name] = balances[name]! + change;
    });
  }
  return accounts.map((a) => a.copyWith(amount: balances[a.name])).toList();
}

/// Summe aller Kontostände (verfügbar + zurückgelegt). Bleibt bei Überträgen immer gleich.
double totalMoney(List<Account> accounts) => accounts.fold(0.0, (sum, a) => sum + a.amount);

/// Namen aller zurückgelegten Konten (wie loadExcludedAccountNames).
Set<String> excludedNames(List<Account> accounts) =>
    accounts.where((a) => !a.includeInNetWorth || a.isGoalAccount || a.archived).map((a) => a.name).toSet();
