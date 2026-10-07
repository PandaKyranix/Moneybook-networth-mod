import 'package:equatable/equatable.dart';
import 'package:moneybook/features/accounts/domain/value_objects/account_type.dart';

class Account extends Equatable {
  final int id;
  final AccountType type;
  final String name;
  final double amount;
  final String currency;

  /// Ob das Konto in die Vermögensberechnung (Vermögen / Schulden / Saldo) einfließt.
  /// Ausgeschlossene Konten gelten als "zurückgelegtes" Geld, das nicht zum verfügbaren Vermögen zählt.
  final bool includeInNetWorth;

  /// Id des Sparziels, zu dem dieses Konto gehört. 0 = normales Konto.
  /// Ziel-Konten sind immer aus dem Vermögen ausgeschlossen und erscheinen nicht in der Kontenliste.
  final int goalId;

  /// Archivierte Konten (abgeschlossene oder gelöschte Ziele) bleiben in der Datenbank, damit
  /// vergangene Überträge weiterhin richtig eingeordnet werden, werden aber nirgends mehr angeboten.
  final bool archived;

  const Account({
    required this.id,
    required this.type,
    required this.name,
    required this.amount,
    required this.currency,
    this.includeInNetWorth = true,
    this.goalId = 0,
    this.archived = false,
  });

  bool get isGoalAccount => goalId != 0;

  /// Liest ein Konto aus einer Datenbankzeile. Fehlen die neuen Spalten (z.B. alte Datenbank),
  /// wird das Konto als normales, einbezogenes Konto behandelt.
  factory Account.fromDbMap(Map account) {
    return Account(
      id: account['id'],
      type: AccountType.fromString(account['type']),
      name: account['name'],
      amount: (account['amount'] as num).toDouble(),
      currency: account['currency'],
      includeInNetWorth: account['includeInNetWorth'] != 0,
      goalId: (account['goalId'] as int?) ?? 0,
      archived: ((account['archived'] as int?) ?? 0) != 0,
    );
  }

  Account copyWith({
    int? id,
    AccountType? type,
    String? name,
    double? amount,
    String? currency,
    bool? includeInNetWorth,
    int? goalId,
    bool? archived,
  }) {
    return Account(
      id: id ?? this.id,
      type: type ?? this.type,
      name: name ?? this.name,
      amount: amount ?? this.amount,
      currency: currency ?? this.currency,
      includeInNetWorth: includeInNetWorth ?? this.includeInNetWorth,
      goalId: goalId ?? this.goalId,
      archived: archived ?? this.archived,
    );
  }

  @override
  List<Object> get props => [id, type, name, amount, currency, includeInNetWorth, goalId, archived];
}
