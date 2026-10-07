import 'dart:async';

import 'package:another_flushbar/flushbar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:moneybook/shared/presentation/widgets/input_fields/amount_text_field.dart';
import 'package:moneybook/shared/presentation/widgets/input_fields/title_text_field.dart';
import 'package:rounded_loading_button_plus/rounded_loading_button.dart';

import '../../../../core/consts/common_consts.dart';
import '../../../../core/utils/app_localizations.dart';
import '../../../../core/utils/number_formatter.dart';
import '../../../../shared/presentation/widgets/buttons/save_button.dart';
import '../../../bookings/domain/value_objects/amount.dart';
import '../../domain/entities/goal.dart';
import '../bloc/goal_bloc.dart';
import '../widgets/buttons/date_button.dart';
import 'goal_action_page.dart';

/// Ziel erstellen oder bearbeiten ([goal] != null). Beim Erstellen wird automatisch ein eigenes,
/// nicht ins Vermögen zählendes Ziel-Konto angelegt.
class CreateGoalPage extends StatefulWidget {
  final Goal? goal;

  const CreateGoalPage({super.key, this.goal});

  @override
  State<CreateGoalPage> createState() => _CreateGoalPageState();
}

class _CreateGoalPageState extends State<CreateGoalPage> {
  final GlobalKey<FormState> _goalFormKey = GlobalKey<FormState>();
  final TextEditingController _goalNameController = TextEditingController();
  final TextEditingController _amountController = TextEditingController();
  final RoundedLoadingButtonController _saveGoalBtnController = RoundedLoadingButtonController();
  DateTime _selectedStartDate = DateTime.now();
  DateTime _selectedEndDate = DateTime.now().add(const Duration(days: 365));

  bool get _isEditing => widget.goal != null;

  @override
  void initState() {
    super.initState();
    final Goal? goal = widget.goal;
    if (goal != null) {
      _goalNameController.text = goal.name;
      _amountController.text = formatToMoneyAmount(goal.goalAmount.toString());
      _selectedStartDate = goal.startDate;
      _selectedEndDate = goal.endDate;
    }
  }

  void _resetButton() {
    Timer(const Duration(milliseconds: durationInMs), () {
      _saveGoalBtnController.reset();
    });
  }

  void _showError(BuildContext context, String titleKey, String messageKey) {
    Flushbar(
      title: AppLocalizations.of(context).translate(titleKey),
      message: AppLocalizations.of(context).translate(messageKey),
      icon: const Icon(Icons.error_outline_rounded, color: Colors.redAccent),
      duration: const Duration(milliseconds: flushbarDurationInMs),
      leftBarIndicatorColor: Colors.redAccent,
      flushbarPosition: FlushbarPosition.TOP,
    ).show(context);
  }

  void _saveGoal(BuildContext context) {
    final FormState form = _goalFormKey.currentState!;
    if (form.validate() == false || Amount.getValue(_amountController.text) <= 0.0) {
      _saveGoalBtnController.error();
      _resetButton();
      return;
    }
    final Goal goal = Goal(
      id: widget.goal?.id ?? 0, // Id wird beim Erstellen von der Datenbank gesetzt
      name: _goalNameController.text.trim(),
      goalAmount: Amount.getValue(_amountController.text),
      currency: Amount.getCurrency(_amountController.text),
      startDate: _selectedStartDate,
      endDate: _selectedEndDate,
      state: widget.goal?.state ?? GoalStatus.active,
      accountName: widget.goal?.accountName ?? _goalNameController.text.trim(),
      savedAmount: widget.goal?.savedAmount ?? 0.0,
    );
    BlocProvider.of<GoalBloc>(context).add(_isEditing ? UpdateGoal(goal) : CreateGoal(goal));
  }

  Future<void> _selectStartDate(BuildContext context) async {
    final DateTime? pickedStartDate = await showDatePicker(
      context: context,
      initialDate: _selectedStartDate,
      firstDate: DateTime(2014),
      lastDate: DateTime(DateTime.now().year + 100),
    );
    if (pickedStartDate == null || !mounted) {
      return;
    }
    if (pickedStartDate.isAfter(_selectedEndDate)) {
      _showError(this.context, 'startdatum_nach_zieldatum', 'startdatum_nach_zieldatum_beschreibung');
    } else {
      setState(() => _selectedStartDate = pickedStartDate);
    }
  }

  Future<void> _selectEndDate(BuildContext context) async {
    final DateTime? pickedEndDate = await showDatePicker(
      context: context,
      initialDate: _selectedEndDate,
      firstDate: DateTime(2014),
      lastDate: DateTime(DateTime.now().year + 100),
    );
    if (pickedEndDate == null || !mounted) {
      return;
    }
    if (pickedEndDate.isBefore(_selectedStartDate)) {
      _showError(this.context, 'zieldatum_vor_startdatum', 'zieldatum_vor_startdatum_beschreibung');
    } else {
      setState(() => _selectedEndDate = pickedEndDate);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context).translate(_isEditing ? 'ziel_bearbeiten' : 'ziel_erstellen')),
      ),
      body: BlocListener<GoalBloc, GoalState>(
        listener: (BuildContext context, GoalState state) {
          if (state is Finished) {
            _saveGoalBtnController.success();
            Timer(const Duration(milliseconds: durationInMs), () {
              if (mounted) {
                openGoalsTab(this.context);
              }
            });
          } else if (state is GoalNameTaken) {
            _saveGoalBtnController.error();
            _resetButton();
            _showError(context, 'zielname_existiert_bereits', 'zielname_existiert_bereits_beschreibung');
          } else if (state is Error) {
            _saveGoalBtnController.error();
            _resetButton();
            Flushbar(
              title: AppLocalizations.of(context).translate(_isEditing ? 'ziel_bearbeiten' : 'ziel_erstellen'),
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
                padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
                child: Form(
                  key: _goalFormKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TitleTextField(
                        titleController: _goalNameController,
                        hintText: '${AppLocalizations.of(context).translate('name')}...',
                        maxLength: 30,
                      ),
                      AmountTextField(
                        amountController: _amountController,
                        hintText: '${AppLocalizations.of(context).translate('zielbetrag')}...',
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _isEditing
                              ? DateButton(
                                  text: AppLocalizations.of(context).translate('startdatum'),
                                  selectedDate: _selectedStartDate,
                                  onPressed: () {},
                                )
                              : DateButton(
                                  text: AppLocalizations.of(context).translate('startdatum'),
                                  selectedDate: _selectedStartDate,
                                  onPressed: () => _selectStartDate(context),
                                ),
                          const Padding(
                            padding: EdgeInsets.only(top: 16.0),
                            child: Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 28.0),
                          ),
                          DateButton(
                            text: AppLocalizations.of(context).translate('deadline'),
                            selectedDate: _selectedEndDate,
                            onPressed: () => _selectEndDate(context),
                          ),
                        ],
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(8.0, 16.0, 8.0, 0.0),
                        child: Text(
                          AppLocalizations.of(context).translate('ziel_konto_beschreibung'),
                          style: TextStyle(fontSize: 12.0, color: Colors.grey.shade400),
                        ),
                      ),
                      SaveButton(
                        text: AppLocalizations.of(context).translate(_isEditing ? 'speichern' : 'erstellen'),
                        saveBtnController: _saveGoalBtnController,
                        onPressed: () => _saveGoal(context),
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
