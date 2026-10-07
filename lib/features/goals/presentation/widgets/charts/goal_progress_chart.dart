import 'dart:math';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../../../core/utils/app_localizations.dart';
import '../../../../../core/utils/date_formatter.dart';
import '../../../../../core/utils/number_formatter.dart';
import '../../../domain/entities/goal.dart';
import '../../../domain/services/goal_calculator.dart';

/// Verlauf eines Sparziels: tatsächlich gespart (Treppenlinie), geplante Überträge (gestrichelt),
/// idealer Sparverlauf bis zur Deadline (grau gestrichelt), Zielbetrag und "Heute"-Markierung.
/// Angelehnt an das Ziel-Diagramm im haushaltsbuch_budget_tracker.
class GoalProgressChart extends StatelessWidget {
  final Goal goal;
  final List<GoalHistoryPoint> history;

  const GoalProgressChart({super.key, required this.goal, required this.history});

  static DateTime _day(DateTime date) => DateTime.utc(date.year, date.month, date.day);

  @override
  Widget build(BuildContext context) {
    final DateTime now = DateTime.now();
    final DateTime today = _day(now);
    DateTime start = _day(goal.startDate);
    DateTime end = _day(goal.endDate);
    for (final GoalHistoryPoint point in history) {
      final DateTime day = _day(point.date);
      if (day.isBefore(start)) start = day;
      if (day.isAfter(end)) end = day;
    }
    if (goal.isActive && today.isAfter(end)) {
      end = today;
    }
    if (!end.isAfter(start)) {
      end = start.add(const Duration(days: 1));
    }
    double x(DateTime date) => _day(date).difference(start).inDays.toDouble();
    final double maxX = x(end);

    // Tatsächlicher Verlauf als Treppe: Der Betrag bleibt bis zur nächsten Buchung gleich.
    final List<FlSpot> dueSpots = [const FlSpot(0.0, 0.0)];
    final List<FlSpot> plannedSpots = [];
    double lastAmount = 0.0;
    for (final GoalHistoryPoint point in history) {
      final double pointX = x(point.date);
      if (point.isPlanned) {
        if (plannedSpots.isEmpty) {
          plannedSpots.add(FlSpot(min(x(today), maxX), lastAmount));
        }
        plannedSpots.add(FlSpot(pointX, plannedSpots.last.y));
        plannedSpots.add(FlSpot(pointX, point.amount));
      } else {
        dueSpots.add(FlSpot(pointX, lastAmount));
        dueSpots.add(FlSpot(pointX, point.amount));
        lastAmount = point.amount;
      }
    }
    // Linie bis heute (bzw. bis zum Abschluss) weiterführen.
    final double lineEndX = goal.isActive ? min(x(today), maxX) : (goal.completedDate != null ? min(x(goal.completedDate!), maxX) : dueSpots.last.x);
    if (lineEndX > dueSpots.last.x) {
      dueSpots.add(FlSpot(lineEndX, lastAmount));
    }

    final List<double> values = [goal.goalAmount, ...dueSpots.map((spot) => spot.y), ...plannedSpots.map((spot) => spot.y)];
    final double maxY = max(values.reduce(max), 1.0) * 1.15;
    final double minY = min(values.reduce(min), 0.0);
    final bool showToday = goal.isActive && !today.isBefore(start) && !today.isAfter(end);

    return SizedBox(
      height: 200.0,
      child: LineChart(
        LineChartData(
          minX: 0.0,
          maxX: maxX,
          minY: minY,
          maxY: maxY,
          clipData: const FlClipData.all(),
          borderData: FlBorderData(show: false),
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: (maxY - minY) / 4.0,
            getDrawingHorizontalLine: (value) => FlLine(color: Colors.grey.shade800, strokeWidth: 0.5),
          ),
          lineBarsData: [
            // Idealer Verlauf: gleichmäßig vom Start bis zur Deadline.
            LineChartBarData(
              spots: [FlSpot(x(goal.startDate), 0.0), FlSpot(x(goal.endDate), goal.goalAmount)],
              color: Colors.grey.shade500,
              barWidth: 1.2,
              dashArray: [6, 6],
              dotData: const FlDotData(show: false),
            ),
            LineChartBarData(
              spots: dueSpots,
              color: Colors.greenAccent,
              barWidth: 2.5,
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(show: true, color: Colors.greenAccent.withOpacity(0.12)),
            ),
            if (plannedSpots.length >= 2)
              LineChartBarData(
                spots: plannedSpots,
                color: Colors.greenAccent.withOpacity(0.6),
                barWidth: 2.0,
                dashArray: [4, 4],
                dotData: const FlDotData(show: false),
              ),
          ],
          extraLinesData: ExtraLinesData(
            horizontalLines: [
              HorizontalLine(
                y: goal.goalAmount,
                color: Colors.amberAccent,
                strokeWidth: 1.2,
                dashArray: [6, 4],
                // "Ziel" rechts unter der Linie, "Heute" oben an der senkrechten Linie: so überlappen sie nie.
                label: HorizontalLineLabel(
                  show: true,
                  alignment: Alignment.bottomRight,
                  style: const TextStyle(color: Colors.amberAccent, fontSize: 10.0),
                  labelResolver: (line) => AppLocalizations.of(context).translate('ziel'),
                ),
              ),
            ],
            verticalLines: [
              if (showToday)
                VerticalLine(
                  x: x(today),
                  color: Colors.orangeAccent,
                  strokeWidth: 1.0,
                  dashArray: [4, 4],
                  label: VerticalLineLabel(
                    show: true,
                    alignment: Alignment.topRight,
                    style: const TextStyle(color: Colors.orangeAccent, fontSize: 10.0),
                    labelResolver: (line) => AppLocalizations.of(context).translate('heute'),
                  ),
                ),
            ],
          ),
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 50.0,
                interval: (maxY - minY) / 4.0,
                getTitlesWidget: (double value, TitleMeta meta) {
                  if (value == meta.max) {
                    return const SizedBox();
                  }
                  return SideTitleWidget(
                    axisSide: meta.axisSide,
                    space: 4.0,
                    child: Text(
                      formatToMoneyAmount(value.toString(), withoutDecimalPlaces: 0),
                      style: TextStyle(color: Colors.grey.shade500, fontSize: 9.0),
                    ),
                  );
                },
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 24.0,
                interval: max(maxX / 2.0, 1.0),
                getTitlesWidget: (double value, TitleMeta meta) {
                  final DateTime date = start.add(Duration(days: value.round()));
                  return SideTitleWidget(
                    axisSide: meta.axisSide,
                    space: 6.0,
                    child: Text(
                      DateFormatter.dateFormatDDMMYYDateTime(date, context),
                      style: TextStyle(color: Colors.grey.shade500, fontSize: 9.0),
                    ),
                  );
                },
              ),
            ),
          ),
          lineTouchData: LineTouchData(
            touchTooltipData: LineTouchTooltipData(
              getTooltipColor: (LineBarSpot spot) => Colors.grey.shade800,
              fitInsideHorizontally: true,
              fitInsideVertically: true,
              getTooltipItems: (List<LineBarSpot> touchedSpots) {
                return touchedSpots.map((LineBarSpot spot) {
                  // Nur die Gespart-Linien beschriften, nicht die Ideallinie.
                  if (spot.barIndex == 0) {
                    return null;
                  }
                  final DateTime date = start.add(Duration(days: spot.x.round()));
                  return LineTooltipItem(
                    '${DateFormatter.dateFormatDDMMYYDateTime(date, context)}\n${formatToMoneyAmount(spot.y.toString())}',
                    const TextStyle(color: Colors.greenAccent, fontSize: 12.0, fontWeight: FontWeight.bold),
                  );
                }).toList();
              },
            ),
          ),
        ),
      ),
    );
  }
}
