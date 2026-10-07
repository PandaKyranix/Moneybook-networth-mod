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

  const Account({
    required this.id,
    required this.type,
    required this.name,
    required this.amount,
    required this.currency,
    this.includeInNetWorth = true,
  });

  /// Liest ein Konto aus einer Datenbankzeile. Fehlt die Spalte includeInNetWorth (z.B. alte Datenbank),
  /// wird das Konto standardmäßig in die Vermögensberechnung einbezogen.
  factory Account.fromDbMap(Map account) {
    return Account(
      id: account['id'],
      type: AccountType.fromString(account['type']),
      name: account['name'],
      amount: (account['amount'] as num).toDouble(),
      currency: account['currency'],
      includeInNetWorth: account['includeInNetWorth'] != 0,
    );
  }

  Account copyWith({
    int? id,
    AccountType? type,
    String? name,
    double? amount,
    String? currency,
    bool? includeInNetWorth,
  }) {
    return Account(
      id: id ?? this.id,
      type: type ?? this.type,
      name: name ?? this.name,
      amount: amount ?? this.amount,
      currency: currency ?? this.currency,
      includeInNetWorth: includeInNetWorth ?? this.includeInNetWorth,
    );
  }

  @override
  List<Object> get props => [id, type, name, amount, currency, includeInNetWorth];
}
