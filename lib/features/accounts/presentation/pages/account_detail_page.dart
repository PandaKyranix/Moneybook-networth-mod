import 'package:dartz/dartz.dart' show Either;
import 'package:flutter/material.dart';

import '../../../../core/consts/route_consts.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/utils/account_schema.dart';
import '../../../../core/utils/app_localizations.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../../../core/utils/number_formatter.dart';
import '../../../../injection_container.dart';
import '../../../../shared/domain/value_objects/serie_mode_type.dart';
import '../../../../shared/presentation/widgets/deco/empty_list.dart';
import '../../../bookings/domain/entities/booking.dart';
import '../../../bookings/domain/repositories/booking_repository.dart';
import '../../../bookings/domain/value_objects/booking_type.dart';
import '../../../bookings/presentation/widgets/page_arguments/edit_booking_page_arguments.dart';
import '../../domain/entities/account.dart';
import '../../domain/services/account_history.dart';
import '../../domain/value_objects/account_type.dart';
import '../widgets/page_arguments/edit_account_page_arguments.dart';

/// Kontoansicht: aktueller Kontostand und alle Buchungen des Kontos mit dem Kontostand nach jeder Buchung.
class AccountDetailPage extends StatefulWidget {
  final Account account;

  const AccountDetailPage({super.key, required this.account});

  @override
  State<AccountDetailPage> createState() => _AccountDetailPageState();
}

