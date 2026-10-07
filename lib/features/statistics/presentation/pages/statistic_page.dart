import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:moneybook/core/consts/common_consts.dart';
import 'package:moneybook/features/statistics/presentation/widgets/buttons/booking_type_segmented_button.dart';
import 'package:moneybook/shared/presentation/widgets/deco/empty_list.dart';

import 'package:dartz/dartz.dart' show Either;

import '../../../../core/error/failures.dart';
import '../../../../core/utils/app_localizations.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../../../injection_container.dart';
import '../../../../shared/domain/value_objects/period_mode.dart';
import '../../../bookings/domain/repositories/booking_repository.dart';
import '../../../bookings/domain/entities/booking.dart';
import '../../../bookings/domain/value_objects/amount_type.dart';
import '../../../bookings/domain/value_objects/booking_type.dart';
import '../../../bookings/presentation/bloc/booking_bloc.dart';
import '../../domain/entities/amount_type_stats.dart';
import '../../domain/entities/categorie_stats.dart';
import '../bloc/categorie_stats_bloc.dart';
import '../widgets/cards/categorie_percentage_card.dart';
import '../widgets/charts/categorie_pie_chart.dart';
import '../widgets/charts/indicator.dart';
import '../widgets/charts/yearly_statistic_bar_chart.dart';

class StatisticPage extends StatefulWidget {
  final DateTime selectedDate;
  final BookingType bookingType;
  final AmountType amountType;
  final PeriodMode periodMode;

  const StatisticPage({
    super.key,
    required this.selectedDate,
    required this.bookingType,
    required this.amountType,
    this.periodMode = PeriodMode.month,
  });

  @override
  State<StatisticPage> createState() => _StatisticPageState();
}

class _StatisticPageState extends State<StatisticPage> with TickerProviderStateMixin {
  BookingType _selectedBookingType = BookingType.expense;
  AmountType _selectedAmountType = AmountType.overallExpense;
  List<AmountTypeStats> _amountTypeStats = [];
  List<CategorieStats> _categorieStats = [];
  bool _categorieFound = false;
  double _overallAmount = 0.0;
  late final AnimationController _animationController;
  late final Animation<Offset> _offsetAnimation;
  static bool _hasAnimated = false;
  // Jahresansicht: Buchungen des gewählten Jahres (direkt geladen, damit der gemeinsame BookingBloc
  // der Monatsansichten nicht verändert wird).
  List<Booking>? _yearBookings;
  int? _requestedYear;
  int? _loadedYear;

  bool get _isYearMode => widget.periodMode == PeriodMode.year;

  Future<void> _loadYearBookings(int year) async {
    if (_requestedYear == year) {
      return;
    }
    _requestedYear = year;
    final Either<Failure, List<Booking>> result = await sl<BookingRepository>().loadBookingsBetween(DateTime(year, 1, 1), DateTime(year, 12, 31));
    if (!mounted || _requestedYear != year) {
      return;
    }
    setState(() {
      _yearBookings = result.fold((failure) => <Booking>[], (bookings) => bookings);
      _loadedYear = year;
    });
  }

  /// Gleiche Auswahl wie bei der Kategorie-Statistik (Buchungsart und Betragsart).
  bool _matchesSelection(Booking booking) {
    if (booking.type != _selectedBookingType) {
      return false;
    }
    return booking.amountType.name == _selectedAmountType.name ||
        _selectedAmountType.name == AmountType.overallExpense.name ||
        _selectedAmountType.name == AmountType.overallIncome.name;
  }

  List<double> _monthlyAmounts(List<Booking> bookings) {
    final List<double> amounts = List<double>.filled(12, 0.0);
    for (final Booking booking in bookings) {
      if (booking.date.year == widget.selectedDate.year && _matchesSelection(booking)) {
        amounts[booking.date.month - 1] += booking.amount;
      }
    }
    return amounts;
  }

  Color _selectionColor() {
    if (_selectedBookingType == BookingType.income) {
      return Colors.greenAccent;
    } else if (_selectedBookingType == BookingType.investment) {
      return Colors.cyanAccent;
    }
    return Colors.redAccent;
  }

  @override
  void initState() {
    super.initState();
    _selectedBookingType = widget.bookingType;
    _selectedAmountType = widget.amountType;

    _animationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _offsetAnimation = Tween<Offset>(
      begin: const Offset(0.0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
    ));

    if (!_hasAnimated) {
      _animationController.forward();
      _hasAnimated = true;
    } else {
      _animationController.value = 1.0;
    }
  }

  void _loadMonthlyBookings(BuildContext context) {
    BlocProvider.of<BookingBloc>(context).add(
      LoadSortedMonthlyBookings(widget.selectedDate),
    );
  }

