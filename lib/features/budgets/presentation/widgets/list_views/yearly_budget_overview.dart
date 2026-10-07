import 'dart:math';

import 'package:dartz/dartz.dart' show Either;
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:percent_indicator/percent_indicator.dart';

import '../../../../../core/consts/common_consts.dart';
import '../../../../../core/error/failures.dart';
import '../../../../../core/utils/app_localizations.dart';
import '../../../../../core/utils/date_formatter.dart';
import '../../../../../core/utils/number_formatter.dart';
import '../../../../../injection_container.dart';
import '../../../../../shared/presentation/widgets/deco/empty_list.dart';
import '../../../../bookings/domain/entities/booking.dart';
import '../../../../bookings/domain/repositories/booking_repository.dart';
import '../../../data/models/budget_model.dart';
import '../../../domain/repositories/budget_repository.dart';
import '../../../domain/services/budget_calculator.dart';
import '../text/text_with_vertical_divider.dart';

/// Jahresansicht im Budget-Tab. Das Jahresbudget ist die Summe der Monatsbudgets; der Verbrauch
/// wird pro Monat genau wie in der Monatsansicht berechnet und aufsummiert.
class YearlyBudgetOverview extends StatefulWidget {
  final int year;

  const YearlyBudgetOverview({super.key, required this.year});

  @override
  State<YearlyBudgetOverview> createState() => _YearlyBudgetOverviewState();
}

