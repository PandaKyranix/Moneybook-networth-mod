import 'package:flutter/material.dart';

import '../../../../core/consts/route_consts.dart';
import '../../../../core/utils/app_localizations.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../../../core/utils/number_formatter.dart';
import '../../../../shared/presentation/widgets/arguments/bottom_nav_bar_arguments.dart';
import '../../../../shared/presentation/widgets/deco/empty_list.dart';
import '../../../../shared/presentation/widgets/navigation_widgets/navigation_widget.dart';
import '../../../bookings/domain/entities/booking.dart';
import '../../../bookings/domain/value_objects/booking_type.dart';
import '../../data/datasources/balance_check_local_data_source.dart';
import '../../domain/services/balance_check.dart';
import '../../domain/services/net_worth_calculator.dart';

/// Kontostand-Prüfung: Zeigt Termine von Daueraufträgen, die wegen eines Fehlers der ursprünglichen App
/// vermutlich nie auf den Kontostand gebucht wurden, und bucht die ausgewählten nach.
class BalanceCheckPage extends StatefulWidget {
  const BalanceCheckPage({super.key});

  @override
  State<BalanceCheckPage> createState() => _BalanceCheckPageState();
}

class _BalanceCheckPageState extends State<BalanceCheckPage> {
  static const BalanceCheckLocalDataSource _dataSource = BalanceCheckLocalDataSource();
  BalanceCheckData? _data;
  List<Booking> _candidates = [];
  final Set<int> _selectedIds = {};
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final BalanceCheckData data = await _dataSource.load();
    if (!mounted) {
      return;
    }
    setState(() {
      _data = data;
      _candidates = data.missedSerieBookings(DateTime.now());
      _selectedIds
        ..clear()
        ..addAll(_candidates.map((booking) => booking.id));
    });
  }

  List<Booking> get _selected => _candidates.where((booking) => _selectedIds.contains(booking.id)).toList();

  Future<void> _confirmAndSave() async {
    final List<Booking> apply = _selected;
    final List<Booking> dismiss = _candidates.where((booking) => !_selectedIds.contains(booking.id)).toList();
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: Text(AppLocalizations.of(dialogContext).translate('kontostände_korrigieren')),
        content: Text(
          AppLocalizations.of(dialogContext)
              .translate('kontostände_korrigieren_bestätigen')
              .replaceAll('{nachbuchen}', '${apply.length}')
              .replaceAll('{korrekt}', '${dismiss.length}'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(AppLocalizations.of(dialogContext).translate('abbrechen')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(AppLocalizations.of(dialogContext).translate('ok'), style: const TextStyle(color: Colors.cyanAccent)),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) {
      return;
    }
    setState(() => _isSaving = true);
    await _dataSource.repair(apply: apply, dismiss: dismiss);
    if (!mounted) {
      return;
    }
    Navigator.pushNamedAndRemoveUntil(
      context,
      bottomNavBarRoute,
      (route) => false,
      arguments: BottomNavBarArguments(tabIndex: accountsTabIndex),
    );
  }

  String _accountsText(BuildContext context, Booking booking) {
    if (booking.type == BookingType.transfer || booking.type == BookingType.investment) {
      return '${AppLocalizations.of(context).translate(booking.fromAccount)} → ${AppLocalizations.of(context).translate(booking.toAccount)}';
    }
    return AppLocalizations.of(context).translate(booking.fromAccount);
  }

  Color _amountColor(Booking booking) {
    switch (booking.type) {
      case BookingType.expense:
        return Colors.redAccent;
      case BookingType.income:
        return Colors.greenAccent;
      case BookingType.transfer:
      case BookingType.investment:
      case BookingType.none:
        return Colors.cyanAccent;
    }
  }

  Widget _buildPreview(BuildContext context, BalanceCheckData data) {
    final Map<String, double> after = balancesAfterRepair(data.accountBalances, _selected);
    final Set<String> affected = {for (final Booking booking in _selected) ...accountBalanceChanges(booking).keys};
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16.0, 12.0, 16.0, 12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(AppLocalizations.of(context).translate('kontostände_danach'), style: TextStyle(fontSize: 12.0, color: Colors.grey.shade400)),
            const SizedBox(height: 6.0),
            if (affected.isEmpty)
              Text(AppLocalizations.of(context).translate('keine_änderung'), style: const TextStyle(fontSize: 13.0)),
            for (final String account in affected.toList()..sort())
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 2.0),
                child: Row(
                  children: [
                    Expanded(child: Text(AppLocalizations.of(context).translate(account), overflow: TextOverflow.ellipsis)),
                    Text(
                      formatToMoneyAmount((data.accountBalances[account] ?? 0.0).toString()),
                      style: TextStyle(fontSize: 13.0, color: Colors.grey.shade500),
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 6.0),
                      child: Icon(Icons.arrow_forward_rounded, size: 14.0, color: Colors.grey),
                    ),
                    Text(
                      formatToMoneyAmount((after[account] ?? 0.0).toString()),
                      style: const TextStyle(fontSize: 13.0, fontWeight: FontWeight.bold),
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
    final BalanceCheckData? data = _data;
    return Scaffold(
      appBar: AppBar(title: Text(AppLocalizations.of(context).translate('kontostände_prüfen'))),
      body: data == null
          ? const Center(child: CircularProgressIndicator())
          : _candidates.isEmpty
              ? EmptyList(
                  text: AppLocalizations.of(context).translate('kontostände_prüfen_nichts_gefunden'),
                  icon: Icons.verified_rounded,
                )
              : Column(
                  children: [
                    Expanded(
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(8.0, 8.0, 8.0, 16.0),
                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(8.0, 4.0, 8.0, 8.0),
                            child: Text(
                              AppLocalizations.of(context).translate('kontostände_prüfen_beschreibung'),
                              style: TextStyle(fontSize: 13.0, color: Colors.grey.shade300),
                            ),
                          ),
                          _buildPreview(context, data),
                          Row(
                            children: [
                              Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.only(left: 12.0),
                                  child: Text(
                                    '${_selectedIds.length} / ${_candidates.length} ${AppLocalizations.of(context).translate('ausgewählt')}',
                                    style: TextStyle(fontSize: 12.0, color: Colors.grey.shade400),
                                  ),
                                ),
                              ),
                              TextButton(
                                onPressed: () => setState(() {
                                  if (_selectedIds.length == _candidates.length) {
                                    _selectedIds.clear();
                                  } else {
                                    _selectedIds.addAll(_candidates.map((booking) => booking.id));
                                  }
                                }),
                                child: Text(AppLocalizations.of(context)
                                    .translate(_selectedIds.length == _candidates.length ? 'keine_auswählen' : 'alle_auswählen')),
                              ),
                            ],
                          ),
                          for (final Booking booking in _candidates)
                            Card(
                              margin: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 3.0),
                              child: CheckboxListTile(
                                value: _selectedIds.contains(booking.id),
                                activeColor: Colors.cyanAccent,
                                checkColor: Colors.black,
                                onChanged: (bool? selected) => setState(() {
                                  if (selected == true) {
                                    _selectedIds.add(booking.id);
                                  } else {
                                    _selectedIds.remove(booking.id);
                                  }
                                }),
                                title: Text(
                                  booking.title.trim().isNotEmpty ? booking.title : AppLocalizations.of(context).translate(booking.categorie),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                subtitle: Text(
                                  '${DateFormatter.dateFormatDDMMYYDateTime(booking.date, context)} · ${_accountsText(context, booking)}',
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(fontSize: 12.0, color: Colors.grey.shade500),
                                ),
                                secondary: Text(
                                  formatToMoneyAmount(booking.amount.toString()),
                                  style: TextStyle(color: _amountColor(booking)),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    SafeArea(
                      top: false,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16.0, 4.0, 16.0, 12.0),
                        child: SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.cyanAccent, foregroundColor: Colors.black87),
                            onPressed: _isSaving ? null : _confirmAndSave,
                            child: Text(
                              AppLocalizations.of(context).translate('auswahl_nachbuchen').replaceAll('{anzahl}', '${_selectedIds.length}'),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
    );
  }
}
