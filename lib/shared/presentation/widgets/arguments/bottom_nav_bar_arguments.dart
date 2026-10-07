import '../../../../features/bookings/domain/value_objects/amount_type.dart';
import '../../../../features/bookings/domain/value_objects/booking_type.dart';

class BottomNavBarArguments {
  final int tabIndex;

  /// Optional: Ohne Angabe bleibt der zuletzt gewählte Monat / das Jahr erhalten.
  final DateTime? selectedDate;
  final BookingType bookingType;
  final AmountType amountType;

  BottomNavBarArguments({
    required this.tabIndex,
    this.selectedDate,
    BookingType? bookingType,
    AmountType? amountType,
  })  : bookingType = bookingType ?? BookingType.expense,
        amountType = amountType ?? AmountType.overallExpense;
}