class _AccountDetailPageState extends State<AccountDetailPage> {
  AccountHistory? _history;
  bool _hasError = false;
  // Buchungen mit Konten abgeschlossener Ziele sind Historie und nicht mehr bearbeitbar.
  Set<String> _lockedAccountNames = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final Either<Failure, List<Booking>> result = await sl<BookingRepository>().loadAccountBookings(widget.account.name);
    final Set<String> lockedAccountNames = await loadArchivedAccountNames();
    if (!mounted) {
      return;
    }
    setState(() {
      _lockedAccountNames = lockedAccountNames;
      result.fold(
        (failure) => _hasError = true,
        (bookings) => _history = calculateAccountHistory(
          bookings: bookings,
          accountName: widget.account.name,
          currentBalance: widget.account.amount,
          now: DateTime.now(),
        ),
      );
    });
  }

  static Color _amountColor(double value) => value >= 0.0 ? Colors.greenAccent : Colors.redAccent;

  static String _signed(double value) {
    final String formatted = formatToMoneyAmount(value.toString());
    return value > 0.0 ? '+$formatted' : formatted;
  }

  String _subtitle(BuildContext context, AccountHistoryEntry entry) {
    final Booking booking = entry.booking;
    if (booking.type == BookingType.transfer || booking.type == BookingType.investment) {
      // Gegenkonto des Übertrags.
      return entry.change < 0.0
          ? '→ ${AppLocalizations.of(context).translate(booking.toAccount)}'
          : '← ${AppLocalizations.of(context).translate(booking.fromAccount)}';
    }
    return AppLocalizations.of(context).translate(booking.categorie);
  }

  bool _isEditable(Booking booking) => !_lockedAccountNames.contains(booking.fromAccount) && !_lockedAccountNames.contains(booking.toAccount);

  Widget _buildHeader(BuildContext context) {
    final Account account = widget.account;
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16.0, 14.0, 16.0, 14.0),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    AppLocalizations.of(context).translate('aktueller_kontostand'),
                    style: TextStyle(fontSize: 12.0, color: Colors.grey.shade400),
                  ),
                  const SizedBox(height: 4.0),
                  Text(
                    formatToMoneyAmount(account.amount.toString()),
                    style: TextStyle(fontSize: 22.0, fontWeight: FontWeight.bold, color: _amountColor(account.amount)),
                  ),
                  if (!account.includeInNetWorth)
                    Padding(
                      padding: const EdgeInsets.only(top: 4.0),
                      child: Row(
                        children: [
                          const Icon(Icons.lock_outline_rounded, size: 13.0, color: Colors.amberAccent),
                          const SizedBox(width: 4.0),
                          Text(
                            AppLocalizations.of(context).translate('nicht_im_vermögen'),
                            style: const TextStyle(fontSize: 11.0, color: Colors.amberAccent),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            Text(
              AppLocalizations.of(context).translate(account.type.name),
              style: TextStyle(fontSize: 12.0, color: Colors.grey.shade500),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String text) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12.0, 14.0, 12.0, 4.0),
      child: Text(text, style: const TextStyle(fontSize: 15.0, fontWeight: FontWeight.bold)),
    );
  }

  Widget _buildEntry(BuildContext context, AccountHistoryEntry entry) {
    final Booking booking = entry.booking;
    final bool editable = _isEditable(booking);
    final String title = booking.title.trim().isNotEmpty ? booking.title : AppLocalizations.of(context).translate(booking.categorie);
    return Opacity(
      opacity: entry.isPending ? 0.6 : 1.0,
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 3.0),
        child: InkWell(
          borderRadius: BorderRadius.circular(12.0),
          onTap: editable
              ? () => Navigator.pushNamed(context, editBookingRoute, arguments: EditBookingPageArguments(booking, SerieModeType.one))
              : null,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12.0, 10.0, 14.0, 10.0),
            child: Row(
              children: [
                SizedBox(
                  width: 52.0,
                  child: Text(
                    DateFormatter.dateFormatEEDD(booking.date, context),
                    style: TextStyle(fontSize: 12.0, color: Colors.grey.shade400),
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14.0)),
                      const SizedBox(height: 2.0),
                      Text(
                        entry.isPending ? '${_subtitle(context, entry)} · ${AppLocalizations.of(context).translate('geplant')}' : _subtitle(context, entry),
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 12.0, color: Colors.grey.shade500),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8.0),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      _signed(entry.change),
                      style: TextStyle(fontSize: 14.0, color: _amountColor(entry.change)),
                    ),
                    const SizedBox(height: 2.0),
                    // Kontostand direkt nach dieser Buchung.
                    Text(
                      formatToMoneyAmount(entry.balanceAfter.toString()),
                      style: TextStyle(fontSize: 12.0, color: Colors.grey.shade400),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _buildEntries(BuildContext context, AccountHistory history) {
    final List<Widget> widgets = [];
    final List<AccountHistoryEntry> pending = history.entries.where((entry) => entry.isPending).toList();
    final List<AccountHistoryEntry> booked = history.entries.where((entry) => !entry.isPending).toList();
    if (pending.isNotEmpty) {
      widgets.add(_buildSectionHeader(AppLocalizations.of(context).translate('ausstehend')));
      widgets.addAll(pending.map((entry) => _buildEntry(context, entry)));
    }
    DateTime? currentMonth;
    for (final AccountHistoryEntry entry in booked) {
      final DateTime month = DateTime(entry.booking.date.year, entry.booking.date.month, 1);
      if (currentMonth == null || month != currentMonth) {
        currentMonth = month;
        widgets.add(_buildSectionHeader(DateFormatter.dateFormatMMMMYYYY(month, context)));
      }
      widgets.add(_buildEntry(context, entry));
    }
    widgets.add(
      Padding(
        padding: const EdgeInsets.fromLTRB(16.0, 12.0, 18.0, 4.0),
        child: Row(
          children: [
            Expanded(
              child: Text(
                AppLocalizations.of(context).translate('anfangsbestand'),
                style: TextStyle(fontSize: 12.0, color: Colors.grey.shade500),
              ),
            ),
            Text(
              formatToMoneyAmount(history.openingBalance.toString()),
              style: TextStyle(fontSize: 12.0, color: Colors.grey.shade400),
            ),
          ],
        ),
      ),
    );
    return widgets;
  }

  @override
  Widget build(BuildContext context) {
    final AccountHistory? history = _history;
    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context).translate(widget.account.name)),
        actions: [
          IconButton(
            tooltip: AppLocalizations.of(context).translate('konto_bearbeiten'),
            icon: const Icon(Icons.edit_rounded),
            onPressed: () => Navigator.pushNamed(context, editAccountRoute, arguments: EditAccountPageArguments(widget.account)),
          ),
        ],
      ),
      body: _hasError
          ? Center(child: Text(AppLocalizations.of(context).translate('fehler_beim_laden')))
          : history == null
              ? const Center(child: CircularProgressIndicator())
              : ListView(
                  padding: const EdgeInsets.fromLTRB(8.0, 8.0, 8.0, 32.0),
                  children: [
                    _buildHeader(context),
                    if (history.entries.isEmpty)
                      SizedBox(
                        height: 220.0,
                        child: EmptyList(
                          text: AppLocalizations.of(context).translate('noch_keine_buchungen_für_konto'),
                          icon: Icons.receipt_long_rounded,
                        ),
                      )
                    else
                      ..._buildEntries(context, history),
                  ],
                ),
    );
  }
}
