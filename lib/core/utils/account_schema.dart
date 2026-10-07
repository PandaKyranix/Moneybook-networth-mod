import 'package:sqflite/sqflite.dart';

import '../consts/database_consts.dart';

/// Stellt sicher, dass die Kontotabelle die Spalte includeInNetWorth besitzt.
/// Idempotent und ohne Änderung der Datenbankversion, damit auch alte Datenbanken
/// (z.B. nach dem Import eines Backups) automatisch ergänzt werden. Bestehende Konten
/// erhalten den Standardwert 1 (= in Vermögen einbezogen).
Future<void> ensureAccountNetWorthColumn(Database db) async {
  final List<Map<String, Object?>> columns = await db.rawQuery('PRAGMA table_info($accountDbName)');
  if (columns.isEmpty) {
    return; // Tabelle existiert (noch) nicht.
  }
  final bool hasColumn = columns.any((column) => column['name'] == 'includeInNetWorth');
  if (!hasColumn) {
    await db.execute('ALTER TABLE $accountDbName ADD COLUMN includeInNetWorth INTEGER NOT NULL DEFAULT 1');
  }
}

/// Lädt die Namen aller Konten, die aus der Vermögensberechnung ausgeschlossen sind.
Future<Set<String>> loadExcludedAccountNames() async {
  final Database database = await openDatabase(localDbName);
  await ensureAccountNetWorthColumn(database);
  final List<Map<String, Object?>> rows = await database.rawQuery('SELECT name FROM $accountDbName WHERE includeInNetWorth = 0');
  return rows.map((row) => row['name'] as String).toSet();
}
