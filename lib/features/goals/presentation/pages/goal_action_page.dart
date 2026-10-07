import 'dart:async';

import 'package:another_flushbar/flushbar.dart';
import 'package:dartz/dartz.dart' show Either;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:rounded_loading_button_plus/rounded_loading_button.dart';

import '../../../../core/consts/common_consts.dart';
import '../../../../core/consts/route_consts.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/utils/app_localizations.dart';
import '../../../../core/utils/number_formatter.dart';
import '../../../../injection_container.dart';
import '../../../../shared/presentation/widgets/arguments/bottom_nav_bar_arguments.dart';
import '../../../../shared/presentation/widgets/buttons/save_button.dart';
import '../../../../shared/presentation/widgets/input_fields/amount_text_field.dart';
import '../../../../shared/presentation/widgets/navigation_widgets/navigation_widget.dart';
import '../../../bookings/domain/value_objects/amount.dart';
import '../../../bookings/domain/value_objects/booking_type.dart';
import '../../../bookings/presentation/widgets/input_fields/account_input_field.dart';
import '../../../bookings/presentation/widgets/input_fields/categorie_input_field.dart';
import '../../domain/entities/goal.dart';
import '../../domain/repositories/goal_repository.dart';
import '../../domain/services/goal_calculator.dart';
import '../bloc/goal_bloc.dart';
import '../widgets/page_arguments/goal_page_arguments.dart';

/// Nach einer erfolgreichen Ziel-Aktion die Hauptseite neu aufbauen (wie nach jeder Buchung),
/// damit Kontostände, Buchungen und Ziele überall aktuell sind.
void openGoalsTab(BuildContext context) {
  Navigator.pushNamedAndRemoveUntil(
    context,
    bottomNavBarRoute,
    (route) => false,
    arguments: BottomNavBarArguments(tabIndex: goalsTabIndex),
  );
}

/// Formular für "Geld hinzufügen", "Abschließen" (Gekauft / Erreicht) und "Löschen" eines Ziels.
class GoalActionPage extends StatefulWidget {
  final Goal goal;
  final GoalActionMode mode;

  const GoalActionPage({super.key, required this.goal, required this.mode});

  @override
  State<GoalActionPage> createState() => _GoalActionPageState();
}

