import 'package:sqflite/sqflite.dart';

import '../../../../core/consts/database_consts.dart';
import '../../../../core/utils/account_schema.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../../accounts/domain/services/net_worth_calculator.dart';
import '../../../accounts/domain/value_objects/account_type.dart';
import '../../../bookings/data/datasources/booking_local_data_source.dart';
import '../../../bookings/domain/entities/booking.dart';
import '../../../bookings/domain/value_objects/amount_type.dart';
import '../../../bookings/domain/value_objects/booking_type.dart';
import '../../../bookings/domain/value_objects/repetition_type.dart';
import '../../domain/entities/goal.dart';
import '../../domain/services/goal_calculator.dart';
import '../models/goal_model.dart';

/// Der Name ist bereits als Konto- oder Zielname vergeben (Buchungen verweisen über den Namen auf Konten).
class GoalNameTakenException implements Exception {
  final String name;

  const GoalNameTakenException(this.name);
}

abstract class GoalLocalDataSource {
  Future<void> create(Goal goal);
  Future<void> update(Goal goal);
  Future<void> delete(int id);
  Future<Goal> load(int id);
  Future<List<Goal>> loadAll();
  Future<List<Booking>> loadGoalBookings(String accountName);
  Future<bool> isNameTaken(String name, {int exceptGoalId = 0});
  Future<int> countPlannedBookings(String accountName);
  Future<void> addMoney({required Goal goal, required String fromAccount, required double amount, required DateTime date});
  Future<void> close({required Goal goal, required GoalCloseAction action, String? targetAccountName, String categorie = '', required DateTime date});
}

/// Alle Ziel-Operationen laufen jeweils in einer einzigen Datenbank-Transaktion: Buchung anlegen,
/// Kontostände anpassen und Ziel archivieren passieren gemeinsam oder gar nicht. So kann kein Geld
/// verloren gehen oder doppelt gezählt werden.
class GoalLocalDataSourceImpl implements GoalLocalDataSource {
  GoalLocalDataSourceImpl();

  Future<Database> _openDatabase() async {
    final Database database = await openDatabase(localDbName);
    await ensureAccountNetWorthColumn(database);
    return database;
  }

  Future<bool> _isNameTaken(DatabaseExecutor executor, String name, int exceptGoalId) async {
    final List<Map<String, Object?>> rows = await executor.rawQuery(
      'SELECT name FROM $accountDbName WHERE goalId != ?',
      [exceptGoalId == 0 ? -1 : exceptGoalId],
    );
    // Vergleich in Dart statt mit SQLite LOWER(), das je nach Plattform nur ASCII (nicht Ä/Ö/Ü) umwandelt.
    final String wanted = name.trim().toLowerCase();
    return rows.any((row) => (row['name'] as String).trim().toLowerCase() == wanted);
  }

  @override
  Future<bool> isNameTaken(String name, {int exceptGoalId = 0}) async {
    final Database database = await _openDatabase();
    return _isNameTaken(database, name, exceptGoalId);
  }

  @override
  Future<void> create(Goal goal) async {
    final Database database = await _openDatabase();
    await database.transaction((Transaction txn) async {
      if (await _isNameTaken(txn, goal.name, 0)) {
        throw GoalNameTakenException(goal.name);
      }
      final int goalId = await txn.rawInsert(
        'INSERT INTO $goalDbName(name, goalAmount, currency, startDate, endDate, state) VALUES(?, ?, ?, ?, ?, ?)',
        [
          goal.name.trim(),
          goal.goalAmount,
          goal.currency,
          dateFormatterYYYYMMDD.format(goal.startDate),
          dateFormatterYYYYMMDD.format(goal.endDate),
          GoalStatus.active.name,
        ],
      );
      // Eigenes Ziel-Konto: startet bei 0, ist nie im Vermögen enthalten.
      await txn.rawInsert(
        'INSERT INTO $accountDbName(type, name, amount, currency, includeInNetWorth, goalId, archived) VALUES(?, ?, ?, ?, ?, ?, ?)',
        [AccountType.other.name, goal.name.trim(), 0.0, goal.currency, 0, goalId, 0],
      );
    });
  }

