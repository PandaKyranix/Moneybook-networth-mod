import 'package:flutter/material.dart';
import 'package:month_picker_dialog/month_picker_dialog.dart';

import '../../../../core/utils/app_localizations.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../../domain/value_objects/period_mode.dart';

/// Wischbare Monats- bzw. Jahresleiste über der Tab-Leiste mit Umschalter "Monat" / "Jahr".
/// Angelehnt an die Navigation im haushaltsbuch_budget_tracker, aber im Moneybook-Stil.
class PeriodSelectorBar extends StatefulWidget {
  static const double height = 54.0;

  final DateTime selectedDate;
  final PeriodMode mode;

  /// Auf Tabs ohne Jahresansicht (Statistiken) wird nur der Monat angezeigt.
  final bool allowYearMode;
  final ValueChanged<DateTime> onDateChanged;
  final ValueChanged<PeriodMode> onModeChanged;

  const PeriodSelectorBar({
    super.key,
    required this.selectedDate,
    required this.mode,
    required this.onDateChanged,
    required this.onModeChanged,
    this.allowYearMode = true,
  });

  @override
  State<PeriodSelectorBar> createState() => _PeriodSelectorBarState();
}

class _PeriodSelectorBarState extends State<PeriodSelectorBar> {
  // Große Startseite, damit in beide Richtungen fast beliebig weit gewischt werden kann.
  static const int _centerPage = 10000;
  late PageController _pageController;
  late DateTime _anchorDate;
  late PeriodMode _anchorMode;

  PeriodMode get _effectiveMode => widget.allowYearMode ? widget.mode : PeriodMode.month;

  @override
  void initState() {
    super.initState();
    _anchorDate = widget.selectedDate;
    _anchorMode = _effectiveMode;
    _pageController = PageController(initialPage: _centerPage, viewportFraction: 0.3);
  }

