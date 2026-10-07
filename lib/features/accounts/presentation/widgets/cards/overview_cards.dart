import 'package:flutter/material.dart';

import '../../../../../core/utils/app_localizations.dart';
import '../../../../../core/utils/number_formatter.dart';
import '../../../../../shared/presentation/widgets/dialogs/info_icon_with_dialog.dart';
import '../../../domain/entities/account.dart';
import 'overview_card.dart';

class OverviewCards extends StatefulWidget {
  final List<Account> accounts;
  final double assets;
  final double debts;
  final double excludedTotal;
  final int excludedCount;

  const OverviewCards({
    super.key,
    required this.accounts,
    required this.assets,
    required this.debts,
    this.excludedTotal = 0.0,
    this.excludedCount = 0,
  });

  @override
  State<OverviewCards> createState() => _OverviewCardsState();
}

class _OverviewCardsState extends State<OverviewCards> {
  @override
  Widget build(BuildContext context) {
    if (widget.excludedCount == 0) {
      return _buildCards(context);
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildCards(context),
        _buildExcludedRow(context),
      ],
    );
  }

  // Hinweis auf zurückgelegtes Geld, damit ausgeschlossene Kontostände sichtbar bleiben
  // und klar ist, warum sie im Saldo fehlen.
  Widget _buildExcludedRow(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(2.0, 2.0, 2.0, 0.0),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
          child: Row(
            children: [
              const Icon(Icons.lock_outline_rounded, size: 16.0, color: Colors.amberAccent),
              const SizedBox(width: 8.0),
              Expanded(
                child: Text(
                  '${AppLocalizations.of(context).translate('zurückgelegt_nicht_im_vermögen')} (${widget.excludedCount})',
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: Colors.grey.shade400, fontSize: 12.0),
                ),
              ),
              Text(
                formatToMoneyAmount(widget.excludedTotal.toString()),
                style: const TextStyle(color: Colors.amberAccent, fontSize: 13.0),
              ),
              InfoIconWithDialog(
                title: AppLocalizations.of(context).translate('zurückgelegt'),
                text: AppLocalizations.of(context).translate('zurückgelegt_beschreibung'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCards(BuildContext context) {
    return SizedBox(
      height: 70.0,
      child: Row(
        children: [
          OverviewCard(
            title: AppLocalizations.of(context).translate('vermögen'),
            value: widget.assets,
            textColor: Colors.greenAccent,
            infoDialogText: AppLocalizations.of(context).translate('vermögen_beschreibung') +
                '\n- ' +
                AppLocalizations.of(context).translate('konto') +
                '\n- ' +
                AppLocalizations.of(context).translate('kapitalanlage') +
                '\n- ' +
                AppLocalizations.of(context).translate('bargeld') +
                '\n- ' +
                AppLocalizations.of(context).translate('karte') +
                '\n- ' +
                AppLocalizations.of(context).translate('versicherung') +
                '\n- ' +
                AppLocalizations.of(context).translate('sonstiges'),
          ),
          OverviewCard(
            title: AppLocalizations.of(context).translate('schulden'),
            value: widget.debts,
            textColor: Colors.redAccent,
            infoDialogText: AppLocalizations.of(context).translate('schulden_beschreibung'),
          ),
          OverviewCard(
            title: AppLocalizations.of(context).translate('saldo'),
            value: widget.assets - widget.debts,
            textColor: widget.assets - widget.debts >= 0.0 ? Colors.greenAccent : Colors.redAccent,
            infoDialogText: AppLocalizations.of(context).translate('saldo_beschreibung') +
                (widget.excludedCount > 0 ? '\n\n' + AppLocalizations.of(context).translate('saldo_ohne_zurückgelegt') : ''),
          ),
        ],
      ),
    );
  }
}
