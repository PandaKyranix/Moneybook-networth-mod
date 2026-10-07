import 'dart:math';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../../../core/utils/app_localizations.dart';
import '../../../../../core/utils/date_formatter.dart';
import '../../../../../core/utils/number_formatter.dart';
import '../../../domain/services/saldo_calculator.dart';

/// Balkendiagramm der Jahresansicht: pro Monat Einnahmen, Zurückgelegt und Ausgaben.
/// Zukünftige Monate zeigen die bereits geplanten Buchungen blasser an.
class YearlySaldoBarChart extends StatelessWidget {
  final List<MonthSaldo> months;
  final int year;
  final bool showSetAside;

  const YearlySaldoBarChart({
    super.key,
    required this.months,
    required this.year,
    required this.showSetAside,
  });

  static const Color incomeColor = Colors.greenAccent;
  static const Color setAsideColor = Colors.amberAccent;
  static const Color expenseColor = Colors.redAccent;

  List<_BarValue> _barValues(MonthSaldo month) {
    final SaldoSummary values = month.chartValues;
    return [
      _BarValue('einnahmen', values.income, incomeColor),
      if (showSetAside) _BarValue('zurückgelegt', values.setAside, setAsideColor),
      _BarValue('ausgaben', values.expense, expenseColor),
    ];
  }

  Widget _legendItem(BuildContext context, String key, Color color) {
    return Padding(
      padding: const EdgeInsets.only(right: 14.0),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 8.0, height: 8.0, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 5.0),
          Text(AppLocalizations.of(context).translate(key), style: TextStyle(fontSize: 11.0, color: Colors.grey.shade400)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final List<double> allValues = [0.0];
    for (final MonthSaldo month in months) {
      allValues.addAll(_barValues(month).map((bar) => bar.value));
    }
    double maxY = allValues.reduce(max);
    double minY = allValues.reduce(min);
    if (maxY == 0.0 && minY == 0.0) {
      maxY = 100.0;
    }
    maxY = maxY * 1.1;
    minY = minY < 0.0 ? minY * 1.1 : 0.0;
    final double interval = (maxY - minY) / 4.0;
    final DateTime now = DateTime.now();

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 6.0),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8.0, 12.0, 12.0, 8.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 8.0, bottom: 12.0),
              child: Wrap(
                runSpacing: 4.0,
                children: [
                  _legendItem(context, 'einnahmen', incomeColor),
                  if (showSetAside) _legendItem(context, 'zurückgelegt', setAsideColor),
                  _legendItem(context, 'ausgaben', expenseColor),
                ],
              ),
            ),
            SizedBox(
              height: 190.0,
              child: BarChart(
                BarChartData(
                  minY: minY,
                  maxY: maxY,
                  alignment: BarChartAlignment.spaceAround,
                  borderData: FlBorderData(show: false),
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    horizontalInterval: interval,
                    getDrawingHorizontalLine: (value) => FlLine(color: Colors.grey.shade800, strokeWidth: 0.5),
                  ),
                  titlesData: FlTitlesData(
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 50.0,
                        interval: interval,
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
                          final bool isCurrentMonth = now.year == year && now.month == month;
                          final String label = DateFormatter.dateFormatMMM(DateTime(year, month, 1), context);
                          return SideTitleWidget(
                            axisSide: meta.axisSide,
                            space: 4.0,
                            child: Text(
                              label.length > 3 ? label.substring(0, 3) : label,
                              style: TextStyle(
                                color: isCurrentMonth ? Colors.cyanAccent : Colors.grey.shade500,
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
                        final MonthSaldo month = months[groupIndex];
                        final List<_BarValue> bars = _barValues(month);
                        if (rodIndex >= bars.length) {
                          return null;
                        }
                        final _BarValue bar = bars[rodIndex];
                        return BarTooltipItem(
                          '${DateFormatter.dateFormatMMMM(DateTime(year, month.month, 1), context)}'
                          '${month.isFuture ? ' (${AppLocalizations.of(context).translate('geplant')})' : ''}\n'
                          '${AppLocalizations.of(context).translate(bar.labelKey)}: ${formatToMoneyAmount(bar.value.toString())}',
                          TextStyle(color: bar.color, fontSize: 12.0, fontWeight: FontWeight.bold),
                        );
                      },
                    ),
                  ),
                  barGroups: [
                    for (final MonthSaldo month in months)
                      BarChartGroupData(
                        x: month.month,
                        barsSpace: 1.5,
                        barRods: _barValues(month)
                            .map(
                              (bar) => BarChartRodData(
                                toY: bar.value,
                                color: month.isFuture ? bar.color.withOpacity(0.35) : bar.color,
                                width: showSetAside ? 4.5 : 6.0,
                                borderRadius: BorderRadius.zero,
                              ),
                            )
                            .toList(),
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

class _BarValue {
  final String labelKey;
  final double value;
  final Color color;

  const _BarValue(this.labelKey, this.value, this.color);
}
