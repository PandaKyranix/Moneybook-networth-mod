import 'dart:math';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../../../core/utils/app_localizations.dart';
import '../../../../../core/utils/number_formatter.dart';
import '../../../domain/entities/booking.dart';
import '../../../domain/services/saldo_calculator.dart';

/// Liniendiagramm: Wie sich der Monatssaldo über die Tage des Monats entwickelt.
/// Startet bei 0 und endet beim Wert der Saldo-Karte. Ausstehende Buchungen werden gestrichelt angezeigt.
class MonthlySaldoLineChart extends StatelessWidget {
  final List<Booking> bookings;
  final Set<String> excludedAccountNames;
  final DateTime selectedDate;

  const MonthlySaldoLineChart({
    super.key,
    required this.bookings,
    required this.excludedAccountNames,
    required this.selectedDate,
  });

  static const Color _positiveColor = Colors.greenAccent;
  static const Color _negativeColor = Colors.redAccent;

  /// Linienfarbe grün über 0 und rot unter 0. Der Farbverlauf bezieht sich auf das Rechteck um die Linie.
  static Gradient? _signGradient(List<FlSpot> spots) {
    final double minY = spots.map((spot) => spot.y).reduce(min);
    final double maxY = spots.map((spot) => spot.y).reduce(max);
    if (minY >= 0.0 || maxY <= 0.0 || maxY == minY) {
      return null;
    }
    final double zero = (0.0 - minY) / (maxY - minY);
    return LinearGradient(
      begin: Alignment.bottomCenter,
      end: Alignment.topCenter,
      colors: const [_negativeColor, _negativeColor, _positiveColor, _positiveColor],
      stops: [0.0, zero, zero, 1.0],
    );
  }

  static Color _signColor(List<FlSpot> spots) {
    final double maxY = spots.map((spot) => spot.y).reduce(max);
    return maxY <= 0.0 && spots.any((spot) => spot.y < 0.0) ? _negativeColor : _positiveColor;
  }

  LineChartBarData _buildLine(List<FlSpot> spots, {required bool isPending}) {
    return LineChartBarData(
      spots: spots,
      isCurved: false,
      barWidth: 2.5,
      color: _signGradient(spots) == null ? _signColor(spots) : null,
      gradient: _signGradient(spots),
      dashArray: isPending ? [5, 5] : null,
      dotData: const FlDotData(show: false),
      belowBarData: BarAreaData(
        show: !isPending,
        color: _positiveColor.withOpacity(0.15),
        cutOffY: 0.0,
        applyCutOffY: true,
      ),
      aboveBarData: BarAreaData(
        show: !isPending,
        color: _negativeColor.withOpacity(0.15),
        cutOffY: 0.0,
        applyCutOffY: true,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final MonthlySaldoSeries series = calculateMonthlySaldoSeries(
      bookings: bookings,
      excludedAccountNames: excludedAccountNames,
      year: selectedDate.year,
      month: selectedDate.month,
      now: DateTime.now(),
    );
    final int days = series.daysInMonth;
    final List<FlSpot> dueSpots = [for (int day = 0; day <= series.lastDueDay; day++) FlSpot(day.toDouble(), series.values[day])];
    final List<FlSpot> pendingSpots = series.hasPendingChanges
        ? [for (int day = series.lastDueDay; day <= days; day++) FlSpot(day.toDouble(), series.values[day])]
        : <FlSpot>[];
    final List<double> shownValues = [0.0, ...dueSpots.map((spot) => spot.y), ...pendingSpots.map((spot) => spot.y)];
    double minY = shownValues.reduce(min);
    double maxY = shownValues.reduce(max);
    final double padding = max((maxY - minY) * 0.12, 10.0);
    minY = minY < 0.0 ? minY - padding : 0.0;
    maxY = maxY > 0.0 ? maxY + padding : padding;
    final double range = maxY - minY;

    final List<LineChartBarData> lines = [];
    if (dueSpots.length >= 2) {
      lines.add(_buildLine(dueSpots, isPending: false));
    }
    if (pendingSpots.length >= 2) {
      lines.add(_buildLine(pendingSpots, isPending: true));
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(4.0, 8.0, 4.0, 4.0),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8.0, 10.0, 14.0, 6.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(left: 8.0, bottom: 8.0),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        AppLocalizations.of(context).translate('saldo_verlauf'),
                        style: TextStyle(color: Colors.grey.shade400, fontSize: 12.0),
                      ),
                    ),
                    if (series.hasPendingChanges)
                      Padding(
                        padding: const EdgeInsets.only(right: 10.0),
                        child: Text(
                          '${AppLocalizations.of(context).translate('prognose')}: ${formatToMoneyAmount(series.projectedBalance.toString())}',
                          style: TextStyle(color: Colors.grey.shade500, fontSize: 11.0),
                        ),
                      ),
                    Text(
                      formatToMoneyAmount(series.dueBalance.toString()),
                      style: TextStyle(
                        color: series.dueBalance >= 0.0 ? _positiveColor : _negativeColor,
                        fontSize: 13.0,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(
                height: 150.0,
                child: LineChart(
                  LineChartData(
                    minX: 0.0,
                    maxX: days.toDouble(),
                    minY: minY,
                    maxY: maxY,
                    lineBarsData: lines,
                    borderData: FlBorderData(show: false),
                    gridData: FlGridData(
                      show: true,
                      drawVerticalLine: false,
                      horizontalInterval: range / 4.0,
                      getDrawingHorizontalLine: (value) => FlLine(color: Colors.grey.shade800, strokeWidth: 0.5),
                    ),
                    extraLinesData: ExtraLinesData(
                      horizontalLines: [
                        HorizontalLine(y: 0.0, color: Colors.grey.shade500, strokeWidth: 0.8),
                      ],
                    ),
                    titlesData: FlTitlesData(
                      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 52.0,
                          interval: range / 4.0,
                          getTitlesWidget: (double value, TitleMeta meta) {
                            // Nur volle Gitterlinien beschriften, nicht die automatisch ergänzten Ränder.
                            if (value == meta.min || value == meta.max) {
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
                          interval: 1.0,
                          getTitlesWidget: (double value, TitleMeta meta) {
                            final int day = value.round();
                            // Beschriftet werden der 1. sowie jeder 5. Tag; Tag 0 (Monatsanfang) und Tage zu nah am 1. nicht.
                            if (value != day.toDouble() || day < 1 || day > days || !(day == 1 || day % 5 == 0)) {
                              return const SizedBox();
                            }
                            return SideTitleWidget(
                              axisSide: meta.axisSide,
                              space: 4.0,
                              child: Text(
                                '$day.${selectedDate.month}.',
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
                            final int day = spot.x.round();
                            return LineTooltipItem(
                              '${day == 0 ? AppLocalizations.of(context).translate('monatsanfang') : '$day.${selectedDate.month}.'}\n'
                              '${formatToMoneyAmount(spot.y.toString())}',
                              TextStyle(
                                color: spot.y >= 0.0 ? _positiveColor : _negativeColor,
                                fontSize: 12.0,
                                fontWeight: FontWeight.bold,
                              ),
                            );
                          }).toList();
                        },
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
