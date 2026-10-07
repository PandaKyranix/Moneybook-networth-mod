import 'package:animations/animations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:moneybook/features/accounts/presentation/pages/account_list_page.dart';
import 'package:moneybook/features/bookings/presentation/pages/booking_list_page.dart';
import 'package:moneybook/features/bookings/presentation/pages/create_booking_page.dart';
import 'package:moneybook/features/budgets/presentation/pages/budget_list_page.dart';
import 'package:moneybook/features/goals/presentation/pages/create_goal_page.dart';
import 'package:moneybook/features/goals/presentation/pages/goal_overview_page.dart';
import 'package:moneybook/features/statistics/presentation/pages/statistic_page.dart';
import 'package:moneybook/shared/presentation/widgets/animations/text_line_animation.dart';
import 'package:moneybook/shared/presentation/widgets/navigation_widgets/side_menu_drawer_widget.dart';

import '../../../../core/utils/app_localizations.dart';
import '../../../../features/bookings/domain/value_objects/amount_type.dart';
import '../../../../features/bookings/domain/value_objects/booking_type.dart';
import '../../../../features/bookings/presentation/bloc/booking_bloc.dart';
import '../../../domain/value_objects/period_mode.dart';
import 'period_selector_bar.dart';

// Tab-Reihenfolge der unteren Navigationsleiste.
const int bookingsTabIndex = 0;
const int accountsTabIndex = 1;
const int statisticsTabIndex = 2;
const int budgetsTabIndex = 3;
const int goalsTabIndex = 4;
const int numberOfTabs = 5;

class BottomNavBar extends StatefulWidget {
  final int tabIndex;

  /// Optional: Startmonat. Ohne Angabe wird der zuletzt gewählte Zeitraum (oder heute) verwendet.
  final DateTime? selectedDate;
  final BookingType bookingType;
  final AmountType amountType;

  BottomNavBar({
    super.key,
    required this.tabIndex,
    this.selectedDate,
    BookingType? bookingType,
    AmountType? amountType,
  })  : bookingType = bookingType ?? BookingType.expense,
        amountType = amountType ?? AmountType.overallExpense;

  @override
  State<BottomNavBar> createState() => _BottomNavBarState();
}


class _BottomNavBarState extends State<BottomNavBar> with TickerProviderStateMixin, WidgetsBindingObserver {
  late int _tabIndex;
  late TabController _tabController;
  late DateTime _selectedDate;
  late PeriodMode _periodMode;
  bool _fabAnimationIsFinished = true;

