import 'package:equatable/equatable.dart';

/// Everything the event widgets need to price and book one field's slots.
///
/// It exists so those widgets never read a provider of their own. A manager
/// builds it from [stadiumNotifierProvider] and the field being expanded; a
/// customer builds it from the stadium and field they were browsing. Both hand
/// over the same short set of facts, so the same widgets serve both without a
/// role branch anywhere near the UI.
///
/// Merchants are deliberately absent: they are reached through [stadiumId] —
/// the manager's payment sheet reads them from its own provider, the
/// customer's fetches them by stadium — so the numbers are never stale by the
/// time the money moves.
class BookingContextModel extends Equatable {
  const BookingContextModel({
    required this.stadiumId,
    required this.fieldId,
    required this.capacity,
    required this.cost,
    required this.allowHalfBooking,
  });

  final String stadiumId;
  final int fieldId;

  /// How many players the field holds. [cost] is charged per player, so the
  /// two together are the price of the slot.
  final int capacity;
  final double cost;

  /// The stadium's policy, not the customer's choice: when it is false the
  /// half-booking options never open and the slot is taken whole.
  final bool allowHalfBooking;

  /// What one slot costs — the same `capacity * cost` that `book_event_fn`
  /// works out server-side.
  double get slotPrice => capacity * cost;

  @override
  List<Object?> get props => [
    stadiumId,
    fieldId,
    capacity,
    cost,
    allowHalfBooking,
  ];
}
