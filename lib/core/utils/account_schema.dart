import 'package:sqflite/sqflite.dart';

import '../consts/database_consts.dart';

/// Ergänzt die Datenbank um die Spalten / Tabellen der Erweiterungen "In Vermögen einbeziehen" und "Ziele".
/// Idempotent und ohne Änderung der Datenbankversion, damit auch alte Datenbanken (z.B. nach dem Import
/// eines Backups) automatisch ergänzt werden und Backups mit der offiziellen App kompatibel bleiben.
///
/// Konten:
/// - includeInNetWorth (1 = in Vermögen einbezogen, Standard)
/// - goalId (0 = normales Konto, sonst Id des zugehörigen Sparziels)
/// - archived (1 = Konto eines abgeschlossenen / gelöschten Ziels; bleibt für die Historie erhalten)
Future<void> ensureAccountNetWorthColumn(DatabaseExecutor db) async {
  final List<Map<String, Object?>> columns = await db.rawQuery('PRAGMA table_info($accountDbName)');
  if (columns.isNotEmpty) {
    final Set<Object?> columnNames = columns.map((column) => column['name']).toSet();
    if (!columnNames.contains('includeInNetWorth')) {
      await db.execute('ALTER TABLE $accountDbName ADD COLUMN includeInNetWorth INTEGER NOT NULL DEFAULT 1');
    }
    if (!columnNames.contains('goalId')) {
      await db.execute('ALTER TABLE $accountDbName ADD COLUMN goalId INTEGER NOT NULL DEFAULT 0');
    }
    if (!columnNames.contains('archived')) {
      await db.execute('ALTER TABLE $accountDbName ADD COLUMN archived INTEGER NOT NULL DEFAULT 0');
    }
  }
  await ensureGoalTable(db);
}

/// Tabelle der Sparziele. Der gesparte Betrag wird nicht hier gespeichert, sondern ergibt sich immer
/// aus dem Kontostand des zugehörigen Ziel-Kontos (accounts.goalId = goals.id).
Future<void> ensureGoalTable(DatabaseExecutor db) async {
  // Eine frühere, nie aktivierte Entwicklungsversion hatte ein anderes Tabellenschema.
  // Falls eine solche (leere) Tabelle existiert, wird sie durch das neue Schema ersetzt.
  final List<Map<String, Object?>> goalColumns = await db.rawQuery('PRAGMA table_info($goalDbName)');
  if (goalColumns.isNotEmpty && !goalColumns.any((column) => column['name'] == 'state')) {
    final List<Map<String, Object?>> rows = await db.rawQuery('SELECT COUNT(*) AS count FROM $goalDbName');
    if (((rows.first['count'] as int?) ?? 0) == 0) {
      await db.execute('DROP TABLE $goalDbName');
    }
  }
  await db.execute('''
      CREATE TABLE IF NOT EXISTS $goalDbName (
        id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        goalAmount DOUBLE NOT NULL,
        currency TEXT NOT NULL,
        startDate TEXT NOT NULL,
        endDate TEXT NOT NULL,
        state TEXT NOT NULL DEFAULT 'active',
        completedDate TEXT,
        finalAmount DOUBLE
      )
      ''');
  final List<Map<String, Object?>> columns = await db.rawQuery('PRAGMA table_info($goalDbName)');
  if (!columns.any((column) => column['name'] == 'finalAmount')) {
    await db.execute('ALTER TABLE $goalDbName ADD COLUMN finalAmount DOUBLE');
  }
}

/// Namen der archivierten Konten (abgeschlossene / gelöschte Ziele). Deren alte Buchungen dürfen nicht mehr
/// bearbeitet werden, weil sonst Geld auf ein nicht mehr sichtbares Konto gebucht würde.
Future<Set<String>> loadArchivedAccountNames() async {
  final Database database = await openDatabase(localDbName);
  await ensureAccountNetWorthColumn(database);
  final List<Map<String, Object?>> rows = await database.rawQuery('SELECT name FROM $accountDbName WHERE archived = 1');
  return rows.map((row) => row['name'] as String).toSet();
}

/// Lädt die Namen aller Konten, die aus der Vermögensberechnung ausgeschlossen sind
/// (inklusive Ziel-Konten und archivierter Ziel-Konten, damit alte Überträge richtig eingeordnet bleiben).
Future<Set<String>> loadExcludedAccountNames() async {
  final Database database = await openDatabase(localDbName);
  await ensureAccountNetWorthColumn(database);
  final List<Map<String, Object?>> rows =
      await database.rawQuery('SELECT name FROM $accountDbName WHERE includeInNetWorth = 0 OR goalId != 0 OR archived = 1');
  return rows.map((row) => row['name'] as String).toSet();
}