  void _addCategoryStat(Booking booking) {
    _categorieFound = false;
    _overallAmount += booking.amount;
    for (int j = 0; j < _categorieStats.length; j++) {
      if (AppLocalizations.of(context).translate(_categorieStats[j].categorie).contains(AppLocalizations.of(context).translate(booking.categorie))) {
        _categorieStats[j].amount += booking.amount;
        _categorieFound = true;
        break;
      }
    }
    if (_categorieFound == false) {
      CategorieStats newCategorieStat = CategorieStats(
        categorie: booking.categorie,
        bookingType: booking.type,
        amount: booking.amount,
        percentage: 0.0,
      );
      _categorieStats.add(newCategorieStat);
    }
  }

  void _calculateCategoryStats(List<Booking> bookings) {
    _categorieFound = false;
    _overallAmount = 0.0;
    _categorieStats = [];
    for (int i = 0; i < bookings.length; i++) {
      if (bookings[i].type == _selectedBookingType && bookings[i].amountType.name == _selectedAmountType.name) {
        _addCategoryStat(bookings[i]);
      } else if (bookings[i].type == _selectedBookingType && _selectedAmountType.name == AmountType.overallExpense.name) {
        _addCategoryStat(bookings[i]);
      } else if (bookings[i].type == _selectedBookingType && _selectedAmountType.name == AmountType.overallIncome.name) {
        _addCategoryStat(bookings[i]);
      }
    }
    // Für jede Kategorie Prozentwert berechnen
    for (int i = 0; i < _categorieStats.length; i++) {
      _categorieStats[i].percentage = (_categorieStats[i].amount / _overallAmount) * 100;
    }
    _categorieStats.sort((first, second) => second.percentage.compareTo(first.percentage));
  }

  void _calculateAmountTypeStats(List<Booking> bookings, BookingType bookingType) {
    _amountTypeStats.clear();
    if (bookingType.pluralName == BookingType.expense.pluralName) {
      _amountTypeStats.add(AmountTypeStats(amountType: AmountType.overallExpense, amount: 0.0, percentage: 0.0));
      _amountTypeStats.add(AmountTypeStats(amountType: AmountType.variable, amount: 0.0, percentage: 0.0));
      _amountTypeStats.add(AmountTypeStats(amountType: AmountType.fix, amount: 0.0, percentage: 0.0));
    } else if (bookingType.pluralName == BookingType.income.pluralName) {
      _amountTypeStats.add(AmountTypeStats(amountType: AmountType.overallIncome, amount: 0.0, percentage: 0.0));
      _amountTypeStats.add(AmountTypeStats(amountType: AmountType.active, amount: 0.0, percentage: 0.0));
      _amountTypeStats.add(AmountTypeStats(amountType: AmountType.passive, amount: 0.0, percentage: 0.0));
    } else if (bookingType.pluralName == BookingType.investment.pluralName) {
      _amountTypeStats.add(AmountTypeStats(amountType: AmountType.buy, amount: 0.0, percentage: 0.0));
      _amountTypeStats.add(AmountTypeStats(amountType: AmountType.sale, amount: 0.0, percentage: 0.0));
    }
    for (int i = 0; i < bookings.length; i++) {
      if (bookings[i].type.name == BookingType.expense.name && bookingType.pluralName == BookingType.expense.pluralName) {
        if (bookings[i].amountType == AmountType.variable) {
          _amountTypeStats[1].amount += bookings[i].amount;
        } else if (bookings[i].amountType == AmountType.fix) {
          _amountTypeStats[2].amount += bookings[i].amount;
        }
        _amountTypeStats[0].amount += bookings[i].amount;
      } else if (bookings[i].type.name == BookingType.income.name && bookingType.pluralName == BookingType.income.pluralName) {
        if (bookings[i].amountType == AmountType.active) {
          _amountTypeStats[1].amount += bookings[i].amount;
        } else if (bookings[i].amountType == AmountType.passive) {
          _amountTypeStats[2].amount += bookings[i].amount;
        }
        _amountTypeStats[0].amount += bookings[i].amount;
      } else if (bookings[i].type.name == BookingType.investment.name && bookingType.pluralName == BookingType.investment.pluralName) {
        if (bookings[i].amountType == AmountType.buy) {
          _amountTypeStats[0].amount += bookings[i].amount;
        } else if (bookings[i].amountType == AmountType.sale) {
          _amountTypeStats[1].amount += bookings[i].amount;
        }
      }
    }
    if (_selectedBookingType != BookingType.investment) {
      // Für jeden AmountType Prozentwert berechnen
      for (int i = 0; i < _amountTypeStats.length; i++) {
        if (_amountTypeStats[0].amount == 0.0) {
          _amountTypeStats[i].percentage = 0.0;
        } else {
          _amountTypeStats[i].percentage = (_amountTypeStats[i].amount / _amountTypeStats[0].amount) * 100;
        }
      }
    }
  }

