import 'package:sqflite/sqflite.dart';

import '../../../../core/consts/database_consts.dart';
import '../../../../core/utils/account_schema.dart';
import '../../../bookings/data/datasources/booking_local_data_source.dart';
import '../../../bookings/domain/entities/booking.dart';
import '../../domain/services/balance_check.dart';
import '../../domain/services/net_worth_calculator.dart';

/// Alles, was für Kontostand-Anzeige und -Prüfung gebraucht wird.
class BalanceCheckData {
  final List<Booking> bookings;
  final Map<String, double> accountBalances;
  final Set<int> checkedBookingIds;
  final Set<int> affectedSerieIds;

  const BalanceCheckData({
    required this.bookings,
    required this.accountBalances,
    required this.checkedBookingIds,
    required this.affectedSerieIds,
  });

  /// Kontostand nach jeder Buchung (bookingId -> {Konto: Stand}).
  Map<int, Map<String, double>> balancesAfterBookings(DateTime now) =>
      calculateBookingBalances(bookings: bookings, accountBalances: accountBalances, now: now);

  /// Serientermine, die vermutlich nie auf den Kontostand gebucht wurden.
  List<Booking> missedSerieBookings(DateTime now) => findMissedSerieBookings(
        bookings: bookings,
        checkedBookingIds: checkedBookingIds,
        affectedSerieIds: affectedSerieIds,
        existingAccounts: accountBalances.keys.toSet(),
        now: now,
      );
}

class BalanceCheckLocalDataSource {
  const BalanceCheckLocalDataSource();

  Future<Database> _openDatabase() async {
    final Database database = await openDatabase(localDbName);
    await ensureAccountNetWorthColumn(database);
    return database;
  }

  Future<BalanceCheckData> load() async {
    final Database database = await _openDatabase();
    final List<Map<String, Object?>> bookingRows = await database.rawQuery('SELECT * FROM $bookingDbName');
    final List<Map<String, Object?>> accountRows = await database.rawQuery('SELECT name, amount FROM $accountDbName');
    final List<Map<String, Object?>> checkRows = await database.rawQuery('SELECT bookingId FROM $bookingCheckDbName');
    final List<Map<String, Object?>> serieRows = await database.rawQuery('SELECT serieId FROM $affectedSerieDbName');
    return BalanceCheckData(
      bookings: bookingRows.map((row) => bookingFromDbMap(row)).toList(),
      accountBalances: {for (final row in accountRows) row['name'] as String: (row['amount'] as num).toDouble()},
      checkedBookingIds: checkRows.map((row) => row['bookingId'] as int).toSet(),
      affectedSerieIds: serieRows.map((row) => row['serieId'] as int).toSet(),
    );
  }

  /// Bucht die ausgewählten Termine auf die Kontostände nach und merkt sich alle geprüften Termine,
  /// damit sie nicht erneut angeboten werden. Alles in einer Transaktion: ganz oder gar nicht.
  Future<void> repair({required List<Booking> apply, required List<Booking> dismiss}) async {
    final Database database = await _openDatabase();
    await database.transaction((Transaction txn) async {
      for (final Booking booking in apply) {
        // Schutz gegen doppeltes Nachbuchen (z.B. zweimal schnell gespeichert).
        final List<Map<String, Object?>> existing =
            await txn.rawQuery('SELECT bookingId FROM $bookingCheckDbName WHERE bookingId = ?', [booking.id]);
        if (existing.isNotEmpty) {
          continue;
        }
        for (final MapEntry<String, double> change in accountBalanceChanges(booking).entries) {
          final List<Map<String, Object?>> rows = await txn.rawQuery('SELECT amount FROM $accountDbName WHERE name = ?', [change.key]);
          if (rows.isEmpty) {
            throw Exception('Account ${change.key} not found');
          }
          final double current = (rows.first['amount'] as num).toDouble();
          await txn.rawUpdate('UPDATE $accountDbName SET amount = ? WHERE name = ?', [current + change.value, change.key]);
        }
        await txn.rawInsert('INSERT INTO $bookingCheckDbName(bookingId, status) VALUES(?, ?)', [booking.id, 'applied']);
      }
      for (final Booking booking in dismiss) {
        await txn.rawInsert('INSERT OR IGNORE INTO $bookingCheckDbName(bookingId, status) VALUES(?, ?)', [booking.id, 'dismissed']);
      }
    });
  }
}
