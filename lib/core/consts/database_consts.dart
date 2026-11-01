var db;

// Demo Modus für Datenbank
bool demoMode = false;

// Datenbank Name in der alle Datenbank Tabellen enthalten sind
String localDbName = demoMode == false ? 'local_db.db' : 'local_db_demo.db';
String remoteDbName = demoMode == false ? 'remote_db.db' : 'remote_db_demo.db';

// Datenbank Tabellen Namen
String bookingDbName = demoMode == false ? 'bookings' : 'bookings_demo';
String accountDbName = demoMode == false ? 'accounts' : 'accounts_demo';
String categorieDbName = demoMode == false ? 'categories' : 'categories_demo';
String budgetDbName = demoMode == false ? 'budgets' : 'budgets_demo';
String userDbName = demoMode == false ? 'user' : 'user_demo';
String goalDbName = demoMode == false ? 'goals' : 'goals_demo';
// Merkt sich, welche gebuchten Serienbuchungen sicher auf den Kontostand angerechnet wurden (Kontostand-Prüfung).
String bookingCheckDbName = demoMode == false ? 'booking_checks' : 'booking_checks_demo';
// Serien, die vom Fehler mit zukünftigen "gebuchten" Terminen betroffen waren.
String affectedSerieDbName = demoMode == false ? 'affected_series' : 'affected_series_demo';

// Aktuelle Datenbank Tabellen Version
int localDbVersion = demoMode == false ? 7 : 7;

void switchDemoMode(bool demoMode) {
  localDbName = demoMode == false ? 'local_db.db' : 'local_db_demo.db';
  remoteDbName = demoMode == false ? 'remote_db.db' : 'remote_db_demo.db';

  // Datenbank Tabellen
  bookingDbName = demoMode == false ? 'bookings' : 'bookings_demo';
  accountDbName = demoMode == false ? 'accounts' : 'accounts_demo';
  categorieDbName = demoMode == false ? 'categories' : 'categories_demo';
  budgetDbName = demoMode == false ? 'budgets' : 'budgets_demo';
  userDbName = demoMode == false ? 'user' : 'user_demo';
  goalDbName = demoMode == false ? 'goals' : 'goals_demo';
  bookingCheckDbName = demoMode == false ? 'booking_checks' : 'booking_checks_demo';
  affectedSerieDbName = demoMode == false ? 'affected_series' : 'affected_series_demo';

  localDbVersion = demoMode == false ? 7 : 7;
}