  void _onBookingTypeChanged(BookingType newBookingType) {
    setState(() {
      _selectedBookingType = newBookingType;
      if (_selectedBookingType == BookingType.expense) {
        _selectedAmountType = AmountType.overallExpense;
      } else if (_selectedBookingType == BookingType.income) {
        _selectedAmountType = AmountType.overallIncome;
      } else if (_selectedBookingType == BookingType.investment) {
        _selectedAmountType = AmountType.buy;
      }
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Widget _buildStatistics(BuildContext context, List<Booking> bookings) {
    return Column(
                children: [
                  SlideTransition(
                    position: _offsetAnimation,
                    child: FadeTransition(
                      opacity: _animationController,
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 6.0),
                        child: Card(
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                flex: 3,
                                child: CategoriePieChart(
                                  categorieStats: _categorieStats,
                                  bookingType: _selectedBookingType,
                                  amountType: _selectedAmountType,
                                ),
                              ),
                              Expanded(
                                flex: 2,
                                child: Padding(
                                  padding: const EdgeInsets.only(right: 6.0, top: 20.0, bottom: 6.0),
                                  child: Column(
                                    children: <Widget>[
                                      ..._amountTypeStats.map((amountTypeStat) {
                                        return GestureDetector(
                                          onTap: () {
                                            setState(() {
                                              _selectedAmountType = amountTypeStat.amountType;
                                              _calculateCategoryStats(bookings);
                                            });
                                          },
                                          child: Indicator(
                                            amountTypeStat: amountTypeStat,
                                            color: Colors.white,
                                            text: _selectedAmountType.name,
                                          ),
                                        );
                                      }),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  SlideTransition(
                    position: _offsetAnimation,
                    child: FadeTransition(
                      opacity: _animationController,
                      child: BookingTypeSegmentedButton(
                        selectedBookingType: _selectedBookingType,
                        onBookingTypeChanged: (Set<BookingType> newBookingType) {
                          setState(() {
                            _selectedBookingType = newBookingType.first;
                            _calculateAmountTypeStats(bookings, _selectedBookingType);
                            _onBookingTypeChanged(_selectedBookingType);
                          });
                        },
                      ),
                    ),
                  ),
                  _categorieStats.isNotEmpty
                      ? Expanded(
                          child: AnimationLimiter(
                            key: ValueKey('${_selectedAmountType}_${widget.selectedDate}'),
                            child: ListView.builder(
                              // Jahresansicht: erst der Monatsverlauf, dann die Kategorien.
                              itemCount: _categorieStats.length + (_isYearMode ? 1 : 0),
                              itemBuilder: (BuildContext context, int listIndex) {
                                if (_isYearMode && listIndex == 0) {
                                  return YearlyStatisticBarChart(
                                    monthlyAmounts: _monthlyAmounts(bookings),
                                    year: widget.selectedDate.year,
                                    color: _selectionColor(),
                                  );
                                }
                                final int index = _isYearMode ? listIndex - 1 : listIndex;
                                return AnimationConfiguration.staggeredList(
                                  position: index,
                                  duration: const Duration(milliseconds: staggeredListDurationInMs),
                                  child: SlideAnimation(
                                    verticalOffset: 30.0,
                                    curve: Curves.easeOut,
                                    child: FadeInAnimation(
                                      child: CategoriePercentageCard(
                                        categorieStats: _categorieStats[index],
                                        index: index,
                                        selectedDate: widget.selectedDate,
                                        amountType: _selectedAmountType,
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        )
                      : Expanded(
                          child: EmptyList(
                            text: AppLocalizations.of(context).translate('noch_keine_buchungen_für') +
                                '\n${_isYearMode ? '${widget.selectedDate.year}' : DateFormatter.dateFormatYMMMM(widget.selectedDate, context)}',
                            icon: Icons.donut_small,
                          ),
                        ),
                ],
);
  }

  @override
  Widget build(BuildContext context) {
    if (_isYearMode) {
      final int year = widget.selectedDate.year;
      _loadYearBookings(year);
      final List<Booking>? yearBookings = _yearBookings;
      if (yearBookings == null || _loadedYear != year) {
        return const Center(child: CircularProgressIndicator());
      }
      _calculateCategoryStats(yearBookings);
      _calculateAmountTypeStats(yearBookings, _selectedBookingType);
      return _buildStatistics(context, yearBookings);
    }
    _loadMonthlyBookings(context);
    return BlocBuilder<BookingBloc, BookingState>(
      builder: (context, bookingState) {
        if (bookingState is Loaded) {
          _calculateCategoryStats(bookingState.bookings);
          _calculateAmountTypeStats(bookingState.bookings, _selectedBookingType);
          return BlocBuilder<CategorieStatsBloc, CategorieStatsState>(
            builder: (context, state) => _buildStatistics(context, bookingState.bookings),
          );
        }
        return const SizedBox();
      },
    );
  }
}
