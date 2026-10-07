import 'dart:math';

import 'package:dartz/dartz.dart' show Either;
import 'package:flutter/material.dart';
import 'package:percent_indicator/percent_indicator.dart';

import '../../../../core/consts/route_consts.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/utils/app_localizations.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../../../core/utils/number_formatter.dart';
import '../../../../injection_container.dart';
import '../../../../shared/presentation/widgets/deco/empty_list.dart';
import '../../../bookings/domain/entities/booking.dart';
import '../../../bookings/presentation/widgets/cards/booking_card.dart';
import '../../domain/entities/goal.dart';
import '../../domain/repositories/goal_repository.dart';
import '../../domain/services/goal_calculator.dart';
import '../widgets/cards/goal_card.dart';
import '../widgets/charts/goal_progress_chart.dart';
import '../widgets/page_arguments/goal_page_arguments.dart';

/// Detailansicht eines Sparziels mit Kennzahlen, Verlauf und den Buchungen des Ziel-Kontos.
class GoalDetailPage extends StatefulWidget {
  final Goal goal;

  const GoalDetailPage({super.key, required this.goal});

  @override
  State<GoalDetailPage> createState() => _GoalDetailPageState();
}

class _GoalDetailPageState extends State<GoalDetailPage> {
  List<Booking>? _bookings;

  @override
  void initState() {
    super.initState();
    _loadBookings();
  }

  Future<void> _loadBookings() async {
    final Either<Failure, List<Booking>> result = await sl<GoalRepository>().loadGoalBookings(widget.goal.accountName);
    if (!mounted) {
      return;
    }
    setState(() {
      _bookings = result.fold((failure) => <Booking>[], (bookings) => bookings);
    });
  }

  void _openAction(GoalActionMode mode) {
    Navigator.pushNamed(context, goalActionRoute, arguments: GoalActionPageArguments(widget.goal, mode));
  }

  Widget _statRow(String label, String value, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: Row(
        children: [
          Expanded(child: Text(label, style: TextStyle(fontSize: 13.0, color: Colors.grey.shade400))),
          Text(value, style: TextStyle(fontSize: 13.0, color: color ?? Colors.white)),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context, GoalMetrics metrics) {
    final bool isCompleted = widget.goal.state == GoalStatus.completed;
    final Color color = isCompleted ? Colors.grey.shade500 : (metrics.isReached ? Colors.greenAccent : Colors.cyanAccent);
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16.0, 14.0, 16.0, 14.0),
        child: Row(
          children: [
            CircularPercentIndicator(
              radius: 46.0,
              lineWidth: 8.0,
              animation: true,
              percent: min(max(metrics.progress, 0.0), 1.0),
              center: Text(GoalCard.formatPercent(metrics.progress), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.0)),
              circularStrokeCap: CircularStrokeCap.round,
              progressColor: color,
              backgroundColor: Colors.grey.shade800,
            ),
            const SizedBox(width: 16.0),
            Expanded(
              child: Column(
                children: [
                  _statRow(AppLocalizations.of(context).translate('gespart'), formatToMoneyAmount(widget.goal.savedAmount.toString()), color: color),
                  _statRow(AppLocalizations.of(context).translate('zielbetrag'), formatToMoneyAmount(widget.goal.goalAmount.toString())),
                  _statRow(AppLocalizations.of(context).translate('verbleibend'), formatToMoneyAmount(metrics.remaining.toString())),
                  _statRow(
                    AppLocalizations.of(context).translate('deadline'),
                    DateFormatter.dateFormatDDMMYYDateTime(widget.goal.endDate, context),
                    color: metrics.isOverdue && !isCompleted ? Colors.redAccent : null,
                  ),
                  if (!isCompleted && metrics.requiredPerMonth != null)
                    _statRow(
                      AppLocalizations.of(context).translate('benötigt_pro_monat'),
                      formatToMoneyAmount(metrics.requiredPerMonth!.toString()),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final Goal goal = widget.goal;
    final GoalMetrics metrics = calculateGoalMetrics(saved: goal.savedAmount, target: goal.goalAmount, deadline: goal.endDate, now: DateTime.now());
    final List<Booking>? bookings = _bookings;
    return Scaffold(
      appBar: AppBar(
        title: Text(goal.name),
        actions: goal.isActive
            ? [
                IconButton(
                  tooltip: AppLocalizations.of(context).translate('ziel_bearbeiten'),
                  icon: const Icon(Icons.edit_rounded),
                  onPressed: () => Navigator.pushNamed(context, editGoalRoute, arguments: GoalPageArguments(goal)),
                ),
                IconButton(
                  tooltip: AppLocalizations.of(context).translate('ziel_löschen'),
                  icon: const Icon(Icons.delete_forever_rounded),
                  onPressed: () => _openAction(GoalActionMode.delete),
                ),
              ]
            : null,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(8.0, 8.0, 8.0, 32.0),
        children: [
          _buildHeader(context, metrics),
          if (goal.isActive)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 4.0),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _openAction(GoalActionMode.addMoney),
                      icon: const Icon(Icons.add_rounded, color: Colors.cyanAccent),
                      label: Text(AppLocalizations.of(context).translate('geld_hinzufügen'), style: const TextStyle(color: Colors.cyanAccent)),
                    ),
                  ),
                  if (metrics.isReached) ...[
                    const SizedBox(width: 8.0),
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.greenAccent, foregroundColor: Colors.black87),
                        onPressed: () => _openAction(GoalActionMode.complete),
                        icon: const Icon(Icons.check_rounded),
                        label: Text(AppLocalizations.of(context).translate('abschließen')),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          Card(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8.0, 14.0, 16.0, 8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(left: 8.0, bottom: 10.0),
                    child: Text(AppLocalizations.of(context).translate('fortschritt'), style: TextStyle(fontSize: 12.0, color: Colors.grey.shade400)),
                  ),
                  bookings == null
                      ? const SizedBox(height: 200.0, child: Center(child: CircularProgressIndicator()))
                      : GoalProgressChart(
                          goal: goal,
                          history: calculateGoalHistory(bookings: bookings, goalAccountName: goal.accountName, now: DateTime.now()),
                        ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12.0, 14.0, 12.0, 4.0),
            child: Text(AppLocalizations.of(context).translate('buchungen'), style: const TextStyle(fontSize: 16.0, fontWeight: FontWeight.bold)),
          ),
          if (bookings != null && bookings.isEmpty)
            SizedBox(
              height: 160.0,
              child: EmptyList(
                text: AppLocalizations.of(context).translate('noch_keine_buchungen_für_ziel'),
                icon: Icons.flag_rounded,
              ),
            ),
          if (bookings != null)
            for (final Booking booking in bookings)
              BookingCard(
                booking: booking,
                activateEditing: false,
                excludedAccountNames: {goal.accountName},
              ),
        ],
      ),
    );
  }
}
