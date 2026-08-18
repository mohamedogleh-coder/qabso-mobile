import '../time_slots_model.dart';

/// One booking found by searching for a customer's phone number.
///
/// Read from `search_bookings_by_phone_fn`. Carries only enough to pick the
/// right booking out of a list and ring the person who made it — the whole
/// record is a tap away in the details sheet, which takes nothing but the id.
class BookingSearchResultModel {
  final int eventId;

  /// The number the booking was found by. A walk-in's is recorded on the
  /// payment itself; a signed-in customer's comes from their account.
  final String phoneNumber;

  final DateTime eventStart;
  final DateTime eventEnd;

  /// What to call the booking now. A booking whose time has passed comes back
  /// as completed, so this is not always what the database stores.
  final EventStatus eventStatus;

  const BookingSearchResultModel({
    required this.eventId,
    required this.phoneNumber,
    required this.eventStart,
    required this.eventEnd,
    required this.eventStatus,
  });

  factory BookingSearchResultModel.fromJson(Map<String, dynamic> json) {
    return BookingSearchResultModel(
      eventId: json['event_id'] as int,
      phoneNumber: json['phone_number'] as String,
      eventStart: DateTime.parse(json['event_start'].toString()),
      eventEnd: DateTime.parse(json['event_end'].toString()),
      eventStatus: EventStatus.fromString(json['event_status'] as String),
    );
  }
}