class _GoalActionPageState extends State<GoalActionPage> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _accountController = TextEditingController();
  final TextEditingController _categorieController = TextEditingController();
  final RoundedLoadingButtonController _saveBtnController = RoundedLoadingButtonController();
  String _accountNameForDb = '';
  String _categorieNameForDb = '';
  GoalCloseAction _closeAction = GoalCloseAction.spend;
  int _plannedBookings = 0;

  @override
  void initState() {
    super.initState();
    if (widget.mode != GoalActionMode.addMoney) {
      _loadPlannedBookings();
    }
  }

  Future<void> _loadPlannedBookings() async {
    final Either<Failure, int> result = await sl<GoalRepository>().countPlannedBookings(widget.goal.accountName);
    if (!mounted) {
      return;
    }
    setState(() {
      _plannedBookings = result.fold((failure) => 0, (count) => count);
    });
  }

  bool get _hasMoney => widget.goal.savedAmount.abs() >= 0.005;

  bool get _needsAccount {
    switch (widget.mode) {
      case GoalActionMode.addMoney:
        return true;
      case GoalActionMode.complete:
        return _closeAction == GoalCloseAction.keep && _hasMoney;
      case GoalActionMode.delete:
        return _hasMoney;
    }
  }

  void _resetButton() {
    Timer(const Duration(milliseconds: durationInMs), () {
      _saveBtnController.reset();
    });
  }

  void _save(BuildContext context) {
    final FormState form = _formKey.currentState!;
    if (form.validate() == false) {
      _saveBtnController.error();
      _resetButton();
      return;
    }
    final GoalBloc goalBloc = BlocProvider.of<GoalBloc>(context);
    switch (widget.mode) {
      case GoalActionMode.addMoney:
        final double amount = Amount.getValue(_amountController.text);
        if (amount <= 0.0) {
          _saveBtnController.error();
          _resetButton();
          return;
        }
        goalBloc.add(AddMoneyToGoal(goal: widget.goal, fromAccount: _accountNameForDb, amount: amount));
      case GoalActionMode.complete:
        goalBloc.add(CloseGoal(
          goal: widget.goal,
          action: _closeAction,
          targetAccountName: _needsAccount ? _accountNameForDb : null,
          categorie: _categorieNameForDb,
        ));
      case GoalActionMode.delete:
        goalBloc.add(CloseGoal(
          goal: widget.goal,
          action: GoalCloseAction.delete,
          targetAccountName: _needsAccount ? _accountNameForDb : null,
        ));
    }
  }

  String _title(BuildContext context) {
    switch (widget.mode) {
      case GoalActionMode.addMoney:
        return AppLocalizations.of(context).translate('geld_hinzufügen');
      case GoalActionMode.complete:
        return AppLocalizations.of(context).translate('ziel_abschließen');
      case GoalActionMode.delete:
        return AppLocalizations.of(context).translate('ziel_löschen');
    }
  }

  String _buttonText(BuildContext context) {
    switch (widget.mode) {
      case GoalActionMode.addMoney:
        return AppLocalizations.of(context).translate('hinzufügen');
      case GoalActionMode.complete:
        return AppLocalizations.of(context).translate(_closeAction == GoalCloseAction.spend ? 'als_gekauft_buchen' : 'abschließen');
      case GoalActionMode.delete:
        return AppLocalizations.of(context).translate(_hasMoney ? 'übertragen_und_löschen' : 'löschen');
    }
  }

  Widget _infoText(String text, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 6.0),
      child: Text(text, style: TextStyle(fontSize: 13.0, color: color ?? Colors.grey.shade400)),
    );
  }

  Widget _buildCloseActionChoice(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: SegmentedButton<GoalCloseAction>(
        segments: [
          ButtonSegment<GoalCloseAction>(
            value: GoalCloseAction.spend,
            icon: const Icon(Icons.shopping_bag_rounded),
            label: Text(AppLocalizations.of(context).translate('gekauft'), style: const TextStyle(fontSize: 12.0)),
          ),
          ButtonSegment<GoalCloseAction>(
            value: GoalCloseAction.keep,
            icon: const Icon(Icons.savings_rounded),
            label: Text(AppLocalizations.of(context).translate('geld_behalten'), style: const TextStyle(fontSize: 12.0)),
          ),
        ],
        selected: {_closeAction},
        showSelectedIcon: false,
        onSelectionChanged: (Set<GoalCloseAction> selection) {
          setState(() {
            _closeAction = selection.first;
          });
        },
      ),
    );
  }

  List<Widget> _buildFields(BuildContext context) {
    final String saved = formatToMoneyAmount(widget.goal.savedAmount.toString());
    switch (widget.mode) {
      case GoalActionMode.addMoney:
        return [
          _infoText(AppLocalizations.of(context).translate('geld_hinzufügen_beschreibung')),
          AmountTextField(
            amountController: _amountController,
            hintText: '${AppLocalizations.of(context).translate('betrag')}...',
          ),
          AccountInputField(
            accountController: _accountController,
            onAccountSelected: (accountName) => setState(() => _accountNameForDb = accountName),
            hintText: '${AppLocalizations.of(context).translate('abbuchungskonto')}...',
            bottomSheetTitle: '${AppLocalizations.of(context).translate('abbuchungskonto_auswählen')}:',
            accountNameFilter: [widget.goal.accountName],
            allowGoalAccounts: true,
          ),
        ];
      case GoalActionMode.complete:
        return [
          _buildCloseActionChoice(context),
          const SizedBox(height: 8.0),
          if (_closeAction == GoalCloseAction.spend) ...[
            _infoText(AppLocalizations.of(context).translate('gekauft_beschreibung').replaceAll('{betrag}', saved)),
            CategorieInputField(
              categorieController: _categorieController,
              onCategorieSelected: (categorie) => setState(() => _categorieNameForDb = categorie),
              bookingType: BookingType.expense,
            ),
          ] else ...[
            _infoText(AppLocalizations.of(context).translate('geld_behalten_beschreibung').replaceAll('{betrag}', saved)),
            if (_needsAccount)
              AccountInputField(
                accountController: _accountController,
                onAccountSelected: (accountName) => setState(() => _accountNameForDb = accountName),
                hintText: '${AppLocalizations.of(context).translate('zielkonto')}...',
                bottomSheetTitle: '${AppLocalizations.of(context).translate('konto_auswählen')}:',
              ),
          ],
        ];
      case GoalActionMode.delete:
        return [
          _infoText(
            _hasMoney
                ? AppLocalizations.of(context).translate('ziel_löschen_mit_geld').replaceAll('{betrag}', saved)
                : AppLocalizations.of(context).translate('ziel_löschen_ohne_geld'),
            color: Colors.white,
          ),
          if (_needsAccount)
            AccountInputField(
              accountController: _accountController,
              onAccountSelected: (accountName) => setState(() => _accountNameForDb = accountName),
              hintText: '${AppLocalizations.of(context).translate('zielkonto')}...',
              bottomSheetTitle: '${AppLocalizations.of(context).translate('wohin_soll_das_geld')}',
            ),
        ];
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('${_title(context)}: ${widget.goal.name}')),
      body: BlocListener<GoalBloc, GoalState>(
        listener: (BuildContext context, GoalState state) {
          if (state is Finished) {
            _saveBtnController.success();
            Timer(const Duration(milliseconds: durationInMs), () {
              if (mounted) {
                openGoalsTab(this.context);
              }
            });
          } else if (state is Error) {
            _saveBtnController.error();
            _resetButton();
            Flushbar(
              title: _title(context),
              message: state.message,
              icon: const Icon(Icons.error_outline_rounded, color: Colors.redAccent),
              duration: const Duration(milliseconds: flushbarDurationInMs),
              leftBarIndicatorColor: Colors.redAccent,
              flushbarPosition: FlushbarPosition.TOP,
            ).show(context);
          }
        },
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16.0, 12.0, 16.0, 4.0),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ..._buildFields(context),
                      if (widget.mode != GoalActionMode.addMoney && _plannedBookings > 0)
                        _infoText(
                          AppLocalizations.of(context).translate('geplante_buchungen_werden_entfernt').replaceAll('{anzahl}', '$_plannedBookings'),
                          color: Colors.amberAccent,
                        ),
                      SaveButton(
                        text: _buttonText(context),
                        saveBtnController: _saveBtnController,
                        onPressed: () => _save(context),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
