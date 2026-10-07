import 'package:dartz/dartz.dart' show Either;
import 'package:flutter/material.dart';

import '../../../../../core/error/failures.dart';
import '../../../../../core/utils/app_localizations.dart';
import '../../../../../injection_container.dart';
import '../../../domain/entities/booking.dart';
import '../../../domain/repositories/booking_repository.dart';
import '../../../domain/services/saldo_calculator.dart';
import '../cards/month_saldo_card.dart';
import '../cards/pending_monthly_card.dart';
import '../charts/yearly_saldo_bar_chart.dart';

/// Jahresansicht im Buchungen-Tab: Balkendiagramm (Einnahmen / Zurückgelegt / Ausgaben pro Monat)
/// und darunter für jeden Monat die Zusammensetzung des Saldos.
class YearlyBookingOverview extends StatefulWidget {
  final int year;
  final Set<String> excludedAccountNames;
  final bool showSetAside;
  final ValueChanged<DateTime>? onMonthSelected;

  const YearlyBookingOverview({
    super.key,
    required this.year,
    required this.excludedAccountNames,
    required this.showSetAside,
    this.onMonthSelected,
  });

  @override
  State<YearlyBookingOverview> createState() => _YearlyBookingOverviewState();
}

class _YearlyBookingOverviewState extends State<YearlyBookingOverview> {
  List<Booking>? _bookings;
  bool _hasError = false;
  int _loadRequest = 0;

  @override
  void initState() {
    super.initState();
    _loadBookings();
  }

  @override
  void didUpdateWidget(YearlyBookingOverview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.year != oldWidget.year) {
      // build() folgt automatisch, daher hier kein setState nötig.
      _bookings = null;
      _hasError = false;
      _loadBookings();
    }
  }

  Future<void> _loadBookings() async {
    final int request = ++_loadRequest;
    final Either<Failure, List<Booking>> result = await sl<BookingRepository>().loadBookingsBetween(
      DateTime(widget.year, 1, 1),
      DateTime(widget.year, 12, 31),
    );
    // Nur das Ergebnis der letzten Anfrage anzeigen (schnelles Wischen zwischen Jahren).
    if (!mounted || request != _loadRequest) {
      return;
    }
    setState(() {
      result.fold(
        (failure) => _hasError = true,
        (bookings) => _bookings = bookings,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_hasError) {
      return Center(child: Text(AppLocalizations.of(context).translate('fehler_beim_laden')));
    }
    final List<Booking>? bookings = _bookings;
    if (bookings == null) {
      return const Center(child: CircularProgressIndicator());
    }
    final List<MonthSaldo> months = calculateYearlySaldo(
      bookings: bookings,
      excludedAccountNames: widget.excludedAccountNames,
      year: widget.year,
      now: DateTime.now(),
    );
    final SaldoSummary yearTotal = months.fold(SaldoSummary.zero, (total, month) => total + month.due);

    return ListView(
      padding: const EdgeInsets.only(bottom: 40.0),
      children: [
        SizedBox(
          height: 70.0,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              PendingMonthlyCard(
                title: AppLocalizations.of(context).translate('einnahmen'),
                pendingMonthlyValue: yearTotal.income,
                textColor: Colors.greenAccent,
              ),
              PendingMonthlyCard(
                title: AppLocalizations.of(context).translate('ausgaben'),
                pendingMonthlyValue: yearTotal.expense,
                textColor: Colors.redAccent,
              ),
              if (widget.showSetAside)
                PendingMonthlyCard(
                  title: AppLocalizations.of(context).translate('zurückgelegt'),
                  pendingMonthlyValue: yearTotal.setAside,
                  textColor: Colors.amberAccent,
                ),
              PendingMonthlyCard(
                title: AppLocalizations.of(context).translate('jahressaldo'),
                pendingMonthlyValue: yearTotal.balance,
                textColor: yearTotal.balance >= 0.0 ? Colors.greenAccent : Colors.redAccent,
              ),
            ],
          ),
        ),
        YearlySaldoBarChart(
          months: months,
          year: widget.year,
          showSetAside: widget.showSetAside,
        ),
        for (final MonthSaldo month in months)
          MonthSaldoCard(
            monthSaldo: month,
            year: widget.year,
            showSetAside: widget.showSetAside,
            onTap: widget.onMonthSelected == null ? null : () => widget.onMonthSelected!(DateTime(widget.year, month.month, 1)),
          ),
      ],
    );
  }
}