class _YearlyBudgetOverviewState extends State<YearlyBudgetOverview> {
  YearlyBudgetSummary? _summary;
  bool _hasError = false;
  int _loadRequest = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(YearlyBudgetOverview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.year != oldWidget.year) {
      _summary = null;
      _hasError = false;
      _load();
    }
  }

  Future<void> _load() async {
    final int request = ++_loadRequest;
    final DateTime from = DateTime(widget.year, 1, 1);
    final DateTime to = DateTime(widget.year, 12, 31);
    final Either<Failure, List<BudgetModel>> budgetsResult = await sl<BudgetRepository>().loadBetween(from, to);
    final Either<Failure, List<Booking>> bookingsResult = await sl<BookingRepository>().loadBookingsBetween(from, to);
    if (!mounted || request != _loadRequest) {
      return;
    }
    final List<BudgetModel>? budgets = budgetsResult.fold((failure) => null, (budgets) => budgets);
    final List<Booking>? bookings = bookingsResult.fold((failure) => null, (bookings) => bookings);
    setState(() {
      if (budgets == null || bookings == null) {
        _hasError = true;
      } else {
        _summary = calculateYearlyBudget(budgets: budgets, bookings: bookings, year: widget.year);
      }
    });
  }

  static Color _usageColor(double percentage) {
    if (percentage <= 75.0) {
      return Colors.green.withOpacity(0.9);
    } else if (percentage < 100.0) {
      return Colors.yellowAccent.withOpacity(0.7);
    }
    return Colors.redAccent;
  }

  Widget _buildOverviewCard(BuildContext context, YearlyBudgetSummary summary) {
    final Color color = _usageColor(summary.percentage);
    final int monthsWithBudget = summary.months.where((month) => month.hasBudget).length;
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20.0, 12.0, 12.0, 12.0),
        child: Row(
          children: [
            CircularPercentIndicator(
              radius: 56.0,
              lineWidth: 9.0,
              animation: true,
              animationDuration: budgetAnimationDurationInMs,
              curve: Curves.linearToEaseOut,
              percent: min(max(summary.percentage / 100.0, 0.0), 1.0),
              center: Text(
                '${summary.percentage.toStringAsFixed(1).replaceAll('.', ',')} %',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17.0),
              ),
              circularStrokeCap: CircularStrokeCap.round,
              progressColor: color,
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(left: 16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextWithVerticalDivider(
                      verticalDividerColor: color,
                      description: '${AppLocalizations.of(context).translate('jahresbudget')} ${widget.year}',
                      value: '${formatToMoneyAmount(summary.used.toString())} / ${formatToMoneyAmount(summary.budget.toString())}',
                    ),
                    TextWithVerticalDivider(
                      verticalDividerColor: summary.remaining >= 0.0 ? Colors.greenAccent : Colors.redAccent,
                      description: AppLocalizations.of(context).translate('verbleibend'),
                      value: formatToMoneyAmount(summary.remaining.toString()),
                    ),
                    TextWithVerticalDivider(
                      verticalDividerColor: Colors.cyanAccent,
                      description: AppLocalizations.of(context).translate('monate_mit_budget'),
                      value: '$monthsWithBudget / 12',
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

  Widget _buildChartCard(BuildContext context, YearlyBudgetSummary summary) {
    final double maxValue = summary.months.fold(0.0, (double current, MonthBudgetTotal month) => max(current, max(month.budget, month.used)));
    final double maxY = maxValue == 0.0 ? 100.0 : maxValue * 1.1;
    final DateTime now = DateTime.now();
    return Card(
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
                  _legendItem(context, 'budget', Colors.grey.shade500),
                  _legendItem(context, 'verbraucht', Colors.green),
                  _legendItem(context, 'überzogen', Colors.redAccent),
                ],
              ),
            ),
            SizedBox(
              height: 180.0,
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
                  titlesData: FlTitlesData(
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 46.0,
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
                          final String label = DateFormatter.dateFormatMMM(DateTime(widget.year, month, 1), context);
                          return SideTitleWidget(
                            axisSide: meta.axisSide,
                            space: 4.0,
                            child: Text(
                              label.length > 3 ? label.substring(0, 3) : label,
                              style: TextStyle(
                                color: now.year == widget.year && now.month == month ? Colors.cyanAccent : Colors.grey.shade500,
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
                        final MonthBudgetTotal month = summary.months[groupIndex];
                        return BarTooltipItem(
                          '${DateFormatter.dateFormatMMMM(DateTime(widget.year, month.month, 1), context)}\n'
                          '${AppLocalizations.of(context).translate('verbraucht')}: ${formatToMoneyAmount(month.used.toString())}\n'
                          '${AppLocalizations.of(context).translate('budget')}: ${formatToMoneyAmount(month.budget.toString())}',
                          const TextStyle(color: Colors.white, fontSize: 12.0, fontWeight: FontWeight.bold),
                        );
                      },
                    ),
                  ),
                  barGroups: [
                    for (final MonthBudgetTotal month in summary.months)
                      BarChartGroupData(
                        x: month.month,
                        barsSpace: 2.0,
                        barRods: [
                          BarChartRodData(toY: month.budget, color: Colors.grey.shade600, width: 6.0, borderRadius: BorderRadius.zero),
                          BarChartRodData(
                            toY: month.used,
                            color: month.used > month.budget ? Colors.redAccent : Colors.green,
                            width: 6.0,
                            borderRadius: BorderRadius.zero,
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ),
            const Divider(height: 18.0),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _statItem(context, 'minimum', summary.minUsed),
                _statItem(context, 'durchschnitt', summary.averageUsed),
                _statItem(context, 'maximum', summary.maxUsed),
              ],
            ),
          ],
        ),
      ),
    );
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

  Widget _statItem(BuildContext context, String key, double value) {
    return Column(
      children: [
        Text(AppLocalizations.of(context).translate(key), style: TextStyle(fontSize: 11.0, color: Colors.grey.shade500)),
        const SizedBox(height: 2.0),
        Text(formatToMoneyAmount(value.toString()), style: const TextStyle(fontSize: 13.0)),
      ],
    );
  }

  Widget _buildCategorieCard(BuildContext context, CategorieBudgetTotal categorie) {
    final Color color = categorie.remaining >= 0.0 ? Colors.green.withOpacity(0.9) : Colors.redAccent;
    return Card(
      child: ClipPath(
        clipper: ShapeBorderClipper(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0))),
        child: Container(
          decoration: BoxDecoration(border: Border(right: BorderSide(color: color, width: 3.5))),
          padding: const EdgeInsets.fromLTRB(14.0, 10.0, 14.0, 12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      AppLocalizations.of(context).translate(categorie.categorie),
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 15.0),
                    ),
                  ),
                  Text(
                    formatToMoneyAmount(categorie.remaining.toString()),
                    style: TextStyle(fontSize: 15.0, color: color),
                  ),
                ],
              ),
              const SizedBox(height: 4.0),
              Text(
                '${formatToMoneyAmount(categorie.used.toString())} / ${formatToMoneyAmount(categorie.budget.toString())}'
                ' · ${categorie.numberOfMonths} ${AppLocalizations.of(context).translate(categorie.numberOfMonths == 1 ? 'monat' : 'monate')}',
                style: TextStyle(fontSize: 12.0, color: Colors.grey.shade400),
              ),
              const SizedBox(height: 8.0),
              LinearPercentIndicator(
                padding: EdgeInsets.zero,
                lineHeight: 8.0,
                barRadius: const Radius.circular(4.0),
                percent: min(max(categorie.percentage / 100.0, 0.0), 1.0),
                progressColor: color,
                backgroundColor: Colors.grey.shade800,
                trailing: Padding(
                  padding: const EdgeInsets.only(left: 8.0),
                  child: Text(
                    '${categorie.percentage.toStringAsFixed(1).replaceAll('.', ',')} %',
                    style: const TextStyle(fontSize: 12.0),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_hasError) {
      return Center(child: Text(AppLocalizations.of(context).translate('fehler_beim_laden')));
    }
    final YearlyBudgetSummary? summary = _summary;
    if (summary == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (summary.categories.isEmpty) {
      return EmptyList(
        text: '${AppLocalizations.of(context).translate('noch_keine_budgets_für')}\n${widget.year} ${AppLocalizations.of(context).translate('vorhanden')}',
        icon: Icons.savings_rounded,
      );
    }
    return ListView(
      padding: const EdgeInsets.only(bottom: 40.0),
      children: [
        _buildOverviewCard(context, summary),
        _buildChartCard(context, summary),
        Padding(
          padding: const EdgeInsets.fromLTRB(16.0, 12.0, 16.0, 4.0),
          child: Text(
            AppLocalizations.of(context).translate('budgets_nach_kategorie'),
            style: const TextStyle(fontSize: 16.0, fontWeight: FontWeight.bold),
          ),
        ),
        for (final CategorieBudgetTotal categorie in summary.categories) _buildCategorieCard(context, categorie),
      ],
    );
  }
}