  @override
  void initState() {
    super.initState();
    _selectedDate = widget.selectedDate ?? PeriodMemory.selectedDate ?? DateTime.now();
    _periodMode = PeriodMemory.mode;
    _tabIndex = widget.tabIndex;
    _tabController = TabController(length: numberOfTabs, vsync: this);
    _tabController.animation!.addListener(_tabListener);
    _tabController.index = widget.tabIndex;
    WidgetsBinding.instance.addObserver(this as WidgetsBindingObserver);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this as WidgetsBindingObserver);
    _tabController.dispose();
    super.dispose();
  }

  void _onAppResumed() {
    BlocProvider.of<BookingBloc>(context).add(const HandleAndUpdateNewBookings());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _onAppResumed();
    }
  }

  void _tabListener() {
    if (_tabIndex != _tabController.animation!.value.round()) {
      setState(() {
        _tabIndex = _tabController.animation!.value.round();
      });
    }
  }

  void _onTabChange(int index) {
    setState(() {
      _tabIndex = index;
      _tabController.animateTo(index);
    });
  }

  void _onDateChanged(DateTime newDate) {
    setState(() {
      _selectedDate = newDate;
      PeriodMemory.selectedDate = newDate;
    });
  }

  void _onPeriodModeChanged(PeriodMode newMode) {
    setState(() {
      _periodMode = newMode;
      PeriodMemory.mode = newMode;
    });
  }

  // Aus der Jahresübersicht in einen bestimmten Monat springen.
  void _openMonth(DateTime month) {
    setState(() {
      _selectedDate = month;
      _periodMode = PeriodMode.month;
      PeriodMemory.selectedDate = month;
      PeriodMemory.mode = PeriodMode.month;
    });
  }

  bool get _showPeriodSelector => _tabIndex == bookingsTabIndex || _tabIndex == statisticsTabIndex || _tabIndex == budgetsTabIndex;

  String _setTitle() {
    switch (_tabIndex) {
      case bookingsTabIndex:
        return AppLocalizations.of(context).translate('buchungen');
      case accountsTabIndex:
        return AppLocalizations.of(context).translate('konten');
      case statisticsTabIndex:
        return AppLocalizations.of(context).translate('statistiken');
      case budgetsTabIndex:
        return AppLocalizations.of(context).translate('budgets');
      case goalsTabIndex:
        return AppLocalizations.of(context).translate('ziele');
      default:
        return '';
    }
  }

  void _handleOpen(BuildContext context, VoidCallback openContainer) {
    setState(() {
      _fabAnimationIsFinished = false;
    });
    Future.microtask(openContainer);
  }

  Widget _buildNavItem(int index, IconData icon, String labelKey) {
    final Color color = _tabIndex == index ? Colors.cyan.shade400 : Colors.white70;
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => _onTabChange(index),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(icon, size: 24.0, color: color),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                AppLocalizations.of(context).translate(labelKey),
                maxLines: 1,
                style: TextStyle(color: color, fontSize: 12.0),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: TextLineAnimation(
          key: ValueKey(_setTitle()),
          text: _setTitle(),
          letterDelayInMilliseconds: 20,
          offsetX: 40.0,
          style: const TextStyle(fontSize: 18.0),
        ),
        leading: Builder(
          builder: (context) {
            return IconButton(
              onPressed: () => Scaffold.of(context).openDrawer(),
              icon: const Icon(Icons.notes_rounded),
            );
          },
        ),
      ),
      floatingActionButton: OpenContainer(
        transitionDuration: const Duration(milliseconds: 400),
        closedShape: const CircleBorder(),
        closedColor: Colors.cyanAccent,
        onClosed: (_) {
          setState(() => _fabAnimationIsFinished = true);
        },
        openBuilder: (context, _) => _tabIndex == goalsTabIndex ? const CreateGoalPage() : const CreateBookingPage(),
        closedBuilder: (context, openContainer) => FloatingActionButton(
          onPressed: () => _handleOpen(context, openContainer),
          child: AnimatedOpacity(
            opacity: _fabAnimationIsFinished ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 1300),
            child: const Icon(Icons.add),
          ),
        ),
      ),
      // Der "+"-Button schwebt rechts über der Leiste, damit alle fünf Tabs gleich viel Platz haben.
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      body: TabBarView(
        controller: _tabController,
        children: [
          BookingListPage(
            selectedDate: _selectedDate,
            periodMode: _periodMode,
            onMonthSelected: _openMonth,
          ),
          const AccountListPage(),
          StatisticPage(
            selectedDate: _selectedDate,
            bookingType: widget.bookingType,
            amountType: widget.amountType,
          ),
          BudgetListPage(
            selectedDate: _selectedDate,
            periodMode: _periodMode,
          ),
          const GoalOverviewPage(),
        ],
      ),
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_showPeriodSelector)
            PeriodSelectorBar(
              selectedDate: _selectedDate,
              mode: _periodMode,
              allowYearMode: _tabIndex != statisticsTabIndex,
              onDateChanged: _onDateChanged,
              onModeChanged: _onPeriodModeChanged,
            ),
          BottomAppBar(
            padding: const EdgeInsets.symmetric(horizontal: 4.0),
            height: 60.0,
            child: Padding(
              padding: const EdgeInsets.only(top: 6.0),
              child: Row(
                children: <Widget>[
                  // Fünf gleich breite Tabs.
                  _buildNavItem(bookingsTabIndex, Icons.auto_stories_rounded, 'buchungen'),
                  _buildNavItem(accountsTabIndex, Icons.account_balance_wallet_rounded, 'konten'),
                  _buildNavItem(statisticsTabIndex, Icons.insights_rounded, 'statistiken'),
                  _buildNavItem(budgetsTabIndex, Icons.savings_rounded, 'budgets'),
                  _buildNavItem(goalsTabIndex, Icons.flag_rounded, 'ziele'),
                ],
              ),
            ),
          ),
        ],
      ),
      drawer: SideMenuDrawer(
        // Der Ziele-Tab hat keinen eigenen Menüeintrag; Index 4 ist im Menü "Kategorien".
        tabIndex: _tabIndex <= budgetsTabIndex ? _tabIndex : -1,
        onTabChange: (tabIndex) => _onTabChange(tabIndex),
      ),
    );
  }
}
