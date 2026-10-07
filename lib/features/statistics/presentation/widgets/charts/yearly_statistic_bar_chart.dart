import 'dart:math';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../../../core/utils/app_localizations.dart';
import '../../../../../core/utils/date_formatter.dart';
import '../../../../../core/utils/number_formatter.dart';

/// Jahresansicht der Statistik: Summe der ausgewählten Buchungsart (z.B. Ausgaben / Fix) pro Monat,
/// mit gestrichelter Linie für den Monatsdurchschnitt.
class YearlyStatisticBarChart extends StatelessWidget {
  /// 12 Werte, Januar bis Dezember.
  final List<double> monthlyAmounts;
  final int year;
  final Color color;

  const YearlyStatisticBarChart({
    super.key,
    required this.monthlyAmounts,
    required this.year,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final double total = monthlyAmounts.fold(0.0, (sum, value) => sum + value);
    final int monthsWithValues = monthlyAmounts.where((value) => value != 0.0).length;
    final double average = monthsWithValues == 0 ? 0.0 : total / monthsWithValues;
    final double maxValue = monthlyAmounts.fold(0.0, (double current, double value) => max(current, value));
    final double maxY = maxValue == 0.0 ? 100.0 : maxValue * 1.15;
    final DateTime now = DateTime.now();

    return Card(
      margin: const EdgeInsets.fromLTRB(4.0, 6.0, 4.0, 6.0),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8.0, 12.0, 12.0, 8.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 8.0, bottom: 12.0),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '${AppLocalizations.of(context).translate('gesamt')} $year: ${formatToMoneyAmount(total.toString())}',
                      style: TextStyle(fontSize: 13.0, color: color, fontWeight: FontWeight.bold),
                    ),
                  ),
                  Text(
                    'Ø ${formatToMoneyAmount(average.toString())} ${AppLocalizations.of(context).translate('pro_monat')}',
                    style: TextStyle(fontSize: 11.0, color: Colors.grey.shade400),
                  ),
                ],
              ),
            ),
            SizedBox(
              height: 170.0,
              child: BarChart(
                BarChartData(
                  minY: 0.0,
                  maxY: maxY,
                  alignment: BarChartAlignment.spaceAround,
                  borderData: FlBorderData(show: false),
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    horizontalInterval: maxY / 4.0,
                    getDrawingHorizontalLine: (value) => FlLine(color: Colors.grey.shade800, strokeWidth: 0.5),
                  ),
                  extraLinesData: ExtraLinesData(
                    horizontalLines: [
                      if (average > 0.0) HorizontalLine(y: average, color: Colors.orange, strokeWidth: 1.0, dashArray: [5, 5]),
                    ],
                  ),
                  titlesData: FlTitlesData(
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 50.0,
                        interval: maxY / 4.0,
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
                        reservedSize: 22.0,
                        getTitlesWidget: (double value, TitleMeta meta) {
                          final int month = value.toInt();
                          if (month < 1 || month > 12) {
                            return const SizedBox();
                          }
                          final String label = DateFormatter.dateFormatMMM(DateTime(year, month, 1), context);
                          return SideTitleWidget(
                            axisSide: meta.axisSide,
                            space: 4.0,
                            child: Text(
                              label.length > 3 ? label.substring(0, 3) : label,
                              style: TextStyle(
                                color: now.year == year && now.month == month ? Colors.cyanAccent : Colors.grey.shade500,
                                fontSize: 9.0,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  barTouchData: BarTouchData(
                    touchTooltipData: BarTouchTooltipData(
                      getTooltipColor: (BarChartGroupData group) => Colors.grey.shade800,
                      fitInsideHorizontally: true,
                      fitInsideVertically: true,
                      getTooltipItem: (BarChartGroupData group, int groupIndex, BarChartRodData rod, int rodIndex) {
                        return BarTooltipItem(
                          '${DateFormatter.dateFormatMMMM(DateTime(year, group.x, 1), context)}\n${formatToMoneyAmount(rod.toY.toString())}',
                          TextStyle(color: color, fontSize: 12.0, fontWeight: FontWeight.bold),
                        );
                      },
                    ),
                  ),
                  barGroups: [
                    for (int month = 1; month <= 12; month++)
                      BarChartGroupData(
                        x: month,
                        barRods: [
                          BarChartRodData(
                            toY: monthlyAmounts[month - 1],
                            color: color,
                            width: 10.0,
                            borderRadius: const BorderRadius.vertical(top: Radius.circular(3.0)),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
