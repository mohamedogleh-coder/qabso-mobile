import 'package:equatable/equatable.dart';
import 'package:qabso_mobile/features/manager/events/time_slots_model.dart';

/// One booking in the signed-in user's history.
///
/// A booking has no user of its own in the database. It belongs to whoever
/// paid on it, so this row is really "a booking this user paid for".
class HistoryModel extends Equatable {
  final int eventId;
  final String stadiumName;
  final DateTime eventStart;
  final DateTime eventEnd;

  /// The status the screen should show. A booking whose time has passed
  /// comes back as completed, so this is not always what the database stores.
  final EventStatus eventStatus;

  /// What this user handed over on this booking, after any discount.
  /// Other people's payments on the same booking are not counted here.
  final double amountPaid;

  /// What the booking still owes. A half-booking waiting for the second
  /// team shows the other half here; a settled booking shows 0.
  final double remaining;

  const HistoryModel({
    required this.eventId,
    required this.stadiumName,
    required this.eventStart,
    required this.eventEnd,
    required this.eventStatus,
    required this.amountPaid,
    required this.remaining,
  });

  factory HistoryModel.fromJson(Map<String, dynamic> json) {
    return HistoryModel(
      eventId: json['event_id'] as int,
      stadiumName: json['stadium_name'] as String,
      eventStart: DateTime.parse(json['event_start'].toString()),
      eventEnd: DateTime.parse(json['event_end'].toString()),
      eventStatus: EventStatus.fromString(json['event_status'] as String),
      amountPaid: (json['amount_paid'] as num).toDouble(),
      remaining: (json['remaining'] as num).toDouble(),
    );
  }

  @override
  List<Object?> get props => [
    eventId,
    stadiumName,
    eventStart,
    eventEnd,
    eventStatus,
    amountPaid,
    remaining,
  ];
}
