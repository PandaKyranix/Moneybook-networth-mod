import 'package:flutter/material.dart';

import '../../../../../core/utils/app_localizations.dart';

/// Schalter "In Vermögen einbeziehen". Ausgeschaltet gilt das Konto als zurückgelegtes Geld:
/// Es bleibt normal sichtbar und bebuchbar, zählt aber nicht zu Vermögen, Schulden und Saldo.
class IncludeInNetWorthSwitch extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;

  const IncludeInNetWorthSwitch({
    super.key,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6.0, vertical: 4.0),
      child: SwitchListTile(
        value: value,
        onChanged: onChanged,
        contentPadding: const EdgeInsets.symmetric(horizontal: 8.0),
        secondary: Icon(
          value ? Icons.account_balance_wallet_outlined : Icons.lock_outline_rounded,
          color: value ? Colors.cyanAccent : Colors.amberAccent,
        ),
        title: Text(AppLocalizations.of(context).translate('in_vermögen_einbeziehen')),
        subtitle: Text(
          AppLocalizations.of(context).translate(value ? 'in_vermögen_einbeziehen_an' : 'in_vermögen_einbeziehen_aus'),
          style: TextStyle(fontSize: 12.0, color: value ? Colors.grey : Colors.amberAccent),
        ),
      ),
    );
  }
}
