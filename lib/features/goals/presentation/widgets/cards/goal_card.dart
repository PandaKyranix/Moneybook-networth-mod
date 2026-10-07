import 'dart:math';

import 'package:flutter/material.dart';
import 'package:percent_indicator/percent_indicator.dart';

import '../../../../../core/utils/app_localizations.dart';
import '../../../../../core/utils/date_formatter.dart';
import '../../../../../core/utils/number_formatter.dart';
import '../../../domain/entities/goal.dart';
import '../../../domain/services/goal_calculator.dart';

/// Übersichtskarte eines Sparziels: gespart / Ziel, Fortschrittsbalken, Deadline und benötigte Sparrate.
class GoalCard extends StatelessWidget {
  final Goal goal;
  final VoidCallback? onTap;

  const GoalCard({
    super.key,
    required this.goal,
    this.onTap,
  });

  static String formatPercent(double progress) => '${(progress * 100.0).toStringAsFixed(1).replaceAll('.', ',')} %';

  @override
  Widget build(BuildContext context) {
    final GoalMetrics metrics = calculateGoalMetrics(
      saved: goal.savedAmount,
      target: goal.goalAmount,
      deadline: goal.endDate,
      now: DateTime.now(),
    );
    final bool isCompleted = goal.state == GoalStatus.completed;
    final Color accentColor = isCompleted
        ? Colors.grey.shade500
        : metrics.isReached
            ? Colors.greenAccent
            : Colors.cyanAccent;

    String deadlineText;
    Color deadlineColor = Colors.grey.shade400;
    if (isCompleted) {
      deadlineText = '${AppLocalizations.of(context).translate('abgeschlossen_am')} '
          '${DateFormatter.dateFormatDDMMYYDateTime(goal.completedDate ?? goal.endDate, context)}';
    } else if (metrics.isOverdue) {
      deadlineText = '${AppLocalizations.of(context).translate('deadline')} ${DateFormatter.dateFormatDDMMYYDateTime(goal.endDate, context)}'
          ' · ${AppLocalizations.of(context).translate('überschritten')}';
      deadlineColor = Colors.redAccent;
    } else {
      deadlineText = '${AppLocalizations.of(context).translate('deadline')} ${DateFormatter.dateFormatDDMMYYDateTime(goal.endDate, context)}'
          ' · ${AppLocalizations.of(context).translate('noch')} ${max(metrics.daysLeft, 0)} ${AppLocalizations.of(context).translate('tage')}';
    }

    return Card(
      child: ClipPath(
        clipper: ShapeBorderClipper(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0))),
        child: InkWell(
          onTap: onTap,
          child: Container(
            decoration: BoxDecoration(border: Border(right: BorderSide(color: accentColor, width: 3.5))),
            padding: const EdgeInsets.fromLTRB(16.0, 12.0, 16.0, 14.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(isCompleted ? Icons.check_circle_rounded : Icons.flag_rounded, size: 18.0, color: accentColor),
                    const SizedBox(width: 8.0),
                    Expanded(
                      child: Text(
                        goal.name,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 17.0, fontWeight: FontWeight.bold),
                      ),
                    ),
                    Text(formatPercent(metrics.progress), style: TextStyle(fontSize: 14.0, color: accentColor)),
                  ],
                ),
                const SizedBox(height: 6.0),
                Text(
                  '${formatToMoneyAmount(goal.savedAmount.toString())} / ${formatToMoneyAmount(goal.goalAmount.toString())}',
                  style: const TextStyle(fontSize: 15.0),
                ),
                const SizedBox(height: 8.0),
                LinearPercentIndicator(
                  padding: EdgeInsets.zero,
                  lineHeight: 10.0,
                  barRadius: const Radius.circular(5.0),
                  percent: min(max(metrics.progress, 0.0), 1.0),
                  progressColor: accentColor,
                  backgroundColor: Colors.grey.shade800,
                  animation: true,
                  animationDuration: 800,
                ),
                const SizedBox(height: 8.0),
                Text(deadlineText, style: TextStyle(fontSize: 12.0, color: deadlineColor)),
                if (!isCompleted) ...[
                  const SizedBox(height: 2.0),
                  Text(
                    metrics.isReached
                        ? AppLocalizations.of(context).translate('ziel_erreicht_abschließen')
                        : metrics.requiredPerMonth != null
                            ? '${AppLocalizations.of(context).translate('noch')} ${formatToMoneyAmount(metrics.remaining.toString())} · '
                                '${formatToMoneyAmount(metrics.requiredPerMonth!.toString())} ${AppLocalizations.of(context).translate('pro_monat')}'
                            : '${AppLocalizations.of(context).translate('noch')} ${formatToMoneyAmount(metrics.remaining.toString())}',
                    style: TextStyle(fontSize: 12.0, color: metrics.isReached ? Colors.greenAccent : Colors.grey.shade400),
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
