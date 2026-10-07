import 'package:flutter/material.dart';

import '../../../../../core/utils/app_localizations.dart';
import '../../../../../core/utils/date_formatter.dart';
import '../../../../../core/utils/number_formatter.dart';
import '../../../domain/services/saldo_calculator.dart';

/// Karte der Jahresansicht: zeigt, wie sich der Saldo eines Monats zusammensetzt.
///
///   Jahressaldo Anfang      1.200,00 €
///   Einnahmen              +2.000,00 €
///   Ausgaben               -1.000,00 €
///   Zurückgelegt             -500,00 €
///   ---------------------------------
///   Monatssaldo               500,00 €
///   Jahressaldo Ende        1.700,00 €
class MonthSaldoCard extends StatelessWidget {
  final MonthSaldo monthSaldo;
  final int year;
  final bool showSetAside;
  final VoidCallback? onTap;

  const MonthSaldoCard({
    super.key,
    required this.monthSaldo,
    required this.year,
    required this.showSetAside,
    this.onTap,
  });

  static String _signed(double value) {
    final String formatted = formatToMoneyAmount(value.toString());
    return value > 0.0 ? '+$formatted' : formatted;
  }

  Widget _row(String label, String value, {Color? valueColor, bool small = false, bool bold = false}) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: small ? 1.0 : 2.0),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: small ? 11.5 : 13.0, color: small ? Colors.grey.shade500 : Colors.grey.shade300),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: small ? 11.5 : 13.0,
              color: valueColor ?? (small ? Colors.grey.shade500 : Colors.white),
              fontWeight: bold ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _summaryRows(BuildContext context, SaldoSummary summary) {
    return [
      _row(AppLocalizations.of(context).translate('einnahmen'), _signed(summary.income), valueColor: Colors.greenAccent),
      _row(AppLocalizations.of(context).translate('ausgaben'), _signed(-summary.expense), valueColor: Colors.redAccent),
      if (showSetAside || summary.setAside != 0.0)
        _row(AppLocalizations.of(context).translate('zurückgelegt'), _signed(-summary.setAside), valueColor: Colors.amberAccent),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final DateTime monthDate = DateTime(year, monthSaldo.month, 1);
    final bool isEmpty = monthSaldo.due.isEmpty && monthSaldo.pending.isEmpty;
    final double balance = monthSaldo.isFuture ? monthSaldo.pending.balance : monthSaldo.due.balance;
    final Color borderColor = isEmpty ? Colors.grey.shade700 : (balance >= 0.0 ? Colors.greenAccent : Colors.redAccent);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 4.0),
      child: ClipPath(
        clipper: ShapeBorderClipper(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0))),
        child: InkWell(
          onTap: onTap,
          child: Container(
            decoration: BoxDecoration(border: Border(right: BorderSide(color: borderColor, width: 3.5))),
            padding: const EdgeInsets.fromLTRB(14.0, 10.0, 14.0, 10.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        DateFormatter.dateFormatMMMM(monthDate, context),
                        style: const TextStyle(fontSize: 15.0, fontWeight: FontWeight.bold),
                      ),
                    ),
                    if (monthSaldo.isFuture && !isEmpty)
                      Padding(
                        padding: const EdgeInsets.only(right: 8.0),
                        child: Text(
                          AppLocalizations.of(context).translate('geplant'),
                          style: TextStyle(fontSize: 11.0, color: Colors.grey.shade500, fontStyle: FontStyle.italic),
                        ),
                      ),
                    if (!isEmpty)
                      Text(
                        formatToMoneyAmount(balance.toString()),
                        style: TextStyle(fontSize: 15.0, fontWeight: FontWeight.bold, color: balance >= 0.0 ? Colors.greenAccent : Colors.redAccent),
                      ),
                  ],
                ),
                if (isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4.0),
                    child: Text(
                      AppLocalizations.of(context).translate('keine_buchungen'),
                      style: TextStyle(fontSize: 12.0, color: Colors.grey.shade500),
                    ),
                  )
                else if (monthSaldo.isFuture) ...[
                  const SizedBox(height: 6.0),
                  ..._summaryRows(context, monthSaldo.pending),
                ] else ...[
                  const SizedBox(height: 6.0),
                  if (monthSaldo.month > 1)
                    _row(
                      AppLocalizations.of(context).translate('jahressaldo_anfang'),
                      formatToMoneyAmount(monthSaldo.yearToDateBefore.toString()),
                      small: true,
                    ),
                  ..._summaryRows(context, monthSaldo.due),
                  Divider(height: 10.0, thickness: 0.6, color: Colors.grey.shade700),
                  _row(
                    AppLocalizations.of(context).translate('monatssaldo'),
                    formatToMoneyAmount(monthSaldo.due.balance.toString()),
                    valueColor: monthSaldo.due.balance >= 0.0 ? Colors.greenAccent : Colors.redAccent,
                    bold: true,
                  ),
                  _row(
                    AppLocalizations.of(context).translate('jahressaldo_ende'),
                    formatToMoneyAmount(monthSaldo.yearToDateAfter.toString()),
                    small: true,
                  ),
                  if (!monthSaldo.pending.isEmpty)
                    _row(
                      AppLocalizations.of(context).translate('noch_ausstehend'),
                      _signed(monthSaldo.pending.balance),
                      small: true,
                    ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