  @override
  Future<void> update(Goal goal) async {
    final Database database = await _openDatabase();
    await database.transaction((Transaction txn) async {
      if (await _isNameTaken(txn, goal.name, goal.id)) {
        throw GoalNameTakenException(goal.name);
      }
      final List<Map<String, Object?>> accountRows = await txn.rawQuery('SELECT name FROM $accountDbName WHERE goalId = ?', [goal.id]);
      final String? oldAccountName = accountRows.isNotEmpty ? accountRows.first['name'] as String : null;
      final String newName = goal.name.trim();
      await txn.rawUpdate(
        'UPDATE $goalDbName SET name = ?, goalAmount = ?, endDate = ? WHERE id = ?',
        [newName, goal.goalAmount, dateFormatterYYYYMMDD.format(goal.endDate), goal.id],
      );
      if (oldAccountName != null && oldAccountName != newName) {
        // Wie beim Umbenennen eines Kontos: Konto und alle Buchungen erhalten den neuen Namen.
        await txn.rawUpdate('UPDATE $accountDbName SET name = ? WHERE goalId = ?', [newName, goal.id]);
        await txn.rawUpdate('UPDATE $bookingDbName SET fromAccount = ? WHERE fromAccount = ?', [newName, oldAccountName]);
        await txn.rawUpdate('UPDATE $bookingDbName SET toAccount = ? WHERE toAccount = ?', [newName, oldAccountName]);
      }
    });
  }

  /// Ziele werden nie hart gelöscht (siehe [close] mit [GoalCloseAction.delete]).
  @override
  Future<void> delete(int id) async {
    throw UnsupportedError('Use close(action: GoalCloseAction.delete) to delete a goal.');
  }

  // Ziel mit Name und Kontostand seines Ziel-Kontos.
  String get _goalQuery =>
      'SELECT g.*, a.name AS accountName, a.amount AS accountAmount FROM $goalDbName g LEFT JOIN $accountDbName a ON a.goalId = g.id';

  @override
  Future<Goal> load(int id) async {
    final Database database = await _openDatabase();
    final List<Map<String, Object?>> rows = await database.rawQuery('$_goalQuery WHERE g.id = ?', [id]);
    if (rows.isEmpty) {
      throw Exception('Goal with id $id not found');
    }
    return GoalModel.fromDbMap(rows.first);
  }

  @override
  Future<List<Goal>> loadAll() async {
    final Database database = await _openDatabase();
    final List<Map<String, Object?>> rows = await database.rawQuery("$_goalQuery WHERE g.state != 'deleted'");
    final List<Goal> goals = rows.map((row) => GoalModel.fromDbMap(row)).toList();
    goals.sort((first, second) => first.endDate.compareTo(second.endDate));
    return goals;
  }

  @override
  Future<List<Booking>> loadGoalBookings(String accountName) async {
    final Database database = await _openDatabase();
    final List<Map<String, Object?>> rows = await database.rawQuery(
      'SELECT * FROM $bookingDbName WHERE fromAccount = ? OR toAccount = ?',
      [accountName, accountName],
    );
    final List<Booking> bookings = rows.map((row) => bookingFromDbMap(row)).toList();
    bookings.sort((first, second) => second.date.compareTo(first.date));
    return bookings;
  }

  String _today(DateTime date) => dateFormatterYYYYMMDD.format(date);

  @override
  Future<int> countPlannedBookings(String accountName) async {
    final Database database = await _openDatabase();
    final List<Map<String, Object?>> rows = await database.rawQuery(
      'SELECT COUNT(*) AS count FROM $bookingDbName WHERE (fromAccount = ? OR toAccount = ?) AND (isBooked = 0 OR substr(date, 1, 10) > ?)',
      [accountName, accountName, _today(DateTime.now())],
    );
    return (rows.first['count'] as int?) ?? 0;
  }

  Future<void> _insertBooking(Transaction txn, Booking booking) async {
    await txn.rawInsert(
      'INSERT INTO $bookingDbName(serieId, type, title, date, repetition, amount, amountType, currency, fromAccount, toAccount, categorie, isBooked) VALUES(?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
      [
        booking.serieId,
        booking.type.name,
        booking.title,
        dateFormatterYYYYMMDD.format(booking.date),
        booking.repetition.name,
        booking.amount,
        booking.amountType.name,
        booking.currency,
        booking.fromAccount,
        booking.toAccount,
        booking.categorie,
        booking.isBooked ? 1 : 0,
      ],
    );
  }

