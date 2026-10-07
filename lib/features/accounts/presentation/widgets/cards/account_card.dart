import 'package:flutter/material.dart';
import 'package:moneybook/features/accounts/presentation/widgets/page_arguments/edit_account_page_arguments.dart';

import '../../../../../core/consts/route_consts.dart';
import '../../../../../core/utils/app_localizations.dart';
import '../../../../../core/utils/number_formatter.dart';
import '../../../domain/entities/account.dart';

class AccountCard extends StatefulWidget {
  final Account account;

  const AccountCard({
    super.key,
    required this.account,
  });

  @override
  State<AccountCard> createState() => _AccountCardState();
}

class _AccountCardState extends State<AccountCard> {
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.pushNamed(context, editAccountRoute, arguments: EditAccountPageArguments(widget.account)),
      child: Card(
        child: ClipPath(
          clipper: ShapeBorderClipper(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
          ),
          child: Container(
            decoration: BoxDecoration(
              border: Border(
                left: BorderSide(
                  color: !widget.account.includeInNetWorth
                      ? Colors.amberAccent
                      : widget.account.amount >= 0.0
                          ? Colors.green
                          : Colors.redAccent,
                  width: 3.5,
                ),
              ),
            ),
            child: ListTile(
              title: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    flex: 2,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            if (!widget.account.includeInNetWorth)
                              const Padding(
                                padding: EdgeInsets.only(right: 6.0),
                                child: Icon(Icons.lock_outline_rounded, size: 15.0, color: Colors.amberAccent),
                              ),
                            Flexible(
                              child: Text(
                                AppLocalizations.of(context).translate(widget.account.name),
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 14.0),
                              ),
                            ),
                          ],
                        ),
                        if (!widget.account.includeInNetWorth)
                          Padding(
                            padding: const EdgeInsets.only(top: 2.0),
                            child: Text(
                              AppLocalizations.of(context).translate('nicht_im_vermögen'),
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 11.0, color: Colors.amberAccent),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12.0),
                  Expanded(
                    flex: 1,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          formatToMoneyAmount(widget.account.amount.toString(), withoutDecimalPlaces: 9),
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 14.0),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