  @override
  void didUpdateWidget(PeriodSelectorBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_effectiveMode != _anchorMode) {
      // Modus gewechselt: Leiste neu am gewählten Datum ausrichten.
      _anchorDate = widget.selectedDate;
      _anchorMode = _effectiveMode;
      if (_pageController.hasClients) {
        _pageController.jumpToPage(_centerPage);
      }
      return;
    }
    if (_pageController.hasClients) {
      final int targetPage = _pageForDate(widget.selectedDate);
      final double? currentPage = _pageController.page;
      if (currentPage != null && currentPage.round() != targetPage) {
        _pageController.jumpToPage(targetPage);
      }
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  DateTime _dateForPage(int page) => shiftPeriod(_anchorDate, _anchorMode, page - _centerPage);

  int _pageForDate(DateTime date) => _centerPage + periodDistance(_anchorDate, date, _anchorMode);

  void _onPageChanged(int page) {
    final DateTime date = _dateForPage(page);
    if (!isSamePeriod(date, widget.selectedDate, PeriodMode.month)) {
      widget.onDateChanged(date);
    }
  }

  void _selectDate(DateTime date) {
    if (!isSamePeriod(date, widget.selectedDate, PeriodMode.month)) {
      widget.onDateChanged(date);
    }
    if (_pageController.hasClients) {
      _pageController.jumpToPage(_pageForDate(date));
    }
  }

  Future<void> _openMonthPicker(BuildContext context) async {
    final DateTime? date = await showMonthPicker(
      context: context,
      initialDate: widget.selectedDate,
      monthPickerDialogSettings: MonthPickerDialogSettings(
        headerSettings: PickerHeaderSettings(
          headerCurrentPageTextStyle: const TextStyle(fontSize: 16.0),
          headerSelectedIntervalTextStyle: const TextStyle(fontSize: 20.0),
          headerBackgroundColor: Colors.black26,
        ),
        dialogSettings: PickerDialogSettings(
          dismissible: true,
          dialogRoundedCornersRadius: 20.0,
          dialogBackgroundColor: Colors.black26,
        ),
        dateButtonsSettings: PickerDateButtonsSettings(
          buttonBorder: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(80.0)),
          ),
          selectedMonthBackgroundColor: Colors.cyanAccent,
          selectedMonthTextColor: Colors.white,
          unselectedMonthsTextColor: Colors.white70,
          currentMonthTextColor: Colors.cyanAccent,
          yearTextStyle: const TextStyle(fontSize: 15.0),
          monthTextStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15.0),
        ),
        actionBarSettings: PickerActionBarSettings(
          buttonSpacing: 12.0,
          customDivider: const Divider(height: 1.0),
          confirmWidget: Text(AppLocalizations.of(context).translate('ok'), style: const TextStyle(color: Colors.cyanAccent)),
          cancelWidget: Text(AppLocalizations.of(context).translate('abbrechen'), style: const TextStyle(color: Colors.grey)),
        ),
      ),
    );
    if (date != null && mounted) {
      _selectDate(DateTime(date.year, date.month, 1));
    }
  }

  Future<void> _openYearPicker(BuildContext context) async {
    final int currentYear = DateTime.now().year;
    final List<int> years = [for (int year = currentYear + 5; year >= currentYear - 15; year--) year];
    final int? year = await showDialog<int>(
      context: context,
      builder: (BuildContext dialogContext) {
        return SimpleDialog(
          title: Text(AppLocalizations.of(dialogContext).translate('zeitraum_jahr_auswählen')),
          children: [
            SizedBox(
              width: 280.0,
              height: 320.0,
              child: ListView(
                children: years
                    .map(
                      (year) => ListTile(
                        title: Text(
                          '$year',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: year == widget.selectedDate.year ? Colors.cyanAccent : Colors.white,
                            fontWeight: year == widget.selectedDate.year ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                        onTap: () => Navigator.pop(dialogContext, year),
                      ),
                    )
                    .toList(),
              ),
            ),
          ],
        );
      },
    );
    if (year != null && mounted) {
      _selectDate(DateTime(year, widget.selectedDate.month, 1));
    }
  }

  void _onSelectedTap(BuildContext context) {
    if (_anchorMode == PeriodMode.month) {
      _openMonthPicker(context);
    } else {
      _openYearPicker(context);
    }
  }

  Widget _buildItem(BuildContext context, int page) {
    final DateTime date = _dateForPage(page);
    final bool isSelected = isSamePeriod(date, widget.selectedDate, _anchorMode);
    final bool isMonthMode = _anchorMode == PeriodMode.month;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        if (isSelected) {
          _onSelectedTap(context);
        } else {
          _pageController.animateToPage(page, duration: const Duration(milliseconds: 300), curve: Curves.easeOutCubic);
        }
      },
      child: Center(
        child: isSelected
            ? Card(
                margin: const EdgeInsets.symmetric(horizontal: 2.0, vertical: 4.0),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10.0),
                  side: const BorderSide(color: Colors.cyanAccent, width: 0.6),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: isMonthMode
                      ? Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text('${date.year}', style: TextStyle(fontSize: 10.0, color: Colors.grey.shade400)),
                            Text(
                              DateFormatter.dateFormatMMM(date, context),
                              style: const TextStyle(fontSize: 14.0, fontWeight: FontWeight.bold, color: Colors.cyanAccent),
                            ),
                          ],
                        )
                      : Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6.0),
                          child: Text(
                            '${date.year}',
                            style: const TextStyle(fontSize: 15.0, fontWeight: FontWeight.bold, color: Colors.cyanAccent),
                          ),
                        ),
                  ),
                ),
              )
            : Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Beim Jahreswechsel das Jahr klein über dem Monat anzeigen.
                  if (isMonthMode && date.year != widget.selectedDate.year)
                    Text('${date.year}', style: TextStyle(fontSize: 9.0, color: Colors.grey.shade600)),
                  Text(
                    isMonthMode ? DateFormatter.dateFormatMMM(date, context) : '${date.year}',
                    style: TextStyle(fontSize: 13.0, color: Colors.grey.shade400),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildModeToggle(BuildContext context) {
    final bool isMonthMode = widget.mode == PeriodMode.month;
    return InkWell(
      borderRadius: BorderRadius.circular(10.0),
      onTap: () => widget.onModeChanged(isMonthMode ? PeriodMode.year : PeriodMode.month),
      child: SizedBox(
        width: 58.0,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isMonthMode ? Icons.calendar_month_rounded : Icons.date_range_rounded,
              size: 20.0,
              color: Colors.cyanAccent,
            ),
            const SizedBox(height: 2.0),
            Text(
              AppLocalizations.of(context).translate(isMonthMode ? 'zeitraum_monat' : 'zeitraum_jahr'),
              style: const TextStyle(fontSize: 11.0, color: Colors.cyanAccent),
            ),
          ],
        ),
      ),
    );
  }

  // Springt zum aktuellen Monat bzw. Jahr.
  Widget _buildTodayButton(BuildContext context) {
    final DateTime now = DateTime.now();
    final bool isCurrent = isSamePeriod(now, widget.selectedDate, _anchorMode);
    final Color color = isCurrent ? Colors.grey.shade600 : Colors.cyanAccent;
    return InkWell(
      borderRadius: BorderRadius.circular(10.0),
      onTap: isCurrent ? null : () => _selectDate(DateTime(now.year, now.month, 1)),
      child: SizedBox(
        width: 58.0,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.today_rounded, size: 20.0, color: color),
            const SizedBox(height: 2.0),
            Text(AppLocalizations.of(context).translate('heute'), style: TextStyle(fontSize: 11.0, color: color)),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: PeriodSelectorBar.height,
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        border: Border(top: BorderSide(color: Colors.grey.shade800, width: 0.5)),
      ),
      child: Row(
        children: [
          Expanded(
            child: PageView.builder(
              controller: _pageController,
              onPageChanged: _onPageChanged,
              itemBuilder: _buildItem,
            ),
          ),
          _buildTodayButton(context),
          if (widget.allowYearMode) _buildModeToggle(context),
          const SizedBox(width: 4.0),
        ],
      ),
    );
  }
}