  Future<void> _changeBalance(Transaction txn, String accountName, double change) async {
    final List<Map<String, Object?>> rows = await txn.rawQuery('SELECT amount FROM $accountDbName WHERE name = ?', [accountName]);
    if (rows.isEmpty) {
      throw Exception('Account $accountName not found');
    }
    final double current = (rows.first['amount'] as num).toDouble();
    await txn.rawUpdate('UPDATE $accountDbName SET amount = ? WHERE name = ?', [current + change, accountName]);
  }

  /// Bucht eine bereits fällige Buchung auf die Kontostände – identisch zu AccountLocalDataSource
  /// (withdraw / deposit / transfer).
  Future<void> _applyToAccounts(Transaction txn, Booking booking) async {
    for (final MapEntry<String, double> change in accountBalanceChanges(booking).entries) {
      await _changeBalance(txn, change.key, change.value);
    }
  }

  @override
  Future<void> addMoney({required Goal goal, required String fromAccount, required double amount, required DateTime date}) async {
    final Database database = await _openDatabase();
    final Booking booking = buildGoalDepositBooking(
      goalAccountName: goal.accountName,
      fromAccount: fromAccount,
      amount: amount,
      title: goal.name,
      date: date,
      currency: goal.currency,
      now: DateTime.now(),
    );
    await database.transaction((Transaction txn) async {
      await _insertBooking(txn, booking);
      if (booking.isBooked) {
        await _applyToAccounts(txn, booking);
      }
    });
  }

  @override
  Future<void> close({
    required Goal goal,
    required GoalCloseAction action,
    String? targetAccountName,
    String categorie = '',
    required DateTime date,
  }) async {
    final Database database = await _openDatabase();
    await database.transaction((Transaction txn) async {
      // Aktuellen Kontostand direkt aus der Datenbank lesen, nicht aus dem (evtl. veralteten) Goal-Objekt.
      final List<Map<String, Object?>> accountRows =
          await txn.rawQuery('SELECT name, amount FROM $accountDbName WHERE goalId = ?', [goal.id]);
      if (accountRows.isEmpty) {
        throw Exception('Goal account for goal ${goal.id} not found');
      }
      final String accountName = accountRows.first['name'] as String;
      final double balance = (accountRows.first['amount'] as num).toDouble();

      // Geplante Buchungen mit dem Ziel-Konto entfernen (z.B. ein Sparplan). Sie haben noch keinen
      // Kontostand verändert und würden sonst später Geld auf ein archiviertes Konto buchen.
      // Bereits gebuchte Buchungen bleiben unverändert erhalten.
      await txn.rawDelete(
        'DELETE FROM $bookingDbName WHERE (fromAccount = ? OR toAccount = ?) AND (isBooked = 0 OR substr(date, 1, 10) > ?)',
        [accountName, accountName, _today(DateTime.now())],
      );

      final List<Booking> closingBookings = buildGoalClosingBookings(
        action: action,
        goalAccountName: accountName,
        balance: balance,
        title: goal.name,
        date: date,
        currency: goal.currency,
        targetAccountName: targetAccountName,
        categorie: categorie,
      );
      for (final Booking booking in closingBookings) {
        await _insertBooking(txn, booking);
        await _applyToAccounts(txn, booking);
      }

      // Konto archivieren statt löschen: alte Überträge bleiben so "zurückgelegt" und die Historie stimmt.
      await txn.rawUpdate('UPDATE $accountDbName SET archived = 1 WHERE goalId = ?', [goal.id]);
      // Den erreichten Betrag festhalten, damit abgeschlossene Ziele ihren Endstand anzeigen.
      await txn.rawUpdate(
        'UPDATE $goalDbName SET state = ?, completedDate = ?, finalAmount = ? WHERE id = ?',
        [
          action == GoalCloseAction.delete ? GoalStatus.deleted.name : GoalStatus.completed.name,
          dateFormatterYYYYMMDD.format(date),
          balance,
          goal.id,
        ],
      );
    });
  }
}
